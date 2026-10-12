package api

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/mario-ezquerro/gubernator/internal/aqueducts"
	"github.com/mario-ezquerro/gubernator/internal/autoscaler"
	"github.com/mario-ezquerro/gubernator/internal/caddy"
	"github.com/mario-ezquerro/gubernator/internal/coredns"
	"github.com/mario-ezquerro/gubernator/internal/db"
	"github.com/mario-ezquerro/gubernator/internal/docker"
	"github.com/mario-ezquerro/gubernator/internal/monitor"
)

// StartSelfHealingWatchdog periodically reconciles all services across cluster nodes.
// If a container dies, fails to start, or has fewer active replicas than desired,
// Gubernator automatically re-schedules and starts replacement replicas on healthy nodes,
// while actively purging stale/dead tasks and orphaned containers from the cluster.
func StartSelfHealingWatchdog(ctx context.Context) {
	slog.Info("self-healing watchdog: cluster reconciliation engine started")

	// Wait 10 seconds after boot before first reconciliation to allow cluster nodes to report heartbeats
	select {
	case <-ctx.Done():
		return
	case <-time.After(10 * time.Second):
	}

	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("self-healing watchdog: stopped")
			return
		case <-ticker.C:
			ReconcileClusterServices()
			autoscaler.EvaluateAndAutoscale()
		}
	}
}

// ReconcileClusterServices scans all active stacks, enforces desired replica counts,
// schedules missing tasks, and purges all dead, duplicate, and orphan containers.
func ReconcileClusterServices() (prunedCount int, rescheduledCount int) {
	var stacks []db.Stack
	if err := db.DB.Find(&stacks).Error; err != nil {
		return 0, 0
	}

	validContainerNames := map[string]bool{
		"gbnt-manager":            true,
		"gbnt-worker":             true,
		"gbnt-coredns":            true,
		"gbnt-caddy":              true,
		"gbnt-monitor-cadvisor":   true,
		"gbnt-monitor-prometheus": true,
		"gbnt-monitor-grafana":    true,
		"gbnt-monitor-loki":       true,
		"gbnt-monitor-promtail":   true,
		"gbnt-monitor-jaeger":     true,
		"gbnt-monitor-scope":      true,
	}

	// Self-heal Core stack (CoreDNS + Caddy) if stopped after node reboot
	reconcileSystemStacks(&rescheduledCount)

	for _, stack := range stacks {
		// Skip system stacks (Caddy/CoreDNS, SRE monitor, and Scope Net-Topology have their own dedicated sync lifecycles)
		sID := strings.ToLower(stack.ID)
		sName := strings.ToLower(stack.Name)
		if isSystemStack(sID) || strings.Contains(sName, "core-gbnt") || strings.Contains(sName, "monitor") ||
			strings.Contains(sName, "topology") || strings.Contains(sName, "scope") {
			continue
		}

		p, r := reconcileStackInternal(&stack, validContainerNames)
		prunedCount += p
		rescheduledCount += r
	}

	// Clean up orphaned gbnt-* Docker containers on the Manager host
	orphanCount := docker.PruneOrphanContainers(validContainerNames)
	prunedCount += orphanCount

	if prunedCount > 0 || rescheduledCount > 0 {
		slog.Info("reconciliation cycle finished", "pruned", prunedCount, "rescheduled", rescheduledCount)
		aqueducts.GenerateAllAsync()
	}

	return prunedCount, rescheduledCount
}

