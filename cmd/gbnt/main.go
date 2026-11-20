package main

import (
	"os"
	"strings"

	"github.com/gubernator-org/gubernator/internal/cli"
	"github.com/gubernator-org/gubernator/internal/web"
)

// @title           Gubernator API
// @version         1.0
// @description     This is the API Server for Gubernator orchestration.
// @host            localhost:4002
// @BasePath        /

// version is injected at compile time via `-ldflags "-X main.version=vX.Y.Z"`.
var version = "dev"

func init() {
	// Only fall back to disk VERSION files in local `go run` dev builds.
	// Release binaries built with `-X main.version=vX.Y.Z` MUST always report their true compiled version.
	if version == "" || version == "dev" {
		for _, p := range []string{"VERSION", "/data/VERSION", "/app/VERSION", "../VERSION"} {
			if data, err := os.ReadFile(p); err == nil {
				v := strings.TrimSpace(string(data))
				if v != "" && strings.HasPrefix(v, "v") {
					version = v
					break
				}
			}
		}
	}
	if version == "" || version == "dev" {
		version = "v4.1.4"
	}
	cli.Version = version
	web.Version = version
}

func main() {
	cli.Execute()
}
