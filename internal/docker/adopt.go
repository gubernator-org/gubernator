package docker

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/gubernator-org/gubernator/internal/db"
	"gopkg.in/yaml.v3"
)

// UnmanagedContainer represents a Docker container running on a cluster node
// that is not currently tracked by any Gubernator Stack/Task or system service.
type UnmanagedContainer struct {
	ID                 string            `json:"id"`
	Name               string            `json:"name"`
	Image              string            `json:"image"`
	Status             string            `json:"status"`
	State              string            `json:"state"`
	Ports              string            `json:"ports"`
	CreatedAt          string            `json:"created_at"`
	NodeID             string            `json:"node_id"`
	NodeIP             string            `json:"node_ip"`
	NodeName           string            `json:"node_name"`
	NodeRole           string            `json:"node_role"`
	ComposeProject     string            `json:"compose_project"`
	ComposeService     string            `json:"compose_service"`
	ComposeConfigFiles string            `json:"compose_config_files"`
	GroupName          string            `json:"group_name"`
	SourceType         string            `json:"source_type"` // "compose" or "docker-run"
	Labels             map[string]string `json:"labels,omitempty"`
}

// UnmanagedGroup aggregates unmanaged containers belonging to the same
// Compose project (or "standalone") on a given node.
type UnmanagedGroup struct {
	GroupKey           string               `json:"group_key"`
	GroupName          string               `json:"group_name"`
	NodeID             string               `json:"node_id"`
	NodeIP             string               `json:"node_ip"`
	NodeName           string               `json:"node_name"`
	SourceType         string               `json:"source_type"` // "compose" or "docker-run"
	ComposeConfigFiles string               `json:"compose_config_files,omitempty"`
	RunningCount       int                  `json:"running_count"`
	TotalCount         int                  `json:"total_count"`
	Containers         []UnmanagedContainer `json:"containers"`
}

// UnmanagedDiscoveryResult is the top-level response for unmanaged container discovery.
type UnmanagedDiscoveryResult struct {
	TotalContainers int                  `json:"total_containers"`
	TotalGroups     int                  `json:"total_groups"`
	Groups          []UnmanagedGroup     `json:"groups"`
	Containers      []UnmanagedContainer `json:"containers"`
	NodeErrors      map[string]string    `json:"node_errors,omitempty"`
}

// AdoptedServiceMeta captures parsed runtime details for each container
// so Gubernator can register Service + Task rows cleanly without restarting containers.
type AdoptedServiceMeta struct {
	ServiceName   string   `json:"service_name"`
	ContainerName string   `json:"container_name"`
	ContainerID   string   `json:"container_id"`
	Image         string   `json:"image"`
	Status        string   `json:"status"` // "running" or "dead"
	ContainerIP   string   `json:"container_ip"`
	Ports         []string `json:"ports"`
	Env           []string `json:"env"`
	Volumes       []string `json:"volumes"`
	Command       string   `json:"command"`
	CpuLimit      string   `json:"cpu_limit"`
	MemoryLimit   string   `json:"memory_limit"`
}

// GeneratedComposeResult holds the reverse-engineered docker-compose.yml and metadata.
type GeneratedComposeResult struct {
	StackName      string               `json:"stack_name"`
	NodeID         string               `json:"node_id"`
	ComposeYAML    string               `json:"compose_yaml"`
	Source         string               `json:"source"` // "inspect" or "host-file"
	ConfigFilePath string               `json:"config_file_path,omitempty"`
	Services       []AdoptedServiceMeta `json:"services"`
	Warnings       []string             `json:"warnings,omitempty"`
}

// dockerPSRow mirrors `docker ps -a --no-trunc --format '{{json .}}'`.
type dockerPSRow struct {
	ID        string `json:"ID"`
	Names     string `json:"Names"`
	Image     string `json:"Image"`
	Status    string `json:"Status"`
	State     string `json:"State"`
	Ports     string `json:"Ports"`
	CreatedAt string `json:"CreatedAt"`
	Labels    string `json:"Labels"`
}