// reconcileSystemStacks ensures CoreDNS, Caddy, and SRE Monitor containers are running after a node reboot
// unless the administrator explicitly stopped the stack.
func reconcileSystemStacks(rescheduledCount *int) {
	// 1. Check Core stack (CoreDNS + Caddy)
	var coreStack db.Stack
	if err := db.DB.First(&coreStack, "id = ?", coredns.CoreStackID).Error; err == nil {
		// Check if CoreDNS container is running
		dnsStatus, dnsErr := docker.InspectContainerStatus("node-local-manager", coredns.ContainerName)
		if dnsErr != nil || dnsStatus != "running" {
			var dnsTask db.Task
			explicitlyStopped := false
			if err := db.DB.First(&dnsTask, "id = ?", "core-task-coredns").Error; err == nil && dnsTask.Status == "stopped" {
				explicitlyStopped = true
			}
			if !explicitlyStopped {
				slog.Warn("watchdog: gbnt-coredns is not running, auto-restarting CoreDNS container")
				if err := coredns.EnsureRunning(); err == nil {
					_ = coredns.RegisterInDB(db.DB)
					*rescheduledCount++
				}
			}
		} else {
			// Ensure task status in DB reflects running state
			db.DB.Model(&db.Task{}).Where("id = ? AND status != ?", "core-task-coredns", "running").Updates(map[string]interface{}{
				"status":     "running",
				"updated_at": time.Now(),
			})
		}

		caddyStatus, caddyErr := docker.InspectContainerStatus("node-local-manager", caddy.ContainerName)
		if caddyErr != nil || caddyStatus != "running" {
			var caddyTask db.Task
			explicitlyStopped := false
			if err := db.DB.First(&caddyTask, "id = ?", "core-task-caddy").Error; err == nil && caddyTask.Status == "stopped" {
				explicitlyStopped = true
			}
			if !explicitlyStopped {
				slog.Warn("watchdog: gbnt-caddy is not running, auto-restarting Caddy container")
				if err := caddy.EnsureRunning(); err == nil {
					_ = coredns.RegisterInDB(db.DB)
					*rescheduledCount++
				}
			}
		} else {
			db.DB.Model(&db.Task{}).Where("id = ? AND status != ?", "core-task-caddy", "running").Updates(map[string]interface{}{
				"status":     "running",
				"updated_at": time.Now(),
			})
		}
	}

	// 2. Check SRE Monitor stack containers (Jaeger, Grafana, Prometheus, Loki, Promtail, cAdvisor)
	var sreStack db.Stack
	if err := db.DB.First(&sreStack, "id = ?", monitor.SREStackID).Error; err == nil {
		sreContainers := []struct {
			taskID string
			name   string
		}{
			{"sre-task-jaeger", "gbnt-monitor-jaeger"},
			{"sre-task-grafana", "gbnt-monitor-grafana"},
			{"sre-task-prometheus", "gbnt-monitor-prometheus"},
			{"sre-task-loki", "gbnt-monitor-loki"},
			{"sre-task-promtail", "gbnt-monitor-promtail"},
			{"sre-task-cadvisor", "gbnt-monitor-cadvisor"},
		}
		for _, sc := range sreContainers {
			var t db.Task
			if err := db.DB.First(&t, "id = ?", sc.taskID).Error; err == nil && t.Status == "stopped" {
				continue // Explicitly stopped by user
			}
			st, err := docker.InspectContainerStatus("node-local-manager", sc.name)
			if err == nil && (st == "exited" || st == "created" || st == "dead") {
				slog.Warn("watchdog: SRE container exited after reboot, auto-starting", "container", sc.name)
				if docker.ExecuteNodeDockerAction("node-local-manager", sc.name, "start") == nil {
					db.DB.Model(&db.Task{}).Where("id = ?", sc.taskID).Updates(map[string]interface{}{
						"status":     "running",
						"updated_at": time.Now(),
					})
					*rescheduledCount++
				}
			} else if err == nil && st == "running" {
				db.DB.Model(&db.Task{}).Where("id = ? AND status != ?", sc.taskID, "running").Updates(map[string]interface{}{
					"status":     "running",
					"updated_at": time.Now(),
				})
			}
		}
	}
}

