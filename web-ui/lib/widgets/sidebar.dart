import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Level-3 subsection item displayed inside an expanded Level-2 sidebar item.
class SidebarSubItem {
  final int subIndex;
  final IconData icon;
  final String label;

  const SidebarSubItem({
    required this.subIndex,
    required this.icon,
    required this.label,
  });
}

/// Level-2 navigation item definition for the sidebar.
class SidebarItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;
  final bool showBadge;
  final List<SidebarSubItem> subItems;

  bool get hasSubItems => subItems.isNotEmpty;

  const SidebarItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
    this.showBadge = false,
    this.subItems = const [],
  });
}

/// Level-1 collapsible navigation section grouping related sidebar items.
class SidebarSection {
  final String id;
  final String title;
  final IconData? icon;
  final List<SidebarItem> items;

  const SidebarSection({
    required this.id,
    required this.title,
    this.icon,
    required this.items,
  });
}

/// Professional 3-level sidebar widget for the Gubernator dashboard.
/// Supports sidebar collapse/expand, collapsible Level-1 sections,
/// expandable Level-2 items with Level-3 subsections, badges, and theme toggle.
class GubernatorSidebar extends StatefulWidget {
  final int selectedIndex;
  final int selectedSubIndex;
  final ValueChanged<int> onDestinationSelected;
  final void Function(int index, int subIndex)? onSubDestinationSelected;
  final String currentThemeId;
  final ValueChanged<String> onThemeChanged;
  final String version;
  final bool updateAvailable;
  final String latestVersion;
  final VoidCallback? onVersionCheckPressed;
  final VoidCallback? onUpdatePressed;
  final VoidCallback onSettingsPressed;
  final List<SidebarSection> sections;
  final Set<String> collapsedSections;
  final ValueChanged<String> onToggleSection;
  final Set<int> expandedItems;
  final ValueChanged<int>? onToggleItemExpand;
  final VoidCallback? onToggleAllSections;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool monitorRunning;

  bool get isDark => GubernatorTheme.getThemeDef(currentThemeId).isDark;

  const GubernatorSidebar({
    super.key,
    required this.selectedIndex,
    this.selectedSubIndex = 0,
    required this.onDestinationSelected,
    this.onSubDestinationSelected,
    required this.currentThemeId,
    required this.onThemeChanged,
    required this.version,
    this.updateAvailable = false,
    this.latestVersion = '',
    this.onVersionCheckPressed,
    this.onUpdatePressed,
    required this.onSettingsPressed,
    required this.sections,
    required this.collapsedSections,
    required this.onToggleSection,
    this.expandedItems = const {},
    this.onToggleItemExpand,
    this.onToggleAllSections,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.monitorRunning = false,
  });

  @override
  State<GubernatorSidebar> createState() => _GubernatorSidebarState();
}

