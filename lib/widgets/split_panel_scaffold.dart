// lib/widgets/split_panel_scaffold.dart
import 'package:flutter/material.dart';
import '../theme/grc_theme.dart';
import '../screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single nav item
// ─────────────────────────────────────────────────────────────────────────────
class NavItem {
  final IconData icon;
  final String label;
  final String? sectionHeader; // optional section header above this item
  final int? badge;            // optional badge count

  const NavItem({
    required this.icon,
    required this.label,
    this.sectionHeader,
    this.badge,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SplitPanelScaffold
// ─────────────────────────────────────────────────────────────────────────────
/// Core responsive layout for Admin, Dean and Program Head dashboards.
///
/// • Desktop  → collapsible side nav (240 px ↔ 56 px) with chevron toggle,
///              hover tooltips when collapsed, accent highlight on active item.
/// • Mobile   → hidden off-screen; hamburger in top-left slides it in with a
///              dark overlay; tap overlay / X / nav-item to close.
class SplitPanelScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Legacy list of NavigationRailDestination — kept for backward compatibility.
  /// Internally converted to [NavItem] list.
  final List<NavigationRailDestination> destinations;

  final Widget body;
  final Widget? floatingActionButton;

  const SplitPanelScaffold({
    required this.title,
    required this.subtitle,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    super.key,
  });

  @override
  State<SplitPanelScaffold> createState() => _SplitPanelScaffoldState();
}

class _SplitPanelScaffoldState extends State<SplitPanelScaffold>
    with SingleTickerProviderStateMixin {
  // ── state ─────────────────────────────────────────────────────────────────
  bool _desktopExpanded = true;
  bool _mobileOpen = false;

  // ── sizes ─────────────────────────────────────────────────────────────────
  static const double _expandedW = 240.0;
  static const double _collapsedW = 56.0;
  static const double _mobileBreak = 768.0;

  // ── helpers ───────────────────────────────────────────────────────────────
  bool get _isMobile =>
      MediaQuery.of(context).size.width < _mobileBreak;

  void _toggleDesktop() =>
      setState(() => _desktopExpanded = !_desktopExpanded);

  void _openMobileNav() => setState(() => _mobileOpen = true);
  void _closeMobileNav() => setState(() => _mobileOpen = false);

  void _selectItem(int index) {
    widget.onDestinationSelected(index);
    if (_isMobile) _closeMobileNav();
  }

  // ── logout ────────────────────────────────────────────────────────────────
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrcColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: GrcColors.border),
        ),
        title: const Text(
          "Confirm Logout",
          style: TextStyle(
              color: GrcColors.maroon,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: GrcColors.textMid, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL",
                style: TextStyle(
                    color: GrcColors.textLight, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GrcColors.maroon,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginScreen()),
              );
            },
            child: const Text("LOG OUT",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return _isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final navW = _desktopExpanded ? _expandedW : _collapsedW;

    return Scaffold(
      backgroundColor: GrcColors.background,
      floatingActionButton: widget.floatingActionButton,
      body: Row(
        children: [
          // ── animated side nav ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: navW,
            child: _SideNav(
              title: widget.title,
              subtitle: widget.subtitle,
              expanded: _desktopExpanded,
              selectedIndex: widget.selectedIndex,
              destinations: widget.destinations,
              onSelect: _selectItem,
              onToggle: _toggleDesktop,
              onLogout: () => _confirmLogout(context),
              isMobile: false,
              onClose: null,
            ),
          ),
          // ── thin divider ───────────────────────────────────────────────
          const VerticalDivider(
              thickness: 1, width: 1, color: GrcColors.border),
          // ── main content ───────────────────────────────────────────────
          Expanded(child: widget.body),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: GrcColors.background,
      floatingActionButton: widget.floatingActionButton,
      // ── top app bar (hamburger) ──────────────────────────────────────
      appBar: AppBar(
        backgroundColor: GrcColors.maroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: GrcColors.leftPanelText),
          tooltip: "Open navigation",
          onPressed: _openMobileNav,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                  color: GrcColors.leftPanelText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1),
            ),
            Text(
              widget.subtitle,
              style: const TextStyle(
                  color: GrcColors.leftPanelSub,
                  fontSize: 10,
                  letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: "Logout",
              icon: const Icon(Icons.logout,
                  color: GrcColors.leftPanelText, size: 20),
              onPressed: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── page body ─────────────────────────────────────────────────
          widget.body,

          // ── dark overlay ──────────────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: _mobileOpen ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_mobileOpen,
              child: GestureDetector(
                onTap: _closeMobileNav,
                child: Container(color: Colors.black54),
              ),
            ),
          ),

          // ── slide-in drawer ───────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _mobileOpen ? 0 : -_expandedW,
            top: 0,
            bottom: 0,
            width: _expandedW,
            child: _SideNav(
              title: widget.title,
              subtitle: widget.subtitle,
              expanded: true,
              selectedIndex: widget.selectedIndex,
              destinations: widget.destinations,
              onSelect: _selectItem,
              onToggle: null,
              onLogout: () => _confirmLogout(context),
              isMobile: true,
              onClose: _closeMobileNav,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SideNav  –  the actual navigation panel widget
// ─────────────────────────────────────────────────────────────────────────────
class _SideNav extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final int selectedIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggle;   // null on mobile
  final VoidCallback? onClose;    // null on desktop
  final VoidCallback onLogout;
  final bool isMobile;

  const _SideNav({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
    required this.onToggle,
    required this.onClose,
    required this.onLogout,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
      color: GrcColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── header ──────────────────────────────────────────────────
          _buildHeader(),
          const Divider(height: 1, thickness: 1, color: GrcColors.border),
          // ── nav items ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _NavTile(
                    destination: destinations[i],
                    index: i,
                    selectedIndex: selectedIndex,
                    expanded: expanded,
                    onSelect: onSelect,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: GrcColors.border),
          // ── logout footer ────────────────────────────────────────────
          _buildLogoutFooter(),
        ],
      ),
    ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return LayoutBuilder(builder: (context, constraints) {
      // Use actual width to decide layout — avoids overflow during animation
      final isNarrow = constraints.maxWidth < 120;

      if (isNarrow && onToggle != null) {
        // Collapsed state: just the chevron
        return Container(
          height: 64,
          color: GrcColors.maroon,
          child: Center(
            child: _ChevronButton(expanded: false, onTap: onToggle!),
          ),
        );
      }

      // Expanded header
      return Container(
        height: 64,
        color: GrcColors.maroon,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.school, color: GrcColors.leftPanelText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: GrcColors.leftPanelText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: GrcColors.leftPanelSub,
                          fontSize: 9.5,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
            if (onToggle != null)
              _ChevronButton(expanded: true, onTap: onToggle!),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close, color: GrcColors.leftPanelText, size: 20),
                tooltip: "Close navigation",
                onPressed: onClose,
              ),
          ],
        ),
      );
    });
  }

  // ── logout footer ────────────────────────────────────────────────────────
  Widget _buildLogoutFooter() {
    if (!expanded) {
      return Tooltip(
        message: "Logout",
        preferBelow: false,
        child: InkWell(
          onTap: onLogout,
          child: const SizedBox(
            height: 52,
            child: Center(
              child:
                  Icon(Icons.logout, color: GrcColors.textLight, size: 20),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: onLogout,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: const [
            Icon(Icons.logout, color: GrcColors.textLight, size: 18),
            SizedBox(width: 12),
            Text(
              "Log Out",
              style: TextStyle(
                  color: GrcColors.textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChevronButton  –  animated collapse/expand button in the header
// ─────────────────────────────────────────────────────────────────────────────
class _ChevronButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ChevronButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedRotation(
          turns: expanded ? 0 : 0.5,   // 0° expanded = chevron-left; 180° = chevron-right
          duration: const Duration(milliseconds: 280),
          child: const Icon(Icons.chevron_left,
              color: GrcColors.leftPanelText, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavTile  –  a single navigation row with tooltip support when collapsed
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatefulWidget {
  final NavigationRailDestination destination;
  final int index;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelect;

  const _NavTile({
    required this.destination,
    required this.index,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelect,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  bool get _active => widget.index == widget.selectedIndex;

  // Extract the label text from the destination's label widget
  String get _labelText {
    final lbl = widget.destination.label;
    if (lbl is Text) return lbl.data ?? '';
    return '';
  }

  // Extract the icon data from the destination's icon widget
  Widget get _iconWidget => widget.destination.icon;

  @override
  Widget build(BuildContext context) {
    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: _active
                ? GrcColors.maroon.withOpacity(0.1)
                : _hovered
                    ? GrcColors.maroon.withOpacity(0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _active
                ? Border(
                    left: BorderSide(
                        color: GrcColors.maroon, width: 3))
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 3)),
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    const SizedBox(width: 4),
                    _buildIcon(),
                    const SizedBox(width: 12),
                    Expanded(child: _buildLabel()),
                  ],
                )
              : Center(child: _buildIcon()),
        ),
      ),
    );

    // When collapsed, wrap in Tooltip
    if (!widget.expanded) {
      return Tooltip(
        message: _labelText,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 200),
        child: tile,
      );
    }
    return tile;
  }

  Widget _buildIcon() {
    // Re-theme the icon widget colors based on active/inactive state
    return IconTheme(
      data: IconThemeData(
        color: _active ? GrcColors.maroon : GrcColors.textLight,
        size: 20,
      ),
      child: _iconWidget,
    );
  }

  Widget _buildLabel() {
    return Text(
      _labelText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _active ? GrcColors.maroon : GrcColors.textMid,
        fontSize: 13,
        fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}