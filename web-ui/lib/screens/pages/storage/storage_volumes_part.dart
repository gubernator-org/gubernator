part of '../storage_page.dart';

extension _StorageVolumesExt on _StoragePageState {
  void _showCreateDirectoryDialog({String? initialPath, String? initialNode}) {
    final pathCtrl = TextEditingController(text: initialPath ?? '/var/contenedores/');
    String selectedTargetNode = initialNode ?? 'all';
    String selectedPerm = '0777';
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.create_new_folder, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Create Storage Directory'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a mountpoint directory on the local Manager or across Centurion Worker nodes with permissions suitable for container volume mobility.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Directory Path',
                        hintText: 'e.g. /var/contenedores/myapp_data or /mnt/nfs/shared',
                        prefixIcon: Icon(Icons.folder_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTargetNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Centurion Node(s)',
                        prefixIcon: Icon(Icons.hub_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('🌐 All Nodes in Cluster (Manager + Workers)'),
                        ),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedTargetNode = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPerm,
                      decoration: const InputDecoration(
                        labelText: 'Filesystem Permissions (POSIX)',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '0777',
                          child: Text('0777 — Full Read/Write (Docker Container Recommended)'),
                        ),
                        DropdownMenuItem(
                          value: '0755',
                          child: Text('0755 — Standard (Owner R/W, Others Read-Only)'),
                        ),
                        DropdownMenuItem(
                          value: '0700',
                          child: Text('0700 — Private (Owner Only)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedPerm = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: isCreating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, size: 16),
                  label: const Text('Create Directory'),
                  onPressed: isCreating
                      ? null
                      : () async {
                          final path = pathCtrl.text.trim();
                          if (path.isEmpty) {
                            _showSnackBar('Please specify a directory path', isError: true);
                            return;
                          }
                          setDlgState(() => isCreating = true);
                          try {
                            final ok = await ApiService.createStorageDirectory(
                              path: path,
                              targetNode: selectedTargetNode,
                              permissions: selectedPerm,
                            );
                            if (ok) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              _showSnackBar('Directory created successfully on $selectedTargetNode');
                              _loadAllData();
                            } else {
                              setDlgState(() => isCreating = false);
                              _showSnackBar('Failed to create directory', isError: true);
                            }
                          } catch (e) {
                            setDlgState(() => isCreating = false);
                            _showSnackBar('Error: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDirectoryExplorerDialog(String initialPath, {String? initialNode}) {
    String currentPath = initialPath.isNotEmpty ? initialPath : '/var/contenedores';
    String currentNode = (initialNode != null && initialNode.isNotEmpty && initialNode != 'cluster') ? initialNode : 'all';
    List<DirectoryEntryModel> entries = [];
    bool isLoading = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void loadEntries() async {
              setDlgState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                final list = await ApiService.listDirectoryContents(path: currentPath, targetNode: currentNode);
                setDlgState(() {
                  entries = list;
                  isLoading = false;
                });
              } catch (e) {
                setDlgState(() {
                  errorMessage = e.toString();
                  isLoading = false;
                });
              }
            }

            // Load on first build
            if (isLoading && errorMessage == null && entries.isEmpty) {
              loadEntries();
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_shared, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Directory File Explorer (ls)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Target Node dropdown inside header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: currentNode,
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('🌐 Manager / First Available')),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            currentNode = val;
                            loadEntries();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Path Navigation Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            tooltip: 'Up to parent directory',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final parent = currentPath.substring(0, currentPath.lastIndexOf('/'));
                              if (parent.isNotEmpty) {
                                currentPath = parent;
                                loadEntries();
                              } else if (currentPath != '/') {
                                currentPath = '/';
                                loadEntries();
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              currentPath,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: 'Refresh listing',
                            visualDensity: VisualDensity.compact,
                            onPressed: loadEntries,
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.create_new_folder, size: 14),
                            label: const Text('New Folder', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              _showCreateDirectoryDialog(initialPath: '$currentPath/new_folder', initialNode: currentNode);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // File List Content
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                                      const SizedBox(height: 8),
                                      Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Retry'),
                                        onPressed: loadEntries,
                                      ),
                                    ],
                                  ),
                                )
                              : entries.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.folder_open, size: 40, color: Colors.grey[500]),
                                          const SizedBox(height: 8),
                                          const Text('Directory is empty', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: entries.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final item = entries[idx];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          leading: Icon(
                                            item.isDir ? Icons.folder : Icons.insert_drive_file,
                                            color: item.isDir ? Colors.amber : const Color(0xFF38BDF8),
                                            size: 22,
                                          ),
                                          title: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: item.isDir ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Permissions: ${item.permissions}',
                                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey[400]),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.sizeFormatted,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (item.isDir) ...[
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                                  tooltip: 'Open folder',
                                                  onPressed: () {
                                                    currentPath = item.path;
                                                    loadEntries();
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                          onTap: item.isDir
                                              ? () {
                                                  currentPath = item.path;
                                                  loadEntries();
                                                }
                                              : null,
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showDirectoryPickerDialog({String? initialPath, String? initialNode, String title = 'Select Directory'}) async {
    String currentPath = initialPath != null && initialPath.isNotEmpty ? initialPath : '/var/contenedores';
    String currentNode = (initialNode != null && initialNode.isNotEmpty && initialNode != 'cluster') ? initialNode : 'all';
    List<DirectoryEntryModel> entries = [];
    bool isLoading = true;
    String? errorMessage;

    return await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            void loadEntries() async {
              setDlgState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                final list = await ApiService.listDirectoryContents(path: currentPath, targetNode: currentNode);
                setDlgState(() {
                  entries = list;
                  isLoading = false;
                });
              } catch (e) {
                setDlgState(() {
                  errorMessage = e.toString();
                  isLoading = false;
                });
              }
            }

            // Load on first build
            if (isLoading && errorMessage == null && entries.isEmpty) {
              loadEntries();
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: currentNode,
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('🌐 Manager / First Available')),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            currentNode = val;
                            loadEntries();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                height: 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Navigation Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            tooltip: 'Up to parent directory',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              final parent = currentPath.substring(0, currentPath.lastIndexOf('/'));
                              if (parent.isNotEmpty) {
                                currentPath = parent;
                                loadEntries();
                              } else if (currentPath != '/') {
                                currentPath = '/';
                                loadEntries();
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              currentPath,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: 'Refresh listing',
                            visualDensity: VisualDensity.compact,
                            onPressed: loadEntries,
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.create_new_folder, size: 14, color: Color(0xFF10B981)),
                            label: const Text('New Folder', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF10B981),
                            ),
                            onPressed: () {
                              final folderNameCtrl = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (fctx) {
                                  return AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.create_new_folder, color: Color(0xFF10B981), size: 20),
                                        SizedBox(width: 8),
                                        Text('Create New Subfolder'),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Create subfolder inside: $currentPath', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: folderNameCtrl,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Folder Name',
                                            hintText: 'e.g. database_backups or myapp',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(fctx), child: const Text('Cancel')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                        onPressed: () async {
                                          final fName = folderNameCtrl.text.trim();
                                          if (fName.isEmpty) return;
                                          Navigator.pop(fctx);
                                          final newPath = currentPath == '/' ? '/$fName' : '$currentPath/$fName';
                                          try {
                                            final ok = await ApiService.createStorageDirectory(
                                              path: newPath,
                                              targetNode: currentNode,
                                              permissions: '0777',
                                            );
                                            if (ok) {
                                              _showSnackBar('✅ Folder "$newPath" created!');
                                              currentPath = newPath;
                                              loadEntries();
                                              _loadAllData();
                                            } else {
                                              _showSnackBar('❌ Failed to create folder', isError: true);
                                            }
                                          } catch (e) {
                                            _showSnackBar('❌ Error: $e', isError: true);
                                          }
                                        },
                                        child: const Text('Create Folder'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Path Bookmark Chips
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14),
                          label: const Text('/var/contenedores', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            currentPath = '/var/contenedores';
                            loadEntries();
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14),
                          label: const Text('/var/backups', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            currentPath = '/var/backups';
                            loadEntries();
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14),
                          label: const Text('/data', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            currentPath = '/data';
                            loadEntries();
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14),
                          label: const Text('/mnt', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            currentPath = '/mnt';
                            loadEntries();
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14),
                          label: const Text('/var/lib/docker/volumes', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            currentPath = '/var/lib/docker/volumes';
                            loadEntries();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Directory Listing
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                                      const SizedBox(height: 8),
                                      Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Retry'),
                                        onPressed: loadEntries,
                                      ),
                                    ],
                                  ),
                                )
                              : entries.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.folder_open, size: 40, color: Colors.grey[500]),
                                          const SizedBox(height: 8),
                                          const Text('Directory is empty', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: entries.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final item = entries[idx];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          leading: Icon(
                                            item.isDir ? Icons.folder : Icons.insert_drive_file,
                                            color: item.isDir ? Colors.amber : const Color(0xFF38BDF8),
                                            size: 22,
                                          ),
                                          title: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: item.isDir ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Path: ${item.path}',
                                            style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey[400]),
                                          ),
                                          trailing: item.isDir
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    OutlinedButton(
                                                      style: OutlinedButton.styleFrom(
                                                        visualDensity: VisualDensity.compact,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                      ),
                                                      onPressed: () => Navigator.pop(ctx, item.path),
                                                      child: const Text('Select', style: TextStyle(fontSize: 11)),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                                      tooltip: 'Open folder',
                                                      onPressed: () {
                                                        currentPath = item.path;
                                                        loadEntries();
                                                      },
                                                    ),
                                                  ],
                                                )
                                              : Text(item.sizeFormatted, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          onTap: item.isDir
                                              ? () {
                                                  currentPath = item.path;
                                                  loadEntries();
                                                }
                                              : null,
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text('Select "$currentPath"'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () => Navigator.pop(ctx, currentPath),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateDockerVolumeDialog({String? initialNode}) {
    final nameCtrl = TextEditingController();
    String selectedDriver = 'local';
    String selectedTargetNode = (initialNode != null && initialNode != 'ALL') ? initialNode : 'all';
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.layers, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Create Docker Named Volume'),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a native Docker volume on a specific Centurion host or replicated across all cluster nodes for use in Docker Compose stacks.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Volume Name *',
                        hintText: 'e.g. postgres_data, redis_cache, app_uploads',
                        prefixIcon: Icon(Icons.dns_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDriver,
                      decoration: const InputDecoration(
                        labelText: 'Volume Driver',
                        prefixIcon: Icon(Icons.settings_suggest_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'local',
                          child: Text('local — Default Node-Local POSIX Docker driver'),
                        ),
                        DropdownMenuItem(
                          value: 'glusterfs',
                          child: Text('glusterfs — Replicated Cluster Volume (/var/contenedores)'),
                        ),
                        DropdownMenuItem(
                          value: 'nfs',
                          child: Text('nfs — Remote network filesystem driver'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedDriver = val);
                      },
                    ),
                    if (selectedDriver == 'glusterfs') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hub, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Backed by the cluster GlusterFS 3-node storage mesh. Automatically maps /var/contenedores/<volume_name> natively into Docker with cross-node replication and zero-downtime persistence.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTargetNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Centurion Host(s)',
                        prefixIcon: Icon(Icons.hub_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('🌐 All Nodes in Cluster (Cluster-Wide Creation)'),
                        ),
                        const DropdownMenuItem(
                          value: 'node-local-manager',
                          child: Text('👑 Manager (Local Host)'),
                        ),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedTargetNode = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: isCreating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Create Volume'),
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            _showSnackBar('Volume name is required', isError: true);
                            return;
                          }
                          setDlgState(() => isCreating = true);
                          try {
                            final msg = await ApiService.createDockerVolume(
                              name: name,
                              targetNode: selectedTargetNode,
                              driver: selectedDriver,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('✅ $msg');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isCreating = false);
                            _showSnackBar('❌ Failed to create volume: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPruneDockerVolumesDialog() {
    String selectedTargetNode = 'all';
    bool isPruning = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Prune Unused Docker Volumes'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Warning: This action will permanently remove all unused and dangling Docker volumes on the chosen host(s). Active volumes in running containers will not be deleted.',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTargetNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Centurion Host(s)',
                        prefixIcon: Icon(Icons.hub_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('🌐 All Nodes in Cluster (Manager + Workers)'),
                        ),
                        const DropdownMenuItem(
                          value: 'node-local-manager',
                          child: Text('👑 Manager (Local Host)'),
                        ),
                        ...widget.state.nodes.map(
                          (node) => DropdownMenuItem(
                            value: node.id,
                            child: Text('💻 ${node.role.toUpperCase()}: ${node.ip} (${node.id})'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedTargetNode = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                  icon: isPruning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Prune Volumes'),
                  onPressed: isPruning
                      ? null
                      : () async {
                          setDlgState(() => isPruning = true);
                          try {
                            final report = await ApiService.pruneDockerVolumes(targetNode: selectedTargetNode);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('🧹 $report');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isPruning = false);
                            _showSnackBar('❌ Failed to prune volumes: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showComposeSnippetDialog(StorageVolumeModel v) {
    final snippet = '''# Docker Compose Blueprint for Volume: ${v.name}
# Centurion Residency: ${v.nodeHostname.isNotEmpty ? v.nodeHostname : v.nodeId} (${v.nodeIp.isNotEmpty ? v.nodeIp : "Cluster"})

services:
  app_service:
    image: nginx:alpine
    volumes:
      - ${v.name}:/app/data

volumes:
  ${v.name}:
    external: true
''';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.code, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text('Compose Snippet: ${v.name}'),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this YAML definition into your stack docker-compose.yml to bind this volume to any container service:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: SelectableText(
                    snippet,
                    style: const TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 12.5,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Snippet'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: snippet));
                Navigator.pop(ctx);
                _showSnackBar('📋 Docker Compose snippet copied to clipboard');
              },
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showInspectDockerVolumeDialog(StorageVolumeModel v) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService.inspectDockerVolume(name: v.name, targetNode: v.nodeId),
          builder: (context, snapshot) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text('Inspect Volume: ${v.name}'),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 380,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)))
                        : SingleChildScrollView(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: SelectableText(
                                JsonEncoder.withIndent('  ').convert(snapshot.data ?? {}),
                                style: const TextStyle(
                                  fontFamily: 'Courier New',
                                  fontSize: 12,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ),
              ),
              actions: [
                if (snapshot.hasData)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy JSON'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: JsonEncoder.withIndent('  ').convert(snapshot.data ?? {}),
                      ));
                      _showSnackBar('📋 Volume inspection copied to clipboard');
                    },
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDockerVolumeConfirm(StorageVolumeModel v) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Delete Docker Volume'),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Are you sure you want to permanently delete Docker volume "${v.name}"?'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Host: ${v.nodeHostname.isNotEmpty ? v.nodeHostname : v.nodeId} (${v.nodeIp})', style: const TextStyle(fontSize: 12)),
                          Text('• Mountpoint: ${v.sourcePath}', style: const TextStyle(fontSize: 12)),
                          Text('• Size: ${v.sizeFormatted}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: isDeleting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete, size: 16),
                  label: const Text('Delete Volume'),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDlgState(() => isDeleting = true);
                          try {
                            final msg = await ApiService.deleteDockerVolume(name: v.name, targetNode: v.nodeId);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showSnackBar('🗑️ $msg');
                            _loadAllData();
                          } catch (e) {
                            setDlgState(() => isDeleting = false);
                            _showSnackBar('❌ Failed to delete volume: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }


  // ── Tab 1: Volumes View ──────────────────────────────────────────

  Widget _buildVolumesTab(bool isDark) {
    final filtered = _volumes.where((v) {
      final matchesSearch = _volumeSearch.isEmpty ||
          v.name.toLowerCase().contains(_volumeSearch.toLowerCase()) ||
          v.stackName.toLowerCase().contains(_volumeSearch.toLowerCase()) ||
          v.sourcePath.toLowerCase().contains(_volumeSearch.toLowerCase()) ||
          v.nodeId.toLowerCase().contains(_volumeSearch.toLowerCase()) ||
          v.nodeHostname.toLowerCase().contains(_volumeSearch.toLowerCase()) ||
          v.nodeIp.toLowerCase().contains(_volumeSearch.toLowerCase());
      final matchesType = _volumeTypeFilter == 'ALL' || v.type == _volumeTypeFilter;
      final matchesNode = _volumeNodeFilter == 'ALL' ||
          v.nodeId == _volumeNodeFilter ||
          v.nodeIp == _volumeNodeFilter ||
          (v.nodeId == 'cluster' && _volumeNodeFilter == 'ALL');
      return matchesSearch && matchesType && matchesNode;
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search volumes by name, host IP, stack, or path...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (val) => _updateState(() => _volumeSearch = val),
              ),
            ),
            const SizedBox(width: 8),
            // Volume Type Dropdown
            DropdownButton<String>(
              value: _volumeTypeFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                DropdownMenuItem(value: 'docker_named', child: Text('Docker Named Volumes')),
                DropdownMenuItem(value: 'shared_pool', child: Text('Shared Pool (/var/contenedores)')),
                DropdownMenuItem(value: 'host_bind', child: Text('Host Bind Mounts')),
              ],
              onChanged: (val) {
                if (val != null) _updateState(() => _volumeTypeFilter = val);
              },
            ),
            const SizedBox(width: 8),
            // Node Filter Dropdown
            DropdownButton<String>(
              value: _volumeNodeFilter,
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('🌐 All Centurions')),
                const DropdownMenuItem(value: 'node-local-manager', child: Text('👑 Manager (Local)')),
                ...widget.state.nodes.map(
                  (n) => DropdownMenuItem(
                    value: n.id,
                    child: Text('💻 ${n.role.toUpperCase()}: ${n.ip}'),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  _updateState(() => _volumeNodeFilter = val);
                  _loadAllData();
                }
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Colors.orange),
              label: const Text('Prune Unused', style: TextStyle(color: Colors.orange)),
              onPressed: _showPruneDockerVolumesDialog,
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Explore (ls)'),
              onPressed: () => _showDirectoryExplorerDialog('/var/contenedores', initialNode: _volumeNodeFilter),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.create_new_folder, size: 16),
              label: const Text('New Dir'),
              onPressed: () => _showCreateDirectoryDialog(initialNode: _volumeNodeFilter),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.add_box, size: 16),
              label: const Text('Create Docker Volume'),
              onPressed: () => _showCreateDockerVolumeDialog(initialNode: _volumeNodeFilter),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 10),
                      Text(
                        'No volumes found matching the filter criteria.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            icon: const Icon(Icons.add_box, size: 16),
                            label: const Text('Create Docker Volume'),
                            onPressed: () => _showCreateDockerVolumeDialog(initialNode: _volumeNodeFilter),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.create_new_folder, size: 16),
                            label: const Text('Create Storage Directory'),
                            onPressed: () => _showCreateDirectoryDialog(initialNode: _volumeNodeFilter),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final v = filtered[i];
                    final isDockerVol = v.type == 'docker_named';
                    final isManager = v.nodeRole == 'MANAGER' || v.nodeId == 'node-local-manager';
                    final isWorker = v.nodeRole == 'WORKER' || v.nodeId.startsWith('node-');

                    return Card(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: v.isShared
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : isDockerVol
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                v.isShared
                                    ? Icons.cloud_done
                                    : isDockerVol
                                        ? Icons.dns
                                        : Icons.storage,
                                color: v.isShared
                                    ? const Color(0xFF10B981)
                                    : isDockerVol
                                        ? Colors.lightBlueAccent
                                        : Colors.grey,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      // Centurion Host Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isManager
                                              ? Colors.purple.withValues(alpha: 0.2)
                                              : isWorker
                                                  ? Colors.cyan.withValues(alpha: 0.2)
                                                  : const Color(0xFF10B981).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isManager
                                                ? Colors.purpleAccent.withValues(alpha: 0.4)
                                                : isWorker
                                                    ? Colors.cyanAccent.withValues(alpha: 0.4)
                                                    : const Color(0xFF10B981).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isManager
                                                  ? Icons.military_tech
                                                  : isWorker
                                                      ? Icons.computer
                                                      : Icons.hub,
                                              size: 13,
                                              color: isManager
                                                  ? Colors.purpleAccent
                                                  : isWorker
                                                      ? Colors.cyanAccent
                                                      : const Color(0xFF10B981),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isManager
                                                  ? '👑 MANAGER: ${v.nodeHostname.isNotEmpty ? v.nodeHostname : "Local"} (${v.nodeIp.isNotEmpty ? v.nodeIp : "127.0.0.1"})'
                                                  : isWorker
                                                      ? '💻 CENTURION: ${v.nodeHostname.isNotEmpty ? v.nodeHostname : v.nodeId} (${v.nodeIp})'
                                                      : '🌐 ALL CENTURIONS (Shared)',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: isManager
                                                    ? Colors.purpleAccent
                                                    : isWorker
                                                        ? Colors.cyanAccent
                                                        : const Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Type chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: v.isShared
                                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                              : isDockerVol
                                                  ? Colors.blue.withValues(alpha: 0.2)
                                                  : Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          v.type.toUpperCase().replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: v.isShared
                                                ? const Color(0xFF10B981)
                                                : isDockerVol
                                                    ? Colors.lightBlueAccent
                                                    : Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                      if (v.driver.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'driver: ${v.driver}',
                                            style: TextStyle(fontSize: 9.5, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[800]),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Origin: ${v.stackName.isNotEmpty ? v.stackName : "System Volume"} | Source: ${v.sourcePath}${v.targetPath.isNotEmpty && v.targetPath != v.sourcePath ? " ➔ Target: ${v.targetPath}" : ""}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                v.sizeFormatted,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.folder_open, size: 14),
                              label: const Text('Files (ls)'),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () {
                                _showDirectoryExplorerDialog(
                                  v.sourcePath,
                                  initialNode: v.nodeId,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.code, size: 14, color: Color(0xFF38BDF8)),
                              label: const Text('Compose', style: TextStyle(color: Color(0xFF38BDF8))),
                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => _showComposeSnippetDialog(v),
                            ),
                            if (isDockerVol) ...[
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.info_outline, size: 14),
                                label: const Text('Inspect'),
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => _showInspectDockerVolumeDialog(v),
                              ),
                            ],
                            const SizedBox(width: 6),
                            FilledButton.icon(
                              icon: const Icon(Icons.camera_alt, size: 14),
                              label: const Text('Snapshot'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                _showCreateBackupDialog(
                                  initialStackId: v.stackId,
                                  initialVolumeName: v.name,
                                  initialSourcePath: v.sourcePath,
                                );
                              },
                            ),
                            if (isDockerVol) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Delete Docker Volume',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _deleteDockerVolumeConfirm(v),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

}
