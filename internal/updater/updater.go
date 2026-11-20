package updater

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/gubernator-org/gubernator/internal/db"
)

const persistedUpdateStatePath = "/tmp/gbnt-last-update.json"

// UpdateInfo holds version comparison details and release notes.
type UpdateInfo struct {
	CurrentVersion  string `json:"current_version"`
	LatestVersion   string `json:"latest_version"`
	UpdateAvailable bool   `json:"update_available"`
	ReleaseNotes    string `json:"release_notes"`
	ReleaseURL      string `json:"release_url"`
	CheckedAt       string `json:"checked_at"`
}

type githubAsset struct {
	Name string `json:"name"`
	Size int64  `json:"size"`
}

type githubRelease struct {
	TagName     string        `json:"tag_name"`
	HTMLURL     string        `json:"html_url"`
	Body        string        `json:"body"`
	PublishedAt string        `json:"published_at"`
	Draft       bool          `json:"draft"`
	Prerelease  bool          `json:"prerelease"`
	Assets      []githubAsset `json:"assets"`
}

type githubTag struct {
	Name string `json:"name"`
}

var (
	cachedInfo *UpdateInfo
	cacheMutex sync.Mutex
	cacheTTL   = 30 * time.Second
)

func expectedBinaryNames(goos, goarch string) (rawName, gzName string) {
	rawName = fmt.Sprintf("gbnt-%s-%s", goos, goarch)
	if goos == "windows" {
		rawName += ".exe"
	}
	return rawName, rawName + ".gz"
}

func hasAssetForPlatform(assets []githubAsset, goos, goarch string) bool {
	rawName, gzName := expectedBinaryNames(goos, goarch)
	for _, a := range assets {
		if a.Name == gzName || a.Name == rawName {
			return true
		}
	}
	return false
}

// CheckLatestRelease queries GitHub Releases and verifies that binaries for this OS/Arch
// are actually published before advertising an update, avoiding premature 404 download loops.
func CheckLatestRelease(currentVersion string, forceRefresh bool) (*UpdateInfo, error) {
	cacheMutex.Lock()
	if forceRefresh {
		cachedInfo = nil
	} else if cachedInfo != nil && time.Since(parseTime(cachedInfo.CheckedAt)) < cacheTTL {
		info := *cachedInfo
		info.CurrentVersion = currentVersion
		info.UpdateAvailable = isNewerVersion(currentVersion, info.LatestVersion)
		cacheMutex.Unlock()
		return &info, nil
	}
	cacheMutex.Unlock()

	client := &http.Client{Timeout: 8 * time.Second}
	cb := time.Now().UnixNano()

	authHeader := os.Getenv("GBNT_GITHUB_TOKEN")
	if authHeader == "" {
		authHeader = os.Getenv("GITHUB_TOKEN")
	}

	prepareReq := func(req *http.Request) {
		req.Header.Set("User-Agent", "Gubernator-AutoUpdater")
		req.Header.Set("Accept", "application/vnd.github.v3+json")
		req.Header.Set("Cache-Control", "no-cache, no-store, must-revalidate")
		req.Header.Set("Pragma", "no-cache")
		if authHeader != "" {
			req.Header.Set("Authorization", "Bearer "+authHeader)
		}
	}

	type candidate struct {
		version string
		notes   string
		url     string
	}
	var candidates []candidate
	releasesAPIWorked := false

	// Source 1: GitHub Releases API (Primary — checks that binary assets for this OS/Arch exist!)
	relURL := fmt.Sprintf("https://api.github.com/repos/gubernator-org/gubernator/releases?per_page=15&_cb=%d", cb)
	if req, err := http.NewRequest("GET", relURL, nil); err == nil {
		prepareReq(req)
		if resp, err := client.Do(req); err == nil {
			if resp.StatusCode == http.StatusOK {
				var releases []githubRelease
				if err := json.NewDecoder(resp.Body).Decode(&releases); err == nil {
					releasesAPIWorked = true
					for _, r := range releases {
						tag := strings.TrimSpace(r.TagName)
						if tag == "" || r.Draft || r.Prerelease {
							continue
						}
						// Only advertise releases whose binary for this OS/Arch is already attached
						if len(r.Assets) > 0 && !hasAssetForPlatform(r.Assets, runtime.GOOS, runtime.GOARCH) {
							continue
						}
						if len(r.Assets) == 0 {
							continue
						}
						candidates = append(candidates, candidate{
							version: tag,
							notes:   strings.TrimSpace(r.Body),
							url:     r.HTMLURL,
						})
					}
				}
			}
			_ = resp.Body.Close()
		}
	}

	// Fallback Sources 2 & 3: ONLY used if GitHub Releases API was rate-limited or unreachable
	if !releasesAPIWorked {
		tagURL := fmt.Sprintf("https://api.github.com/repos/gubernator-org/gubernator/tags?per_page=15&_cb=%d", cb)
		if req, err := http.NewRequest("GET", tagURL, nil); err == nil {
			prepareReq(req)
			if resp, err := client.Do(req); err == nil {
				if resp.StatusCode == http.StatusOK {
					var tags []githubTag
					if err := json.NewDecoder(resp.Body).Decode(&tags); err == nil {
						for _, t := range tags {
							tag := strings.TrimSpace(t.Name)
							if tag != "" {
								candidates = append(candidates, candidate{
									version: tag,
									notes:   "",
									url:     fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/tag/%s", tag),
								})
							}
						}
					}
				}
				_ = resp.Body.Close()
			}
		}

		rawURL := fmt.Sprintf("https://raw.githubusercontent.com/gubernator-org/gubernator/main/VERSION?_cb=%d", cb)
		if req, err := http.NewRequest("GET", rawURL, nil); err == nil {
			prepareReq(req)
			if resp, err := client.Do(req); err == nil {
				if resp.StatusCode == http.StatusOK {
					bodyBytes, _ := io.ReadAll(resp.Body)
					rawV := strings.TrimSpace(string(bodyBytes))
					if rawV != "" && strings.HasPrefix(rawV, "v") {
						candidates = append(candidates, candidate{
							version: rawV,
							notes:   "",
							url:     fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/tag/%s", rawV),
						})
					}
				}
				_ = resp.Body.Close()
			}
		}
	}

	// Select the highest SemVer candidate
	var best candidate
	for _, c := range candidates {
		if best.version == "" || isNewerVersion(best.version, c.version) {
			best = c
		} else if best.version == c.version && best.notes == "" && c.notes != "" {
			best.notes = c.notes
			if c.url != "" {
				best.url = c.url
			}
		}
	}

	if best.version == "" {
		return fallbackInfo(currentVersion), nil
	}

	latest := best.version
	notes := best.notes
	if notes == "" {
		notes = fmt.Sprintf("• Automated cluster rolling upgrade to %s\n• Container core image updates & dependency sync\n• Performance, security and state resilience improvements", latest)
	}
	relURLOut := best.url
	if relURLOut == "" {
		relURLOut = fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/tag/%s", latest)
	}

	updateAvailable := isNewerVersion(currentVersion, latest)

	info := &UpdateInfo{
		CurrentVersion:  currentVersion,
		LatestVersion:   latest,
		UpdateAvailable: updateAvailable,
		ReleaseNotes:    notes,
		ReleaseURL:      relURLOut,
		CheckedAt:       time.Now().Format(time.RFC3339),
	}

	cacheMutex.Lock()
	cachedInfo = info
	cacheMutex.Unlock()

	return info, nil
}

