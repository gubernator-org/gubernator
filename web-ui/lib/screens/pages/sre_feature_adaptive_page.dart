import 'package:flutter/material.dart';
import '../../widgets/sre_profiles_dialog.dart';

/// Contextual adaptive page shown when an observability tool (such as Grafana Network Monitor or Jaeger)
/// is not part of the currently active SRE profile.
class SreFeatureAdaptivePage extends StatelessWidget {
  final String featureName;
  final IconData featureIcon;
  final String requiredProfileName;
  final String activeProfileId;
  final VoidCallback? onSwitchedProfile;
  final VoidCallback? onBackToOverview;

  const SreFeatureAdaptivePage({
    super.key,
    required this.featureName,
    required this.featureIcon,
    this.requiredProfileName = 'Cloud-Native Balanced',
    this.activeProfileId = 'enterprise-elk',
    this.onSwitchedProfile,
    this.onBackToOverview,
  });

  String _getActiveProfileTitle() {
    switch (activeProfileId) {
      case 'enterprise-elk':
        return 'Enterprise SIEM & Analytics';
      case 'ultra-light':
        return 'Ultra-Lightweight (VictoriaMetrics)';
      case 'unified-otel':
        return 'Next-Gen Unified OTel (ClickHouse)';
      case 'external-saas':
        return 'Zero-Footprint Forwarder';
      default:
        return 'Cloud-Native Balanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(featureIcon, size: 48, color: const Color(0xFFF97316)),
            ),
            const SizedBox(height: 20),

            // Feature Name
            Text(
              featureName,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Explanation
            Text(
              'This observability tool is not included in the currently active profile (${_getActiveProfileTitle()}). '
              'It requires the $requiredProfileName architecture (Prometheus + Grafana / Jaeger).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Architecture Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_outlined, color: Colors.deepOrangeAccent, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Active SRE Profile: ${_getActiveProfileTitle()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeProfileId == 'enterprise-elk'
                              ? 'Running services: OpenSearch (:9200), OpenSearch Dashboards (:5601), and Fluent Bit.'
                              : 'Review the services configured for this observability preset.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    if (onBackToOverview != null) {
                      onBackToOverview!();
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Overview'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SreProfilesDialog(),
                    ).then((_) {
                      onSwitchedProfile?.call();
                    });
                  },
                  icon: const Icon(Icons.auto_awesome_motion, size: 18),
                  label: const Text(
                    'Switch SRE Profile',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
