package docker

import (
	"encoding/json"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestBuildComposeFromInspectEntries(t *testing.T) {
	rawInspect := `[
		{
			"Id": "abc123def456",
			"Name": "/legacy-web",
			"State": { "Status": "running", "Running": true },
			"Config": {
				"Image": "nginx:1.27-alpine",
				"Env": ["PATH=/usr/local/sbin:/usr/local/bin", "APP_ENV=production", "API_URL=http://api:8080"],
				"Cmd": ["nginx", "-g", "daemon off;"],
				"Labels": {
					"com.docker.compose.project": "legacy-shop",
					"com.docker.compose.service": "web",
					"com.docker.compose.project.config_files": "/srv/legacy-shop/docker-compose.yml",
					"custom.team": "checkout"
				},
				"Healthcheck": {
					"Test": ["CMD-SHELL", "wget -qO- http://localhost/ || exit 1"],
					"Interval": 30000000000,
					"Timeout": 5000000000,
					"Retries": 3
				}
			},
			"HostConfig": {
				"RestartPolicy": { "Name": "unless-stopped", "MaximumRetryCount": 0 },
				"PortBindings": {
					"80/tcp": [{ "HostIp": "0.0.0.0", "HostPort": "8088" }],
					"443/tcp": [{ "HostIp": "127.0.0.1", "HostPort": "8443" }]
				},
				"Memory": 536870912,
				"NanoCpus": 1500000000
			},
			"Mounts": [
				{ "Type": "bind", "Source": "/srv/html", "Destination": "/usr/share/nginx/html", "RW": false },
				{ "Type": "volume", "Name": "shop_cache", "Source": "/var/lib/docker/volumes/shop_cache/_data", "Destination": "/var/cache/nginx", "RW": true }
			],
			"NetworkSettings": {
				"IPAddress": "",
				"Networks": {
					"legacy_net": { "IPAddress": "172.22.0.5" }
				}
			}
		}
	]`

	var entries []dockerInspectEntry
	if err := json.Unmarshal([]byte(rawInspect), &entries); err != nil {
		t.Fatalf("unmarshal inspect fixture failed: %v", err)
	}

	var imgDef dockerImageInspectEntry
	imgDef.Config.Env = []string{"PATH=/usr/local/sbin:/usr/local/bin"}
	imgDef.Config.Cmd = []string{"nginx", "-g", "daemon off;"}

	res, err := BuildComposeFromInspectEntries(
		entries,
		map[string]dockerImageInspectEntry{"nginx:1.27-alpine": imgDef},
		"",
		"node-local-manager",
	)
	if err != nil {
		t.Fatalf("BuildComposeFromInspectEntries returned error: %v", err)
	}

	if res.StackName != "legacy-shop" {
		t.Errorf("expected inferred stack name 'legacy-shop', got %q", res.StackName)
	}
	if res.ConfigFilePath != "/srv/legacy-shop/docker-compose.yml" {
		t.Errorf("expected config file path, got %q", res.ConfigFilePath)
	}
	if len(res.Services) != 1 {
		t.Fatalf("expected 1 service meta, got %d", len(res.Services))
	}
	meta := res.Services[0]
	if meta.ServiceName != "web" || meta.ContainerName != "legacy-web" || meta.Status != "running" {
		t.Errorf("unexpected service meta: %+v", meta)
	}
	if meta.ContainerIP != "172.22.0.5" {
		t.Errorf("expected container IP 172.22.0.5, got %q", meta.ContainerIP)
	}
	if meta.CpuLimit != "1.5" || meta.MemoryLimit != "512M" {
		t.Errorf("expected limits 1.5 / 512M, got %q / %q", meta.CpuLimit, meta.MemoryLimit)
	}

	// Verify generated YAML is valid and filters out default PATH & default CMD
	var parsed map[string]interface{}
	if err := yaml.Unmarshal([]byte(res.ComposeYAML), &parsed); err != nil {
		t.Fatalf("generated YAML failed to parse: %v\n%s", err, res.ComposeYAML)
	}
	if strings.Contains(res.ComposeYAML, "PATH=/usr/local/sbin") {
		t.Errorf("expected image default PATH to be filtered out:\n%s", res.ComposeYAML)
	}
	if !strings.Contains(res.ComposeYAML, "APP_ENV=production") {
		t.Errorf("expected user env var APP_ENV=production:\n%s", res.ComposeYAML)
	}
	if !strings.Contains(res.ComposeYAML, "8088:80") || !strings.Contains(res.ComposeYAML, "127.0.0.1:8443:443") {
		t.Errorf("expected reconstructed port mappings:\n%s", res.ComposeYAML)
	}
	if !strings.Contains(res.ComposeYAML, "/srv/html:/usr/share/nginx/html:ro") {
		t.Errorf("expected read-only bind mount:\n%s", res.ComposeYAML)
	}
	if !strings.Contains(res.ComposeYAML, "shop_cache:") || !strings.Contains(res.ComposeYAML, "legacy_net:") {
		t.Errorf("expected external volume and network declarations:\n%s", res.ComposeYAML)
	}
	if strings.Contains(res.ComposeYAML, "com.docker.compose.project:") {
		t.Errorf("expected compose internal labels to be stripped:\n%s", res.ComposeYAML)
	}
	if !strings.Contains(res.ComposeYAML, "custom.team: checkout") {
		t.Errorf("expected custom user label to be preserved:\n%s", res.ComposeYAML)
	}
}
