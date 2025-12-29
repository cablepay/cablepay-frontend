// lib/customer/pages/customer_home.dart
import 'dart:convert';

import 'package:cable_pay/customer/pages/profile_page.dart';
import 'package:cable_pay/customer/pages/referral_page.dart';
import 'package:cable_pay/customer/pages/wallet_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_config.dart';
import '../../core/local_storage.dart';
import '../../core/app_theme.dart';
import '../../routes.dart';
import '../../services/customer_service.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/side_menu.dart';
import 'customer_detail.dart';
import 'customer_history.dart';
import '../../core/safe_state.dart';
import '../../core/date_utils.dart';


class CustomerHomePage extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerHomePage({Key? key, required this.customer}) : super(key: key);

  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  List<dynamic> boxes = [];
  bool loading = true;
  final Map<String, bool> activating = {}; // boxId -> loading
  String? errorMsg;

  // Colors & theme
  // final Color _cardBlueStart = const Color(0xFF2196F3);
  // final Color _cardBlueEnd = const Color(0xFF1976D2);
  // final Color _buttonBlue = const Color(0xFF2196F3);

  final Color _cardBlueStart = const Color(0xFF3568B1); // lighter primary
  final Color _cardBlueEnd = const Color(0xFF143664); // darker primary
  final Color _buttonBlue = const Color(0xFF3568B1); // matches start color

  final Color _referralGreen = const Color(0xFF4CAF50);
  final Color _referralGreenLight = const Color(0xFF81C784);

  // add near top of State class
  int _cardWalletPaise = 0;
  DateTime? _cardWalletUpdatedAt;
  bool _cardWalletLoading = true;
  String? _cardWalletError;

  final Map<String, bool> _useWalletForBox = {}; // boxId -> useWallet toggle

  // modify initState to fetch wallet for the card (keep existing calls)
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadBoxes();
    await _loadWalletForCard();
  }


  Future<void> _loadBoxes() async {
    if (!mounted) return;
    await safeSetState(this, () {
      loading = true;
      errorMsg = null;
    });

    final customerId = widget.customer['_id'] ?? widget.customer['id'];
    if (customerId == null) {
      if (!mounted) return setState(() => loading = false);
      await safeSetState(this, () {
        errorMsg = 'Invalid customer ID';
        loading = false;
      });
      return;
    }

    try {
      final res = await CustomerService.listBoxes(customerId.toString());
      if (!mounted) return;
      if (res['statusCode'] == 200) {
        await safeSetState(this, () {
          boxes = (res['data'] is List) ? res['data'] as List<dynamic> : [];
        });
      } else {
        await safeSetState(this, () {
          boxes = [];
          errorMsg = (res['data'] is Map && res['data']['error'] != null)
              ? res['data']['error'].toString()
              : 'Failed to load boxes';
        });
      }
    } catch (e) {
      if (!mounted) return;
      await safeSetState(this, () {
        boxes = [];
        errorMsg = 'Network error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return '-';
    try {
      DateTime dt;
      if (val is DateTime)
        dt = val;
      else
        dt = DateTime.parse(val.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  bool _needsPayment(Map<String, dynamic> box) {
    final status = (box['status'] ?? '').toString().toLowerCase();
    if (status != 'active') return true;
    final last = box['lastCutoffDate'];
    if (last == null) return true;
    try {
      final DateTime dt = (last is DateTime)
          ? last
          : DateTime.parse(last.toString());
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return dt.isBefore(today);
    } catch (_) {
      return true;
    }
  }

  int? _amountPaiseForBox(Map<String, dynamic> box) {
    if (box == null) return null;

    final pp = box['pricePaise'];
    if (pp != null) {
      if (pp is int) return pp;
      if (pp is num) return pp.toInt();
      final parsed = int.tryParse(pp.toString());
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(pp.toString());
      if (parsedDouble != null) return parsedDouble.round();
    }

    final pr = box['priceRupees'];
    if (pr != null) {
      if (pr is num) return (pr * 100).round();
      final parsed = double.tryParse(pr.toString());
      if (parsed != null) return (parsed * 100).round();
    }

    final lcoRef = box['lcoRef'];
    final boxLcoId = box['lcoId']?.toString();
    if (lcoRef is Map && boxLcoId != null && lcoRef['networks'] is List) {
      try {
        final networks = (lcoRef['networks'] as List).cast<dynamic>();
        for (final n in networks) {
          if (n is Map) {
            final nid = (n['lcoId'] ?? '').toString();
            if (nid == boxLcoId) {
              final fp = n['fixedPrice'];
              if (fp != null) {
                final fpNum =
                    double.tryParse(fp.toString()) ??
                    (fp is num ? fp.toDouble() : double.nan);
                if (fpNum.isFinite && fpNum > 0) return (fpNum * 100).round();
              }
            }
          }
        }
      } catch (e, st) {
        debugPrint('CustomerHome error: $e');
      }

    }

    return null;
  }

  Future<void> _confirmAndPay(Map<String, dynamic> box) async {
    final customerId = widget.customer['_id'] ?? widget.customer['id'];
    final boxId = (box['_id'] ?? box['id']);
    if (customerId == null || boxId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing identifiers')));
      return;
    }

    // Refresh local box data (best-effort)
    Map<String, dynamic>? freshBox;
    try {
      final listRes = await CustomerService.listBoxes(customerId.toString());
      if (listRes['statusCode'] == 200 && listRes['data'] is List) {
        final boxes = List<Map<String, dynamic>>.from(listRes['data'] as List);
        freshBox = boxes.firstWhere((b) {
          final idA = (b['_id'] ?? b['id']).toString();
          final idB = boxId.toString();
          return idA == idB;
        }, orElse: () => <String, dynamic>{});
        if (freshBox.isEmpty) freshBox = null;
      }
    } catch (_) {
      freshBox = null;
    }

    final useBox = (freshBox != null) ? freshBox : box;
    final amountPaise = _amountPaiseForBox(useBox);
    if (amountPaise == null || amountPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No price configured for this box. Contact your LCO.'),
        ),
      );
      return;
    }
    final period = DateFormat('yyyy-MM').format(DateTime.now());

    // Fetch wallet summary right before payment (to show in dialog)
    int walletPaiseAvailable = 0;
    DateTime? walletUpdatedAt;
    try {
      final wres = await CustomerService.getWallet(customerId.toString());
      if (wres['statusCode'] == 200 && wres['data'] != null) {
        final body = wres['data'] as Map<String, dynamic>;
        final raw = body['walletPaise'] ?? 0;
        walletPaiseAvailable = (raw is int) ? raw : int.tryParse('$raw') ?? 0;
        final tu = body['walletUpdatedAt'];
        walletUpdatedAt = tu != null ? DateTime.tryParse(tu.toString()) : null;
      }
    } catch (_) {
      walletPaiseAvailable = 0;
    }

    // Use per-box toggle (set default if not present)
    final idStr = boxId.toString();
    if (!_useWalletForBox.containsKey(idStr)) {
      final defaultApply = (walletPaiseAvailable > 0)
          ? (walletPaiseAvailable <= amountPaise ? true : true)
          : false;
      _useWalletForBox[idStr] = defaultApply;
    }
    final useWalletFlag = _useWalletForBox[idStr] == true;

    // compute amounts
    final int walletApply = useWalletFlag
        ? (walletPaiseAvailable <= amountPaise
              ? walletPaiseAvailable
              : amountPaise)
        : 0;
    final int netPayPaise = amountPaise - walletApply;
    String paiseToRupees(int p) => '₹${(p / 100.0).toStringAsFixed(2)}';

    // Show confirmation dialog (no checkbox here)
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Box: ${useBox['setupBoxNumber'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Period',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      period,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _rowLabelValue('Amount', paiseToRupees(amountPaise)),
                      const SizedBox(height: 8),
                      _rowLabelValue(
                        'Wallet balance',
                        paiseToRupees(walletPaiseAvailable),
                      ),
                      if (walletUpdatedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Updated ${DateFormat.yMMMd().add_jm().format(walletUpdatedAt!.toLocal())}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      _rowLabelValue(
                        'Wallet applied',
                        paiseToRupees(walletApply),
                      ),
                      const SizedBox(height: 8),
                      _rowLabelValue(
                        'Net to pay',
                        paiseToRupees(netPayPaise),
                        valueStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Note: wallet credits are applied at checkout. If server does not support disabling the wallet, it may still be consumed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm & Pay'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => activating[idStr] = true);

    try {
      final payload = <String, dynamic>{
        'period': period,
        'useWallet': useWalletFlag,
      };
      final apiRes = await ApiConfig.post(
        '/api/customers/$customerId/boxes/$boxId/activate',
        payload,
      );

      setState(() => activating[idStr] = false);

      final statusCode = apiRes['statusCode'] as int? ?? 500;
      final data = apiRes['body'];

      if (statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment succeeded — box activated')),
        );
        await _loadBoxes();
        await _loadWalletForCard(); // refresh wallet after payment
      } else {
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Payment failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => activating[idStr] = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment error: $e')));
    }
  }

  // small helper used inside dialog
  Widget _rowLabelValue(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        Text(
          value,
          style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  void _logout() async {
    try {
      try {
        await ApiConfig.post('/api/auth/logout', {});
      } catch (e, st) {
        debugPrint('CustomerHome error: $e');
      }
      await LocalStorage.clearSession();
      await LocalStorage.clearCustomer();
      ApiConfig.setSessionKey(null);
      Navigator.pushReplacementNamed(context, AppRoutes.customerLogin);
    } catch (e) {
      Navigator.pushReplacementNamed(context, AppRoutes.customerLogin);
    }
  }

  String _lcoDisplay(Map<String, dynamic> box) {
    final lcoRef = box['lcoRef'];
    if (lcoRef is Map &&
        (lcoRef['businessName'] != null || lcoRef['name'] != null)) {
      return (lcoRef['businessName'] ?? lcoRef['name']).toString();
    }
    return (box['lcoId']?.toString() ?? '-');
  }

  /// Map box['status'] (or inferred state) -> friendly label + color
  Map<String, dynamic> _statusInfo(Map<String, dynamic> box) {
    final raw = (box['status'] ?? '').toString().toLowerCase();
    final lastCutoff = box['lastCutoffDate'];
    // default: red (unpaid)
    Color color = Colors.red.shade700;
    String label = (raw.isNotEmpty) ? raw.toUpperCase() : 'INACTIVE';

    if (raw == 'active') {
      color = Colors.green.shade700;
      label = 'ACTIVE';
    } else if (raw == 'pending' || raw == 'processing' || raw == 'waiting') {
      color = Colors.yellow.shade700; // yellow/orange for waiting/processing
      label = raw.toUpperCase();
    } else if (raw == 'inactive' ||
        raw == 'suspended' ||
        raw == 'canceled' ||
        raw == 'cancelled') {
      color = Colors.red.shade700;
      label = 'INACTIVE';
    } else if (raw.isEmpty) {
      // If status empty, infer from cutoff date
      try {
        if (lastCutoff != null) {
          final dt = (lastCutoff is DateTime)
              ? lastCutoff
              : DateTime.parse(lastCutoff.toString());
          if (dt.isBefore(DateTime.now())) {
            color = Colors.red.shade700;
            label = 'DUE';
          } else {
            color = Colors.yellow.shade700;
            label = 'PENDING';
          }
        } else {
          color = Colors.red.shade700;
          label = 'INACTIVE';
        }
      } catch (_) {
        color = Colors.red.shade700;
        label = 'INACTIVE';
      }
    }

    return {'label': label, 'color': color};
  }

  Widget _buildEmpty(String title, String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv, size: 84, color: AppTheme.primaryLight),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headline6),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyText2,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailPage(data: widget.customer),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Register First Box'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMsg!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoxCard(Map<String, dynamic> box, int index, double maxWidth) {
    // --- Logic Setup (Unchanged) ---
    final needsPay = _needsPayment(box);
    final boxId = (box['_id'] ?? box['id'] ?? index.toString()).toString();
    final isProcessing = activating[boxId] == true;

    final status = _statusInfo(box);
    final statusLabel = status['label'] as String;
    final statusColor = status['color'] as Color;

    final paise = _amountPaiseForBox(box);
    final priceText = (paise != null && paise > 0)
        ? '₹${(paise / 100).toStringAsFixed(0)}'
        : '—';

    final cutoff = box['lastCutoffDate'];
    final cutoffDate = _formatDate(cutoff);

    final boxNumber = box['setupBoxNumber']?.toString() ?? '-';
    final planName = (box['network']?.toString() ?? '').isNotEmpty
        ? box['network'].toString()
        : (box['networkCode']?.toString() ?? 'Standard Plan');
    final lcoName = _lcoDisplay(box);
    final lcoId =
        box['lcoId']?.toString() ?? box['networkCode']?.toString() ?? '-';

    // Helper for status text color contrast
    final statusTextColor = statusColor.computeLuminance() > 0.6
        ? Colors.black
        : Colors.white;

    // Safe runner
    void _safeRun(VoidCallback cb) => Future.microtask(cb);

    // --- UI Structure ---
    return Container(
      // margin: const EdgeInsets.only(
      //   bottom: 8,
      // ), // Increased spacing between cards
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // -----------------------------------------------------------------
          // 1. MAIN CARD (Blue Gradient)
          // -----------------------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20), // More breathing room inside
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cardBlueStart, _cardBlueEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                16,
              ), // Slightly softer corners
              boxShadow: [
                BoxShadow(
                  color: _cardBlueStart.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Row: Logo + Info + Status ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          planName.isNotEmpty ? planName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Plan Name & STB
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'STB : $boxNumber',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- Middle Row: Price ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36, // Hero size
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/month',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- Footer Row: Provider Info + Cutoff Box ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left: Provider Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lcoName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'LCO ID: $lcoId',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right: Cutoff Date Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Due date',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cutoffDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // -----------------------------------------------------------------
          // WALLET TOGGLE (inline) + ACTION BUTTON
          // -----------------------------------------------------------------
          // Wallet toggle: visible only if wallet exists and box price is valid
          Builder(
            builder: (ctx) {
              final idStr = boxId;
              final walletAvailable = _cardWalletPaise; // from your state
              final origPaise = paise ?? 0;

              // walletApplicable: show wallet UI only if wallet exists and box price is valid
              final walletApplicable = (walletAvailable > 0) && (origPaise > 0);

              // ensure we have an entry for this box in the map (checkbox state)
              if (!_useWalletForBox.containsKey(idStr)) {
                // default behaviour: apply wallet if available
                _useWalletForBox[idStr] = walletApplicable;
              }

              final useWallet = _useWalletForBox[idStr] == true;

              // wallet that will actually be applied (used for payment)
              final walletApplyActual = useWallet
                  ? (walletAvailable <= origPaise ? walletAvailable : origPaise)
                  : 0;

              // wallet amount to display (always show possible applied amount independent of checkbox)
              final walletApplyDisplayed = (origPaise > 0)
                  ? (walletAvailable <= origPaise ? walletAvailable : origPaise)
                  : 0;

              final netToPay = origPaise - walletApplyActual;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (walletApplicable) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: useWallet,
                          onChanged: (v) {
                            setState(() {
                              _useWalletForBox[idStr] = v == true;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            // show the display amount that is independent of checkbox
                            'Use wallet (available ${_formatWallet(walletApplyDisplayed)})',
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        ),
                        if (_cardWalletLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50, // Comfortable tap target
                    child: (() {
                      // Extract backend status
                      final rawStatus = (box['status'] ?? '').toString().toLowerCase();

                      // Conditions
                      final isActive = rawStatus == 'active' || rawStatus == 'succeeded';
                      final isProcessingState =
                          rawStatus == 'pending' ||
                              rawStatus == 'processing' ||
                              rawStatus == 'waiting';

                      // ---- CASE 1: ACTIVE → Show "Paid" ----
                      if (isActive) {
                        return Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.2)),
                          ),
                          child: const Center(
                            child: Text(
                              'Paid',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      // ---- CASE 2: PROCESSING → Show "Processing…" ----
                      if (isProcessingState) {
                        return Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              'Paid…',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      // ---- CASE 3: NOT ACTIVE + NOT PROCESSING → Show Pay Now ----
                      return ElevatedButton(
                        onPressed: isProcessing
                            ? null
                            : () => _safeRun(() => _confirmAndPay(box)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _buttonBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isProcessing
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                            : LayoutBuilder(
                          builder: (c, constraints) {
                            final label = walletApplyActual > 0
                                ? 'Pay Now • ${_formatWallet(netToPay)}'
                                : 'Pay Now • ${_formatWallet(origPaise)}';
                            return Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            );
                          },
                        ),
                      );
                    })(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // new helper to load wallet for the card
  Future<void> _loadWalletForCard() async {
    final customerId =
        widget.customer['_id'] ??
        widget.customer['id'] ??
        widget.customer['uid'];
    if (customerId == null) return;
    try {
      await safeSetState(this, () {
        _cardWalletLoading = true;
        _cardWalletError = null;
      });
      final res = await CustomerService.getWallet(customerId.toString());
      if (res['statusCode'] == 200 && res['data'] != null) {
        final body = res['data'] as Map<String, dynamic>;
        final rawPaise = body['walletPaise'] ?? 0;
        final paise = (rawPaise is int)
            ? rawPaise
            : int.tryParse('$rawPaise') ?? 0;
        final tu = body['walletUpdatedAt'];
        await safeSetState(this, () {
          _cardWalletPaise = paise;
          _cardWalletUpdatedAt = tu != null
              ? DateTime.tryParse(tu.toString())
              : null;
        });
      } else {
        await safeSetState(this, () {
          _cardWalletError = 'Failed to fetch wallet';
        });
      }
    } catch (e) {
      await safeSetState(this, () {
        _cardWalletError = 'Error';
      });
    } finally {
      await safeSetState(this, () {
        _cardWalletLoading = false;
      });
    }
  }

  Widget _buildReferralCard(double contentMaxWidth) {
    // small helper to format wallet safely
    String _safeWallet(dynamic w) {
      try {
        return _formatWallet(w);
      } catch (_) {
        final paise = (w is int) ? w : int.tryParse('$w') ?? 0;
        final rupees = paise / 100.0;
        return '₹${rupees.toStringAsFixed(2)}';
      }
    }

    // fixed icon box used for both rows so sizes remain identical
    Widget iconBox(Icon icon, {Color? bg}) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: (bg ?? Colors.orange.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: icon),
      );
    }

    // decide wallet text: prefer live card state, fallback to widget.customer stored value
    final walletText = _cardWalletLoading
        ? '...'
        : (_cardWalletPaise != 0
              ? _safeWallet(_cardWalletPaise)
              : (widget.customer['walletPaise'] != null
                    ? _safeWallet(widget.customer['walletPaise'])
                    : '₹0.00'));

    // central styles
    final titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppTheme.text,
    );
    final subtitleStyle = TextStyle(fontSize: 13, color: Colors.grey.shade600);
    final amountStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: Colors.green.shade700,
    );

    // Single-line row builder: icon | title/subtitle (flex) | amount (fixed) | chevron
    Widget infoRow({
      required VoidCallback onTap,
      required Widget icon,
      required String title,
      required String subtitle,
      String? amountText,
      bool amountBold = true,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ICON
                icon,
                const SizedBox(width: 12),

                // TITLE / SUBTITLE - flexible and will ellipsize if needed
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),

                // AMOUNT (if present) - constrained so it doesn't push the title too far
                if (amountText != null) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      maxWidth: 140,
                    ),
                    child: Text(
                      amountText,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: amountBold
                          ? amountStyle
                          : amountStyle.copyWith(fontSize: 14),
                      maxLines: 1,
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // CHEVRON - always next to amount
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: contentMaxWidth,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey1,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Text(
            'Offers & Wallet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.text.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 3),

          // Refer & Earn row — include amount in title as before
          infoRow(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppBottomNavigation(
                    customer: widget.customer,
                    initialIndex: 3,
                  ),
                ),
              );
            },
            icon: iconBox(
              const Icon(Icons.redeem, color: Colors.orange, size: 26),
              bg: Colors.orange.withOpacity(0.12),
            ),
            title: 'Refer & Earn ₹50',
            subtitle: 'Wallet credit for new connections',
            amountText: null,
          ),
          const SizedBox(height: 3),

          // Wallet row — amount and chevron stay on the same line
          infoRow(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletPage(customer: widget.customer),
                ),
              );
            },
            icon: iconBox(
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.green,
                size: 26,
              ),
              bg: Colors.green.withOpacity(0.08),
            ),
            title: 'Wallet',
            subtitle: 'View wallet balance',
            amountText: walletText,
            amountBold: true,
          ),
        ],
      ),
    );
  }

  // keep your existing _formatWallet helper
  String _formatWallet(dynamic paise) {
    final int p = (paise is int) ? paise : int.tryParse('$paise') ?? 0;
    return '₹${(p / 100).toStringAsFixed(2)}';
  }

  String _customerNameSafe() {
    final c = widget.customer;
    if (c == null) return 'Customer';

    try {
      // Case 1: widget.customer is a raw String
      if (c is String) {
        final s = c.toString().trim();
        return s.isNotEmpty ? s : 'Customer';
      }

      // Case 2: widget.customer is a Map
      if (c is Map) {
        dynamic getValue(dynamic v) {
          if (v == null) return null;
          final s = v.toString().trim(); // ALWAYS convert toString first
          return s.isNotEmpty ? s : null;
        }

        // direct fields
        final direct =
            getValue(c['name']) ??
            getValue(c['fullName']) ??
            getValue(c['displayName']);
        if (direct != null) return direct;

        // nested
        final nested = c['customer'] ?? c['profile'] ?? c['data'];
        if (nested is Map) {
          final nestedName =
              getValue(nested['name']) ??
              getValue(nested['fullName']) ??
              getValue(nested['displayName']);
          if (nestedName != null) return nestedName;
        }

        // fallback: phone
        final phone = getValue(c['phone']);
        if (phone != null) return phone;
      }
    } catch (_) {
      // ignore and fallback
    }

    return 'Customer';
  }

  int? _minDaysLeftForExpiry(List<dynamic> boxes) {
    final now = DateTime.now();
    int? minDays;

    for (final raw in boxes) {
      if (raw is! Map<String, dynamic>) continue;

      final cutoff = raw['lastCutoffDate'];
      if (cutoff == null) continue;

      try {
        final DateTime cutoffDate =
        cutoff is DateTime ? cutoff : DateTime.parse(cutoff.toString());

        final diff = cutoffDate
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;

        if (diff < 0 || diff > 10) continue;

        if (minDays == null || diff < minDays) {
          minDays = diff;
        }
      } catch (_) {
        continue;
      }
    }

    return minDays;
  }

  Widget _buildExpiryHint() {
    final daysLeft = _minDaysLeftForExpiry(boxes);
    if (daysLeft == null) return const SizedBox.shrink();

    String text;
    Color color;

    if (daysLeft > 1) {
      text = 'Expires in $daysLeft days';
      color = Colors.orange.shade700;
    } else if (daysLeft == 1) {
      text = 'Expires tomorrow';
      color = Colors.deepOrange;
    } else {
      text = 'Expires today';
      color = Colors.red.shade700;
    }

    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLarge = mq.size.width >= 720;
    final contentMaxWidth = isLarge ? 500.0 : double.infinity;

    return Scaffold(
      backgroundColor: AppTheme.grey1,
      drawer: SideMenu(customer: widget.customer, onLogout: _logout),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Cable Pay',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.text,
          ),
        ),

        // Drawer menu
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: AppTheme.primary,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),

        actions: [
          // // Refresh button
          // IconButton(
          //   onPressed: _loadBoxes,
          //   icon: Icon(Icons.refresh, color: AppTheme.primary),
          // ),

          IconButton(
            icon: const Icon(Icons.notifications_none),
            color: AppTheme.primary,
            onPressed: () {
              // TODO: notification screen
            },
          ),

          // ---- NEW: Profile navigation button ----
          IconButton(
            icon: Icon(Icons.person, color: AppTheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(customer: widget.customer),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Body: top area shows "Hello, <name>" on the same background (no card)
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBoxes,
                  color: _buttonBlue,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Single-line greeting: "Hello, Name"
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Hello, ${_customerNameSafe()}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  _buildExpiryHint(),
                                ],
                              ),

                              const SizedBox(height: 3),
                            ],
                          ),
                        ),
                      ),

                      // Content area: empty state or list of boxes
                      if (boxes.isEmpty) ...[
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmpty(
                            'No Plans Found',
                            'Link a Set-Top Box to view your plan details.',
                          ),
                        ),
                      ] else ...[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((context, i) {
                              final raw = boxes[i];
                              final box = (raw is Map<String, dynamic>)
                                  ? raw
                                  : Map<String, dynamic>.from(raw as Map);
                              return _buildBoxCard(box, i, contentMaxWidth);
                            }, childCount: boxes.length),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: _buildReferralCard(contentMaxWidth),
                        ),
                      ],
                      // bottom padding so list has breathing room
                      SliverToBoxAdapter(child: const SizedBox(height: 20)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