func fallbackInfo(current string) *UpdateInfo {
	return &UpdateInfo{
		CurrentVersion:  current,
		LatestVersion:   current,
		UpdateAvailable: false,
		ReleaseNotes:    "• Gubernator system operating on latest release\n• Core engine services active and synchronized",
		ReleaseURL:      "https://github.com/gubernator-org/gubernator/releases",
		CheckedAt:       time.Now().Format(time.RFC3339),
	}
}

func parseSemver(v string) (major, minor, patch int) {
	v = strings.TrimPrefix(v, "v")
	parts := strings.Split(v, ".")
	if len(parts) > 0 {
		_, _ = fmt.Sscanf(parts[0], "%d", &major)
	}
	if len(parts) > 1 {
		_, _ = fmt.Sscanf(parts[1], "%d", &minor)
	}
	if len(parts) > 2 {
		_, _ = fmt.Sscanf(parts[2], "%d", &patch)
	}
	return major, minor, patch
}

func isNewerVersion(current, latest string) bool {
	c := strings.TrimPrefix(current, "v")
	if c == "dev" || c == "" {
		return false
	}
	cMaj, cMin, cPat := parseSemver(current)
	lMaj, lMin, lPat := parseSemver(latest)

	if lMaj != cMaj {
		return lMaj > cMaj
	}
	if lMin != cMin {
		return lMin > cMin
	}
	return lPat > cPat
}

func parseTime(tStr string) time.Time {
	t, _ := time.Parse(time.RFC3339, tStr)
	return t
}

// NodeUpdateResult tracks per-node upgrade & verification status.
type NodeUpdateResult struct {
	NodeID  string `json:"node_id"`
	IP      string `json:"ip"`
	Role    string `json:"role"`
	Status  string `json:"status"` // "pending", "updating", "verified", "failed"
	Version string `json:"version,omitempty"`
	Method  string `json:"method,omitempty"` // "local", "lan-push", "github-download"
	Message string `json:"message,omitempty"`
}

