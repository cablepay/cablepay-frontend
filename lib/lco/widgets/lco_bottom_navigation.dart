// lib/lco/widgets/lco_bottom_navigation.dart
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../lco/pages/lco_call_page.dart';
import '../../lco/pages/lco_chat_page.dart';
import '../../lco/pages/lco_profile_page.dart';
import '../../lco/pages/lco_home.dart';
import '../../lco/pages/lco_history.dart';

/// LcoBottomNavigation
/// - mirrors the customer app bottom nav: 5 items (Home, History, Call, Profile, Chat)
/// - keeps child pages alive via IndexedStack
/// - responsive scaling and lifted central call button
class LcoBottomNavigation extends StatefulWidget {
  final Map<String, dynamic> lco;
  final bool embedInScaffold;
  final int initialIndex;

  const LcoBottomNavigation({
    Key? key,
    required this.lco,
    this.embedInScaffold = true,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<LcoBottomNavigation> createState() => _LcoBottomNavigationState();
}

class _LcoBottomNavigationState extends State<LcoBottomNavigation> {
  // 0: Home, 1: History, 2: Call (center), 3: Profile, 4: Chat
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    _currentIndex = (idx < 0) ? 0 : (idx > 4 ? 4 : idx);
  }

  void _setIndex(int i) {
    if (!mounted) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final lco = widget.lco;

    // Responsive scale: avoid extremely small results on very narrow screens
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth < 360) ? (screenWidth / 360).clamp(0.78, 1.0) : 1.0;

    final itemIconSize = 40.0 * scale;
    final callSize = 56.0 * scale; // central call button diameter

    final pages = <Widget>[
      LcoHomePage(lco: lco),
      LcoHistoryPage(lco: lco),
      LcoCallPage(),
      LcoChatPage(lco: lco),
      LcoProfilePage(lco: lco),
    ];

    // Use the customer-app green for the call button
    const callGreen = Color(0xFF34A853);

    Widget navBar() {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: (itemIconSize * 0.9) + (callSize / 2) + 8.0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // background row with 4 nav items and a gap for the center call button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 8.0 * scale, vertical: 6.0 * scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SimpleNavItem(
                        icon: Icons.home_outlined,
                        label: 'Home',
                        size: itemIconSize,
                        selected: _currentIndex == 0,
                        onTap: () => _setIndex(0),
                      ),
                      _SimpleNavItem(
                        icon: Icons.history_rounded,
                        label: 'History',
                        size: itemIconSize,
                        selected: _currentIndex == 1,
                        onTap: () => _setIndex(1),
                      ),
                      SizedBox(width: callSize), // space for central call button
                      _SimpleNavItem(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        size: itemIconSize,
                        selected: _currentIndex == 3,
                        onTap: () => _setIndex(3),
                      ),
                      _SimpleNavItem(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        size: itemIconSize,
                        selected: _currentIndex == 4,
                        onTap: () => _setIndex(4),
                      ),
                    ],
                  ),
                ),
              ),

              // central call button (green gradient like customer app)
              Positioned(
                bottom: ((itemIconSize * 0.9) - (callSize / 2)) + 6.0,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _setIndex(2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: callSize,
                          height: callSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                callGreen,
                                callGreen.withOpacity(0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: callGreen.withOpacity(0.28),
                                blurRadius: 10 * scale,
                                offset: Offset(0, 6 * scale),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.call,
                            color: Colors.white,
                            size: (callSize * 0.45).clamp(18.0, 28.0),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Call',
                          style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w600, color: Colors.black87),
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

    final body = IndexedStack(index: _currentIndex, children: pages);

    if (widget.embedInScaffold) {
      return Scaffold(
        body: body,
        bottomNavigationBar: navBar(),
      );
    }

    return Column(
      children: [
        Expanded(child: body),
        navBar(),
      ],
    );
  }
}

class _SimpleNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  const _SimpleNavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.selected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppTheme.primary : Colors.black54;
    final labelColor = selected ? AppTheme.primary : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size + 14,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.onPrimary,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              child: Icon(icon, size: (size * 0.50).clamp(16.0, 22.0), color: iconColor),
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: labelColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