// dockerInspectEntry captures the relevant subset of `docker inspect` JSON.
type dockerInspectEntry struct {
	ID    string `json:"Id"`
	Name  string `json:"Name"`
	Image string `json:"Image"`
	State struct {
		Status  string `json:"Status"`
		Running bool   `json:"Running"`
	} `json:"State"`
	Config struct {
		Image       string            `json:"Image"`
		Env         []string          `json:"Env"`
		Cmd         []string          `json:"Cmd"`
		Entrypoint  []string          `json:"Entrypoint"`
		WorkingDir  string            `json:"WorkingDir"`
		User        string            `json:"User"`
		Labels      map[string]string `json:"Labels"`
		Healthcheck *struct {
			Test        []string `json:"Test"`
			Interval    int64    `json:"Interval"`
			Timeout     int64    `json:"Timeout"`
			StartPeriod int64    `json:"StartPeriod"`
			Retries     int      `json:"Retries"`
		} `json:"Healthcheck"`
	} `json:"Config"`
	HostConfig struct {
		RestartPolicy struct {
			Name              string `json:"Name"`
			MaximumRetryCount int    `json:"MaximumRetryCount"`
		} `json:"RestartPolicy"`
		PortBindings map[string][]struct {
			HostIP   string `json:"HostIp"`
			HostPort string `json:"HostPort"`
		} `json:"PortBindings"`
		NetworkMode string   `json:"NetworkMode"`
		Memory      int64    `json:"Memory"`
		NanoCpus    int64    `json:"NanoCpus"`
		Privileged  bool     `json:"Privileged"`
		CapAdd      []string `json:"CapAdd"`
		CapDrop     []string `json:"CapDrop"`
	} `json:"HostConfig"`
	Mounts []struct {
		Type        string `json:"Type"`
		Name        string `json:"Name"`
		Source      string `json:"Source"`
		Destination string `json:"Destination"`
		RW          bool   `json:"RW"`
	} `json:"Mounts"`
	NetworkSettings struct {
		IPAddress string `json:"IPAddress"`
		Networks  map[string]struct {
			IPAddress string   `json:"IPAddress"`
			Aliases   []string `json:"Aliases"`
		} `json:"Networks"`
	} `json:"NetworkSettings"`
}

// dockerImageInspectEntry captures default Env/Cmd from `docker image inspect`.
type dockerImageInspectEntry struct {
	Config struct {
		Env        []string `json:"Env"`
		Cmd        []string `json:"Cmd"`
		Entrypoint []string `json:"Entrypoint"`
		WorkingDir string   `json:"WorkingDir"`
	} `json:"Config"`
}

// isSystemInfrastructureContainer returns true if the container belongs to
// Gubernator's own core/monitoring infrastructure and should never be flagged as unmanaged.
func isSystemInfrastructureContainer(name string, labels map[string]string) bool {
	lower := strings.ToLower(strings.TrimPrefix(name, "/"))
	if labels != nil {
		if v, ok := labels["gbnt.managed"]; ok && strings.EqualFold(v, "true") {
			return true
		}
		if _, ok := labels["gbnt.stack"]; ok {
			return true
		}
		if proj := strings.ToLower(labels["com.docker.compose.project"]); proj == "gubernator" || proj == "gbnt-monitor" {
			return true
		}
	}

	systemPrefixes := []string{
		"gbnt-",
		"gubernator-",
		"coredns",
		"caddy",
		"prometheus",
		"grafana",
		"loki",
		"promtail",
		"jaeger",
		"cadvisor",
		"weavescope",
		"weave-scope",
		"scope",
		"node-exporter",
		"node_exporter",
		"alertmanager",
		"opensearch",
		"victoriametrics",
		"victorialogs",
		"vmagent",
		"vmalert",
	}
	for _, p := range systemPrefixes {
		if lower == p || strings.HasPrefix(lower, p) {
			return true
		}
	}
	return false
}