// ReconcileSingleStack reconciles a specific stack by ID or name,
// aligning container counts with desired replicas and purging dead/stale instances.
func ReconcileSingleStack(stackID string) (prunedCount int, rescheduledCount int, err error) {
	var stack db.Stack
	if err := db.DB.Where("id = ? OR name = ?", stackID, stackID).First(&stack).Error; err != nil {
		return 0, 0, fmt.Errorf("stack not found: %s", stackID)
	}

	validContainerNames := make(map[string]bool)
	p, r := reconcileStackInternal(&stack, validContainerNames)

	if p > 0 || r > 0 {
		aqueducts.GenerateAllAsync()
	}
	return p, r, nil
}

//noinspection GoUnusedExportedFunction
// PruneAllDeadAndOrphanTasks triggers an immediate full-cluster garbage collection.
// TODO(watchdog): Exposed as a REST API endpoint in future scheduler iterations for manual GC triggers.
func PruneAllDeadAndOrphanTasks() (prunedCount int, err error) {
	p, _ := ReconcileClusterServices()
	return p, nil
}

// reconcileStackInternal performs the core reconciliation logic for a single stack.
func reconcileStackInternal(stack *db.Stack, validContainerNames map[string]bool) (prunedCount int, rescheduledCount int) {
	var services []db.Service
	if err := db.DB.Where("stack_id = ?", stack.ID).Find(&services).Error; err != nil {
		return 0, 0
	}

	for _, svc := range services {
		desired := svc.DesiredReplicas
		if desired <= 0 {
			desired = 1 // Default fallback for Compose services
		}

		var tasks []db.Task
		if err := db.DB.Where("service_id = ?", svc.ID).Order("created_at desc").Find(&tasks).Error; err != nil {
			continue
		}

		var runningTasks []db.Task
		var stoppedTasks []db.Task
		var deadTasks []db.Task

		for _, task := range tasks {
			cName := task.ContainerName
			if cName == "" {
				cName = "gbnt-" + task.ID
			}

			if task.Status == "running" || task.Status == "pulling" || task.Status == "starting" || task.Status == "pending" {
				// 1. Verify node is healthy and active
				var node db.Node
				nodeHealthy := false
				if err := db.DB.First(&node, "id = ?", task.NodeID).Error; err == nil {
					if node.Status == "active" || node.Status == "ready" {
						nodeHealthy = true
					}
				}

				if !nodeHealthy {
					slog.Warn("reconciler: node unreachable for task, marking dead", "task", task.ID[:8], "node", task.NodeID)
					db.DB.Model(&db.Task{}).Where("id = ?", task.ID).Updates(map[string]interface{}{
						"status": "dead",
						"error":  fmt.Sprintf("Node %s is unreachable", task.NodeID),
					})
					deadTasks = append(deadTasks, task)
					continue
				}

				// 2. If running on Manager, inspect container status in Docker
				if task.NodeID == "node-local-manager" || strings.Contains(task.NodeID, "manager") {
					status, err := docker.InspectContainerStatus(task.NodeID, cName)
					if err != nil || status == "exited" || status == "dead" {
						// Container exited or died in Docker!
						// Try restart once if exited
						if status == "exited" && docker.ExecuteNodeDockerAction(task.NodeID, cName, "start") == nil {
							slog.Info("reconciler: restarted exited container", "container", cName)
							runningTasks = append(runningTasks, task)
							validContainerNames[cName] = true
							continue
						}

						slog.Warn("reconciler: container dead/exited in docker, marking dead", "task", task.ID[:8], "container", cName)
						db.DB.Model(&db.Task{}).Where("id = ?", task.ID).Updates(map[string]interface{}{
							"status": "dead",
							"error":  "Container exited or killed in Docker",
						})
						_ = docker.RemoveContainerOnNode(task.NodeID, cName)
						deadTasks = append(deadTasks, task)
						continue
					}
				}

				runningTasks = append(runningTasks, task)
				validContainerNames[cName] = true
			} else if task.Status == "stopped" {
				stoppedTasks = append(stoppedTasks, task)
			} else {
				deadTasks = append(deadTasks, task)
			}
		}

		// SCENARIO 1: Stack is STOPPED (no running tasks, only stopped/dead tasks)
		if len(runningTasks) == 0 && len(stoppedTasks) > 0 {
			// Enforce at most 'desired' stopped tasks
			if len(stoppedTasks) > desired {
				excess := stoppedTasks[desired:]
				for _, et := range excess {
					cName := et.ContainerName
					if cName == "" {
						cName = "gbnt-" + et.ID
					}
					_ = docker.RemoveContainerOnNode(et.NodeID, cName)
					db.DB.Delete(&et)
					prunedCount++
					slog.Info("reconciler: pruned excess stopped container", "task", et.ID[:8], "service", svc.Name)
				}
				stoppedTasks = stoppedTasks[:desired]
			}

			// Keep valid container names for desired stopped tasks
			for _, st := range stoppedTasks {
				cName := st.ContainerName
				if cName == "" {
					cName = "gbnt-" + st.ID
				}
				validContainerNames[cName] = true
			}

			// Purge any dead tasks for this stopped service
			for _, dt := range deadTasks {
				cName := dt.ContainerName
				if cName == "" {
					cName = "gbnt-" + dt.ID
				}
				_ = docker.RemoveContainerOnNode(dt.NodeID, cName)
				db.DB.Delete(&dt)
				prunedCount++
				slog.Info("reconciler: pruned dead task from stopped service", "task", dt.ID[:8], "service", svc.Name)
			}
			continue
		}

		// SCENARIO 2: Stack is ACTIVE / RUNNING
		// 2.1 Missing active replicas: schedule replacement
		if len(runningTasks) < desired {
			missing := desired - len(runningTasks)
			slog.Info("reconciler: repairing degraded service", "stack", stack.Name, "service", svc.Name, "running", len(runningTasks), "desired", desired, "missing", missing)
			targetHost := stack.NodeID
			if targetHost != "" {
				var targetCheck db.Node
				if err := db.DB.First(&targetCheck, "id = ?", targetHost).Error; err != nil || (targetCheck.Status != "active" && targetCheck.Status != "ready") {
					// Host is unreachable or down! Re-evaluate optimal host for stack
					if newHost, err := SelectOptimalNodeForStack(svc.Constraints, "auto"); err == nil {
						targetHost = newHost.ID
						stack.NodeID = newHost.ID
						db.DB.Model(&stack).Update("node_id", newHost.ID)
					}
				}
			}
			for i := 0; i < missing; i++ {
				newTask := ScheduleSingleReplica(&svc, targetHost)
				if newTask != nil {
					rescheduledCount++
				}
			}
		} else if len(runningTasks) > desired {
			// Excess running replicas: keep newest 'desired', prune older duplicates
			excess := runningTasks[desired:]
			for _, et := range excess {
				cName := et.ContainerName
				if cName == "" {
					cName = "gbnt-" + et.ID
				}
				_ = docker.RemoveContainerOnNode(et.NodeID, cName)
				db.DB.Delete(&et)
				prunedCount++
				slog.Info("reconciler: pruned excess running task", "task", et.ID[:8], "service", svc.Name)
			}
		}

		// 2.2 Actively purge all dead tasks from running service
		for _, dt := range deadTasks {
			cName := dt.ContainerName
			if cName == "" {
				cName = "gbnt-" + dt.ID
			}
			_ = docker.RemoveContainerOnNode(dt.NodeID, cName)
			db.DB.Delete(&dt)
			prunedCount++
			slog.Info("reconciler: purged dead task from running service", "task", dt.ID[:8], "service", svc.Name)
		}

		// 2.3 Purge any leftover stopped tasks from a running service
		for _, st := range stoppedTasks {
			cName := st.ContainerName
			if cName == "" {
				cName = "gbnt-" + st.ID
			}
			_ = docker.RemoveContainerOnNode(st.NodeID, cName)
			db.DB.Delete(&st)
			prunedCount++
			slog.Info("reconciler: purged stale stopped task from running service", "task", st.ID[:8], "service", svc.Name)
		}
	}

	return prunedCount, rescheduledCount
}
