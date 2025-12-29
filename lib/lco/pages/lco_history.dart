// lib/lco/pages/lco_history.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/lco_service.dart';

class LcoHistoryPage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const LcoHistoryPage({Key? key, required this.lco}) : super(key: key);

  @override
  _LcoHistoryPageState createState() => _LcoHistoryPageState();
}

class _LcoHistoryPageState extends State<LcoHistoryPage> {
  bool loading = true;
  bool customersLoading = false;

  Map<String, dynamic>? financials;
  List<Map<String, dynamic>> networks = [];
  String selectedNetworkId = '';

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  String searchQuery = '';

  final currencyFormat = NumberFormat.decimalPattern();

  /// Selected month for billing (first day of that month)
  DateTime? selectedMonth;
  /// YYYY-MM used for payment period queries
  String? singlePeriod;

  @override
  void initState() {
    super.initState();
    _initDefaults();
    _loadAll();
  }

  void _initDefaults() {
    // Default: current month
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    singlePeriod = _monthToPeriod(selectedMonth!);
  }

  String _monthToPeriod(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  String _currentPeriodLabel() {
    if (selectedMonth == null) return 'All time';
    return DateFormat.yMMM().format(selectedMonth!); // e.g. "Dec 2025"
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
    });

    await _loadFinancials();