// runDockerCommandOnNode executes a docker CLI command either locally (manager) or over SSH (worker).
func runDockerCommandOnNode(node *db.Node, args ...string) ([]byte, error) {
	isRemote := node != nil &&
		node.Role != "manager" &&
		node.ID != "node-local-manager" &&
		node.IP != "" &&
		node.IP != "127.0.0.1"

	if !isRemote {
		return exec.Command("docker", args...).CombinedOutput()
	}

	sshArgs := []string{
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "StrictHostKeyChecking=no",
		"-o", "ConnectTimeout=5",
	}
	keyCandidates := []string{
		"/root/.ssh/id_ed25519", "/root/.ssh/id_rsa",
		"/data/id_ed25519", "/data/id_rsa",
		"/data/ssh/id_ed25519", "/data/ssh/id_rsa",
		"/home/ubuntu/.ssh/id_ed25519", "/home/ubuntu/.ssh/id_rsa",
	}
	if home, err := os.UserHomeDir(); err == nil {
		keyCandidates = append(keyCandidates,
			filepath.Join(home, ".ssh", "id_ed25519"),
			filepath.Join(home, ".ssh", "id_rsa"),
		)
	}
	for _, k := range keyCandidates {
		if _, err := os.Stat(k); err == nil {
			sshArgs = append(sshArgs, "-i", k)
			break
		}
	}

	quoted := make([]string, 0, len(args))
	for _, a := range args {
		quoted = append(quoted, shellSingleQuote(a))
	}
	remoteCmd := "sudo docker " + strings.Join(quoted, " ")
	sshArgs = append(sshArgs, fmt.Sprintf("ubuntu@%s", node.IP), remoteCmd)
	return exec.Command("ssh", sshArgs...).CombinedOutput()
}

// readHostFileOnNode reads a file on the target node (used for reading original compose files if requested).
func readHostFileOnNode(node *db.Node, path string) ([]byte, error) {
	isRemote := node != nil &&
		node.Role != "manager" &&
		node.ID != "node-local-manager" &&
		node.IP != "" &&
		node.IP != "127.0.0.1"

	if !isRemote {
		return os.ReadFile(path)
	}

	sshArgs := []string{
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "StrictHostKeyChecking=no",
		"-o", "ConnectTimeout=5",
	}
	keyCandidates := []string{
		"/root/.ssh/id_ed25519", "/root/.ssh/id_rsa",
		"/data/id_ed25519", "/data/id_rsa",
		"/data/ssh/id_ed25519", "/data/ssh/id_rsa",
		"/home/ubuntu/.ssh/id_ed25519", "/home/ubuntu/.ssh/id_rsa",
	}
	if home, err := os.UserHomeDir(); err == nil {
		keyCandidates = append(keyCandidates,
			filepath.Join(home, ".ssh", "id_ed25519"),
			filepath.Join(home, ".ssh", "id_rsa"),
		)
	}
	for _, k := range keyCandidates {
		if _, err := os.Stat(k); err == nil {
			sshArgs = append(sshArgs, "-i", k)
			break
		}
	}

	remoteCmd := "sudo cat " + shellSingleQuote(path)
	sshArgs = append(sshArgs, fmt.Sprintf("ubuntu@%s", node.IP), remoteCmd)
	return exec.Command("ssh", sshArgs...).CombinedOutput()
}

func shellSingleQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'"
}

func parseDockerPSLabels(raw string) map[string]string {
	out := make(map[string]string)
	if strings.TrimSpace(raw) == "" {
		return out
	}
	for _, part := range strings.Split(raw, ",") {
		idx := strings.Index(part, "=")
		if idx <= 0 {
			continue
		}
		k := strings.TrimSpace(part[:idx])
		v := strings.TrimSpace(part[idx+1:])
		if k != "" {
			out[k] = v
		}
	}
	return out
}