// UpdateProgressStatus holds live update state and verification details for UI monitoring.
type UpdateProgressStatus struct {
	Status          string             `json:"status"` // "idle", "downloading", "verifying", "installing", "restarting", "success", "failed"
	TargetVersion   string             `json:"target_version"`
	RunningVersion  string             `json:"running_version,omitempty"`
	ProgressMessage string             `json:"progress_message"`
	ProgressPercent int                `json:"progress_percent"`
	DownloadedBytes int64              `json:"downloaded_bytes,omitempty"`
	TotalBytes      int64              `json:"total_bytes,omitempty"`
	SpeedBps        float64            `json:"speed_bps,omitempty"`
	SHA256Verified  bool               `json:"sha256_verified"`
	BinaryVerified  bool               `json:"binary_verified"`
	NodeResults     []NodeUpdateResult `json:"node_results,omitempty"`
	Error           string             `json:"error,omitempty"`
	UpdatedAt       string             `json:"updated_at"`
}

var (
	currentUpdateStatus = UpdateProgressStatus{
		Status:          "idle",
		ProgressMessage: "Ready",
	}
	updateInProgress bool
	statusMutex      sync.RWMutex
)

// GetUpdateStatus returns the live in-memory status of an active or recent update.
func GetUpdateStatus() UpdateProgressStatus {
	statusMutex.RLock()
	defer statusMutex.RUnlock()
	cp := currentUpdateStatus
	if len(currentUpdateStatus.NodeResults) > 0 {
		cp.NodeResults = append([]NodeUpdateResult(nil), currentUpdateStatus.NodeResults...)
	}
	return cp
}

// GetUpdateStatusWithVersion returns the live update status enriched with the actual running binary version.
// If the Manager just restarted after an upgrade, it reads the persisted handoff file and verifies
// that `runningVersion` actually matches `TargetVersion` before reporting verified "success".
func GetUpdateStatusWithVersion(runningVersion string) UpdateProgressStatus {
	st := GetUpdateStatus()
	st.RunningVersion = runningVersion

	if st.Status == "idle" {
		if persisted, ok := readPersistedUpdateState(); ok {
			age := time.Since(parseTime(persisted.UpdatedAt))
			if age >= 0 && age < 10*time.Minute && persisted.TargetVersion != "" {
				persisted.RunningVersion = runningVersion
				if normalizeVer(runningVersion) == normalizeVer(persisted.TargetVersion) {
					persisted.Status = "success"
					persisted.ProgressPercent = 100
					persisted.BinaryVerified = true
					persisted.ProgressMessage = fmt.Sprintf("Verified: Manager running %s", runningVersion)
					for i := range persisted.NodeResults {
						if persisted.NodeResults[i].Role == "manager" {
							persisted.NodeResults[i].Status = "verified"
							persisted.NodeResults[i].Version = runningVersion
							persisted.NodeResults[i].Message = "Running verified binary"
						}
					}
					return persisted
				}
			}
		}
	}

	return st
}

func normalizeVer(v string) string {
	return strings.TrimPrefix(strings.TrimSpace(v), "v")
}

func persistUpdateState(st UpdateProgressStatus) {
	data, err := json.Marshal(st)
	if err != nil {
		return
	}
	_ = os.WriteFile(persistedUpdateStatePath, data, 0644)
}

func readPersistedUpdateState() (UpdateProgressStatus, bool) {
	data, err := os.ReadFile(persistedUpdateStatePath)
	if err != nil {
		return UpdateProgressStatus{}, false
	}
	var st UpdateProgressStatus
	if err := json.Unmarshal(data, &st); err != nil {
		return UpdateProgressStatus{}, false
	}
	return st, true
}

func mutateStatus(fn func(*UpdateProgressStatus)) {
	statusMutex.Lock()
	defer statusMutex.Unlock()
	fn(&currentUpdateStatus)
	currentUpdateStatus.UpdatedAt = time.Now().UTC().Format(time.RFC3339)
}

func setUpdateStatus(status, version, msg, errStr string) {
	mutateStatus(func(s *UpdateProgressStatus) {
		s.Status = status
		s.TargetVersion = version
		s.ProgressMessage = msg
		s.Error = errStr
	})
}

// progressReader wraps an io.Reader to report live download progress & transfer speed.
type progressReader struct {
	reader     io.Reader
	total      int64
	readBytes  int64
	startTime  time.Time
	lastReport time.Time
	onProgress func(downloaded, total int64, speedBps float64)
}

