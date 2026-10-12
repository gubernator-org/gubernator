package aqueducts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"

	"github.com/mario-ezquerro/gubernator/internal/coredns"
	"github.com/mario-ezquerro/gubernator/internal/db"
)

func TestSanitizeDNSLabel(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"CORE-GBNT", "core-gbnt"},
		{"CORE-GBNT (worker-1)", "core-gbnt-worker-1"},
		{"[SRE] Monitor (Manager)", "sre-monitor-manager"},
		{"node-local-manager", "node-local-manager"},
		{"gbnt_worker_1", "gbnt-worker-1"},
		{"  service.name/123:foo  ", "service-name-123-foo"},
		{"---hello---world---", "hello-world"},
		{"NormalName123", "normalname123"},
	}

	for _, tc := range tests {
		got := SanitizeDNSLabel(tc.input)
		if got != tc.expected {
			t.Errorf("SanitizeDNSLabel(%q) = %q; want %q", tc.input, got, tc.expected)
		}
	}
}

func TestIsSystemStack(t *testing.T) {
	if !isSystemStack("core-gbnt-stack", "CORE-GBNT") {
		t.Errorf("expected core-gbnt-stack to be recognized as system stack")
	}
	if !isSystemStack("core-stack-node-1", "CORE-GBNT (node-1)") {
		t.Errorf("expected worker core-stack to be recognized as system stack")
	}
	if !isSystemStack("sre-monitor-stack", "[SRE] Monitor (Manager)") {
		t.Errorf("expected sre-monitor-stack to be recognized as system stack")
	}
	if isSystemStack("wp-stack", "wordpress") {
		t.Errorf("expected wordpress stack to NOT be recognized as system stack")
	}
}