// DiscoverUnmanagedContainers scans all cluster nodes (Manager + Workers) for Docker containers
// not tracked in Gubernator's Tasks table and not belonging to Gubernator system infrastructure.
func DiscoverUnmanagedContainers() (*UnmanagedDiscoveryResult, error) {
	result := &UnmanagedDiscoveryResult{
		Groups:     []UnmanagedGroup{},
		Containers: []UnmanagedContainer{},
		NodeErrors: map[string]string{},
	}

	// Build set of managed container names per node (and globally)
	var tasks []db.Task
	if db.DB != nil {
		db.DB.Find(&tasks)
	}
	managedNames := make(map[string]bool, len(tasks))
	for _, t := range tasks {
		clean := strings.TrimPrefix(strings.TrimSpace(t.ContainerName), "/")
		if clean != "" {
			managedNames[clean] = true
		}
	}

	var nodes []db.Node
	if db.DB != nil {
		db.DB.Find(&nodes)
	}
	if len(nodes) == 0 {
		nodes = []db.Node{{ID: "node-local-manager", Role: "manager", IP: "127.0.0.1"}}
	}

	var mu sync.Mutex
	var wg sync.WaitGroup

	for _, n := range nodes {
		node := n
		wg.Add(1)
		go func() {
			defer wg.Done()
			out, err := runDockerCommandOnNode(&node, "ps", "-a", "--no-trunc", "--format", "{{json .}}")
			if err != nil {
				mu.Lock()
				result.NodeErrors[node.ID] = strings.TrimSpace(string(out))
				if result.NodeErrors[node.ID] == "" {
					result.NodeErrors[node.ID] = err.Error()
				}
				mu.Unlock()
				return
			}

			lines := strings.Split(strings.TrimSpace(string(out)), "\n")
			nodeContainers := make([]UnmanagedContainer, 0)
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if line == "" || !strings.HasPrefix(line, "{") {
					continue
				}
				var row dockerPSRow
				if err := json.Unmarshal([]byte(line), &row); err != nil {
					continue
				}
				cleanName := strings.TrimPrefix(strings.TrimSpace(row.Names), "/")
				if cleanName == "" || managedNames[cleanName] {
					continue
				}
				labels := parseDockerPSLabels(row.Labels)
				if isSystemInfrastructureContainer(cleanName, labels) {
					continue
				}

				composeProject := labels["com.docker.compose.project"]
				composeService := labels["com.docker.compose.service"]
				composeFiles := labels["com.docker.compose.project.config_files"]

				groupName := "standalone"
				sourceType := "docker-run"
				if composeProject != "" {
					groupName = composeProject
					sourceType = "compose"
				}

				nodeDisplay := node.ID
				if nodeDisplay == "" {
					nodeDisplay = node.IP
				}

				nodeContainers = append(nodeContainers, UnmanagedContainer{
					ID:                 row.ID,
					Name:               cleanName,
					Image:              row.Image,
					Status:             row.Status,
					State:              strings.ToLower(row.State),
					Ports:              row.Ports,
					CreatedAt:          row.CreatedAt,
					NodeID:             node.ID,
					NodeIP:             node.IP,
					NodeName:           nodeDisplay,
					NodeRole:           node.Role,
					ComposeProject:     composeProject,
					ComposeService:     composeService,
					ComposeConfigFiles: composeFiles,
					GroupName:          groupName,
					SourceType:         sourceType,
					Labels:             labels,
				})
			}

			mu.Lock()
			result.Containers = append(result.Containers, nodeContainers...)
			mu.Unlock()
		}()
	}
	wg.Wait()

	// Sort containers deterministically
	sort.Slice(result.Containers, func(i, j int) bool {
		if result.Containers[i].NodeID != result.Containers[j].NodeID {
			return result.Containers[i].NodeID < result.Containers[j].NodeID
		}
		if result.Containers[i].GroupName != result.Containers[j].GroupName {
			return result.Containers[i].GroupName < result.Containers[j].GroupName
		}
		return result.Containers[i].Name < result.Containers[j].Name
	})

	// Group by (NodeID + GroupName)
	groupMap := make(map[string]*UnmanagedGroup)
	groupOrder := make([]string, 0)
	for _, c := range result.Containers {
		key := c.NodeID + "::" + c.GroupName
		g, exists := groupMap[key]
		if !exists {
			g = &UnmanagedGroup{
				GroupKey:           key,
				GroupName:          c.GroupName,
				NodeID:             c.NodeID,
				NodeIP:             c.NodeIP,
				NodeName:           c.NodeName,
				SourceType:         c.SourceType,
				ComposeConfigFiles: c.ComposeConfigFiles,
				Containers:         []UnmanagedContainer{},
			}
			groupMap[key] = g
			groupOrder = append(groupOrder, key)
		}
		g.Containers = append(g.Containers, c)
		g.TotalCount++
		if c.State == "running" {
			g.RunningCount++
		}
		if g.ComposeConfigFiles == "" && c.ComposeConfigFiles != "" {
			g.ComposeConfigFiles = c.ComposeConfigFiles
		}
	}

	for _, key := range groupOrder {
		result.Groups = append(result.Groups, *groupMap[key])
	}
	result.TotalContainers = len(result.Containers)
	result.TotalGroups = len(result.Groups)
	if len(result.NodeErrors) == 0 {
		result.NodeErrors = nil
	}

	return result, nil
}

