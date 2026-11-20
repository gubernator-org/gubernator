package updater

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestIsNewerVersion(t *testing.T) {
	tests := []struct {
		current string
		latest  string
		want    bool
	}{
		{"v4.1.0", "v4.1.4", true},
		{"v4.1.4", "v4.1.4", false},
		{"v4.2.0", "v4.1.9", false},
		{"v3.9.9", "v4.0.0", true},
		{"dev", "v4.1.4", false},
		{"", "v4.1.4", false},
	}
	for _, tc := range tests {
		if got := isNewerVersion(tc.current, tc.latest); got != tc.want {
			t.Errorf("isNewerVersion(%q, %q) = %v, want %v", tc.current, tc.latest, got, tc.want)
		}
	}
}

func TestHasAssetForPlatform(t *testing.T) {
	assets := []githubAsset{
		{Name: "gbnt-linux-arm64.gz"},
		{Name: "gbnt-linux-amd64"},
		{Name: "gbnt-windows-amd64.exe.gz"},
	}
	if !hasAssetForPlatform(assets, "linux", "arm64") {
		t.Fatal("expected linux/arm64 .gz asset to match")
	}
	if !hasAssetForPlatform(assets, "linux", "amd64") {
		t.Fatal("expected linux/amd64 raw asset to match")
	}
	if !hasAssetForPlatform(assets, "windows", "amd64") {
		t.Fatal("expected windows/amd64 .exe.gz asset to match")
	}
	if hasAssetForPlatform(assets, "darwin", "arm64") {
		t.Fatal("did not expect darwin/arm64 to match")
	}
}

func TestAtomicInstallBinary(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "src-bin")
	dst := filepath.Join(dir, "dst-bin")

	if err := os.WriteFile(src, []byte("#!/bin/sh\necho v4.1.4\n"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(dst, []byte("#!/bin/sh\necho old\n"), 0755); err != nil {
		t.Fatal(err)
	}

	if err := atomicInstallBinary(src, dst); err != nil {
		t.Fatalf("atomicInstallBinary failed: %v", err)
	}
	got, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "#!/bin/sh\necho v4.1.4\n" {
		t.Fatalf("unexpected installed content: %q", string(got))
	}
}

func TestPostRestartVerificationHandoff(t *testing.T) {
	defer func() { _ = os.Remove(persistedUpdateStatePath) }()

	// Reset in-memory state to idle (simulating freshly restarted Manager process)
	statusMutex.Lock()
	currentUpdateStatus = UpdateProgressStatus{
		Status:          "idle",
		ProgressMessage: "Ready",
	}
	statusMutex.Unlock()

	persistUpdateState(UpdateProgressStatus{
		Status:         "restarting",
		TargetVersion:  "v4.1.4",
		SHA256Verified: true,
		NodeResults: []NodeUpdateResult{
			{NodeID: "node-local-manager", Role: "manager", Status: "updating"},
			{NodeID: "node-gbnt-worker1", Role: "worker", Status: "verified", Version: "Gubernator v4.1.4"},
		},
		UpdatedAt: time.Now().UTC().Format(time.RFC3339),
	})

	// Case 1: Manager restarted onto the OLD version -> MUST NOT report success!
	stOld := GetUpdateStatusWithVersion("v4.1.0")
	if stOld.Status == "success" {
		t.Fatalf("must not report success when running version is still %s", stOld.RunningVersion)
	}
	if stOld.RunningVersion != "v4.1.0" {
		t.Fatalf("expected RunningVersion v4.1.0, got %s", stOld.RunningVersion)
	}

	// Case 2: Manager restarted onto the TARGET version -> MUST report verified success!
	stNew := GetUpdateStatusWithVersion("v4.1.4")
	if stNew.Status != "success" {
		t.Fatalf("expected status 'success', got %q", stNew.Status)
	}
	if !stNew.BinaryVerified || !stNew.SHA256Verified {
		t.Fatalf("expected BinaryVerified & SHA256Verified to be true")
	}
	if len(stNew.NodeResults) != 2 || stNew.NodeResults[0].Status != "verified" {
		t.Fatalf("expected manager node result to be marked verified, got %+v", stNew.NodeResults)
	}
}