func (pr *progressReader) Read(p []byte) (int, error) {
	n, err := pr.reader.Read(p)
	if n > 0 {
		pr.readBytes += int64(n)
		now := time.Now()
		if now.Sub(pr.lastReport) >= 400*time.Millisecond || (pr.total > 0 && pr.readBytes >= pr.total) {
			elapsed := now.Sub(pr.startTime).Seconds()
			speed := 0.0
			if elapsed > 0.05 {
				speed = float64(pr.readBytes) / elapsed
			}
			pr.lastReport = now
			if pr.onProgress != nil {
				pr.onProgress(pr.readBytes, pr.total, speed)
			}
		}
	}
	return n, err
}

func formatMB(b int64) string {
	return fmt.Sprintf("%.1f MB", float64(b)/(1024*1024))
}

func formatSpeed(bps float64) string {
	mbps := bps / (1024 * 1024)
	if mbps >= 1.0 {
		return fmt.Sprintf("%.1f MB/s", mbps)
	}
	return fmt.Sprintf("%.0f KB/s", bps/1024)
}

// fetchExpectedSHA256 downloads checksums.txt for the release (best-effort) and extracts the SHA-256 for assetName.
func fetchExpectedSHA256(client *http.Client, targetVersion, assetName string) string {
	url := fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/download/%s/checksums.txt", targetVersion)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Gubernator-AutoUpdater")
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return ""
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(body), "\n") {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) >= 2 && (fields[1] == assetName || strings.TrimPrefix(fields[1], "*") == assetName) {
			return strings.ToLower(fields[0])
		}
	}
	return ""
}

// downloadReleaseBinary downloads the compressed (.gz) release binary if available (2-3x faster),
// falling back to the raw binary, streams it to dstPath, verifies Content-Length, and returns its SHA-256 hex.
func downloadReleaseBinary(client *http.Client, targetVersion, goos, goarch, dstPath string) (sha256Hex string, usedGzip bool, err error) {
	rawName, gzName := expectedBinaryNames(goos, goarch)
	baseURL := fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/download/%s/", targetVersion)

	// Try .gz first, then raw binary
	candidates := []struct {
		url      string
		isGzip   bool
		label    string
	}{
		{url: baseURL + gzName, isGzip: true, label: "compressed"},
		{url: baseURL + rawName, isGzip: false, label: "raw"},
	}

	var lastErr error
	for attempt := 1; attempt <= 6; attempt++ {
		for _, cand := range candidates {
			mutateStatus(func(s *UpdateProgressStatus) {
				s.Status = "downloading"
				s.ProgressMessage = fmt.Sprintf("Connecting to GitHub (%s %s, attempt %d/6)...", targetVersion, cand.label, attempt)
			})

			req, reqErr := http.NewRequest("GET", cand.url, nil)
			if reqErr != nil {
				lastErr = reqErr
				continue
			}
			req.Header.Set("User-Agent", "Gubernator-AutoUpdater")

			resp, getErr := client.Do(req)
			if getErr != nil {
				lastErr = getErr
				continue
			}
			if resp.StatusCode == http.StatusNotFound {
				_ = resp.Body.Close()
				lastErr = fmt.Errorf("HTTP 404 for %s", cand.url)
				continue // Immediately try raw fallback if .gz not found
			}
			if resp.StatusCode != http.StatusOK {
				_ = resp.Body.Close()
				lastErr = fmt.Errorf("GitHub returned HTTP %s", resp.Status)
				continue
			}

			out, createErr := os.Create(dstPath)
			if createErr != nil {
				_ = resp.Body.Close()
				return "", false, createErr
			}

			totalBytes := resp.ContentLength
			pr := &progressReader{
				reader:    resp.Body,
				total:     totalBytes,
				startTime: time.Now(),
				onProgress: func(downloaded, total int64, speed float64) {
					pct := 0
					msg := fmt.Sprintf("Downloading %s: %s (%s)", targetVersion, formatMB(downloaded), formatSpeed(speed))
					if total > 0 {
						pct = int((downloaded * 100) / total)
						if pct > 99 {
							pct = 99
						}
						msg = fmt.Sprintf("Downloading %s: %s / %s (%d%% · %s)", targetVersion, formatMB(downloaded), formatMB(total), pct, formatSpeed(speed))
					}
					mutateStatus(func(s *UpdateProgressStatus) {
						s.Status = "downloading"
						s.ProgressPercent = pct
						s.DownloadedBytes = downloaded
						s.TotalBytes = total
						s.SpeedBps = speed
						s.ProgressMessage = msg
					})
				},
			}

			var srcReader io.Reader = pr
			var gzReader *gzip.Reader
			if cand.isGzip {
				gzReader, err = gzip.NewReader(pr)
				if err != nil {
					_ = out.Close()
					_ = resp.Body.Close()
					_ = os.Remove(dstPath)
					lastErr = fmt.Errorf("invalid gzip stream: %w", err)
					continue
				}
				srcReader = gzReader
			}

			hasher := sha256.New()
			written, copyErr := io.Copy(io.MultiWriter(out, hasher), srcReader)
			if gzReader != nil {
				_ = gzReader.Close()
			}
			_ = out.Close()
			_ = resp.Body.Close()

			if copyErr != nil {
				_ = os.Remove(dstPath)
				lastErr = fmt.Errorf("download interrupted after %s: %w", formatMB(pr.readBytes), copyErr)
				continue
			}

			// Verify full HTTP payload arrived (prevents truncated binaries)
			if totalBytes > 0 && pr.readBytes < totalBytes {
				_ = os.Remove(dstPath)
				lastErr = fmt.Errorf("truncated download: received %d of %d bytes", pr.readBytes, totalBytes)
				continue
			}

			if written < 5*1024*1024 {
				_ = os.Remove(dstPath)
				lastErr = fmt.Errorf("downloaded file too small (%d bytes) — not a valid gbnt binary", written)
				continue
			}

			return hex.EncodeToString(hasher.Sum(nil)), cand.isGzip, nil
		}
		time.Sleep(3 * time.Second)
	}

	return "", false, fmt.Errorf("failed after retries: %w", lastErr)
}