// GenerateComposeForNode inspects the specified containers on nodeID (local or SSH)
// and reverse-engineers a clean docker-compose.yml (or reads the host compose file if preferHostFile is true).
func GenerateComposeForNode(nodeID string, containerNames []string, stackName string, preferHostFile bool) (*GeneratedComposeResult, error) {
	if len(containerNames) == 0 {
		return nil, fmt.Errorf("at least one container name is required")
	}

	var node *db.Node
	if db.DB != nil && nodeID != "" {
		var n db.Node
		if err := db.DB.Where("id = ? OR ip = ?", nodeID, nodeID).First(&n).Error; err == nil {
			node = &n
		}
	}

	inspectArgs := append([]string{"inspect"}, containerNames...)
	rawInspect, err := runDockerCommandOnNode(node, inspectArgs...)
	if err != nil {
		return nil, fmt.Errorf("docker inspect failed: %s (%w)", strings.TrimSpace(string(rawInspect)), err)
	}

	var entries []dockerInspectEntry
	if err := json.Unmarshal(rawInspect, &entries); err != nil {
		return nil, fmt.Errorf("failed to parse docker inspect JSON: %w", err)
	}
	if len(entries) == 0 {
		return nil, fmt.Errorf("no containers found for inspection")
	}

	// Collect unique images and fetch their defaults to filter out boilerplate env vars
	imageDefaults := make(map[string]dockerImageInspectEntry)
	seenImages := make(map[string]bool)
	for _, e := range entries {
		img := e.Config.Image
		if img == "" || seenImages[img] {
			continue
		}
		seenImages[img] = true
		if imgOut, imgErr := runDockerCommandOnNode(node, "image", "inspect", img); imgErr == nil {
			var imgEntries []dockerImageInspectEntry
			if json.Unmarshal(imgOut, &imgEntries) == nil && len(imgEntries) > 0 {
				imageDefaults[img] = imgEntries[0]
			}
		}
	}

	res, err := BuildComposeFromInspectEntries(entries, imageDefaults, stackName, nodeID)
	if err != nil {
		return nil, err
	}

	// Optionally read original host docker-compose file if requested and present
	if preferHostFile && res.ConfigFilePath != "" {
		firstPath := strings.TrimSpace(strings.Split(res.ConfigFilePath, ",")[0])
		if firstPath != "" {
			if fileBytes, readErr := readHostFileOnNode(node, firstPath); readErr == nil && len(bytesTrimSpace(fileBytes)) > 0 {
				res.ComposeYAML = string(fileBytes)
				res.Source = "host-file"
				res.ConfigFilePath = firstPath
			} else {
				res.Warnings = append(res.Warnings, fmt.Sprintf("Could not read host compose file %s; fell back to docker inspect reconstruction.", firstPath))
			}
		}
	}

	return res, nil
}

