import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubernator_web/widgets/sidebar.dart';

void main() {
  List<SidebarSection> buildTestSections() => const [
        SidebarSection(
          id: 'cluster',
          title: 'Cluster',
          icon: Icons.hub_outlined,
          items: [
            SidebarItem(
              index: 0,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Overview',
            ),
            SidebarItem(
              index: 1,
              icon: Icons.dns_outlined,
              activeIcon: Icons.dns,
              label: 'Centurions [Host]',
              badgeCount: 3,
              showBadge: true,
            ),
          ],
        ),
        SidebarSection(
          id: 'security',
          title: 'Security',
          icon: Icons.verified_user_outlined,
          items: [
            SidebarItem(
              index: 5,
              icon: Icons.security_outlined,
              activeIcon: Icons.security,
              label: 'Image Security & SBOM',
              subItems: [
                SidebarSubItem(
                  subIndex: 0,
                  icon: Icons.security_outlined,
                  label: 'Vulnerabilities',
                ),
                SidebarSubItem(
                  subIndex: 1,
                  icon: Icons.inventory_outlined,
                  label: 'SBOM Explorer',
                ),
                SidebarSubItem(
                  subIndex: 2,
                  icon: Icons.verified_outlined,
                  label: 'Signatures & Keys',
                ),
              ],
            ),
            SidebarItem(
              index: 15,
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield,
              label: 'Security & Directory',
            ),
          ],
        ),
      ];

  testWidgets('supports 3-level expand/collapse and sub-destination selection',
      (WidgetTester tester) async {
    final collapsed = <String>{};
    final expandedItems = <int>{};
    int selected = 0;
    int selectedSub = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return GubernatorSidebar(
                selectedIndex: selected,
                selectedSubIndex: selectedSub,
                onDestinationSelected: (idx) => setState(() {
                  selected = idx;
                  selectedSub = 0;
                  if (idx == 5) expandedItems.add(5);
                }),
                onSubDestinationSelected: (idx, subIdx) => setState(() {
                  selected = idx;
                  selectedSub = subIdx;
                  expandedItems.add(idx);
                }),
                currentThemeId: 'dark',
                onThemeChanged: (_) {},
                version: 'v4.0.0',
                onSettingsPressed: () {},
                sections: buildTestSections(),
                collapsedSections: Set<String>.from(collapsed),
                onToggleSection: (id) {
                  setState(() {
                    if (!collapsed.remove(id)) {
                      collapsed.add(id);
                    }
                  });
                },
                expandedItems: Set<int>.from(expandedItems),
                onToggleItemExpand: (itemIdx) {
                  setState(() {
                    if (!expandedItems.remove(itemIdx)) {
                      expandedItems.add(itemIdx);
                    }
                  });
                },
                onToggleAllSections: () {
                  setState(() {
                    if (collapsed.length == 2) {
                      collapsed.clear();
                    } else {
                      collapsed.addAll(['cluster', 'security']);
                    }
                  });
                },
                isCollapsed: false,
                onToggleCollapse: () {},
              );
            },
          ),
        ),
      ),
    );

    // Level-1 sections and Level-2 items visible; Level-3 collapsed initially
    expect(find.text('CLUSTER'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Image Security & SBOM'), findsOneWidget);
    expect(find.text('SBOM Explorer'), findsNothing);

    // Tapping Level-2 item selects it and expands its Level-3 subsections
    await tester.tap(find.text('Image Security & SBOM'));
    await tester.pumpAndSettle();
    expect(selected, 5);
    expect(find.text('Vulnerabilities'), findsOneWidget);
    expect(find.text('SBOM Explorer'), findsOneWidget);
    expect(find.text('Signatures & Keys'), findsOneWidget);

    // Tapping Level-3 subsection selects both parent index and subIndex
    await tester.tap(find.text('SBOM Explorer'));
    await tester.pumpAndSettle();
    expect(selected, 5);
    expect(selectedSub, 1);

    // Tapping the already-selected Level-2 item collapses its Level-3 children
    await tester.tap(find.text('Image Security & SBOM'));
    await tester.pumpAndSettle();
    expect(find.text('SBOM Explorer'), findsNothing);

    // Collapse the entire Security Level-1 section
    await tester.tap(find.text('SECURITY'));
    await tester.pumpAndSettle();
    expect(find.text('Image Security & SBOM'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);

    // Collapse all sections via toolbar button
    await tester.tap(find.byIcon(Icons.unfold_less));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsNothing);

    // Expand all sections via toolbar button
    await tester.tap(find.byIcon(Icons.unfold_more));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Image Security & SBOM'), findsOneWidget);
  });
}
