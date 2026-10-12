package aqueducts

import (
	"fmt"
	"log/slog"
	"net"
	"os"
	"strings"
	"sync"

	"github.com/mario-ezquerro/gubernator/internal/coredns"
	"github.com/mario-ezquerro/gubernator/internal/db"
)

// aqueductMutex protects concurrent access to file generation and database queries
var aqueductMutex sync.Mutex

// WG tracks background/asynchronous config generation tasks (primarily used in tests)
var WG sync.WaitGroup

// GenerateAllAsync triggers hosts and caddy file generation asynchronously.
func GenerateAllAsync() {
	WG.Add(1)
	go func() {
		defer WG.Done()
		GenerateHostsFile()
		GenerateCaddyfile()
	}()
}

// SanitizeDNSLabel converts a string into an RFC 1123 compliant DNS subdomain label.
// Allowed characters are lowercase [a-z0-9] and hyphens '-'.
// Spaces, brackets, parentheses, underscores, slashes, colons, and dots are converted to hyphens.
func SanitizeDNSLabel(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var sb strings.Builder
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			sb.WriteRune(r)
		} else if r == ' ' || r == '_' || r == '.' || r == '(' || r == ')' || r == '[' || r == ']' || r == '/' || r == ':' {
			sb.WriteRune('-')
		}
	}
	res := sb.String()
	for strings.Contains(res, "--") {
		res = strings.ReplaceAll(res, "--", "-")
	}
	return strings.Trim(res, "-")
}

// isSystemStack checks if a stack represents an internal Gubernator infrastructure stack.
func isSystemStack(stackID, stackName string) bool {
	sID := strings.ToLower(stackID)
	sName := strings.ToLower(stackName)
	return strings.Contains(sID, "core-gbnt") ||
		strings.Contains(sID, "core-stack") ||
		strings.Contains(sID, "sre-monitor") ||
		strings.Contains(sID, "sre-stack") ||
		strings.Contains(sName, "core-gbnt") ||
		strings.Contains(sName, "monitor")
}

// ExtractIngressHosts parses service constraints/labels (supporting both "==" and "=")
// and returns any configured ingress hostnames (e.g., ingress.host=wordpress.gbnt.local).
func ExtractIngressHosts(svc db.Service) []string {
	var hosts []string
	seen := make(map[string]bool)
	for _, constraint := range svc.Constraints {
		var key, val string
		if strings.Contains(constraint, "==") {
			parts := strings.SplitN(constraint, "==", 2)
			if len(parts) == 2 {
				key = strings.TrimSpace(parts[0])
				val = strings.TrimSpace(parts[1])
			}
		} else if strings.Contains(constraint, "=") {
			parts := strings.SplitN(constraint, "=", 2)
			if len(parts) == 2 {
				key = strings.TrimSpace(parts[0])
				val = strings.TrimSpace(parts[1])
			}
		}
		val = strings.Trim(val, "\"'")
		if val == "" {
			continue
		}
		switch key {
		case "ingress.host", "gbnt.ingress.host", "node.labels.gbnt.ingress.host", "gbnt.caddy.host":
			if !seen[val] {
				seen[val] = true
				hosts = append(hosts, val)
			}
		}
	}
	return hosts
}