func TestGenerateHostsFile_MultiNode_CleanMinimal(t *testing.T) {
	testDB, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to connect database: %v", err)
	}
	db.DB = testDB

	_ = testDB.AutoMigrate(&db.Node{}, &db.Stack{}, &db.Service{}, &db.Task{}, &db.CustomDNSRecord{}, &db.ClusterConfig{})

	tmpDir, err := os.MkdirTemp("", "gbnt-dns-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer func() { _ = os.RemoveAll(tmpDir) }()

	origHome := os.Getenv("HOME")
	_ = os.Setenv("HOME", tmpDir)
	defer func() { _ = os.Setenv("HOME", origHome) }()

	_ = os.MkdirAll(coredns.LocalConfigDir(), 0755)

	now := time.Now()

	// 1. Manager Node
	testDB.Create(&db.Node{
		ID:     "node-local-manager",
		IP:     "192.168.1.100",
		Role:   "manager",
		Status: "active",
	})

	// 2. Worker Node
	testDB.Create(&db.Node{
		ID:     "node-gbnt-worker1",
		IP:     "192.168.1.101",
		Role:   "worker",
		Status: "active",
	})

	// 3. Stacks
	testDB.Create(&db.Stack{
		ID:        "core-gbnt-stack",
		Name:      "CORE-GBNT",
		CreatedAt: now,
		UpdatedAt: now,
	})
	testDB.Create(&db.Stack{
		ID:        "core-stack-node-gbnt-worker1",
		Name:      "CORE-GBNT (node-gbnt-worker1)",
		CreatedAt: now,
		UpdatedAt: now,
	})
	testDB.Create(&db.Stack{
		ID:        "sre-monitor-stack",
		Name:      "[SRE] Monitor (Manager)",
		CreatedAt: now,
		UpdatedAt: now,
	})
	testDB.Create(&db.Stack{
		ID:        "wp-stack",
		Name:      "wordpress",
		CreatedAt: now,
		UpdatedAt: now,
	})

	// 4. Services
	testDB.Create(&db.Service{ID: "core-svc-caddy", StackID: "core-gbnt-stack", Name: "caddy"})
	testDB.Create(&db.Service{ID: "core-svc-worker-caddy", StackID: "core-stack-node-gbnt-worker1", Name: "caddy"})
	testDB.Create(&db.Service{ID: "sre-svc-loki", StackID: "sre-monitor-stack", Name: "loki"})
	// Internal DB service without ingress.host
	testDB.Create(&db.Service{ID: "svc-wp-db", StackID: "wp-stack", Name: "db"})
	// WordPress service WITH ingress.host=wordpress.gbnt.local (single '=' from Compose labels)
	testDB.Create(&db.Service{
		ID:          "svc-wp-web",
		StackID:     "wp-stack",
		Name:        "wordpress",
		Constraints: []string{"ingress.host=wordpress.gbnt.local"},
	})

	// 5. Tasks
	testDB.Create(&db.Task{
		ID:          "core-task-caddy",
		ServiceID:   "core-svc-caddy",
		NodeID:      "node-local-manager",
		Status:      "running",
		ContainerIP: "172.18.0.2",
	})
	testDB.Create(&db.Task{
		ID:          "core-task-worker-caddy",
		ServiceID:   "core-svc-worker-caddy",
		NodeID:      "node-gbnt-worker1",
		Status:      "running",
		ContainerIP: "172.18.0.3",
	})
	testDB.Create(&db.Task{
		ID:          "sre-task-loki",
		ServiceID:   "sre-svc-loki",
		NodeID:      "node-local-manager",
		Status:      "running",
		ContainerIP: "172.18.0.4",
	})
	testDB.Create(&db.Task{
		ID:          "task-wp-db",
		ServiceID:   "svc-wp-db",
		NodeID:      "node-gbnt-worker1",
		Status:      "running",
		ContainerIP: "172.18.0.5",
	})
	testDB.Create(&db.Task{
		ID:          "task-wp-web",
		ServiceID:   "svc-wp-web",
		NodeID:      "node-gbnt-worker1",
		Status:      "running",
		ContainerIP: "172.18.0.6",
	})

	// Run GenerateHostsFile
	GenerateHostsFile()

	hostsFile := filepath.Join(coredns.LocalConfigDir(), "gubernator.hosts")
	contentBytes, err := os.ReadFile(hostsFile)
	if err != nil {
		t.Fatalf("failed to read generated hosts file: %v", err)
	}

	content := string(contentBytes)
	lines := strings.Split(content, "\n")

	t.Logf("Generated gubernator.hosts:\n%s", content)

	// Verify manager caddy entries
	if !strings.Contains(content, "172.18.0.2\tmanager.caddy.gbnt.local") {
		t.Errorf("missing manager caddy entry")
	}

	// Verify worker caddy entries
	if !strings.Contains(content, "192.168.1.101\tnode-gbnt-worker1.caddy.gbnt.local") {
		t.Errorf("missing node-gbnt-worker1 caddy entry")
	}

	// Verify manager loki entries
	if !strings.Contains(content, "172.18.0.4\tmanager.loki.gbnt.local") {
		t.Errorf("missing manager loki entry")
	}

	// CRITICAL TEST 1: Service WITH ingress.host=wordpress.gbnt.local MUST point to the Worker Node IP (192.168.1.101)
	// and MUST NOT emit internal 172.18.0.6 or duplicate host-qualified records!
	if !strings.Contains(content, "192.168.1.101\twordpress.gbnt.local") {
		t.Errorf("expected ingress.host wordpress.gbnt.local to resolve to worker node IP 192.168.1.101, got:\n%s", content)
	}
	if strings.Contains(content, "172.18.0.6") {
		t.Errorf("service with ingress.host must NOT publish internal bridge IP 172.18.0.6 in CoreDNS, got:\n%s", content)
	}
	if strings.Contains(content, "node-gbnt-worker1.wordpress") || strings.Contains(content, "wordpress.wordpress") {
		t.Errorf("service with ingress.host must NOT pollute CoreDNS with duplicate host/stack records, got:\n%s", content)
	}

	// Verify internal DB service (without ingress.host) stack-scoped entries
	if !strings.Contains(content, "172.18.0.5\tdb.wordpress.gbnt.local") {
		t.Errorf("missing internal stack-scoped domain db.wordpress.gbnt.local")
	}
	if !strings.Contains(content, "172.18.0.5\tdb.wordpress.gbnt") {
		t.Errorf("missing internal stack-scoped domain db.wordpress.gbnt")
	}
	if !strings.Contains(content, "192.168.1.101\tnode-gbnt-worker1.db.gbnt.local") {
		t.Errorf("missing host-qualified domain node-gbnt-worker1.db.gbnt.local")
	}

	// CRITICAL TEST 2: Verify that generic "caddy.gbnt.local" or "loki.gbnt.local" are NOT present to prevent collisions
	for _, l := range lines {
		fields := strings.Fields(l)
		if len(fields) >= 2 {
			domain := fields[1]
			if domain == "caddy.gbnt.local" || domain == "caddy.gbnt" {
				t.Errorf("forbidden generic entry found: %q (causes duplicate IP conflicts across nodes)", domain)
			}
			if domain == "loki.gbnt.local" || domain == "loki.gbnt" {
				t.Errorf("forbidden generic entry found: %q", domain)
			}
			if strings.ContainsAny(domain, " ()[]_") {
				t.Errorf("invalid character in domain %q", domain)
			}
		}
	}

	// ── TEST CUSTOM CLUSTER DOMAIN (e.g. acme.corp) ─────────────────────────
	_ = db.SetClusterDomain("acme.corp")
	GenerateHostsFile()

	customBytes, err := os.ReadFile(hostsFile)
	if err != nil {
		t.Fatalf("failed to read custom domain hosts file: %v", err)
	}
	customContent := string(customBytes)
	t.Logf("Generated custom domain gubernator.hosts:\n%s", customContent)

	if !strings.Contains(customContent, "manager.caddy.acme.corp") {
		t.Errorf("missing manager.caddy.acme.corp")
	}
	if !strings.Contains(customContent, "node-gbnt-worker1.caddy.acme.corp") {
		t.Errorf("missing node-gbnt-worker1.caddy.acme.corp")
	}
	if !strings.Contains(customContent, "db.wordpress.acme.corp") {
		t.Errorf("missing db.wordpress.acme.corp")
	}
}
