part of '../storage_page.dart';

extension _StorageBackupsPoolsExt on _StoragePageState {
  Future<void> _downloadBackup(String id, String name) async {
    final uri = Uri.parse('/api/backups/download/$id');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showSnackBar('Downloading backup $name.tar.gz...');
    } catch (e) {
      _showSnackBar('Could not initiate download: $e', isError: true);
    }
  }

  Future<void> _deleteBackup(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete backup "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteBackup(id);
        _showSnackBar('Backup deleted successfully');
        _loadAllData();
      } catch (e) {
        _showSnackBar('Failed to delete backup: $e', isError: true);
      }
    }
  }


  void _showCreateBackupDialog({String? initialStackId, String? initialVolumeName, String? initialSourcePath}) {
    final nameCtrl = TextEditingController(text: initialVolumeName != null ? 'backup-$initialVolumeName' : '');
    final sourcePathCtrl = TextEditingController(text: initialSourcePath ?? '');
    final destinationPathCtrl = TextEditingController(text: '/var/backups/gbnt');
    String selectedStack = initialStackId ?? (widget.state.stacks.isNotEmpty ? widget.state.stacks.first.id : '');
    String selectedVolumeName = initialVolumeName ?? '';
    String sourceMode = (initialSourcePath != null || initialVolumeName != null) ? 'select' : (_volumes.isNotEmpty ? 'select' : 'custom');
    bool pauseContainer = true;
    bool isCreatingSourceDir = false;
    bool isCreatingDestDir = false;
    bool encryptBackup = false;
    final passphraseCtrl = TextEditingController();
    final confirmPassphraseCtrl = TextEditingController();
    bool obscurePassphrase = true;

    // Collect all selectable storage targets
    final List<Map<String, String>> selectableTargets = [];

    // 1. Volumes & Shared Pools
    for (final v in _volumes) {
      final label = v.type == 'docker_named'
          ? '💾 [Docker] ${v.name} (${v.nodeHostname})'
          : (v.type == 'shared_pool'
              ? '📁 [Shared] ${v.name} (/var/contenedores)'
              : '📂 [Bind] ${v.name} (${v.sourcePath})');
      selectableTargets.add({
        'id': v.id,
        'name': v.name,
        'path': v.sourcePath,
        'stackId': v.stackId,
        'label': label,
      });
    }

    // 2. Network Mounts
    for (final m in _mounts) {
      selectableTargets.add({
        'id': m.id,
        'name': m.name,
        'path': m.mountPoint,
        'stackId': '',
        'label': '🌐 [Mount] ${m.name} (${m.mountPoint})',
      });
    }

    // 3. Stacks
    for (final s in widget.state.stacks) {
      selectableTargets.add({
        'id': s.id,
        'name': s.name,
        'path': '/var/contenedores/${s.name}',
        'stackId': s.id,
        'label': '📦 [Stack] ${s.name} (${s.id})',
      });
    }

    String? selectedTargetId;
    if (initialVolumeName != null && initialVolumeName.isNotEmpty) {
      for (final t in selectableTargets) {
        if (t['name'] == initialVolumeName || t['path'] == initialSourcePath) {
          selectedTargetId = t['id'];
          break;
        }
      }
    } else if (selectableTargets.isNotEmpty) {
      selectedTargetId = selectableTargets.first['id'];
      if (sourcePathCtrl.text.isEmpty) {
        sourcePathCtrl.text = selectableTargets.first['path'] ?? '';
        selectedVolumeName = selectableTargets.first['name'] ?? '';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.archive, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Create Compressed Backup / Snapshot'),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a point-in-time compressed .tar.gz archive with cryptographic SHA-256 integrity verification.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // 1. NOMBRE DEL BACKUP
                      _buildSectionHeader('1. NOMBRE DEL BACKUP / SNAPSHOT', Icons.label_outline, const Color(0xFF10B981), isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Backup Name',
                          hintText: 'e.g. backup-wordpress-db',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. ORIGEN DE DATOS
                      _buildSectionHeader('2. ORIGEN DE DATOS (¿Qué respaldar?)', Icons.source_outlined, const Color(0xFF38BDF8), isDark),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'select',
                              icon: Icon(Icons.inventory_2_outlined, size: 16),
                              label: Text('Discovered Volumes / Stacks'),
                            ),
                            ButtonSegment(
                              value: 'custom',
                              icon: Icon(Icons.folder_open, size: 16),
                              label: Text('Custom Filesystem Path'),
                            ),
                          ],
                          selected: {sourceMode},
                          onSelectionChanged: (newVal) {
                            setDlgState(() {
                              sourceMode = newVal.first;
                              if (sourceMode == 'select' && selectedTargetId != null) {
                                final match = selectableTargets.firstWhere(
                                  (t) => t['id'] == selectedTargetId,
                                  orElse: () => selectableTargets.first,
                                );
                                sourcePathCtrl.text = match['path'] ?? '';
                                selectedVolumeName = match['name'] ?? '';
                                if (match['stackId'] != null && match['stackId']!.isNotEmpty) {
                                  selectedStack = match['stackId']!;
                                }
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (sourceMode == 'select' && selectableTargets.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedTargetId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Discovered Volume, Pool or Stack',
                            prefixIcon: Icon(Icons.storage),
                            border: OutlineInputBorder(),
                          ),
                          items: selectableTargets.map((t) {
                            return DropdownMenuItem(
                              value: t['id'],
                              child: Text(
                                t['label'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedTargetId = val;
                                final match = selectableTargets.firstWhere((t) => t['id'] == val);
                                sourcePathCtrl.text = match['path'] ?? '';
                                selectedVolumeName = match['name'] ?? '';
                                if (match['stackId'] != null && match['stackId']!.isNotEmpty) {
                                  selectedStack = match['stackId']!;
                                }
                                if (nameCtrl.text.isEmpty || nameCtrl.text.startsWith('backup-')) {
                                  nameCtrl.text = 'backup-${match['name']}';
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_open, size: 16, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Source Path: ${sourcePathCtrl.text}',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sourcePathCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Source Directory / Volume Path',
                                  hintText: 'e.g. /var/contenedores/wordpress/data or /data/storage',
                                  prefixIcon: Icon(Icons.folder_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.explore, size: 16),
                              label: const Text('Browse...'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              onPressed: () async {
                                final selected = await _showDirectoryPickerDialog(
                                  initialPath: sourcePathCtrl.text.isNotEmpty ? sourcePathCtrl.text : '/var/contenedores',
                                  title: 'Browse Source Directory',
                                );
                                if (selected != null) {
                                  setDlgState(() {
                                    sourcePathCtrl.text = selected;
                                    if (nameCtrl.text.isEmpty || nameCtrl.text.startsWith('backup-')) {
                                      final baseName = selected.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'source';
                                      nameCtrl.text = 'backup-$baseName';
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            ActionChip(
                              label: const Text('/var/contenedores/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => sourcePathCtrl.text = '/var/contenedores/'),
                            ),
                            ActionChip(
                              label: const Text('/var/lib/docker/volumes/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => sourcePathCtrl.text = '/var/lib/docker/volumes/'),
                            ),
                            ActionChip(
                              label: const Text('/mnt/shared/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => sourcePathCtrl.text = '/mnt/shared/'),
                            ),
                            ActionChip(
                              label: const Text('/data/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => sourcePathCtrl.text = '/data/'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: isCreatingSourceDir
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.create_new_folder, size: 15, color: Color(0xFF38BDF8)),
                              label: const Text('Create Source Directory (mkdir -p)', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFF38BDF8),
                              ),
                              onPressed: isCreatingSourceDir
                                  ? null
                                  : () async {
                                      final path = sourcePathCtrl.text.trim();
                                      if (path.isEmpty) {
                                        _showSnackBar('Please enter a source directory path first', isError: true);
                                        return;
                                      }
                                      setDlgState(() => isCreatingSourceDir = true);
                                      try {
                                        final ok = await ApiService.createStorageDirectory(
                                          path: path,
                                          targetNode: 'all',
                                          permissions: '0777',
                                        );
                                        if (ok) {
                                          _showSnackBar('✅ Source directory "$path" ready across cluster!');
                                          _loadAllData();
                                        } else {
                                          _showSnackBar('❌ Failed to create directory', isError: true);
                                        }
                                      } catch (e) {
                                        _showSnackBar('❌ Error: $e', isError: true);
                                      } finally {
                                        setDlgState(() => isCreatingSourceDir = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. DESTINO DEL BACKUP
                      _buildSectionHeader('3. DESTINO DEL BACKUP (¿Dónde guardar la copia?)', Icons.save_alt, const Color(0xFFF59E0B), isDark),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: destinationPathCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Destination Directory Path',
                                hintText: 'e.g. /var/backups/gbnt or /var/contenedores/backups',
                                prefixIcon: Icon(Icons.folder_special_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.explore, size: 16),
                            label: const Text('Browse...'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            onPressed: () async {
                              final selected = await _showDirectoryPickerDialog(
                                initialPath: destinationPathCtrl.text.isNotEmpty ? destinationPathCtrl.text : '/var/backups',
                                title: 'Browse / Select Destination Directory',
                              );
                              if (selected != null) {
                                setDlgState(() => destinationPathCtrl.text = selected);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          ActionChip(
                            label: const Text('Default (/var/backups/gbnt)', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/var/backups/gbnt'),
                          ),
                          ActionChip(
                            label: const Text('/var/contenedores/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/var/contenedores/backups/'),
                          ),
                          ActionChip(
                            label: const Text('/data/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/data/backups/'),
                          ),
                          ActionChip(
                            label: const Text('/mnt/shared/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/mnt/shared/backups/'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: isCreatingDestDir
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.create_new_folder, size: 15, color: Color(0xFFF59E0B)),
                            label: const Text('Create Destination Directory (mkdir -p)', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFFF59E0B),
                            ),
                            onPressed: isCreatingDestDir
                                ? null
                                : () async {
                                    final path = destinationPathCtrl.text.trim();
                                    if (path.isEmpty) {
                                      _showSnackBar('Please enter a destination path first', isError: true);
                                      return;
                                    }
                                    setDlgState(() => isCreatingDestDir = true);
                                    try {
                                      final ok = await ApiService.createStorageDirectory(
                                        path: path,
                                        targetNode: 'all',
                                        permissions: '0777',
                                      );
                                      if (ok) {
                                        _showSnackBar('✅ Destination directory "$path" ready across cluster!');
                                        _loadAllData();
                                      } else {
                                        _showSnackBar('❌ Failed to create directory', isError: true);
                                      }
                                    } catch (e) {
                                      _showSnackBar('❌ Error: $e', isError: true);
                                    } finally {
                                      setDlgState(() => isCreatingDestDir = false);
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-creación inteligente: La carpeta de destino (ej. /var/backups/gbnt) se creará automáticamente en el sistema con permisos 0777 al guardar el backup si aún no existe.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. OPCIONES
                      _buildSectionHeader('4. OPCIONES ADICIONALES', Icons.tune, Colors.grey, isDark),
                      const SizedBox(height: 8),
                      if (widget.state.stacks.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedStack.isNotEmpty ? selectedStack : null,
                          decoration: const InputDecoration(
                            labelText: 'Associated Stack (Legion) - Optional',
                            prefixIcon: Icon(Icons.layers_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('None / Standalone Volume')),
                            ...widget.state.stacks.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.id})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => selectedStack = val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock, size: 20, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pause Containers during backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text('Freezes write operations temporarily for 100% DB consistency', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Switch(
                              value: pauseContainer,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) => setDlgState(() => pauseContainer = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. CIFRADO EN REPOSO (ENS - Esquema Nacional de Seguridad)
                      _buildSectionHeader('5. CIFRADO EN REPOSO (ENS mp.si.2 / op.exp.10)', Icons.security, const Color(0xFF10B981), isDark),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: encryptBackup
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: encryptBackup
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.enhanced_encryption,
                                  size: 22,
                                  color: encryptBackup ? const Color(0xFF10B981) : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cifrar Copia con AES-256-GCM',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Cumplimiento ENS categoría MEDIA/ALTA (mp.si.2) con PBKDF2-SHA256 (100k iter.)',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: encryptBackup,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) => setDlgState(() => encryptBackup = val),
                                ),
                              ],
                            ),
                            if (encryptBackup) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              TextField(
                                controller: passphraseCtrl,
                                obscureText: obscurePassphrase,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña de Cifrado (Passphrase)',
                                  hintText: 'Mínimo 8 caracteres para derivar clave AES-256',
                                  prefixIcon: const Icon(Icons.key, size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassphrase ? Icons.visibility : Icons.visibility_off,
                                      size: 18,
                                    ),
                                    onPressed: () => setDlgState(() => obscurePassphrase = !obscurePassphrase),
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: confirmPassphraseCtrl,
                                obscureText: obscurePassphrase,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar Contraseña',
                                  hintText: 'Repita la contraseña de cifrado',
                                  prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.amber),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'El archivo se guardará como .tar.gz.enc. Sin la contraseña será imposible restaurar los datos.',
                                      style: TextStyle(fontSize: 11, color: Colors.amber),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  icon: const Icon(Icons.archive, size: 18),
                  label: const Text('Create Backup'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final srcPath = sourcePathCtrl.text.trim();
                    final destPath = destinationPathCtrl.text.trim();
                    if (name.isEmpty && srcPath.isEmpty) {
                      _showSnackBar('Please specify a backup name or source path', isError: true);
                      return;
                    }
                    if (encryptBackup) {
                      final pass = passphraseCtrl.text;
                      if (pass.length < 8) {
                        _showSnackBar('La contraseña de cifrado debe tener al menos 8 caracteres', isError: true);
                        return;
                      }
                      if (pass != confirmPassphraseCtrl.text) {
                        _showSnackBar('Las contraseñas de cifrado no coinciden', isError: true);
                        return;
                      }
                    }
                    Navigator.pop(ctx);
                    try {
                      _showSnackBar(encryptBackup ? 'Creating AES-256 encrypted backup...' : 'Creating backup archive...');
                      await ApiService.createBackup(
                        name: name,
                        stackId: selectedStack,
                        volumeName: selectedVolumeName,
                        sourcePath: srcPath,
                        destinationPath: destPath,
                        pauseContainers: pauseContainer,
                        encrypted: encryptBackup,
                        encryptionPassphrase: encryptBackup ? passphraseCtrl.text : '',
                      );
                      _showSnackBar(encryptBackup ? '✅ Encrypted backup (AES-256-GCM) created successfully!' : '✅ Backup created successfully!');
                      _loadAllData();
                    } catch (e) {
                      _showSnackBar('❌ Failed to create backup: $e', isError: true);
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

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  void _showRestoreDialog(BackupModel backup) {
    final targetCtrl = TextEditingController(text: backup.sourcePath);
    final passphraseCtrl = TextEditingController();
    bool obscurePassphrase = true;
    bool isCreatingTarget = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.restore, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text('Restore Backup Archive'),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are about to restore backup "${backup.name}" (${backup.sizeFormatted}).', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: targetCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Target Restore Directory',
                              hintText: 'e.g. /var/contenedores/wordpress/data',
                              prefixIcon: Icon(Icons.folder_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.explore, size: 16),
                          label: const Text('Browse...'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          onPressed: () async {
                            final selected = await _showDirectoryPickerDialog(
                              initialPath: targetCtrl.text.isNotEmpty ? targetCtrl.text : '/var/contenedores',
                              title: 'Select Restore Target Directory',
                            );
                            if (selected != null) {
                              setDlgState(() => targetCtrl.text = selected);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (backup.sourcePath.isNotEmpty)
                          ActionChip(
                            label: const Text('Original Path', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => targetCtrl.text = backup.sourcePath),
                          ),
                        ActionChip(
                          label: const Text('/var/contenedores/', style: TextStyle(fontSize: 11)),
                          onPressed: () => setDlgState(() => targetCtrl.text = '/var/contenedores/'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: isCreatingTarget
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.create_new_folder, size: 16, color: Color(0xFF3B82F6)),
                          label: const Text('Ensure Target Directory Exists (mkdir -p)', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFF3B82F6),
                          ),
                          onPressed: isCreatingTarget
                              ? null
                              : () async {
                                  final path = targetCtrl.text.trim();
                                  if (path.isEmpty) {
                                    _showSnackBar('Please enter a target path first', isError: true);
                                    return;
                                  }
                                  setDlgState(() => isCreatingTarget = true);
                                  try {
                                    final ok = await ApiService.createStorageDirectory(
                                      path: path,
                                      targetNode: 'all',
                                      permissions: '0777',
                                    );
                                    if (ok) {
                                      _showSnackBar('✅ Directory "$path" ready on host(s)!');
                                      _loadAllData();
                                    } else {
                                      _showSnackBar('❌ Failed to create directory', isError: true);
                                    }
                                  } catch (e) {
                                    _showSnackBar('❌ Error: $e', isError: true);
                                  } finally {
                                    setDlgState(() => isCreatingTarget = false);
                                  }
                                },
                        ),
                      ],
                    ),
                    if (backup.isEncrypted) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lock, size: 18, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Text(
                                  'Copia de Seguridad Cifrada (AES-256-GCM / ENS)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Esta copia está cifrada criptográficamente. Introduzca la clave establecida durante su creación para descifrarla.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: passphraseCtrl,
                              obscureText: obscurePassphrase,
                              decoration: InputDecoration(
                                labelText: 'Contraseña de Descifrado',
                                hintText: 'Ingrese la clave de cifrado',
                                prefixIcon: const Icon(Icons.key, size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassphrase ? Icons.visibility : Icons.visibility_off,
                                    size: 18,
                                  ),
                                  onPressed: () => setDlgState(() => obscurePassphrase = !obscurePassphrase),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '⚠️ Existing files with the same name in the target directory will be overwritten with backup contents.',
                      style: TextStyle(fontSize: 11.5, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  icon: const Icon(Icons.unarchive, size: 18),
                  label: const Text('Restore Now'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                  onPressed: () async {
                    if (backup.isEncrypted && passphraseCtrl.text.isEmpty) {
                      _showSnackBar('Debe ingresar la contraseña de descifrado', isError: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      _showSnackBar('Restoring backup archive...');
                      await ApiService.restoreBackup(
                        backupId: backup.id,
                        targetPath: targetCtrl.text.trim(),
                        encryptionPassphrase: backup.isEncrypted ? passphraseCtrl.text : '',
                      );
                      _showSnackBar('✅ Backup restored successfully!');
                      _loadAllData();
                    } catch (e) {
                      _showSnackBar('❌ Failed to restore backup: $e', isError: true);
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

  void _showScheduleDialog({BackupScheduleModel? schedule}) {
    final nameCtrl = TextEditingController(text: schedule?.name ?? '');
    final cronCtrl = TextEditingController(text: schedule?.cronExpression ?? '0 3 * * *');
    final customPathCtrl = TextEditingController(
      text: schedule != null && (schedule.targetType == 'path' || schedule.targetId.startsWith('/'))
          ? schedule.targetId
          : '',
    );
    final destinationPathCtrl = TextEditingController(
      text: schedule?.destinationPath != null && schedule!.destinationPath.isNotEmpty
          ? schedule.destinationPath
          : '/var/backups/gbnt',
    );
    String targetType = schedule?.targetType ?? 'stack';
    String selectedStack = (schedule != null && schedule.targetType == 'stack')
        ? schedule.targetId
        : (widget.state.stacks.isNotEmpty ? widget.state.stacks.first.id : '');
    String selectedVolumeId = (schedule != null && schedule.targetType == 'volume')
        ? schedule.targetId
        : (_volumes.isNotEmpty ? _volumes.first.id : (_mounts.isNotEmpty ? _mounts.first.id : ''));
    int retention = schedule?.retentionCount ?? 7;
    bool pauseContainers = schedule?.pauseContainers ?? true;
    bool encrypted = schedule?.encrypted ?? false;
    final passphraseCtrl = TextEditingController(text: schedule?.encryptionPassphrase ?? '');
    bool obscurePassphrase = true;
    bool isCreatingSourceDir = false;
    bool isCreatingDestDir = false;

    // Collect selectable volumes and mounts
    final List<Map<String, String>> selectableVolumes = [];
    for (final v in _volumes) {
      final label = v.type == 'docker_named'
          ? '💾 [Docker] ${v.name} (${v.nodeHostname})'
          : (v.type == 'shared_pool'
              ? '📁 [Shared] ${v.name} (/var/contenedores)'
              : '📂 [Bind] ${v.name} (${v.sourcePath})');
      selectableVolumes.add({
        'id': v.id,
        'name': v.name,
        'path': v.sourcePath,
        'label': label,
      });
    }
    for (final m in _mounts) {
      selectableVolumes.add({
        'id': m.id,
        'name': m.name,
        'path': m.mountPoint,
        'label': '🌐 [Mount] ${m.name} (${m.mountPoint})',
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(schedule == null ? 'New Backup Schedule' : 'Edit Backup Schedule'),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. NOMBRE DE LA POLÍTICA
                      _buildSectionHeader('1. NOMBRE DE LA POLÍTICA', Icons.label_outline, const Color(0xFF8B5CF6), isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Policy Name',
                          hintText: 'e.g. Daily WordPress DB Backup',
                          prefixIcon: Icon(Icons.label_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. ORIGEN DE DATOS
                      _buildSectionHeader('2. ORIGEN DE DATOS (Target to Backup)', Icons.source_outlined, const Color(0xFF38BDF8), isDark),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'stack',
                              icon: Icon(Icons.layers_outlined, size: 16),
                              label: Text('Stack (Legion)'),
                            ),
                            ButtonSegment(
                              value: 'volume',
                              icon: Icon(Icons.inventory_2_outlined, size: 16),
                              label: Text('Volume / Mount'),
                            ),
                            ButtonSegment(
                              value: 'path',
                              icon: Icon(Icons.folder_outlined, size: 16),
                              label: Text('Custom Path'),
                            ),
                          ],
                          selected: {targetType},
                          onSelectionChanged: (newVal) {
                            setDlgState(() => targetType = newVal.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (targetType == 'stack') ...[
                        if (widget.state.stacks.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: selectedStack.isNotEmpty ? selectedStack : null,
                            decoration: const InputDecoration(
                              labelText: 'Target Stack (Legion)',
                              prefixIcon: Icon(Icons.layers_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: widget.state.stacks.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.name} (${s.id})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedStack = val;
                                  if (nameCtrl.text.isEmpty || nameCtrl.text.startsWith('Daily ') || nameCtrl.text.startsWith('Backup ')) {
                                    final stack = widget.state.stacks.firstWhere((s) => s.id == val);
                                    nameCtrl.text = 'Daily ${stack.name} Backup';
                                  }
                                });
                              }
                            },
                          )
                        else
                          const Text('No stacks deployed yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ] else if (targetType == 'volume') ...[
                        if (selectableVolumes.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: selectedVolumeId.isNotEmpty ? selectedVolumeId : selectableVolumes.first['id'],
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Discovered Volume or Mount',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: selectableVolumes.map((v) {
                              return DropdownMenuItem(
                                value: v['id'],
                                child: Text(
                                  v['label'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedVolumeId = val;
                                  final match = selectableVolumes.firstWhere((v) => v['id'] == val);
                                  if (nameCtrl.text.isEmpty || nameCtrl.text.startsWith('Daily ') || nameCtrl.text.startsWith('Backup ')) {
                                    nameCtrl.text = 'Daily ${match['name']} Snapshot';
                                  }
                                });
                              }
                            },
                          )
                        else
                          const Text('No volumes or mounts discovered yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customPathCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Directory Path',
                                  hintText: 'e.g. /var/contenedores/myapp or /data/glusterfs',
                                  prefixIcon: Icon(Icons.folder_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.explore, size: 16),
                              label: const Text('Browse...'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              onPressed: () async {
                                final selected = await _showDirectoryPickerDialog(
                                  initialPath: customPathCtrl.text.isNotEmpty ? customPathCtrl.text : '/var/contenedores',
                                  title: 'Select Target Source Directory',
                                );
                                if (selected != null) {
                                  setDlgState(() => customPathCtrl.text = selected);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            ActionChip(
                              label: const Text('/var/contenedores/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => customPathCtrl.text = '/var/contenedores/'),
                            ),
                            ActionChip(
                              label: const Text('/var/lib/docker/volumes/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => customPathCtrl.text = '/var/lib/docker/volumes/'),
                            ),
                            ActionChip(
                              label: const Text('/mnt/shared/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => customPathCtrl.text = '/mnt/shared/'),
                            ),
                            ActionChip(
                              label: const Text('/data/', style: TextStyle(fontSize: 11)),
                              onPressed: () => setDlgState(() => customPathCtrl.text = '/data/'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: isCreatingSourceDir
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.create_new_folder, size: 16, color: Color(0xFF8B5CF6)),
                              label: const Text('Create Directory on Host(s) (mkdir -p)', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFF8B5CF6),
                              ),
                              onPressed: isCreatingSourceDir
                                  ? null
                                  : () async {
                                      final path = customPathCtrl.text.trim();
                                      if (path.isEmpty) {
                                        _showSnackBar('Please enter a directory path first', isError: true);
                                        return;
                                      }
                                      setDlgState(() => isCreatingSourceDir = true);
                                      try {
                                        final ok = await ApiService.createStorageDirectory(
                                          path: path,
                                          targetNode: 'all',
                                          permissions: '0777',
                                        );
                                        if (ok) {
                                          _showSnackBar('✅ Directory "$path" created across cluster!');
                                          _loadAllData();
                                        } else {
                                          _showSnackBar('❌ Failed to create directory', isError: true);
                                        }
                                      } catch (e) {
                                        _showSnackBar('❌ Error: $e', isError: true);
                                      } finally {
                                        setDlgState(() => isCreatingSourceDir = false);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. DESTINO DEL BACKUP
                      _buildSectionHeader('3. DESTINO DEL BACKUP (¿Dónde guardar las copias?)', Icons.save_alt, const Color(0xFFF59E0B), isDark),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: destinationPathCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Destination Directory Path',
                                hintText: 'e.g. /var/backups/gbnt or /var/contenedores/backups',
                                prefixIcon: Icon(Icons.folder_special_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.explore, size: 16),
                            label: const Text('Browse...'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            onPressed: () async {
                              final selected = await _showDirectoryPickerDialog(
                                initialPath: destinationPathCtrl.text.isNotEmpty ? destinationPathCtrl.text : '/var/backups',
                                title: 'Select Backup Destination Directory',
                              );
                              if (selected != null) {
                                setDlgState(() => destinationPathCtrl.text = selected);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          ActionChip(
                            label: const Text('Default (/var/backups/gbnt)', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/var/backups/gbnt'),
                          ),
                          ActionChip(
                            label: const Text('/var/contenedores/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/var/contenedores/backups/'),
                          ),
                          ActionChip(
                            label: const Text('/data/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/data/backups/'),
                          ),
                          ActionChip(
                            label: const Text('/mnt/shared/backups/', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => destinationPathCtrl.text = '/mnt/shared/backups/'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: isCreatingDestDir
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.create_new_folder, size: 15, color: Color(0xFFF59E0B)),
                            label: const Text('Create Destination Directory (mkdir -p)', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFFF59E0B),
                            ),
                            onPressed: isCreatingDestDir
                                ? null
                                : () async {
                                    final path = destinationPathCtrl.text.trim();
                                    if (path.isEmpty) {
                                      _showSnackBar('Please enter a destination path first', isError: true);
                                      return;
                                    }
                                    setDlgState(() => isCreatingDestDir = true);
                                    try {
                                      final ok = await ApiService.createStorageDirectory(
                                        path: path,
                                        targetNode: 'all',
                                        permissions: '0777',
                                      );
                                      if (ok) {
                                        _showSnackBar('✅ Destination directory "$path" ready across cluster!');
                                        _loadAllData();
                                      } else {
                                        _showSnackBar('❌ Failed to create directory', isError: true);
                                      }
                                    } catch (e) {
                                      _showSnackBar('❌ Error: $e', isError: true);
                                    } finally {
                                      setDlgState(() => isCreatingDestDir = false);
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-creación inteligente: La carpeta de destino (ej. /var/backups/gbnt) se creará automáticamente en el sistema con permisos 0777 al ejecutar el snapshot programado si aún no existe.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. PROGRAMACIÓN & RETENCIÓN
                      _buildSectionHeader('4. PROGRAMACIÓN & RETENCIÓN', Icons.alarm_outlined, const Color(0xFF8B5CF6), isDark),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cronCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cron Expression',
                          hintText: 'e.g. 0 3 * * * (Daily at 03:00 AM)',
                          prefixIcon: Icon(Icons.alarm_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Daily (3 AM)', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => cronCtrl.text = '0 3 * * *'),
                          ),
                          ActionChip(
                            label: const Text('Every 12h', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => cronCtrl.text = '0 */12 * * *'),
                          ),
                          ActionChip(
                            label: const Text('Every 6h', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => cronCtrl.text = '0 */6 * * *'),
                          ),
                          ActionChip(
                            label: const Text('Weekly (Sun)', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => cronCtrl.text = '0 3 * * 0'),
                          ),
                          ActionChip(
                            label: const Text('Hourly', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDlgState(() => cronCtrl.text = '0 * * * *'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Retention (Keep Last N):', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          DropdownButton<int>(
                            value: retention,
                            items: [3, 7, 14, 30, 60].map((n) {
                              return DropdownMenuItem(value: n, child: Text('$n copies'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => retention = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Pause Containers during backup:', style: TextStyle(fontSize: 13)),
                          const Spacer(),
                          Switch(
                            value: pauseContainers,
                            activeThumbColor: const Color(0xFF8B5CF6),
                            onChanged: (val) => setDlgState(() => pauseContainers = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. CIFRADO CRIPTOGRÁFICO EN REPOSO (ENS mp.si.2 / op.exp.10)
                      _buildSectionHeader('5. CIFRADO CRIPTOGRÁFICO EN REPOSO (ENS mp.si.2 / op.exp.10)', Icons.security, const Color(0xFF10B981), isDark),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Cifrado AES-256-GCM Autenticado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('Derivación de clave PBKDF2-HMAC-SHA256 (100.000 iteraciones) para cumplimiento ENS nivel ALTO.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Switch(
                            value: encrypted,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) => setDlgState(() => encrypted = val),
                          ),
                        ],
                      ),
                      if (encrypted) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: passphraseCtrl,
                          obscureText: obscurePassphrase,
                          decoration: InputDecoration(
                            labelText: 'Contraseña de Cifrado / Passphrase',
                            hintText: 'Clave robusta para cifrar las copias periódicas',
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassphrase ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setDlgState(() => obscurePassphrase = !obscurePassphrase),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      String targetId = '';
                      String targetName = '';

                      if (targetType == 'stack') {
                        targetId = selectedStack;
                        final match = widget.state.stacks.where((s) => s.id == selectedStack);
                        targetName = match.isNotEmpty ? match.first.name : selectedStack;
                      } else if (targetType == 'volume') {
                        targetId = selectedVolumeId;
                        final match = selectableVolumes.where((v) => v['id'] == selectedVolumeId);
                        if (match.isNotEmpty) {
                          targetName = match.first['name'] ?? selectedVolumeId;
                          if (match.first['path'] != null && match.first['path']!.isNotEmpty) {
                            targetId = match.first['path']!;
                          }
                        } else {
                          targetName = selectedVolumeId;
                        }
                      } else {
                        targetId = customPathCtrl.text.trim();
                        targetName = customPathCtrl.text.trim();
                      }

                      final item = BackupScheduleModel(
                        id: schedule?.id ?? '',
                        name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Scheduled Backup ($targetName)',
                        cronExpression: cronCtrl.text.trim(),
                        targetType: targetType,
                        targetId: targetId,
                        targetName: targetName,
                        destinationPath: destinationPathCtrl.text.trim(),
                        retentionCount: retention,
                        pauseContainers: pauseContainers,
                        enabled: schedule?.enabled ?? true,
                        encrypted: encrypted,
                        encryptionPassphrase: encrypted && passphraseCtrl.text.isNotEmpty ? passphraseCtrl.text.trim() : null,
                      );
                      await ApiService.saveBackupSchedule(item);
                      _showSnackBar('✅ Schedule saved successfully!');
                      _loadAllData();
                    } catch (e) {
                      _showSnackBar('❌ Failed to save schedule: $e', isError: true);
                    }
                  },
                  child: const Text('Save Policy'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // ── Tab 2: Backups & Snapshots View ──────────────────────────────

  Widget _buildBackupsTab(bool isDark) {
    final filtered = _backups.where((b) {
      return _backupSearch.isEmpty ||
          b.name.toLowerCase().contains(_backupSearch.toLowerCase()) ||
          b.stackName.toLowerCase().contains(_backupSearch.toLowerCase()) ||
          b.sha256.toLowerCase().contains(_backupSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search backups by name, stack, or SHA-256 hash...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (val) => _updateState(() => _backupSearch = val),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Backup'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => _showCreateBackupDialog(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.backup_outlined, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      const Text('No backups found. Create your first compressed snapshot!'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final b = filtered[i];
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
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.archive, color: Color(0xFF10B981), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: b.isScheduled
                                              ? Colors.purple.withValues(alpha: 0.2)
                                              : Colors.blue.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          b.isScheduled ? 'SCHEDULED' : 'MANUAL',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: b.isScheduled ? Colors.purpleAccent : Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                      if (b.isEncrypted) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock, size: 10, color: Color(0xFF10B981)),
                                              SizedBox(width: 4),
                                              Text(
                                                'AES-256 (ENS)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stack: ${b.stackName.isNotEmpty ? b.stackName : "All"} | Created: ${b.createdAt} | Path: ${b.filePath}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: b.sha256));
                                      _showSnackBar('SHA-256 copied to clipboard');
                                    },
                                    child: Text(
                                      'SHA-256: ${b.sha256}',
                                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                b.sizeFormatted,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.download, size: 20, color: Colors.blueAccent),
                              tooltip: 'Download .tar.gz',
                              onPressed: () => _downloadBackup(b.id, b.name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore, size: 20, color: Color(0xFF10B981)),
                              tooltip: 'Restore Backup',
                              onPressed: () => _showRestoreDialog(b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              tooltip: 'Delete Backup',
                              onPressed: () => _deleteBackup(b.id, b.name),
                            ),
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

  // ── Tab 3: Schedules View ────────────────────────────────────────

  Widget _buildSchedulesTab(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Automated Backup Routines & Retention Policies',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Backup Schedule'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              onPressed: () => _showScheduleDialog(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule_outlined, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      const Text('No automated backup schedules configured yet.'),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _schedules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final s = _schedules[i];
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
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.alarm, color: Color(0xFF8B5CF6), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: s.enabled ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s.enabled ? 'ACTIVE' : 'PAUSED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: s.enabled ? Colors.greenAccent : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (s.encrypted) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock, size: 10, color: Color(0xFF10B981)),
                                              SizedBox(width: 3),
                                              Text(
                                                'AES-256-GCM',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cron: ${s.cronExpression} | Target: ${s.targetName} | Retention: Last ${s.retentionCount} copies',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                              tooltip: 'Edit Schedule',
                              onPressed: () => _showScheduleDialog(schedule: s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              tooltip: 'Delete Schedule',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Schedule'),
                                    content: Text('Delete backup schedule "${s.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ApiService.deleteBackupSchedule(s.id);
                                  _showSnackBar('Schedule deleted');
                                  _loadAllData();
                                }
                              },
                            ),
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

  // ── Tab 4: Storage Pools View ─────────────────────────────────────

  Widget _buildPoolsTab(bool isDark) {
    final health = _poolHealth;
    final isHealthy = health?.status == 'healthy';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Base path card
          Card(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 10),
                      const Text('Shared Storage Pool Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHealthy ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isHealthy ? const Color(0xFF10B981) : Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isHealthy ? Icons.check_circle : Icons.warning, size: 14, color: isHealthy ? const Color(0xFF10B981) : Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              isHealthy ? 'POOL HEALTHY (RW)' : 'DEGRADED / NOT MOUNTED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isHealthy ? const Color(0xFF10B981) : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Shared mount directory accessible across all nodes for container mobility: $_poolPath',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  if (health != null && health.totalBytes > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Disk Usage: ${health.usedFormatted} / ${health.totalFormatted} (${health.usagePercent.toStringAsFixed(1)}%)'),
                        Text('Free Space: ${health.freeFormatted}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: health.usagePercent / 100.0,
                        minHeight: 10,
                        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          health.usagePercent > 85 ? Colors.redAccent : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Node Health Matrix
          const Text('Centurion Nodes Health Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          if (health?.nodes != null && health!.nodes.isNotEmpty) ...[
            ...health.nodes.map((n) {
              return Card(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: n.isWritable ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          n.isWritable ? Icons.dns : Icons.error_outline,
                          color: n.isWritable ? Colors.greenAccent : Colors.orange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${n.nodeId} (${n.nodeIp})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    n.role.toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mount: ${n.path} | Writable: ${n.isWritable ? "Yes (RW)" : "No (RO/Missing)"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                            if (n.error != null && n.error!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('Error: ${n.error}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: n.isWritable ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          n.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: n.isWritable ? Colors.greenAccent : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 16),
          // NFS / Storage Mount Helper Card
          Card(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Color(0xFFF97316), size: 20),
                      SizedBox(width: 8),
                      Text('How to Configure Shared Storage (/var/contenedores)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To allow containers to move between hosts without data loss, mount an NFS, GlusterFS, or CephFS share on /var/contenedores on all Manager and Worker nodes:',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'sudo mkdir -p /var/contenedores\nsudo mount -t nfs <NFS_SERVER_IP>:/storage/contenedores /var/contenedores',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 12,
                      color: isDark ? const Color(0xFFF97316) : Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    bool isDark,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