func bytesTrimSpace(b []byte) []byte {
	return []byte(strings.TrimSpace(string(b)))
}

var nonServiceNameChars = regexp.MustCompile(`[^a-zA-Z0-9._-]+`)

func sanitizeServiceName(raw string) string {
	s := strings.TrimPrefix(strings.TrimSpace(raw), "/")
	s = nonServiceNameChars.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-_.")
	if s == "" {
		return "service"
	}
	return s
}

func formatNanoDuration(ns int64) string {
	if ns <= 0 {
		return ""
	}
	d := time.Duration(ns)
	if d%time.Second == 0 {
		return fmt.Sprintf("%ds", int64(d/time.Second))
	}
	return d.String()
}

// BuildComposeFromInspectEntries is the pure reverse-engineering engine that turns
// Docker inspect JSON entries + optional image defaults into a clean docker-compose.yml.
func BuildComposeFromInspectEntries(
	entries []dockerInspectEntry,
	imageDefaults map[string]dockerImageInspectEntry,
	stackName string,
	nodeID string,
) (*GeneratedComposeResult, error) {
	if len(entries) == 0 {
		return nil, fmt.Errorf("no inspect entries provided")
	}

	// Infer stackName if not explicitly provided
	inferredConfigPath := ""
	for _, e := range entries {
		if stackName == "" && e.Config.Labels != nil {
			if proj := strings.TrimSpace(e.Config.Labels["com.docker.compose.project"]); proj != "" {
				stackName = proj
			}
		}
		if inferredConfigPath == "" && e.Config.Labels != nil {
			if cf := strings.TrimSpace(e.Config.Labels["com.docker.compose.project.config_files"]); cf != "" {
				inferredConfigPath = cf
			}
		}
	}
	if stackName == "" {
		stackName = sanitizeServiceName(entries[0].Name)
	}

	servicesMap := make(map[string]map[string]interface{})
	externalVolumes := make(map[string]map[string]interface{})
	externalNetworks := make(map[string]map[string]interface{})
	usedServiceNames := make(map[string]int)
	servicesMeta := make([]AdoptedServiceMeta, 0, len(entries))
	warnings := []string{}

	for _, e := range entries {
		cleanContainerName := strings.TrimPrefix(strings.TrimSpace(e.Name), "/")
		svcName := ""
		if e.Config.Labels != nil {
			svcName = strings.TrimSpace(e.Config.Labels["com.docker.compose.service"])
		}
		if svcName == "" {
			svcName = sanitizeServiceName(cleanContainerName)
		}
		if count, exists := usedServiceNames[svcName]; exists {
			usedServiceNames[svcName] = count + 1
			svcName = fmt.Sprintf("%s-%d", svcName, count+1)
		} else {
			usedServiceNames[svcName] = 1
		}

		svc := make(map[string]interface{})
		svc["image"] = e.Config.Image
		if cleanContainerName != "" {
			svc["container_name"] = cleanContainerName
		}

		// Restart policy
		if rp := e.HostConfig.RestartPolicy.Name; rp != "" && rp != "no" {
			if rp == "on-failure" && e.HostConfig.RestartPolicy.MaximumRetryCount > 0 {
				svc["restart"] = fmt.Sprintf("on-failure:%d", e.HostConfig.RestartPolicy.MaximumRetryCount)
			} else {
				svc["restart"] = rp
			}
		}

		// Ports
		ports := extractPortMappings(e)
		if len(ports) > 0 {
			svc["ports"] = ports
		}

		// Volumes & Bind Mounts
		volumes := make([]string, 0, len(e.Mounts))
		for _, m := range e.Mounts {
			if m.Destination == "" {
				continue
			}
			var spec string
			switch m.Type {
			case "bind":
				spec = fmt.Sprintf("%s:%s", m.Source, m.Destination)
			case "volume":
				volName := m.Name
				if volName == "" {
					volName = m.Source
				}
				spec = fmt.Sprintf("%s:%s", volName, m.Destination)
				if m.Name != "" {
					externalVolumes[m.Name] = map[string]interface{}{"external": true}
				}
			default:
				continue
			}
			if !m.RW {
				spec += ":ro"
			}
			volumes = append(volumes, spec)
		}
		sort.Strings(volumes)
		if len(volumes) > 0 {
			svc["volumes"] = volumes
		}

		// Environment variables (filtered against image defaults when available)
		imgDefaultEnv := make(map[string]bool)
		var imgDef dockerImageInspectEntry
		hasImgDef := false
		if imageDefaults != nil {
			if d, ok := imageDefaults[e.Config.Image]; ok {
				imgDef = d
				hasImgDef = true
				for _, kv := range d.Config.Env {
					imgDefaultEnv[kv] = true
				}
			}
		}
		envVars := make([]string, 0)
		for _, kv := range e.Config.Env {
			if hasImgDef && imgDefaultEnv[kv] {
				continue
			}
			if !hasImgDef && strings.HasPrefix(kv, "PATH=") {
				continue
			}
			envVars = append(envVars, kv)
		}
		sort.Strings(envVars)
		if len(envVars) > 0 {
			svc["environment"] = envVars
		}

		// Command (only include if different from image default)
		cmdStr := ""
		if len(e.Config.Cmd) > 0 {
			sameAsDefault := hasImgDef && stringSlicesEqual(e.Config.Cmd, imgDef.Config.Cmd)
			if !sameAsDefault {
				svc["command"] = e.Config.Cmd
				cmdStr = strings.Join(e.Config.Cmd, " ")
			}
		}

		// WorkingDir & User
		if e.Config.WorkingDir != "" && (!hasImgDef || e.Config.WorkingDir != imgDef.Config.WorkingDir) {
			svc["working_dir"] = e.Config.WorkingDir
		}
		if e.Config.User != "" {
			svc["user"] = e.Config.User
		}
		if e.HostConfig.Privileged {
			svc["privileged"] = true
		}
		if len(e.HostConfig.CapAdd) > 0 {
			svc["cap_add"] = e.HostConfig.CapAdd
		}
		if len(e.HostConfig.CapDrop) > 0 {
			svc["cap_drop"] = e.HostConfig.CapDrop
		}

		// Networks
		netMode := e.HostConfig.NetworkMode
		if netMode == "host" || netMode == "none" {
			svc["network_mode"] = netMode
		} else {
			customNets := make([]string, 0)
			for netName := range e.NetworkSettings.Networks {
				if netName == "" || netName == "bridge" || netName == "default" || netName == "host" || netName == "none" {
					continue
				}
				customNets = append(customNets, netName)
				externalNetworks[netName] = map[string]interface{}{"external": true}
			}
			sort.Strings(customNets)
			if len(customNets) > 0 {
				svc["networks"] = customNets
			}
		}

		// Labels (filter out noisy compose/OCI metadata)
		if len(e.Config.Labels) > 0 {
			filteredLabels := make(map[string]string)
			for k, v := range e.Config.Labels {
				if strings.HasPrefix(k, "com.docker.compose.") ||
					strings.HasPrefix(k, "org.opencontainers.image.") ||
					strings.HasPrefix(k, "org.label-schema.") ||
					k == "maintainer" {
					continue
				}
				filteredLabels[k] = v
			}
			if len(filteredLabels) > 0 {
				svc["labels"] = filteredLabels
			}
		}

		// Healthcheck
		if hc := e.Config.Healthcheck; hc != nil && len(hc.Test) > 0 && hc.Test[0] != "NONE" {
			hcMap := map[string]interface{}{
				"test": hc.Test,
			}
			if s := formatNanoDuration(hc.Interval); s != "" {
				hcMap["interval"] = s
			}
			if s := formatNanoDuration(hc.Timeout); s != "" {
				hcMap["timeout"] = s
			}
			if s := formatNanoDuration(hc.StartPeriod); s != "" {
				hcMap["start_period"] = s
			}
			if hc.Retries > 0 {
				hcMap["retries"] = hc.Retries
			}
			svc["healthcheck"] = hcMap
		}

		// Resource limits
		cpuLimitStr := ""
		memLimitStr := ""
		limits := make(map[string]interface{})
		if e.HostConfig.NanoCpus > 0 {
			cpus := float64(e.HostConfig.NanoCpus) / 1e9
			cpuLimitStr = strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.2f", cpus), "0"), ".")
			limits["cpus"] = cpuLimitStr
		}
		if e.HostConfig.Memory > 0 {
			memMB := e.HostConfig.Memory / (1024 * 1024)
			if memMB > 0 {
				memLimitStr = fmt.Sprintf("%dM", memMB)
				limits["memory"] = memLimitStr
			}
		}
		if len(limits) > 0 {
			svc["deploy"] = map[string]interface{}{
				"resources": map[string]interface{}{
					"limits": limits,
				},
			}
		}

		servicesMap[svcName] = svc

		// Extract container IP
		containerIP := e.NetworkSettings.IPAddress
		if containerIP == "" {
			for _, netInfo := range e.NetworkSettings.Networks {
				if netInfo.IPAddress != "" {
					containerIP = netInfo.IPAddress
					break
				}
			}
		}

		taskStatus := "dead"
		if e.State.Running || strings.EqualFold(e.State.Status, "running") {
			taskStatus = "running"
		}

		servicesMeta = append(servicesMeta, AdoptedServiceMeta{
			ServiceName:   svcName,
			ContainerName: cleanContainerName,
			ContainerID:   e.ID,
			Image:         e.Config.Image,
			Status:        taskStatus,
			ContainerIP:   containerIP,
			Ports:         ports,
			Env:           envVars,
			Volumes:       volumes,
			Command:       cmdStr,
			CpuLimit:      cpuLimitStr,
			MemoryLimit:   memLimitStr,
		})
	}

	composeDoc := make(map[string]interface{})
	composeDoc["name"] = stackName
	composeDoc["services"] = servicesMap
	if len(externalVolumes) > 0 {
		composeDoc["volumes"] = externalVolumes
	}
	if len(externalNetworks) > 0 {
		composeDoc["networks"] = externalNetworks
	}

	yamlBytes, err := yaml.Marshal(composeDoc)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal reconstructed compose YAML: %w", err)
	}

	header := fmt.Sprintf("# Reconstructed by Gubernator from docker inspect (%s)\n# Review before adopting or redeploying.\n",
		time.Now().UTC().Format(time.RFC3339))

	if len(entries) > 1 {
		warnings = append(warnings, "Startup dependencies (depends_on) cannot be inferred from docker inspect; add them manually if needed.")
	}

	return &GeneratedComposeResult{
		StackName:      stackName,
		NodeID:         nodeID,
		ComposeYAML:    header + string(yamlBytes),
		Source:         "inspect",
		ConfigFilePath: inferredConfigPath,
		Services:       servicesMeta,
		Warnings:       warnings,
	}, nil
}

func extractPortMappings(e dockerInspectEntry) []string {
	seen := make(map[string]bool)
	ports := make([]string, 0)
	for containerPortProto, bindings := range e.HostConfig.PortBindings {
		cPort := strings.TrimSuffix(containerPortProto, "/tcp")
		for _, b := range bindings {
			if b.HostPort == "" {
				continue
			}
			var mapping string
			if b.HostIP != "" && b.HostIP != "0.0.0.0" && b.HostIP != "::" {
				mapping = fmt.Sprintf("%s:%s:%s", b.HostIP, b.HostPort, cPort)
			} else {
				mapping = fmt.Sprintf("%s:%s", b.HostPort, cPort)
			}
			if !seen[mapping] {
				seen[mapping] = true
				ports = append(ports, mapping)
			}
		}
	}
	sort.Strings(ports)
	return ports
}

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
