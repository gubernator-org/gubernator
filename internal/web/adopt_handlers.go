package web

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gubernator-org/gubernator/internal/db"
	"github.com/gubernator-org/gubernator/internal/docker"
	"gopkg.in/yaml.v3"
)

// unmanagedListHandler discovers all Docker containers across Manager + Workers
// that are not managed by any Gubernator Stack/Task or core infrastructure.
func unmanagedListHandler(c *gin.Context) {
	result, err := docker.DiscoverUnmanagedContainers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, result)
}

// unmanagedGenerateComposeHandler runs docker inspect (or reads the host compose file if requested)
// to reverse-engineer a clean docker-compose.yml for the selected unmanaged containers.
func unmanagedGenerateComposeHandler(c *gin.Context) {
	var req struct {
		NodeID         string   `json:"node_id"`
		ContainerNames []string `json:"container_names" binding:"required"`
		StackName      string   `json:"stack_name"`
		PreferHostFile bool     `json:"prefer_host_file"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(req.ContainerNames) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "container_names must not be empty"})
		return
	}
	if req.NodeID == "" {
		req.NodeID = "node-local-manager"
	}

	res, err := docker.GenerateComposeForNode(req.NodeID, req.ContainerNames, req.StackName, req.PreferHostFile)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

// unmanagedAdoptHandler registers existing unmanaged containers as a managed Gubernator Stack
// without restarting or interrupting the running containers (Zero-Downtime Adoption).
func unmanagedAdoptHandler(c *gin.Context) {
	var req struct {
		StackName      string   `json:"stack_name" binding:"required"`
		NodeID         string   `json:"node_id"`
		ContainerNames []string `json:"container_names" binding:"required"`
		ComposeYAML    string   `json:"compose_yaml"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	req.StackName = strings.TrimSpace(req.StackName)
	if req.StackName == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "stack_name is required"})
		return
	}
	if len(req.ContainerNames) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "at least one container is required"})
		return
	}
	if req.NodeID == "" {
		req.NodeID = "node-local-manager"
	}

	// Ensure no stack with the same name already exists
	var existing db.Stack
	if err := db.DB.Where("LOWER(name) = LOWER(?) OR id = ?", req.StackName, req.StackName).First(&existing).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{
			"error": fmt.Sprintf("A stack named %q already exists in Gubernator. Choose a different stack name.", req.StackName),
		})
		return
	}

	// Inspect live containers to extract accurate runtime metadata (and fallback YAML if none supplied)
	gen, err := docker.GenerateComposeForNode(req.NodeID, req.ContainerNames, req.StackName, false)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to inspect containers: %v", err)})
		return
	}

	composeYAML := strings.TrimSpace(req.ComposeYAML)
	if composeYAML == "" {
		composeYAML = gen.ComposeYAML
	}

	// Validate YAML syntax before saving
	var parsedCheck map[string]interface{}
	if err := yaml.Unmarshal([]byte(composeYAML), &parsedCheck); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid Compose YAML: %v", err)})
		return
	}

	now := time.Now()
	stackID := "stack-" + uuid.New().String()[:8]
	newStack := db.Stack{
		ID:             stackID,
		Name:           req.StackName,
		RawComposeFile: composeYAML,
		NodeID:         req.NodeID,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := db.DB.Create(&newStack).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to save stack: %v", err)})
		return
	}

	adoptedTasks := 0
	for _, svcMeta := range gen.Services {
		svcID := fmt.Sprintf("svc-%s-%s", stackID, uuid.New().String()[:6])
		newSvc := db.Service{
			ID:              svcID,
			StackID:         stackID,
			Name:            svcMeta.ServiceName,
			Image:           svcMeta.Image,
			DesiredReplicas: 1,
			Ports:           svcMeta.Ports,
			Env:             svcMeta.Env,
			Volumes:         svcMeta.Volumes,
			Command:         svcMeta.Command,
			CpuLimit:        svcMeta.CpuLimit,
			MemoryLimit:     svcMeta.MemoryLimit,
			CreatedAt:       now,
			UpdatedAt:       now,
		}
		if err := db.DB.Create(&newSvc).Error; err != nil {
			continue
		}

		taskID := fmt.Sprintf("task-%s-%s", svcMeta.ServiceName, uuid.New().String()[:6])
		newTask := db.Task{
			ID:            taskID,
			ServiceID:     svcID,
			NodeID:        req.NodeID,
			Status:        svcMeta.Status,
			ContainerIP:   svcMeta.ContainerIP,
			ContainerName: svcMeta.ContainerName,
			CpuLimit:      svcMeta.CpuLimit,
			MemoryLimit:   svcMeta.MemoryLimit,
			CreatedAt:     now,
			UpdatedAt:     now,
		}
		if err := db.DB.Create(&newTask).Error; err == nil {
			adoptedTasks++
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"status":           "adopted",
		"stack_id":         stackID,
		"stack_name":       req.StackName,
		"node_id":          req.NodeID,
		"adopted_services": len(gen.Services),
		"adopted_tasks":    adoptedTasks,
	})
}

// unmanagedActionHandler performs day-1 lifecycle actions (start, stop, restart, rm) on an unmanaged container.
func unmanagedActionHandler(c *gin.Context) {
	var req struct {
		NodeID        string `json:"node_id"`
		ContainerName string `json:"container_name" binding:"required"`
		Action        string `json:"action" binding:"required"` // start, stop, restart, rm
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.NodeID == "" {
		req.NodeID = "node-local-manager"
	}

	var dockerAction string
	switch strings.ToLower(strings.TrimSpace(req.Action)) {
	case "start":
		dockerAction = "start"
	case "stop":
		dockerAction = "stop"
	case "restart":
		dockerAction = "restart"
	case "rm", "remove":
		dockerAction = "rm -f"
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported action (allowed: start, stop, restart, rm)"})
		return
	}

	if err := docker.ExecuteNodeDockerAction(req.NodeID, req.ContainerName, dockerAction); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":         "ok",
		"action":         req.Action,
		"container_name": req.ContainerName,
		"node_id":        req.NodeID,
	})
}
