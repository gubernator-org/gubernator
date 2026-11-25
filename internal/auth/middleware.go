package auth

import (
	"encoding/base64"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/gubernator-org/gubernator/internal/db"
)

const (
	ContextUserKey = "gbnt_auth_user"
)

// ExtractUserSession retrieves the authenticated user from JWT header, session cookie, or basic auth.
func ExtractUserSession(c *gin.Context) *UserSession {
	// 1. Check Context cache
	if val, exists := c.Get(ContextUserKey); exists {
		if session, ok := val.(*UserSession); ok {
			return session
		}
	}

	// 2. Check Bearer JWT Token
	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if session, err := ValidateToken(tokenStr); err == nil {
			c.Set(ContextUserKey, session)
			return session
		}

		// Also support cluster API token override as Admin
		expectedAPIToken := os.Getenv("GBNT_API_TOKEN")
		if expectedAPIToken == "" {
			expectedAPIToken = db.GetAPIToken()
		}
		if expectedAPIToken != "" && tokenStr == expectedAPIToken {
			adminSession := GenerateLocalAdminSession("api-client")
			c.Set(ContextUserKey, &adminSession)
			return &adminSession
		}
	}

	// 3. Check Query Parameter (?token=... or ?jwt=...) for iframes and websockets
	if tokenParam := c.Query("token"); tokenParam != "" {
		if session, err := ValidateToken(tokenParam); err == nil {
			c.Set(ContextUserKey, session)
			c.SetCookie("gbnt_session", tokenParam, 3600*24, "/", "", false, false)
			return session
		}
	}

	// 4. Check Session Cookie (`gbnt_session`)
	if cookie, err := c.Cookie("gbnt_session"); err == nil && cookie != "" {
		if session, err := ValidateToken(cookie); err == nil {
			c.Set(ContextUserKey, session)
			return session
		}
	}

	// 4. Check Basic Auth (Local Administrator fallback)
	username, password, hasBasic := c.Request.BasicAuth()
	if !hasBasic && strings.HasPrefix(authHeader, "Basic ") {
		payload, _ := base64.StdEncoding.DecodeString(strings.TrimPrefix(authHeader, "Basic "))
		pair := strings.SplitN(string(payload), ":", 2)
		if len(pair) == 2 {
			username, password, hasBasic = pair[0], pair[1], true
		}
	}

	if hasBasic {
		expectedUser := os.Getenv("GBNT_WEB_USER")
		if expectedUser == "" {
			expectedUser = "admin"
		}
		expectedPass := os.Getenv("GBNT_WEB_PASSWORD")
		if expectedPass == "" {
			expectedPass = "admin"
		}

		if username == expectedUser && password == expectedPass {
			adminSession := GenerateLocalAdminSession(username)
			c.Set(ContextUserKey, &adminSession)
			return &adminSession
		}

		// Try Active Directory / LDAP authentication on Basic Auth
		var ldapConfigs []db.LDAPConfig
		if db.DB != nil {
			if err := db.DB.Where("enabled = ?", true).Find(&ldapConfigs).Error; err == nil {
				for _, cfg := range ldapConfigs {
					if res, authErr := AuthenticateLDAP(cfg, username, password); authErr == nil {
						ldapSession := UserSession{
							Username:    res.Username,
							DisplayName: res.DisplayName,
							Email:       res.Email,
							Role:        res.Role,
							Provider:    "ldap:" + cfg.ID,
							Permissions: GetPermissions(res.Role),
						}
						c.Set(ContextUserKey, &ldapSession)
						return &ldapSession
					}
				}
			}
		}
	}
	return nil
}

// RequireAuth middleware ensures the request has a valid authenticated session.
func RequireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		session := ExtractUserSession(c)
		if session == nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required. Please log in.",
			})
			return
		}
		c.Next()
	}
}

// RequireRole middleware ensures the authenticated user has one of the allowed roles.
func RequireRole(roles ...Role) gin.HandlerFunc {
	return func(c *gin.Context) {
		session := ExtractUserSession(c)
		if session == nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required",
			})
			return
		}

		for _, r := range roles {
			if session.Role == r {
				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
			"error":     "Access denied: insufficient permissions for this operation",
			"user_role": session.Role,
			"required":  roles,
		})
	}
}

// OWASPSecureHeadersMiddleware injects OWASP ASVS / Secure Headers Project HTTP headers.
func OWASPSecureHeadersMiddleware(isWebUI bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "SAMEORIGIN")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()")
		c.Header("X-XSS-Protection", "0")
		if c.Request.TLS != nil || strings.EqualFold(c.GetHeader("X-Forwarded-Proto"), "https") {
			c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}
		if !isWebUI {
			c.Header("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		}
		c.Next()
	}
}

// MaxBodySizeMiddleware caps request body size to mitigate OWASP API4:2023 DoS attacks.
func MaxBodySizeMiddleware(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Body != nil && maxBytes > 0 {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		}
		c.Next()
	}
}

type authBucket struct {
	attempts    int
	windowStart time.Time
	blockedTil  time.Time
}

var (
	rateMu      sync.Mutex
	authBuckets = make(map[string]*authBucket)
)

// AuthRateLimitMiddleware applies OWASP ASVS V2.2 / API4 progressive rate limiting on login & MFA endpoints.
func AuthRateLimitMiddleware(maxAttempts int, window time.Duration) gin.HandlerFunc {
	if maxAttempts <= 0 {
		maxAttempts = 15
	}
	if window <= 0 {
		window = 5 * time.Minute
	}
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if ip == "" {
			ip = "unknown"
		}
		now := time.Now()
		rateMu.Lock()
		b, ok := authBuckets[ip]
		if !ok || now.Sub(b.windowStart) > window {
			b = &authBucket{windowStart: now}
			authBuckets[ip] = b
		}
		if now.Before(b.blockedTil) {
			retryAfter := int(time.Until(b.blockedTil).Seconds()) + 1
			rateMu.Unlock()
			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "OWASP Rate Limit: too many authentication attempts. Please retry later.",
				"retry_after": retryAfter,
			})
			return
		}
		b.attempts++
		if b.attempts > maxAttempts {
			b.blockedTil = now.Add(window)
			rateMu.Unlock()
			c.Header("Retry-After", strconv.Itoa(int(window.Seconds())))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "OWASP Rate Limit: temporary lockout active due to excessive authentication attempts.",
				"retry_after": int(window.Seconds()),
			})
			return
		}
		rateMu.Unlock()
		c.Next()
	}
}

// ResetAuthRateLimit clears rate limit counters for an IP after a successful authentication.
func ResetAuthRateLimit(ip string) {
	if ip == "" {
		return
	}
	rateMu.Lock()
	delete(authBuckets, ip)
	rateMu.Unlock()
}

// noinspection GoUnusedExportedFunction
// RequirePermission ensures the user has a specific boolean capability.
// TODO(rbac): This middleware is the future RBAC enforcement point (Phase 6-8 roadmap).
// It will be wired to route groups as granular permission checks replace the current role-based checks.
func RequirePermission(permCheck func(p Permissions) bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		session := ExtractUserSession(c)
		if session == nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required",
			})
			return
		}

		if !permCheck(session.Permissions) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":     "Access denied: your role does not have permission for this action",
				"user_role": session.Role,
			})
			return
		}

		c.Next()
	}
}
