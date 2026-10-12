part of '../image_security_page.dart';

extension _ImageSignaturesPoliciesExt on _ImageSecurityPageState {

  // ── Tab 3: Signatures & Keys ──────────────────────────────────────

  Widget _buildSignaturesTab(bool isDark) {
    final signedScans = _scans.where((s) => s.signatureStatus == 'verified' || s.signatureStatus == 'signed').toList();
    final unsignedScans = _scans.where((s) => s.signatureStatus != 'verified' && s.signatureStatus != 'signed').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trusted Signing Keys (Cosign / Sigstore)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Generate Keypair'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                    onPressed: _showGenerateKeyDialog,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: const Text('Sign Image'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    onPressed: _showSignImageDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_keys.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 42, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    const Text('No trusted signing keys configured. Click "Generate Keypair" to create one!'),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _keys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final k = _keys[i];
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
                          child: const Icon(Icons.key, color: Color(0xFF8B5CF6), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(k.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (k.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('DEFAULT', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: k.hasPrivateKey ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      k.hasPrivateKey ? 'IN-CLUSTER KEYPAIR (READY TO SIGN)' : 'PUBLIC KEY ONLY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: k.hasPrivateKey ? const Color(0xFF10B981) : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Type: ${k.keyType} | Added: ${k.createdAt}', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Colors.blueAccent),
                          tooltip: 'Copy Public Key PEM',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: k.publicKeyPem));
                            _showSnackBar('Public Key PEM copied to clipboard');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Key',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Key'),
                                content: Text('Delete trusted key "${k.name}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ApiService.deleteTrustedKey(k.id);
                              _showSnackBar('Key deleted');
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
          const SizedBox(height: 28),

          // ── Signed Images & Distributed Cluster Registry ──────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Signed Images & Cluster Registry (${signedScans.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (signedScans.isNotEmpty)
                Text(
                  'Synchronized with Admission Gatekeeper for multi-host deployment',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (signedScans.isEmpty)
            Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.shield_outlined, size: 36, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No signed images registered yet.'),
                      const SizedBox(height: 4),
                      Text(
                        'Click "Sign Image" above or use the "Sign" button on any image card to cryptographically sign container digests.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signedScans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final s = signedScans[i];
                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
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
                          child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s.imageName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('VERIFIED', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                  ),
                                  if (s.signatureSigner != null && s.signatureSigner!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Signer: ${s.signatureSigner}',
                                        style: const TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Digest: ${s.imageDigest.isNotEmpty ? (s.imageDigest.length > 24 ? "${s.imageDigest.substring(0, 24)}..." : s.imageDigest) : "local-digest"}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                  ),
                                  if (s.hosts.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.dns, size: 12, color: Colors.tealAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hosts: ${s.hosts.join(", ")}',
                                      style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.share_location, size: 15, color: Colors.lightBlueAccent),
                          label: const Text('Distribute', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                          onPressed: () => _showDistributeDialog(
                            s.imageName,
                            signatureStatus: s.signatureStatus,
                            signatureSigner: s.signatureSigner,
                            currentHosts: s.hosts,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_document, size: 15, color: Color(0xFF10B981)),
                          label: const Text('Re-sign', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                          onPressed: () => _showSignImageDialog(initialImage: s.imageName),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.remove_moderator, size: 15, color: Colors.orangeAccent),
                          label: const Text('Unsign', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          onPressed: () => _confirmUnsignImage(s.imageName),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever, size: 15, color: Colors.redAccent),
                          label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () => _deleteHostImage(s.imageName),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 28),

          // ── Unsigned Images in Cluster ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Unsigned Cluster Images (${unsignedScans.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (unsignedScans.isNotEmpty)
                Text(
                  'Images deployed or stored in cluster without a cryptographic signature',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (unsignedScans.isEmpty)
            Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 20, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('All cluster images are cryptographically signed!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unsignedScans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final s = unsignedScans[i];
                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s.imageName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text('UNSIGNED', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Status: Awaiting cryptographic signature',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                  ),
                                  if (s.hosts.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.dns, size: 12, color: Colors.tealAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hosts: ${s.hosts.join(", ")}',
                                      style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.share_location, size: 15, color: Colors.lightBlueAccent),
                          label: const Text('Distribute', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                          onPressed: () => _showDistributeDialog(
                            s.imageName,
                            signatureStatus: s.signatureStatus,
                            signatureSigner: s.signatureSigner,
                            currentHosts: s.hosts,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.verified_user_outlined, size: 15),
                          label: const Text('Sign Image', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _showSignImageDialog(initialImage: s.imageName),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever, size: 15, color: Colors.redAccent),
                          label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () => _deleteHostImage(s.imageName),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Tab 4: Gatekeeper Policies ────────────────────────────────────

  Widget _buildPoliciesTab(bool isDark) {
    if (_policy == null) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, color: Color(0xFFF97316), size: 24),
                      SizedBox(width: 10),
                      Text('Cluster Admission Gatekeeper Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Signature Enforcement
                  const Text('1. Cryptographic Signature Enforcement (Cosign):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  RadioListTile<String>(
                    title: const Text('Disabled'),
                    subtitle: const Text('Allow deploying unsigned container images without restrictions.'),
                    value: 'disabled',
                    groupValue: _policy!.enforceSignatures,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: val!,
                      blockCveSeverity: _policy!.blockCveSeverity,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  RadioListTile<String>(
                    title: const Text('Audit / Warn Only (Recommended)'),
                    subtitle: const Text('Allow deploying unsigned images but flag with warnings in dashboard.'),
                    value: 'audit',
                    groupValue: _policy!.enforceSignatures,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: val!,
                      blockCveSeverity: _policy!.blockCveSeverity,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  RadioListTile<String>(
                    title: const Text('Strict Enforcement (Block Unsigned)'),
                    subtitle: const Text('⛔ Reject any container deployment whose image is not cryptographically signed.'),
                    value: 'enforce',
                    groupValue: _policy!.enforceSignatures,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: val!,
                      blockCveSeverity: _policy!.blockCveSeverity,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  const Divider(height: 24),

                  // CVE Severity Threshold
                  const Text('2. CVE Vulnerability Admission Gate:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  RadioListTile<String>(
                    title: const Text('Allow All Images'),
                    subtitle: const Text('Do not block deployments based on vulnerability counts.'),
                    value: 'none',
                    groupValue: _policy!.blockCveSeverity,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: _policy!.enforceSignatures,
                      blockCveSeverity: val!,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  RadioListTile<String>(
                    title: const Text('Block on CRITICAL Vulnerabilities'),
                    subtitle: const Text('⛔ Reject deployments if the container contains known Critical CVEs.'),
                    value: 'critical',
                    groupValue: _policy!.blockCveSeverity,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: _policy!.enforceSignatures,
                      blockCveSeverity: val!,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  RadioListTile<String>(
                    title: const Text('Block on HIGH and CRITICAL Vulnerabilities'),
                    subtitle: const Text('⛔ Strict compliance: reject deployments with High or Critical CVEs.'),
                    value: 'high',
                    groupValue: _policy!.blockCveSeverity,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: _policy!.enforceSignatures,
                      blockCveSeverity: val!,
                      allowUnfixedCve: _policy!.allowUnfixedCve,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Allow deployments if no official fix is available yet (Unfixed CVEs)'),
                    subtitle: const Text('Prevents blocking applications when upstream vendors have not released a patch.'),
                    value: _policy!.allowUnfixedCve,
                    onChanged: (val) => _updateState(() => _policy = SecurityPolicyModel(
                      id: _policy!.id,
                      name: _policy!.name,
                      enforceSignatures: _policy!.enforceSignatures,
                      blockCveSeverity: _policy!.blockCveSeverity,
                      allowUnfixedCve: val,
                      trustedRegistries: _policy!.trustedRegistries,
                      updatedAt: _policy!.updatedAt,
                    )),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save Gatekeeper Policy'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                    onPressed: () async {
                      try {
                        await ApiService.saveSecurityPolicy(_policy!);
                        _showSnackBar('✅ Security policy saved successfully!');
                        _loadAllData();
                      } catch (e) {
                        _showSnackBar('❌ Failed to save policy: $e', isError: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
