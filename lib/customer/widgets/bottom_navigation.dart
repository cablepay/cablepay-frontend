// lib/widgets/bottom_navigation.dart
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/customer_service.dart';
import '../pages/call_page.dart';
import '../pages/chat_page.dart';
import '../pages/customer_history.dart';
import '../pages/referral_page.dart';
import '../pages/customer_home.dart';

/// AppBottomNavigation
/// - default: renders as a full page (Scaffold) and keeps the bottom nav fixed.
/// - set embedInScaffold: false to render only the content + nav (useful if you
///   already have an outer Scaffold).
class AppBottomNavigation extends StatefulWidget {
  final Map<String, dynamic> customer;
  final bool embedInScaffold;
  final int initialIndex; // NEW

  const AppBottomNavigation({
    Key? key,
    required this.customer,
    this.embedInScaffold = true,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  // 0: Home, 1: History, 2: Call (center), 3: Referral, 4: Chat
  late int _currentIndex;
  String? _selectedBoxId;
  bool _loadingBox = true;

  @override
  void initState() {
    super.initState();
    // clamp to valid range [0..4]
    final idx = widget.initialIndex;
    _currentIndex = (idx < 0) ? 0 : (idx > 4 ? 4 : idx);
    _loadDefaultBox();
  }

  Future<void> _loadDefaultBox() async {
    final customerId = widget.customer['_id'] ?? widget.customer['id'];
    final res = await CustomerService.listBoxes(customerId.toString());

    final boxes = (res['data'] as List?) ?? [];
    if (boxes.isNotEmpty) {
      _selectedBoxId = boxes.first['_id'];
    }

    if (mounted) {
      setState(() => _loadingBox = false);
    }
  }

  void _setIndex(int i) {
    if (!mounted) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final customerId = (customer['_id'] ?? customer['id'] ?? '').toString();
    // Responsive scale: keep behavior identical to your original but avoid
    // extremely small results by clamping sensibly.
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth < 360)
        ? (screenWidth / 360).clamp(0.78, 1.0)
        : 1.0;

    final itemIconSize = 40.0 * scale;
    final callSize = 56.0 * scale; // call button diameter

    if (_loadingBox || _selectedBoxId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      CustomerHomePage(customer: customer),
      CustomerHistoryPage(customer: customer, boxId: null),
      CallPage(customerId: customerId),
      ReferralPage(customer: customer),
      ChatPage(customer: customer, boxId: _selectedBoxId!),
    ];

    // The nav widget itself (keeps exact layout, call button lifted half-out)
    Widget navBar() {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: (itemIconSize * 0.9) + (callSize / 2) + 8.0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.0 * scale,
                    vertical: 6.0 * scale,
                  ),
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
                      SizedBox(width: callSize),
                      _SimpleNavItem(
                        icon: Icons.group_add_outlined,
                        label: 'Referral',
                        size: itemIconSize,
                        selected: _currentIndex == 3,
                        onTap: () => _setIndex(3),
                      ),
                      _SimpleNavItem(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        size: itemIconSize,
                        selected: _currentIndex == 4,
                        onTap: () => _setIndex(4),
                      ),
                    ],
                  ),
                ),
              ),

              // central call button
              Positioned(
                // simplified safe bottom placement
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
                                const Color(0xFF34A853),
                                const Color(0xFF34A853).withOpacity(0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF34A853,
                                ).withOpacity(0.28),
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
                          style: TextStyle(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
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



    // Body area that swaps while keeping state
    final body = IndexedStack(index: _currentIndex, children: pages);

    // If embedInScaffold is true we return a full scaffold (recommended),
    // otherwise we return a Column suitable to place inside an outer Scaffold.
    if (widget.embedInScaffold) {
      return Scaffold(body: body, bottomNavigationBar: navBar());
    }

    // embedded variant: expands to available height and places nav fixed bottom
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
    final iconColor = selected ? AppTheme.primary : AppTheme.primary;
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: (size * 0.50).clamp(16.0, 22.0),
                color: iconColor,
              ),
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
