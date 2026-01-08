// lib/lco/widgets/lco_side_menu.dart
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../lco/pages/lco_networks.dart';
import '../../lco/widgets/lco_bottom_navigation.dart';
import '../../lco/pages/lco_settings_page.dart';

class LcoSideMenu extends StatelessWidget {
  final Map<String, dynamic> lco;
  final VoidCallback? onLogout;

  const LcoSideMenu({
    Key? key,
    required this.lco,
    this.onLogout,
  }) : super(key: key);

  String _phonesText() {
    try {
      final ph = (lco['phones'] ?? []) as List<dynamic>;
      if (ph.isEmpty) return 'No phone';
      return ph
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    } catch (_) {
      return '-';
    }
  }

  /// Helper: Navigate using bottom navigation instead of pushing new pages.
  void _navigateBottom(BuildContext ctx, int index) {
    Navigator.pop(ctx); // close drawer
    Navigator.pushReplacement(
      ctx,
      MaterialPageRoute(
        builder: (_) => LcoBottomNavigation(
          lco: lco,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (lco['name'] ?? 'LCO User').toString();
    final business = (lco['businessName'] ?? '').toString();
    final phones = _phonesText();

    final avatarInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Responsive width calculation
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth >= 720 ? 360.0 : screenWidth * 0.80;

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        elevation: 10,
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // 1. Header Area (Polished Container)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        avatarInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (business.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              business,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 12, color: Colors.white.withOpacity(0.8)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  phones,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // HOME - Index 0
                  _buildTile(
                    context,
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () => _navigateBottom(context, 0),
                  ),

                  // MANAGE NETWORKS (Push new page)
                  _buildTile(
                    context,
                    icon: Icons.settings_applications_rounded,
                    label: 'Manage Networks',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LcoNetworksPage(lco: lco),
                        ),
                      );
                    },
                  ),

                  // HISTORY - Index 1
                  _buildTile(
                    context,
                    icon: Icons.history_rounded,
                    label: 'History',
                    onTap: () => _navigateBottom(context, 1),
                  ),

                  // CALL - Index 2
                  _buildTile(
                    context,
                    icon: Icons.call_outlined,
                    label: 'Call',
                    onTap: () => _navigateBottom(context, 2),
                  ),

                  // CHAT - Index 3
                  _buildTile(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    onTap: () => _navigateBottom(context, 3),
                  ),

                  Divider(height: 24, thickness: 1, color: Colors.grey.shade200),

                  // PROFILE - Index 4
                  _buildTile(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () => _navigateBottom(context, 4),
                  ),

                  _buildTile(
                    context,
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LcoSettingsPage(lco: lco),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),

            // 3. Logout Area (FIXED)
            // Added explicit background and padding to avoid overlap with floating button
            Container(
              decoration: BoxDecoration(
                color: Colors.white, // Opaque background
                border: Border(
                  top: BorderSide(color: AppTheme.divider),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                // Lifts the content up so the floating button doesn't obscure it
                minimum: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (onLogout != null) onLogout!();
                          },
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            alignment: Alignment.centerLeft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.redAccent.withOpacity(0.04),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget for consistent list tiles
  Widget _buildTile(BuildContext context,
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      minLeadingWidth: 20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      horizontalTitleGap: 12,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: AppTheme.surfaceVariant,
      dense: true,
      visualDensity: VisualDensity.compact,
      trailing:
      const Icon(Icons.chevron_right, size: 20, color: Colors.black45),
    );
  }
}