    if (networks.isNotEmpty) {
      final firstNet = networks.first;
      selectedNetworkId = (firstNet['lcoId'] ??
          firstNet['networkId'] ??
          firstNet['_id'] ??
          firstNet['id'] ??
          '')
          .toString();
      await _loadCustomersForSelectedNetwork(usePeriod: singlePeriod != null);
    }

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  Future<void> _loadFinancials() async {
    final lcoId = widget.lco['_id'] ?? widget.lco['id'];
    if (lcoId == null) return;

    try {
      final res = await LcoService.getLcoFinancials(lcoId.toString());
      if (res['statusCode'] == 200 && res['data'] != null) {
        final data =
        Map<String, dynamic>.from(res['data'] as Map<String, dynamic>);
        setState(() {
          financials = data;
          final nets = data['networks'] as List<dynamic>? ?? [];
          networks = nets.map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).toList();
        });
      } else {
        setState(() {
          financials = null;
          networks = [];
        });
      }
    } catch (_) {
      setState(() {
        financials = null;
        networks = [];
      });
    }
  }

  String _formatDateLocal(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _loadCustomersForSelectedNetwork({bool usePeriod = false}) async {
    final lcoId = widget.lco['_id'] ?? widget.lco['id'];
    final networkId = (selectedNetworkId).toString();

    if (lcoId == null || networkId.isEmpty) {
      setState(() {
        customers = [];
        filteredCustomers = [];
      });
      return;
    }

    setState(() {
      customersLoading = true;
    });

    try {
      final period = usePeriod ? singlePeriod : null;
      final res = await LcoService.getNetworkCustomers(
        lcoId.toString(),
        networkId.toString(),
        period: period,
      );

      if (!mounted) return;

      if (res['statusCode'] == 200 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list =
        (data['customers'] as List? ?? []).map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();

        setState(() {
          customers = list;
          _applySearchFilter();
        });
      } else {
        setState(() {
          customers = [];
          filteredCustomers = [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        customers = [];
        filteredCustomers = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        customersLoading = false;
      });
    }
  }

  void _applySearchFilter() {
    final q = searchQuery.trim().toLowerCase();

    if (q.isEmpty) {
      filteredCustomers = List<Map<String, dynamic>>.from(customers);
      return;
    }

    filteredCustomers = customers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final boxes = (c['boxes'] as List? ?? [])
          .map((b) => (b['setupBoxNumber'] ?? '').toString().toLowerCase())
          .join(' ');

      return name.contains(q) || phone.contains(q) || boxes.contains(q);
    }).toList();
  }

  void _onSearchChanged(String q) {
    setState(() {
      searchQuery = q;
      _applySearchFilter();
    });
  }

  /// Month+year picker; only year & month matter for backend
  /// Month+year picker; starts on month view (day picker), default = current year/month.
  /// We ignore the day and only use picked.year + picked.month.
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    // allow up to 3 years back, and till end of current year
    final firstDate = DateTime(now.year - 3, 1, 1);
    final lastDate = DateTime(now.year, 12, 31);

    // if user already picked a month, reuse that; otherwise current month
    final initialDate = selectedMonth ?? DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      // start directly in the default (day/month) view – user can change year from header if needed
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppTheme.primary,
              onPrimary: AppTheme.onPrimary,
              surface: AppTheme.surface,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      // normalize: only keep month + year, drop the day
      final normalized = DateTime(picked.year, picked.month, 1);
      setState(() {
        selectedMonth = normalized;
        singlePeriod = _monthToPeriod(normalized); // e.g. "2025-12"
      });
      await _loadCustomersForSelectedNetwork(usePeriod: true);
    }
  }


  Future<void> _refreshCustomers() async {
    await _loadFinancials();
    await _loadCustomersForSelectedNetwork(usePeriod: singlePeriod != null);
  }

  String _amountDisplay(dynamic v) {
    if (v == null) return '-';
    try {
      final numVal = (v is num) ? v : num.parse(v.toString());
      return currencyFormat.format(numVal);
    } catch (_) {
      return v.toString();
    }
  }

  Widget _buildHeader() {
    final overall = financials?['overall'] ?? {};
    final totalCust = (overall['totalCustomers'] ?? 0) as int;
    final paidCust = (overall['paidCustomers'] ?? 0) as int;
    final notPaidCust = (overall['notPaidCustomers'] ?? 0) as int;

    final totalAmt = (overall['totalAmountRupees'] ?? 0) as num;
    final paidAmt = (overall['paidAmountRupees'] ?? 0) as num;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title + icon
            Row(
              children: [
                const Icon(Icons.insights, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Billing overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // counts
            Row(
              children: [
                _smallMetric(
                  icon: Icons.people_alt,
                  label: 'Customers',
                  value: '$totalCust',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _smallMetric(
                  icon: Icons.check_circle,
                  label: 'Paid',
                  value: '$paidCust',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _smallMetric(
                  icon: Icons.error_outline,
                  label: 'Unpaid',
                  value: '$notPaidCust',
                  color: Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // amounts
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Customer Payable',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${currencyFormat.format(totalAmt)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_downward,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Paid ₹${currencyFormat.format(paidAmt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward,
                            size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Not paid ₹${currencyFormat.format(totalAmt - paidAmt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider.withOpacity(0.9)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkAndRangeRow(String periodLabel) {
    if (networks.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider.withOpacity(0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.router, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text(
                'Network & month',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range,
                          size: 14, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Text(
                        periodLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value:
                  selectedNetworkId.isNotEmpty ? selectedNetworkId : null,
                  decoration: const InputDecoration(
                    labelText: 'Network',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  hint: const Text(
                    'Select network',
                    style: TextStyle(fontSize: 13),
                  ),
                  items: networks.map((n) {
                    final lcoId = (n['lcoId'] ??
                        n['networkId'] ??
                        n['_id'] ??
                        n['id'] ??
                        '')
                        .toString();
                    final name = (n['networkName'] ?? lcoId).toString();
                    final fixed = n['fixedPrice'];
                    final subtitle = fixed != null
                        ? '₹${currencyFormat.format(fixed)}'
                        : '';
                    return DropdownMenuItem<String>(
                      value: lcoId,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ]
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      selectedNetworkId = val ?? '';
                    });
                    await _loadCustomersForSelectedNetwork(
                        usePeriod: singlePeriod != null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, size: 20),
                color: AppTheme.primary,
                onPressed: () => _refreshCustomers(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search by name, phone or box number',
      ),
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildCustomerTile(Map<String, dynamic> c) {
    final isPaid = c['isPaid'] == true;
    final amountDue = c['amountDue'];

    final boxes =
    (c['boxes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    String initials = '';
    final name = (c['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      initials =
      parts.length == 1 ? parts.first[0] : (parts[0][0] + parts[1][0]);
      initials = initials.toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider.withOpacity(0.9)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: isPaid
                ? Colors.green.withOpacity(0.15)
                : Colors.redAccent.withOpacity(0.15),
            child: Text(
              initials.isNotEmpty ? initials : 'C',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPaid ? Colors.green : Colors.redAccent,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name.isNotEmpty ? name : '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.withOpacity(0.12)
                      : Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'NOT PAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? Colors.green : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.phone, size: 14, color: AppTheme.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  (c['phone'] ?? '-').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (boxes.isNotEmpty) ...[
                  const Text(
                    'Boxes & last cutoff',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: boxes.map((b) {
                      final lastCut = b['lastCutoffDate'];
                      final cutoffText = lastCut != null
                          ? DateFormat.yMMMd().format(
                        DateTime.tryParse(lastCut.toString())
                            ?.toLocal() ??
                            DateTime.now(),
                      )
                          : '—';
                      final boxNumber =
                      (b['setupBoxNumber'] ?? '-').toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tv,
                                size: 14, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              boxNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cutoffText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount due',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                    Text(
                      amountDue == null
                          ? '-'
                          : '₹${_amountDisplay(amountDue)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                if (singlePeriod != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Payments for selected month',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...boxes.map((b) {
                    final payments = (b['payments'] as List? ?? []);
                    final boxNo = (b['setupBoxNumber'] ?? '-').toString();

                    if (payments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '$boxNo: no payment',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: payments.map<Widget>((p) {
                        final amtPaise = p['amount'] ?? 0;
                        final rupees = (amtPaise is num)
                            ? (amtPaise / 100)
                            : (double.tryParse(amtPaise.toString()) ?? 0) /
                            100;
                        final paidAt = p['paidAt'] != null
                            ? _formatDateLocal(p['paidAt'].toString())
                            : '-';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$boxNo — ${p['providerPaymentId'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${rupees.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    paidAt,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
    (widget.lco['businessName'] ?? widget.lco['name'] ?? 'LCO')
        .toString()
        .trim();
    final periodLabel = _currentPeriodLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text('$title — History'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCustomers,
        color: AppTheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              _buildHeader(),
              _buildNetworkAndRangeRow(periodLabel),
              const SizedBox(height: 8),
              _buildSearchField(),
              const SizedBox(height: 10),
              Expanded(
                child: customersLoading
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : filteredCustomers.isEmpty
                    ? const Center(
                  child: Text(
                    'No customers found for this selection',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.muted,
                    ),
                  ),
                )
                    : ListView.separated(
                  itemCount: filteredCustomers.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _buildCustomerTile(
                          filteredCustomers[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