class _GubernatorSidebarState extends State<GubernatorSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _widthAnimation;

  static const double _defaultExpandedWidth = 280.0;
  static const double _updateExpandedWidth = 315.0;
  static const double _collapsedWidth = 72.0;

  double get _currentExpandedWidth =>
      widget.updateAvailable ? _updateExpandedWidth : _defaultExpandedWidth;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: widget.isCollapsed ? _collapsedWidth : _currentExpandedWidth,
      end: widget.isCollapsed ? _collapsedWidth : _currentExpandedWidth,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(GubernatorSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCollapsed != widget.isCollapsed ||
        oldWidget.updateAvailable != widget.updateAvailable) {
      _widthAnimation = Tween<double>(
        begin: _widthAnimation.value,
        end: widget.isCollapsed ? _collapsedWidth : _currentExpandedWidth,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ));
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeDef = GubernatorTheme.getThemeDef(widget.currentThemeId);
    final bgColor = themeDef.sidebarBg;
    final borderColor = themeDef.sidebarBorder;
    final textColor = themeDef.textPrimary;
    final mutedColor = themeDef.textSecondary;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final width = _widthAnimation.value;
        final isExpanded = width > _collapsedWidth + 20;

        return Container(
          width: width,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // ─── Logo Header ────────────────────────────────
              _buildLogoHeader(theme, isExpanded, textColor, mutedColor),

              const SizedBox(height: 6),

              // ─── Sections Controls (Expanded Mode) ──────────
              if (isExpanded && widget.onToggleAllSections != null)
                _buildSectionsToolbar(
                  mutedColor: mutedColor,
                  isDark: themeDef.isDark,
                ),

              // ─── Navigation Sections ─────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  children: [
                    for (int s = 0; s < widget.sections.length; s++) ...[
                      if (isExpanded)
                        _buildCollapsibleSection(
                          section: widget.sections[s],
                          isLast: s == widget.sections.length - 1,
                          theme: theme,
                          themeDef: themeDef,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          borderColor: borderColor,
                        )
                      else ...[
                        if (s > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            child: Divider(
                              height: 1,
                              color: borderColor,
                            ),
                          ),
                        for (final item in widget.sections[s].items)
                          _buildNavItem(
                            item: item,
                            sectionTitle: widget.sections[s].title,
                            isExpanded: false,
                            theme: theme,
                            textColor: textColor,
                            mutedColor: mutedColor,
                          ),
                      ],
                    ],
                  ],
                ),
              ),

              // ─── Bottom Section ──────────────────────────────
              _buildBottomSection(theme, isExpanded, textColor, mutedColor, borderColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoHeader(ThemeData theme, bool isExpanded, Color textColor, Color mutedColor) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isExpanded ? 20 : 16,
        20,
        isExpanded ? 12 : 16,
        12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? sidebarDarkBorder : sidebarLightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo icon with dark slate background and orange glow/border
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF97316).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.network(
                '/gubernator-icon.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.hub,
                  color: Color(0xFFF97316),
                  size: 24,
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gubernator',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (widget.updateAvailable && widget.onUpdatePressed != null)
                    InkWell(
                      onTap: widget.onUpdatePressed,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // First portion in Orange
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'MANAGER ${widget.version}',
                                style: const TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: Text(
                                '→',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Second portion in Red
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'MANAGER ${widget.latestVersion}',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.rocket_launch,
                              size: 11,
                              color: Color(0xFFEF4444),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Tooltip(
                          message: 'Click to scan GitHub for new releases',
                          child: InkWell(
                            onTap: widget.onVersionCheckPressed,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: sidebarActiveIndicator.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: sidebarActiveIndicator.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'MANAGER ${widget.version}',
                                    style: const TextStyle(
                                      color: sidebarActiveIndicator,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.search, size: 10, color: sidebarActiveIndicator),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionsToolbar({
    required Color mutedColor,
    required bool isDark,
  }) {
    final allCollapsed = widget.sections.isNotEmpty &&
        widget.sections
            .every((s) => widget.collapsedSections.contains(s.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 10, 4),
      child: Row(
        children: [
          Text(
            'NAVIGATION',
            style: TextStyle(
              color: mutedColor.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Tooltip(
            message:
                allCollapsed ? 'Expand all sections' : 'Collapse all sections',
            child: InkWell(
              onTap: widget.onToggleAllSections,
              borderRadius: BorderRadius.circular(6),
              hoverColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  allCollapsed ? Icons.unfold_more : Icons.unfold_less,
                  size: 16,
                  color: mutedColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required SidebarSection section,
    required bool isLast,
    required ThemeData theme,
    required GubernatorThemeDef themeDef,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    final isSectionCollapsed = widget.collapsedSections.contains(section.id);
    final hasActiveItem =
        section.items.any((item) => item.index == widget.selectedIndex);
    final isDark = themeDef.isDark;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 4 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              hoverColor: hoverBg,
              onTap: () => widget.onToggleSection(section.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    if (section.icon != null) ...[
                      Icon(
                        section.icon,
                        size: 14,
                        color: (isSectionCollapsed && hasActiveItem)
                            ? themeDef.sidebarActive
                            : mutedColor.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Expanded(
                      child: Text(
                        section.title.toUpperCase(),
                        style: TextStyle(
                          color: (isSectionCollapsed && hasActiveItem)
                              ? textColor
                              : mutedColor.withValues(alpha: 0.8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSectionCollapsed && hasActiveItem)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: themeDef.sidebarActive,
                          shape: BoxShape.circle,
                        ),
                      ),
                    AnimatedRotation(
                      turns: isSectionCollapsed ? -0.25 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: mutedColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Items
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isSectionCollapsed
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in section.items)
                            _buildNavItem(
                              item: item,
                              sectionTitle: section.title,
                              isExpanded: true,
                              theme: theme,
                              textColor: textColor,
                              mutedColor: mutedColor,
                            ),
                        ],
                      ),
                    ),
            ),
          ),

          if (!isLast)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Divider(
                height: 1,
                color: borderColor.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required SidebarItem item,
    required String sectionTitle,
    required bool isExpanded,
    required ThemeData theme,
    required Color textColor,
    required Color mutedColor,
  }) {
    final isSelected = widget.selectedIndex == item.index;
    final hasSubItems = item.hasSubItems;
    final isItemExpanded =
        hasSubItems && widget.expandedItems.contains(item.index);
    final themeDef = GubernatorTheme.getThemeDef(widget.currentThemeId);
    final isDark = themeDef.isDark;

    final selectedBg =
        themeDef.sidebarActive.withValues(alpha: isDark ? 0.15 : 0.1);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    final navRow = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: hoverBg,
          onTap: () {
            if (isExpanded && hasSubItems && isSelected) {
              widget.onToggleItemExpand?.call(item.index);
            } else {
              widget.onDestinationSelected(item.index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 10 : 0,
              vertical: 8.5,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                // Active indicator bar
                if (isSelected)
                  Container(
                    width: 3,
                    height: 20,
                    margin: EdgeInsets.only(right: isExpanded ? 9 : 0),
                    decoration: BoxDecoration(
                      color: themeDef.sidebarActive,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  SizedBox(width: isExpanded ? 12 : 0),

                // Icon with badge
                _buildIconWithBadge(
                  icon: isSelected ? item.activeIcon : item.icon,
                  isSelected: isSelected,
                  badgeCount: item.badgeCount,
                  showBadge: item.showBadge,
                  activeColor: themeDef.sidebarActive,
                  mutedColor: mutedColor,
                ),

                if (isExpanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? textColor : mutedColor,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Badge count text (shown in expanded mode)
                  if (item.showBadge &&
                      item.badgeCount != null &&
                      item.badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.badgeCount}',
                        style: TextStyle(
                          color: isSelected
                              ? themeDef.sidebarActive
                              : mutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Level-3 expand/collapse chevron for items with subsections
                  if (hasSubItems)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => widget.onToggleItemExpand?.call(item.index),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: AnimatedRotation(
                          turns: isItemExpanded ? 0.0 : -0.25,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: isSelected
                                ? themeDef.sidebarActive
                                : mutedColor.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: '$sectionTitle · ${item.label}',
        waitDuration: const Duration(milliseconds: 250),
        child: navRow,
      );
    }

    if (!hasSubItems) {
      return navRow;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        navRow,
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !isItemExpanded
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(left: 22, top: 2, bottom: 4),
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isSelected
                              ? themeDef.sidebarActive.withValues(alpha: 0.45)
                              : themeDef.sidebarBorder,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final subItem in item.subItems)
                          _buildSubNavItem(
                            parentIndex: item.index,
                            subItem: subItem,
                            isParentSelected: isSelected,
                            themeDef: themeDef,
                            textColor: textColor,
                            mutedColor: mutedColor,
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubNavItem({
    required int parentIndex,
    required SidebarSubItem subItem,
    required bool isParentSelected,
    required GubernatorThemeDef themeDef,
    required Color textColor,
    required Color mutedColor,
  }) {
    final isSubSelected =
        isParentSelected && widget.selectedSubIndex == subItem.subIndex;
    final isDark = themeDef.isDark;
    final selectedBg =
        themeDef.sidebarActive.withValues(alpha: isDark ? 0.14 : 0.09);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverBg,
          onTap: () {
            if (widget.onSubDestinationSelected != null) {
              widget.onSubDestinationSelected!(parentIndex, subItem.subIndex);
            } else {
              widget.onDestinationSelected(parentIndex);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
            decoration: BoxDecoration(
              color: isSubSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  subItem.icon,
                  size: 15,
                  color: isSubSelected
                      ? themeDef.sidebarActive
                      : mutedColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    subItem.label,
                    style: TextStyle(
                      color: isSubSelected ? textColor : mutedColor,
                      fontSize: 12,
                      fontWeight:
                          isSubSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSubSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: themeDef.sidebarActive,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithBadge({
    required IconData icon,
    required bool isSelected,
    int? badgeCount,
    bool showBadge = false,
    required Color activeColor,
    required Color mutedColor,
  }) {
    final iconWidget = Icon(
      icon,
      size: 21,
      color: isSelected ? activeColor : mutedColor,
    );

    if (!showBadge ||
        badgeCount == null ||
        badgeCount <= 0 ||
        !widget.isCollapsed) {
      return iconWidget;
    }

    // In collapsed mode, show badge on icon
    return Badge(
      label: Text(
        badgeCount > 99 ? '99+' : '$badgeCount',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
      backgroundColor: activeColor,
      child: iconWidget,
    );
  }

  Widget _buildBottomSection(
    ThemeData theme,
    bool isExpanded,
    Color textColor,
    Color mutedColor,
    Color borderColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        children: [
          // Collapse/Expand button
          _buildBottomButton(
            icon: widget.isCollapsed
                ? Icons.chevron_right
                : Icons.chevron_left,
            label: widget.isCollapsed ? 'Expand' : 'Collapse',
            isExpanded: isExpanded,
            textColor: mutedColor,
            onTap: widget.onToggleCollapse,
          ),

          const SizedBox(height: 4),

          // Theme toggle
          _buildBottomButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            label: isDark ? 'Light Theme' : 'Dark Theme',
            isExpanded: isExpanded,
            textColor: mutedColor,
            onTap: () {
              final def = GubernatorTheme.getThemeDef(widget.currentThemeId);
              if (def.isDark) {
                widget.onThemeChanged('light');
              } else {
                widget.onThemeChanged('dark');
              }
            },
          ),

          const SizedBox(height: 4),

          // Settings
          _buildBottomButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isExpanded: isExpanded,
            textColor: mutedColor,
            onTap: widget.onSettingsPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required bool isExpanded,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 12 : 0,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: textColor),
              if (isExpanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