// GenerateHostsFile queries the DB for all running tasks and regenerates the CoreDNS hosts file.
// Services with an explicit ingress.host label publish ONLY their ingress domain mapped to the
// deployed node's LAN IP (aligned with Caddy Ingress), avoiding noisy internal bridge IP records.
func GenerateHostsFile() {
	aqueductMutex.Lock()
	defer aqueductMutex.Unlock()

	var tasks []db.Task
	// Only fetch tasks that have an IP
	if err := db.DB.Where("status = ? AND container_ip != ?", "running", "").Find(&tasks).Error; err != nil {
		slog.Error("failed to fetch tasks for DNS generation", "err", err)
		return
	}

	var managerNode db.Node
	hostIP := "127.0.0.1" // Fallback
	if err := db.DB.Where("role = ?", "manager").First(&managerNode).Error; err == nil && managerNode.IP != "" {
		hostIP = managerNode.IP
	}

	content := "# Gubernator Auto-Generated CoreDNS Hosts File\n"
	content += "# Format: <IP> <domain>\n\n"

	seenRecords := make(map[string]bool)
	claimedDomains := make(map[string]bool)
	addRecord := func(ip, domain string) {
		ip = strings.TrimSpace(ip)
		domain = strings.TrimSpace(domain)
		if ip == "" || domain == "" || ip == "invalid" || strings.Contains(ip, "invalid") {
			return
		}
		if net.ParseIP(ip) == nil {
			return
		}
		key := fmt.Sprintf("%s\t%s", ip, domain)
		if !seenRecords[key] {
			seenRecords[key] = true
			content += key + "\n"
		}
	}

	// 1. First pass: Publish Ingress Domains (ingress.host) aligned with the deployed Node IP (Caddy Ingress)
	ingressServiceIDs := make(map[string]bool)
	var services []db.Service
	if err := db.DB.Find(&services).Error; err == nil {
		for _, svc := range services {
			ingressHosts := ExtractIngressHosts(svc)
			if len(ingressHosts) == 0 {
				continue
			}
			ingressServiceIDs[svc.ID] = true

			var svcTasks []db.Task
			_ = db.DB.Where("service_id = ? AND status = ?", svc.ID, "running").Find(&svcTasks)

			var nodeIPOrder []string
			nodeIPSeen := make(map[string]bool)
			for _, t := range svcTasks {
				var ip string
				if t.NodeID == "node-local-manager" || t.NodeID == "" || strings.Contains(strings.ToLower(t.NodeID), "manager") {
					ip = hostIP
				} else {
					var node db.Node
					if err := db.DB.First(&node, "id = ?", t.NodeID).Error; err == nil && node.IP != "" {
						ip = node.IP
					}
				}
				if ip == "" || ip == "invalid" || strings.Contains(ip, "invalid") || net.ParseIP(ip) == nil {
					ip = hostIP
				}
				if !nodeIPSeen[ip] {
					nodeIPSeen[ip] = true
					nodeIPOrder = append(nodeIPOrder, ip)
				}
			}

			for _, h := range ingressHosts {
				if len(nodeIPOrder) > 0 {
					for _, ip := range nodeIPOrder {
						addRecord(ip, h)
					}
					claimedDomains[strings.ToLower(h)] = true
				} else if !claimedDomains[strings.ToLower(h)] {
					// Fallback if no tasks are running yet, point to Manager IP
					addRecord(hostIP, h)
					claimedDomains[strings.ToLower(h)] = true
				}
			}
		}
	}

	// 2. Second pass: Internal & System services WITHOUT ingress.host
	for _, t := range tasks {
		var svc db.Service
		if err := db.DB.First(&svc, "id = ?", t.ServiceID).Error; err != nil {
			continue
		}
		// Skip noisy internal/host-qualified auto-records for services that explicitly publish via ingress.host
		if ingressServiceIDs[svc.ID] || len(ExtractIngressHosts(svc)) > 0 {
			continue
		}

		var stack db.Stack
		if err := db.DB.First(&stack, "id = ?", svc.StackID).Error; err != nil {
			continue
		}

		nodeIP := t.ContainerIP
		cleanNode := "manager"

		if t.NodeID != "node-local-manager" && t.NodeID != "" {
			var taskNode db.Node
			if err := db.DB.First(&taskNode, "id = ?", t.NodeID).Error; err == nil {
				if taskNode.IP != "" {
					nodeIP = taskNode.IP
				}
				cleanNode = SanitizeDNSLabel(taskNode.ID)
			} else {
				cleanNode = SanitizeDNSLabel(t.NodeID)
			}
		}

		// Fallback for missing/invalid node IPs
		if nodeIP == "" || nodeIP == "invalid" || strings.Contains(nodeIP, "invalid") || net.ParseIP(nodeIP) == nil {
			nodeIP = hostIP
		}

		// Service container IP for internal container-to-container communication within the stack
		serviceIP := t.ContainerIP
		if serviceIP == "" || serviceIP == "invalid" || strings.Contains(serviceIP, "invalid") || net.ParseIP(serviceIP) == nil {
			serviceIP = nodeIP
		}

		cleanSvc := SanitizeDNSLabel(svc.Name)
		if cleanSvc == "" {
			continue
		}

		clusterDomain := db.GetClusterDomain()
		addInternalRecord := func(ip, domain string) {
			if claimedDomains[strings.ToLower(domain)] {
				return
			}
			addRecord(ip, domain)
		}

		if isSystemStack(stack.ID, stack.Name) {
			// System Stack: Host-Qualified Domain (<node>.<service>.<clusterDomain> and <node>.<service>.gbnt)
			addInternalRecord(nodeIP, fmt.Sprintf("%s.%s.%s", cleanNode, cleanSvc, clusterDomain))
			if clusterDomain != "gbnt" {
				addInternalRecord(nodeIP, fmt.Sprintf("%s.%s.gbnt", cleanNode, cleanSvc))
			}
			if (t.NodeID == "node-local-manager" || t.NodeID == "") && cleanNode != "manager" {
				addInternalRecord(nodeIP, fmt.Sprintf("manager.%s.%s", cleanSvc, clusterDomain))
				if clusterDomain != "gbnt" {
					addInternalRecord(nodeIP, fmt.Sprintf("manager.%s.gbnt", cleanSvc))
				}
			}
		} else {
			// Internal User Service (without ingress.host, e.g. db):
			// Emit only stack-scoped domains (<service>.<stack>.<clusterDomain> and <service>.<stack>.gbnt)
			// and host-qualified domains (<node>.<service>.<clusterDomain>)
			cleanStack := SanitizeDNSLabel(stack.Name)
			if cleanStack != "" {
				addInternalRecord(serviceIP, fmt.Sprintf("%s.%s.%s", cleanSvc, cleanStack, clusterDomain))
				if clusterDomain != "gbnt" {
					addInternalRecord(serviceIP, fmt.Sprintf("%s.%s.gbnt", cleanSvc, cleanStack))
				}
			}
			addInternalRecord(nodeIP, fmt.Sprintf("%s.%s.%s", cleanNode, cleanSvc, clusterDomain))
			if clusterDomain != "gbnt" {
				addInternalRecord(nodeIP, fmt.Sprintf("%s.%s.gbnt", cleanNode, cleanSvc))
			}
		}
	}

	// Add Custom User-Defined Static DNS Records
	var customRecords []db.CustomDNSRecord
	if err := db.DB.Find(&customRecords).Error; err == nil && len(customRecords) > 0 {
		content += "\n# Custom User-Defined Static DNS Records\n"
		for _, rec := range customRecords {
			addRecord(rec.IP, rec.Domain)
		}
	}

	// Write to the CoreDNS config directory (~/.gbnt/coredns/gubernator.hosts)
	hostsPath := coredns.HostsFilePath()
	err := os.WriteFile(hostsPath, []byte(content), 0644)
	if err != nil {
		slog.Error("failed to write gubernator.hosts", "err", err)
		return
	}

	slog.Info("aqueducts: generated clean gubernator.hosts file")

	// Signal CoreDNS to reload the updated hosts file
	if err := coredns.ReloadConfig(); err != nil {
		slog.Warn("aqueducts: CoreDNS reload failed", "err", err)
	}
}
