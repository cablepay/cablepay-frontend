// lib/widgets/side_menu.dart
import 'package:cable_pay/customer/pages/wallet_page.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/logout_helper.dart';
import '../pages/my_connections_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';
import 'bottom_navigation.dart';
import '../pages/customer_settings_page.dart';

/// Polished side drawer with responsive width and a dedicated logout area.
/// CORRECTED: Adjusted layout to prevent Bottom Navigation overlap on the Logout button.
class SideMenu extends StatelessWidget {
  final Map<String, dynamic>? customer;
  final VoidCallback? onLogout;

  const SideMenu({Key? key, this.customer, this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = (customer?['name'] ?? customer?['fullName'] ?? 'Customer')
        .toString();
    final phone = (customer?['phone'] ?? customer?['mobile'] ?? '').toString();

    // Responsive width:
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth >= 720 ? 360.0 : screenWidth * 0.80;

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        elevation: 10,
        backgroundColor: Colors.white, // Ensure drawer background is solid
        child: Column(
          children: [
            // 1. Header Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                      backgroundColor: Colors.white,
                      child: Text(
                        (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
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
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone.isEmpty ? 'No phone' : phone,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Member since ${_memberSinceText(customer)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
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
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                children: [
                  _buildTile(
                    context,
                    icon: Icons.home,
                    label: 'Home',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBottomNavigation(
                            customer: customer ?? {},
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.chat_bubble,
                    label: 'Chat',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBottomNavigation(
                            customer: customer ?? {},
                            initialIndex: 4,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.group_add,
                    label: 'Referral',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBottomNavigation(
                            customer: customer ?? {},
                            initialIndex: 3,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.call,
                    label: 'Call',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBottomNavigation(
                            customer: customer ?? {},
                            initialIndex: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.history,
                    label: 'History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppBottomNavigation(
                            customer: customer ?? {},
                            initialIndex: 1,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.wallet_rounded,
                    label: 'Wallet',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletPage(customer: customer ?? {}),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 24,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  ),
                  _buildTile(
                    context,
                    icon: Icons.person,
                    label: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(customer: customer ?? {}),
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.notifications,
                    label: 'Notifications',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationPage()),
                      );
                    },
                  ),
                  _buildTile(
                    context,
                    icon: Icons.devices,
                    label: 'My Connections',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyConnectionsPage(customer: customer ?? {}),
                        ),
                      );
                    },
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
                          builder: (_) => CustomerSettingsPage(customer: customer ?? {}),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),

            // 3. Logout Area (FIXED)
            // Added explicit background color and increased bottom padding
            // to lift the button above the floating 'Call' button overlap zone.
            Container(
              decoration: BoxDecoration(
                color: Colors.white, // Opaque background
                border: Border(top: BorderSide(color: AppTheme.divider)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                // Add extra bottom padding here to clear the floating button
                minimum: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {

                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Confirm Logout'),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Logout'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) return;
                            // 1️⃣ Close drawer
                            Navigator.of(context).pop();

                            // 2️⃣ Defer logout to next frame with ROOT context
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final rootContext = Navigator.of(
                                context,
                                rootNavigator: true,
                              ).context;
                              performLogout(rootContext);
                            });
                          },

                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
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
                              vertical: 14,
                              horizontal: 12,
                            ),
                            alignment:
                                Alignment.centerLeft, // Align left clearly
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

  String _memberSinceText(Map<String, dynamic>? customer) {
    try {
      final createdAt =
          customer?['createdAt'] ??
          customer?['created_at'] ??
          customer?['createdAtUtc'];
      if (createdAt == null) return '—';
      final d = DateTime.tryParse(createdAt.toString());
      if (d == null) return '—';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: Colors.black45,
      ),
    );
  }
}