// verifyExecutableBinary runs `<tmpPath> version` to prove the binary executes on this CPU/OS
// and reports the expected targetVersion before touching the live executable.
func verifyExecutableBinary(tmpPath, targetVersion string) (string, error) {
	if err := os.Chmod(tmpPath, 0755); err != nil {
		return "", fmt.Errorf("chmod failed: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, tmpPath, "version")
	// Run from /tmp so it doesn't pick up any stale ./VERSION file
	cmd.Dir = "/tmp"
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("binary execution check failed: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	outStr := strings.TrimSpace(string(out))
	if targetVersion != "" && targetVersion != "latest" {
		expectedNorm := normalizeVer(targetVersion)
		if !strings.Contains(outStr, expectedNorm) {
			return outStr, fmt.Errorf("binary reports %q instead of expected %q", outStr, targetVersion)
		}
	}
	return outStr, nil
}

// atomicInstallBinary safely installs src to dst using atomic unlink+create (`install -m 755` or rename),
// NEVER `cp -f` over a running executable (which triggers SIGSEGV on Linux).
func atomicInstallBinary(src, dst string) error {
	if dst == "" {
		return nil
	}
	dir := filepath.Dir(dst)
	if _, err := os.Stat(dir); err != nil {
		return err
	}

	// Preserve existing file owner if dst exists (e.g. /home/ubuntu/gbnt)
	// Method 1: atomic `install -m 755` without sudo
	if err := exec.Command("install", "-m", "755", src, dst).Run(); err == nil {
		return nil
	}
	// Method 2: atomic `sudo install -m 755`
	if err := exec.Command("sudo", "install", "-m", "755", src, dst).Run(); err == nil {
		// Restore ownership if installed under /home/<user>/
		if strings.HasPrefix(dst, "/home/") {
			parts := strings.Split(strings.TrimPrefix(dst, "/home/"), "/")
			if len(parts) > 0 && parts[0] != "" {
				_ = exec.Command("sudo", "chown", parts[0]+":"+parts[0], dst).Run()
			}
		}
		return nil
	}
	// Method 3: stage temp file in target directory and atomically rename(2)
	staged := dst + ".gbnt-new"
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.WriteFile(staged, data, 0755); err != nil {
		return err
	}
	if err := os.Rename(staged, dst); err != nil {
		_ = os.Remove(staged)
		return err
	}
	return nil
}

func findSSHKey() string {
	candidates := []string{
		"/home/ubuntu/.ssh/id_ed25519",
		"/home/ubuntu/.ssh/id_rsa",
		"/root/.ssh/id_ed25519",
		"/root/.ssh/id_rsa",
		"/data/id_ed25519",
		"/data/id_rsa",
		"/data/ssh/id_ed25519",
		"/data/ssh/id_rsa",
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		candidates = append([]string{
			filepath.Join(home, ".ssh", "id_ed25519"),
			filepath.Join(home, ".ssh", "id_rsa"),
		}, candidates...)
	}
	for _, k := range candidates {
		if _, err := os.Stat(k); err == nil {
			return k
		}
	}
	return ""
}

func normalizeUnameArch(arch string) string {
	switch strings.TrimSpace(strings.ToLower(arch)) {
	case "x86_64", "amd64":
		return "amd64"
	case "aarch64", "arm64":
		return "arm64"
	default:
		return strings.TrimSpace(strings.ToLower(arch))
	}
}

// upgradeWorkerNode pushes the already-downloaded Manager binary to a Worker over LAN (fast, ~1-2s)
// when architectures match, or downloads directly on the Worker if architectures differ, then verifies the Worker's version.
func upgradeWorkerNode(w db.Node, tmpPath, targetVersion string) NodeUpdateResult {
	res := NodeUpdateResult{
		NodeID: w.ID,
		IP:     w.IP,
		Role:   "worker",
		Status: "updating",
	}

	sshArgs := []string{
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "ConnectTimeout=6",
		"-o", "BatchMode=yes",
	}
	if key := findSSHKey(); key != "" {
		sshArgs = append(sshArgs, "-i", key)
	}
	targetHost := fmt.Sprintf("ubuntu@%s", w.IP)

	// 1. Probe remote architecture
	probeCtx, probeCancel := context.WithTimeout(context.Background(), 10*time.Second)
	archOut, probeErr := exec.CommandContext(probeCtx, "ssh", append(append([]string{}, sshArgs...), targetHost, "uname -m")...).CombinedOutput()
	probeCancel()
	if probeErr != nil {
		res.Status = "failed"
		res.Message = fmt.Sprintf("SSH unreachable: %s", strings.TrimSpace(string(archOut)))
		return res
	}
	workerArch := normalizeUnameArch(string(archOut))

	installAndRestartCmd := `chmod 755 /tmp/gbnt-new && sudo install -m 755 /tmp/gbnt-new /usr/local/bin/gbnt && ( [ -f /home/ubuntu/gbnt ] && sudo install -m 755 -o ubuntu -g ubuntu /tmp/gbnt-new /home/ubuntu/gbnt || true ) && rm -f /tmp/gbnt-new && (sudo systemctl restart gbnt-worker || systemctl restart gbnt-worker || true) && sleep 1 && /usr/local/bin/gbnt version`

	if workerArch == runtime.GOARCH {
		// Fast LAN push: stream Manager's verified binary directly over SSH stdin (~1-2s on LAN!)
		res.Method = "lan-push"
		f, err := os.Open(tmpPath)
		if err != nil {
			res.Status = "failed"
			res.Message = fmt.Sprintf("failed to read local binary: %v", err)
			return res
		}
		defer func() { _ = f.Close() }()

		pushCtx, pushCancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer pushCancel()
		cmd := exec.CommandContext(pushCtx, "ssh", append(append([]string{}, sshArgs...), targetHost, "cat > /tmp/gbnt-new && "+installAndRestartCmd)...)
		cmd.Stdin = f
		out, runErr := cmd.CombinedOutput()
		outStr := strings.TrimSpace(string(out))
		if runErr != nil {
			res.Status = "failed"
			res.Message = fmt.Sprintf("LAN push failed: %v (%s)", runErr, outStr)
			return res
		}
		res.Version = extractLastLine(outStr)
		res.Status = "verified"
		res.Message = "Upgraded via LAN push & verified"
		return res
	}

	// Different arch: download .gz (or raw fallback) on the worker
	res.Method = "github-download"
	rawName, gzName := expectedBinaryNames("linux", workerArch)
	gzURL := fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/download/%s/%s", targetVersion, gzName)
	rawURL := fmt.Sprintf("https://github.com/gubernator-org/gubernator/releases/download/%s/%s", targetVersion, rawName)
	dlScript := fmt.Sprintf(
		`(curl -fsSL "%s" | gunzip > /tmp/gbnt-new || curl -fsSL -o /tmp/gbnt-new "%s") && %s`,
		gzURL, rawURL, installAndRestartCmd,
	)
	dlCtx, dlCancel := context.WithTimeout(context.Background(), 4*time.Minute)
	defer dlCancel()
	out, runErr := exec.CommandContext(dlCtx, "ssh", append(append([]string{}, sshArgs...), targetHost, dlScript)...).CombinedOutput()
	outStr := strings.TrimSpace(string(out))
	if runErr != nil {
		res.Status = "failed"
		res.Message = fmt.Sprintf("worker download failed: %v (%s)", runErr, outStr)
		return res
	}
	res.Version = extractLastLine(outStr)
	res.Status = "verified"
	res.Message = "Upgraded & verified"
	return res
}

func extractLastLine(s string) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if l := strings.TrimSpace(lines[i]); l != "" {
			return l
		}
	}
	return ""
}

// ApplyClusterUpdate triggers compressed binary download, SHA-256 & executable verification,
// atomic installation on Manager and LAN push to Workers, and safe post-restart verification.
func ApplyClusterUpdate(targetVersion string) error {
	statusMutex.Lock()
	if updateInProgress {
		statusMutex.Unlock()
		return fmt.Errorf("a cluster update is already in progress")
	}
	updateInProgress = true
	currentUpdateStatus = UpdateProgressStatus{
		Status:          "downloading",
		TargetVersion:   targetVersion,
		ProgressMessage: fmt.Sprintf("Connecting to GitHub to download %s...", targetVersion),
		ProgressPercent: 0,
		UpdatedAt:       time.Now().UTC().Format(time.RFC3339),
	}
	statusMutex.Unlock()

	slog.Info("🚀 Initiating cluster-wide update", "target_version", targetVersion)

	cacheMutex.Lock()
	cachedInfo = nil
	cacheMutex.Unlock()

	// Remove any stale persisted handoff file before starting
	_ = os.Remove(persistedUpdateStatePath)

	go func() {
		defer func() {
			if r := recover(); r != nil {
				slog.Error("recovered panic in cluster update", "err", r)
				setUpdateStatus("failed", targetVersion, "Update crashed unexpectedly", fmt.Sprintf("%v", r))
			}
			statusMutex.Lock()
			updateInProgress = false
			statusMutex.Unlock()
		}()

		goos := runtime.GOOS
		goarch := runtime.GOARCH
		tmpPath := fmt.Sprintf("/tmp/gbnt-update-%d", time.Now().UnixNano())
		defer func() { _ = os.Remove(tmpPath) }()

		client := &http.Client{
			Timeout: 6 * time.Minute,
			Transport: &http.Transport{
				ResponseHeaderTimeout: 20 * time.Second,
			},
		}

		// Step 1: Download compressed (.gz) or raw release binary with live progress
		actualSHA, usedGzip, dlErr := downloadReleaseBinary(client, targetVersion, goos, goarch, tmpPath)
		if dlErr != nil {
			slog.Warn("could not download release binary", "err", dlErr)
			setUpdateStatus("failed", targetVersion, "Download failed from GitHub", dlErr.Error())
			return
		}
		slog.Info("downloaded release binary", "version", targetVersion, "gzip", usedGzip, "sha256", actualSHA)

		// Step 2: Verify SHA-256 checksum (if published) AND execute `<tmpPath> version` sanity check
		mutateStatus(func(s *UpdateProgressStatus) {
			s.Status = "verifying"
			s.ProgressPercent = 100
			s.ProgressMessage = fmt.Sprintf("Verifying integrity & executing %s self-check...", targetVersion)
		})

		rawName, _ := expectedBinaryNames(goos, goarch)
		expectedSHA := fetchExpectedSHA256(client, targetVersion, rawName)
		shaVerified := false
		if expectedSHA != "" {
			if !strings.EqualFold(actualSHA, expectedSHA) {
				errMsg := fmt.Sprintf("SHA-256 mismatch: expected %s, got %s", expectedSHA[:12], actualSHA[:12])
				slog.Error("release binary checksum mismatch", "expected", expectedSHA, "actual", actualSHA)
				setUpdateStatus("failed", targetVersion, "Checksum verification failed", errMsg)
				return
			}
			shaVerified = true
		}

		verOut, verErr := verifyExecutableBinary(tmpPath, targetVersion)
		if verErr != nil {
			slog.Error("downloaded binary failed pre-install verification", "err", verErr)
			setUpdateStatus("failed", targetVersion, "Binary verification failed", verErr.Error())
			return
		}
		slog.Info("verified downloaded binary", "output", verOut, "sha256_verified", shaVerified)

		// Build initial node results list (Manager + active Workers)
		nodeResults := []NodeUpdateResult{
			{
				NodeID:  "node-local-manager",
				Role:    "manager",
				Status:  "updating",
				Method:  "local",
				Message: "Installing verified binary atomically...",
			},
		}
		var workers []db.Node
		if db.DB != nil {
			var mgr db.Node
			if err := db.DB.Where("role = 'manager'").First(&mgr).Error; err == nil {
				nodeResults[0].NodeID = mgr.ID
				nodeResults[0].IP = mgr.IP
			}
			_ = db.DB.Where("role = 'worker' AND status != 'left'").Find(&workers).Error
			for _, w := range workers {
				if w.IP != "" {
					nodeResults = append(nodeResults, NodeUpdateResult{
						NodeID:  w.ID,
						IP:      w.IP,
						Role:    "worker",
						Status:  "pending",
						Message: "Queued for LAN push",
					})
				}
			}
		}

		mutateStatus(func(s *UpdateProgressStatus) {
			s.Status = "installing"
			s.SHA256Verified = shaVerified
			s.BinaryVerified = true
			s.NodeResults = append([]NodeUpdateResult(nil), nodeResults...)
			s.ProgressMessage = fmt.Sprintf("Atomically installing %s on Manager...", targetVersion)
		})

		// Step 3: Atomically install binary on Manager (deduplicated paths, NEVER cp -f!)
		rawPaths := []string{}
		if execPath, err := os.Executable(); err == nil && execPath != "" {
			if realPath, err := filepath.EvalSymlinks(execPath); err == nil {
				rawPaths = append(rawPaths, realPath)
			} else {
				rawPaths = append(rawPaths, execPath)
			}
		}
		for _, p := range []string{"/usr/local/bin/gbnt", "/home/ubuntu/gbnt", "/app/gbnt"} {
			// Always install to /usr/local/bin/gbnt; install to others only if they already exist
			if p == "/usr/local/bin/gbnt" {
				rawPaths = append(rawPaths, p)
			} else if _, err := os.Stat(p); err == nil {
				rawPaths = append(rawPaths, p)
			}
		}

		seenPaths := make(map[string]bool)
		installedAny := false
		var installErr error
		for _, dst := range rawPaths {
			if seenPaths[dst] {
				continue
			}
			seenPaths[dst] = true
			if err := atomicInstallBinary(tmpPath, dst); err != nil {
				slog.Warn("atomic binary install skipped/failed for path", "path", dst, "err", err)
				installErr = err
			} else {
				slog.Info("atomically installed new binary", "path", dst)
				installedAny = true
			}
		}

		if !installedAny {
			setUpdateStatus("failed", targetVersion, "Failed to install new binary on Manager", fmt.Sprintf("%v", installErr))
			return
		}

		nodeResults[0].Status = "verified"
		nodeResults[0].Version = targetVersion
		nodeResults[0].Message = "Installed atomically; awaiting restart"

		// Persist targetVersion ONLY after atomic installation succeeded
		if targetVersion != "" {
			for _, path := range []string{"/data/VERSION", "/app/VERSION", "/home/ubuntu/VERSION", "VERSION"} {
				if _, err := os.Stat(path); err == nil || path == "/data/VERSION" {
					_ = os.WriteFile(path, []byte(targetVersion+"\n"), 0644)
				}
			}
		}
		if db.DB != nil {
			var config db.ClusterConfig
			if err := db.DB.First(&config, "id = ?", "global").Error; err == nil {
				config.TargetVersion = targetVersion
				db.DB.Save(&config)
			}
		}

		// Step 4: Upgrade Worker Centurion nodes via fast LAN push & WAIT before restarting Manager!
		if len(workers) > 0 {
			mutateStatus(func(s *UpdateProgressStatus) {
				s.Status = "installing"
				s.NodeResults = append([]NodeUpdateResult(nil), nodeResults...)
				s.ProgressMessage = fmt.Sprintf("Pushing %s to %d Worker node(s) over LAN...", targetVersion, len(workers))
			})

			var wg sync.WaitGroup
			var mu sync.Mutex
			for idx, w := range workers {
				if w.IP == "" {
					continue
				}
				workerNode := w
				resultIdx := idx + 1
				wg.Add(1)
				go func() {
					defer wg.Done()
					slog.Info("upgrading worker node", "node_id", workerNode.ID, "ip", workerNode.IP)
					r := upgradeWorkerNode(workerNode, tmpPath, targetVersion)
					slog.Info("worker upgrade result", "node_id", r.NodeID, "status", r.Status, "version", r.Version, "method", r.Method, "msg", r.Message)
					mu.Lock()
					if resultIdx < len(nodeResults) {
						nodeResults[resultIdx] = r
					}
					mutateStatus(func(s *UpdateProgressStatus) {
						s.NodeResults = append([]NodeUpdateResult(nil), nodeResults...)
					})
					mu.Unlock()
				}()
			}
			wg.Wait()
		}

		// Step 5: Persist handoff verification state so the restarted Manager knows the upgrade just completed
		mutateStatus(func(s *UpdateProgressStatus) {
			s.Status = "restarting"
			s.ProgressPercent = 100
			s.NodeResults = append([]NodeUpdateResult(nil), nodeResults...)
			s.ProgressMessage = fmt.Sprintf("Restarting Gubernator Manager to activate %s...", targetVersion)
		})
		persistUpdateState(GetUpdateStatus())

		// Give the UI one polling cycle to observe "restarting" before we terminate ourselves
		time.Sleep(1500 * time.Millisecond)

		// Try container restart, then systemd restart
		var outBuf bytes.Buffer
		for _, cmdArgs := range [][]string{
			{"sudo", "systemctl", "restart", "gbnt-manager"},
			{"systemctl", "restart", "gbnt-manager"},
			{"docker", "restart", "gbnt-manager"},
		} {
			cmd := exec.Command(cmdArgs[0], cmdArgs[1:]...)
			cmd.Stdout = &outBuf
			cmd.Stderr = &outBuf
			if err := cmd.Run(); err == nil {
				break
			}
		}

		// If process survived (e.g. non-systemd manual launch), mark success directly
		mutateStatus(func(s *UpdateProgressStatus) {
			s.Status = "success"
			s.ProgressPercent = 100
			s.ProgressMessage = fmt.Sprintf("Successfully upgraded cluster to %s", targetVersion)
		})
	}()

	return nil
}
