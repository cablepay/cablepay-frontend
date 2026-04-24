// lib/customer/pages/customer_history.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/customer_service.dart';

class CustomerHistoryPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String? boxId;

  const CustomerHistoryPage({super.key, required this.customer, this.boxId});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

enum SortMode { recentPaidDesc, recentPaidAsc }

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  bool loading = true;
  String? error;
  List<dynamic> boxes = [];

  SortMode _sortMode = SortMode.recentPaidDesc;


  // Formatters
  final NumberFormat money0 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final NumberFormat money2 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final DateFormat dtDisplay = DateFormat('dd MMM yyyy, hh:mm a');
  final DateFormat shortDate = DateFormat('dd MMM yyyy');
  final DateFormat monthDisplay = DateFormat('MMMM yyyy');

  // UI Colors
  final Color _bgGrey = const Color(0xFFF5F7FA);
  final Color _cardWhite = Colors.white;
  final Color _textDark = const Color(0xFF1A1A1A);
  final Color _textGrey = const Color(0xFF757575);
  final Color _greenColor = const Color(0xFF2E7D32);
  final Color _orangeColor = const Color(0xFFEF6C00);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      loading = true;
      error = null;
    });

    final customerId = widget.customer['_id'] ?? widget.customer['id'];
    if (customerId == null) {
      setState(() {
        error = 'Invalid customer id';
        loading = false;
      });
      return;
    }

    try {
      final res = await CustomerService.getPaymentHistory(
        customerId.toString(),
        boxId: widget.boxId,
      );
      if (res['statusCode'] == 200) {
        final data = res['data'];
        setState(() {
          boxes = (data != null && data['boxes'] is List)
              ? data['boxes'] as List<dynamic>
              : [];
        });
      } else {
        final body = res['data'];
        setState(() {
          error = (body is Map && body['error'] != null)
              ? body['error'].toString()
              : 'Failed to load history';
        });
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      setState(() {
        if (msg.contains('socket') || msg.contains('network')) {
          error = 'No internet connection';
        } else {
          error = 'Server under maintenance';
        }
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // --- Logic Helpers (Unchanged) ---
  int _toPaise(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return (v * 100).round();
    final s = v.toString();
    final d = double.tryParse(s);
    if (d != null) return (d * 100).round();
    return 0;
  }

  String _fmtAmount(double rupees, {bool decimals = false}) {
    return decimals ? money2.format(rupees) : money0.format(rupees);
  }

  String _fmtDateTime(dynamic v) {
    if (v == null) return '-';
    try {
      if (v is int)
        return dtDisplay.format(
          DateTime.fromMillisecondsSinceEpoch(v).toLocal(),
        );
      return dtDisplay.format(DateTime.parse(v.toString()).toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  String _fmtShortDate(dynamic v) {
    if (v == null) return '-';
    try {
      if (v is int)
        return shortDate.format(
          DateTime.fromMillisecondsSinceEpoch(v).toLocal(),
        );
      return shortDate.format(DateTime.parse(v.toString()).toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  String _fmtMonthSafe(dynamic period) {
    if (period == null) return '-';
    try {
      final s = period.toString();
      final parts = s.split('-'); // expecting YYYY-MM
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return monthDisplay.format(DateTime(y, m));
    } catch (_) {
      return period.toString();
    }
  }

  // sort boxes by selected mode (returns new list)
  // List<dynamic> _sortedBoxes() {
  //   final List<dynamic> copy = boxes.map((b) => b).toList();
  //   if (_sortMode == SortMode.serverOrder) return copy;
  //
  //   int paidAtForBox(dynamic box) {
  //     final months = (box['months'] is List) ? box['months'] as List : [];
  //     int latest = 0;
  //
  //     for (final m in months) {
  //       final ts = m['paidAtTs'];
  //       if (ts is int && ts > latest) latest = ts;
  //     }
  //     return latest;
  //   }
  //
  //   if (_sortMode == SortMode.recentPaidDesc) {
  //     copy.sort((a, b) => paidAtForBox(b).compareTo(paidAtForBox(a)));
  //   } else if (_sortMode == SortMode.recentPaidAsc) {
  //     copy.sort((a, b) => paidAtForBox(a).compareTo(paidAtForBox(b)));
  //   } else if (_sortMode == SortMode.unpaidFirst) {
  //     int unpaidCount(dynamic box) {
  //       final months = (box['months'] is List)
  //           ? (box['months'] as List<dynamic>)
  //           : <dynamic>[];
  //       return months.where((m) => !(m is Map && m['paid'] == true)).length;
  //     }
  //
  //     copy.sort((a, b) => unpaidCount(b).compareTo(unpaidCount(a)));
  //   }
  //   return copy;
  // }

  // --- UI Components ---

  Widget _buildLabelValue(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: _textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _boxHeaderCard(Map<String, dynamic> b) {
    final network = (b['network'] ?? b['networkCode'])?.toString() ?? '-';
    final boxNo = (b['setupBoxNumber'] ?? b['boxId'])?.toString() ?? '-';
    final price = (_toPaise(b['pricePaise'] ?? b['price'] ?? 0) / 100.0);

    final lco = b['lco'];
    String lcoText = '-';
    if (lco is Map) {
      lcoText = (lco['businessName'] ?? lco['name'])?.toString() ?? '-';
    } else if (b['lcoId'] != null) {
      lcoText = b['lcoId'].toString();
    }

    final lastCutoff =
        b['lastCutoffDate'] ?? b['lastCutoff'] ?? b['activeUntil'];
    final isActive =
        (b['status'] ?? '').toString().toLowerCase() == 'active' ||
        b['isActive'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header Gradient / Status strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.tv, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    boxNo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _greenColor.withOpacity(0.1)
                        : _orangeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 3,
                        backgroundColor: isActive ? _greenColor : _orangeColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isActive ? _greenColor : _orangeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          network,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lcoText,
                          style: TextStyle(fontSize: 13, color: _textGrey),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmtAmount(price),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '/month',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLabelValue("Next Cutoff", _fmtShortDate(lastCutoff)),
                    // _buildLabelValue("Total Paid", _fmtAmount((_toPaise(b['totalPaidPaise'] ?? b['totalPaid'] ?? 0) / 100.0)), alignEnd: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthCard(Map<String, dynamic> m) {
    final paid = m['paid'] == true;
    final amount = (_toPaise(m['amountPaise'] ?? m['amount'] ?? 0) / 100.0);
    final period = m['period'] ?? m['month'] ?? '';
    final paidAt =
        m['paidAtIST'] ?? m['paidAtISO'] ?? m['paidAt'] ?? m['paidAtTs'];
    final receiptUrl = m['receiptUrl']?.toString();

    final statusColor = paid ? _greenColor : _orangeColor;
    final statusIcon = paid ? Icons.check_circle : Icons.warning_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Placeholder for detail view if needed
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Status
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtMonthSafe(period),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paid ? _fmtDateTime(paidAt) : 'Payment pending',
                        style: TextStyle(fontSize: 12, color: _textGrey),
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtAmount(amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    if (paid && receiptUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Receipt >',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildSortControl() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortMode>(
          isExpanded: true,
          icon: Icon(Icons.sort, color: _textGrey),
          value: _sortMode,
          style: TextStyle(
            color: _textDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(
              value: SortMode.recentPaidDesc,
              child: Text('Newest payments first'),
            ),
            DropdownMenuItem(
              value: SortMode.recentPaidAsc,
              child: Text('Oldest payments first'),
            ),
          ],

          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _sortMode = v;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.customer['name'] ?? widget.customer['phone'] ?? 'Customer';
    final visibleBoxes = boxes.where((b) {
      final isOwner = b['customer'] == widget.customer['_id'];
      final isLinkedToMe = b['linkedCustomer'] == widget.customer['_id'];
      final isRemoved = b['wasLinked'] == true;

      return (isOwner || isLinkedToMe) && !isRemoved;
    }).toList();

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.primary,
        foregroundColor: _textDark,
        elevation: 0,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : (error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(error!, style: TextStyle(color: _textGrey)),
                        TextButton(
                          onPressed: _loadHistory,
                          child: const Text("Try Again"),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    color: AppTheme.primary,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          color: Colors.white,
                          child: Text(
                            'Showing transaction history for $title',
                            style: TextStyle(color: _textGrey, fontSize: 13),
                          ),
                        ),

                        _buildSortControl(),

                        if (visibleBoxes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transaction history found',
                                  style: TextStyle(
                                    color: _textGrey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...visibleBoxes.map<Widget>((rawBox) {
                            final Map<String, dynamic> b =
                                Map<String, dynamic>.from(rawBox as Map);
                            final months = (b['months'] is List)
                                ? (b['months'] as List<dynamic>)
                                : <dynamic>[];
                            // final paid = months.where((m) => m is Map && m['paid'] == true).toList();
                            // final unpaid = months.where((m) => !(m is Map && m['paid'] == true)).toList();

                            final paid = List<Map<String, dynamic>>.from(months);

                            if (_sortMode == SortMode.recentPaidDesc) {
                              paid.sort((a, b) =>
                                  (b['paidAtTs'] ?? 0).compareTo(a['paidAtTs'] ?? 0));
                            }

                            if (_sortMode == SortMode.recentPaidAsc) {
                              paid.sort((a, b) =>
                                  (a['paidAtTs'] ?? 0).compareTo(b['paidAtTs'] ?? 0));
                            }


                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _boxHeaderCard(b),

                                // if (unpaid.isNotEmpty) ...[
                                //   _buildSectionTitle('Pending Dues', _orangeColor, Icons.pending_actions),
                                //   ...unpaid.map((m) => _monthCard(Map<String, dynamic>.from(m as Map))).toList(),
                                // ],
                                if (paid.isNotEmpty) ...[
                                  _buildSectionTitle(
                                    'Completed Payments',
                                    _greenColor,
                                    Icons.verified,
                                  ),
                                  ...paid.map((m) => _monthCard(m)).toList(),

                                ],

                                const SizedBox(
                                  height: 24,
                                ), // Spacer between boxes
                              ],
                            );
                          }).toList(),
                      ],
                    ),
                  )),
    );
  }
}
