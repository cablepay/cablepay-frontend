// lib/lco/pages/lco_home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_config.dart';
import '../../core/local_storage.dart';
import '../../routes.dart';
import '../../services/lco_service.dart';
import '../../core/app_theme.dart';
import 'lco_history.dart';
import 'lco_network_detail.dart';
import 'lco_networks.dart';
import '../../lco/widgets/lco_side_menu.dart';
import '../../lco/widgets/lco_bottom_navigation.dart';

class LcoHomePage extends StatefulWidget {
  final Map<String, dynamic> lco;
  const LcoHomePage({Key? key, required this.lco}) : super(key: key);

  @override
  _LcoHomePageState createState() => _LcoHomePageState();
}

class _LcoHomePageState extends State<LcoHomePage> {
  Map<String, dynamic>? lcoDetails;
  Map<String, dynamic>? stats; // holds the /stats response
  Map<String, dynamic>? financials; // holds /finance response
  bool loading = true;
  bool statsLoading = true;
  bool financeLoading = true;

  final Map<int, bool> _selected = {};
  final currencyFormat = NumberFormat.decimalPattern();
  DateTime? _overviewMonth; // null => current month

  String get _overviewMonthLabel {
    final dt = _overviewMonth ?? DateTime.now();
    return DateFormat.yMMM().format(dt); // e.g. "Dec 2025"
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String? _resolvePeriodForApi() {
    if (_overviewMonth == null) return null;

    final now = DateTime.now();
    final isCurrentMonth =
        _overviewMonth!.year == now.year &&
            _overviewMonth!.month == now.month;

    return isCurrentMonth ? null : _overviewPeriodKey;
  }


  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      statsLoading = true;
      financeLoading = true;
    });

    // If user has picked a month, always use that period.
    // Otherwise let backend use current month by passing null.
    final String? period = _resolvePeriodForApi();

    await Future.wait([
      _loadLco(),
      _loadStats(period: period),
      _loadFinancials(period: period),
    ]);

    if (!mounted) return;
    setState(() {
      loading = false;
      statsLoading = false;
      financeLoading = false;
    });
  }

  Future<void> _loadLco() async {
    final id = widget.lco['_id'] ?? widget.lco['id'];
    if (id == null) {
      setState(() {
        lcoDetails = Map<String, dynamic>.from(widget.lco);
      });
      _initSelectionFromDetails();
      return;
    }

    try {
      final res = await LcoService.getLco(id.toString());
      if (res['statusCode'] == 200 && res['data'] != null) {
        setState(() {
          lcoDetails = Map<String, dynamic>.from(
            res['data'] as Map<String, dynamic>,
          );
        });
      } else {
        setState(() {
          lcoDetails = Map<String, dynamic>.from(widget.lco);
        });
      }
    } catch (_) {
      setState(() {
        lcoDetails = Map<String, dynamic>.from(widget.lco);
      });
    } finally {
      _initSelectionFromDetails();
    }
  }

  Future<void> _loadStats({String? period}) async {
    setState(() => statsLoading = true);
    final lcoId = widget.lco['_id'] ?? widget.lco['id'];
    if (lcoId == null) {
      setState(() {
        stats = null;
        statsLoading = false;
      });
      return;
    }

    try {
      final res = await LcoService.getLcoStats(
        lcoId.toString(),
        period: period,
      );
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['data'] != null) {
        setState(() {
          stats = Map<String, dynamic>.from(
            res['data'] as Map<String, dynamic>,
          );
        });
      } else {
        setState(() => stats = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => stats = null);
    } finally {
      if (!mounted) return;
      setState(() => statsLoading = false);
    }
  }

  Future<void> _loadFinancials({String? period}) async {
    setState(() => financeLoading = true);
    final lcoId = widget.lco['_id'] ?? widget.lco['id'];
    if (lcoId == null) {
      setState(() {
        financials = null;
        financeLoading = false;
      });
      return;
    }

    try {
      final res = await LcoService.getLcoFinancials(
        lcoId.toString(),
        period: period, // <-- pass period to service (query ?period=)
      );
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['data'] != null) {
        setState(() {
          financials = Map<String, dynamic>.from(
            res['data'] as Map<String, dynamic>,
          );
        });
      } else {
        setState(() => financials = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => financials = null);
    } finally {
      if (!mounted) return;
      setState(() => financeLoading = false);
    }
  }

  /// Month+year picker for the Overview card.
  /// Defaults to current month; user can change year from the header.
  Future<void> _pickOverviewMonth() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 3, 1, 1);
    final lastDate = DateTime(now.year, 12, 31);

    final initialDate = _overviewMonth ?? DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: DateTime(initialDate.year, initialDate.month, 1),

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
      // normalize: only year+month
      final normalized = DateTime(picked.year, picked.month, 1);

      setState(() {
        _overviewMonth = normalized;
      });

      // 🔥 SINGLE source of truth for period
      await _loadAll();
    }
  }

  void _initSelectionFromDetails() {
    _selected.clear();
    final networks = _getNetworks();
    for (var i = 0; i < networks.length; i++) {
      _selected[i] = _selected[i] ?? false;
    }
  }

  List<Map<String, dynamic>> _getNetworks() {
    final raw = lcoDetails == null ? [] : (lcoDetails!['networks'] ?? []);
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          })
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, Map<String, int>> _getNetworkMetricsFromStats() {
    final out = <String, Map<String, int>>{};
    if (stats == null) return out;
    final netArr = stats!['networks'];
    if (netArr is List) {
      for (final e in netArr) {
        if (e is Map) {
          final lcoId =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          final total = (e['totalCustomers'] is int)
              ? e['totalCustomers'] as int
              : (e['totalCustomers'] is num
                    ? (e['totalCustomers'] as num).toInt()
                    : 0);
          final paid = (e['paidCustomers'] is int)
              ? e['paidCustomers'] as int
              : (e['paidCustomers'] is num
                    ? (e['paidCustomers'] as num).toInt()
                    : 0);
          final notPaid = (e['notPaidCustomers'] is int)
              ? e['notPaidCustomers'] as int
              : (e['notPaidCustomers'] is num
                    ? (e['notPaidCustomers'] as num).toInt()
                    : (total - paid));
          out[lcoId] = {'total': total, 'paid': paid, 'notPaid': notPaid};
        }
      }
    }
    final unknown = stats!['unknown'];
    if (unknown is List) {
      for (final e in unknown) {
        if (e is Map) {
          final lcoId =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          final total = (e['totalCustomers'] is int)
              ? e['totalCustomers'] as int
              : (e['totalCustomers'] is num
                    ? (e['totalCustomers'] as num).toInt()
                    : 0);
          final paid = (e['paidCustomers'] is int)
              ? e['paidCustomers'] as int
              : (e['paidCustomers'] is num
                    ? (e['paidCustomers'] as num).toInt()
                    : 0);
          final notPaid = (e['notPaidCustomers'] is int)
              ? e['notPaidCustomers'] as int
              : (e['notPaidCustomers'] is num
                    ? (e['notPaidCustomers'] as num).toInt()
                    : (total - paid));
          out[lcoId] = {'total': total, 'paid': paid, 'notPaid': notPaid};
        }
      }
    }
    return out;
  }

  Map<String, Map<String, dynamic>> _getNetworkFinancialMap() {
    final out = <String, Map<String, dynamic>>{};
    if (financials == null) return out;
    final netArr = financials!['networks'];
    if (netArr is List) {
      for (final e in netArr) {
        if (e is Map) {
          final lcoId =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          out[lcoId] = Map<String, dynamic>.from(e);
        }
      }
    }
    final unknown = financials!['unknown'];
    if (unknown is List) {
      for (final e in unknown) {
        if (e is Map) {
          final lcoId =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          out[lcoId] = Map<String, dynamic>.from(e);
        }
      }
    }
    return out;
  }

  int get _selectedCount => _selected.values.where((v) => v).length;

  void _toggleSelection(int index, bool? value) {
    setState(() {
      _selected[index] = value == true;
    });
  }

  void _logout() async {
    try {
      // attempt server-side logout (best-effort)
      try {
        await ApiConfig.post('/api/auth/logout', {});
      } catch (_) {}

      // clear client-side session + profile
      await LocalStorage.clearSession();
      await LocalStorage.clearLco();

      // clear runtime header token
      ApiConfig.setSessionKey(null);

      // navigate to login (use AppRoutes constant)
      Navigator.pushReplacementNamed(context, AppRoutes.lcoLogin);
    } catch (e) {
      Navigator.pushReplacementNamed(context, AppRoutes.lcoLogin);
    }
  }

  void _navigateToManageNetworks() async {
    final current = lcoDetails ?? widget.lco;
    final updated = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => LcoNetworksPage(lco: current)),
    );

    final period = _resolvePeriodForApi();

    if (updated != null) {
      setState(() {
        lcoDetails = updated;
        _initSelectionFromDetails();
      });
      await LocalStorage.saveLco(updated);

      await Future.wait([
        _loadStats(period: period),
        _loadFinancials(period: period),
      ]);
    } else {
      // Even if nothing changed, reload WITH PERIOD
      await Future.wait([
        _loadStats(period: period),
        _loadFinancials(period: period),
      ]);
    }
  }


  void _showSelectedNetworksDialog() {
    final networks = _getNetworks();
    final chosen = <Map<String, dynamic>>[];
    _selected.forEach((idx, sel) {
      if (sel && idx >= 0 && idx < networks.length) chosen.add(networks[idx]);
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selected networks ($_selectedCount)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: chosen.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final n = chosen[i];
              return ListTile(
                title: Text(n['networkName'] ?? '-'),
                subtitle: Text(_networkId(n) ?? '-'),
                trailing: n['fixedPrice'] != null
                    ? Text('₹${currencyFormat.format(n['fixedPrice'])}')
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // helper: normalize network id from a network object (supports multiple possible backend field names)
  String _networkId(Map<String, dynamic> n) {
    return (n['lcoId'] ?? n['networkId'] ?? n['_id'] ?? n['id'] ?? '')
        .toString();
  }

  // Helper: period key for current overview month (YYYY-MM)
  String get _overviewPeriodKey {
    final dt = _overviewMonth ?? DateTime.now();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Widget _buildHeaderCard(double maxWidth) {
    // ---------- 1. Base overall data (amounts, fallback counts) ----------
    final overallDyn = financials?['overall'];
    final Map<String, dynamic> overall = (overallDyn is Map)
        ? Map<String, dynamic>.from(overallDyn as Map)
        : <String, dynamic>{};

    // amounts always come from overall for now
    final periodFin = _currentPeriodFinancials();

    // final num totalAmt = _num(
    //     financials?['overall']?['totalAmountRupees']
    // );
    final num totalAmt =
    _num(stats?['financials']?['totalAmountRupees']);



    final num paidAmt = _num(
        periodFin['incomeRupees'] ??
            financials?['overall']?['paidAmountRupees']
    );

    final num notPaidAmt = _num(
        periodFin['remainingRupees'] ??
            financials?['overall']?['notPaidAmountRupees']
    );


    // ---------- 2. Per-period customer summary ----------
    final periodKey = _overviewPeriodKey;

    final csRaw = financials?['customerSummaryByPeriod'];
    Map<String, dynamic> periodSummary = <String, dynamic>{};

    if (csRaw is Map) {
      // normalize outer map: key -> dynamic
      final Map<String, dynamic> csMap = {};
      csRaw.forEach((k, v) {
        csMap[k.toString()] = v;
      });

      final entry = csMap[periodKey];
      if (entry is Map) {
        periodSummary = Map<String, dynamic>.from(entry as Map);
      }
    }


    // ---------- 3. Overall stats (new / referred) ----------


    // // NEW / REFERRED must be period-aware
    // int newCust = 0;
    // int referredCust = 0;
    //
    // final periodStatsArr = stats?['networks'];
    // if (periodStatsArr is List) {
    //   for (final e in periodStatsArr) {
    //     if (e is Map) {
    //       newCust += _int(e['newCustomers']);
    //       referredCust += _int(e['referredCustomers']);
    //     }
    //   }
    // }



    // final overallStatsDyn = stats?['overall'];
    // final Map<String, dynamic> overallStats = (overallStatsDyn is Map)
    //     ? Map<String, dynamic>.from(overallStatsDyn as Map)
    //     : <String, dynamic>{};

    // Always normalize numbers BEFORE math
    // final int totalCust = _int(
    //   periodSummary['totalCustomers'] ?? overall['totalCustomers'],
    // );
    //
    // final int paidCust = _int(
    //   periodSummary['paidCustomers'] ?? overall['paidCustomers'],
    // );
    //
    // final int notPaidCust = _int(
    //   periodSummary['notPaidCustomers'] ??
    //       (totalCust - paidCust >= 0 ? totalCust - paidCust : 0),
    // );

    final overallStats = stats?['overall'] as Map<String, dynamic>? ?? {};

    final int totalCust = _int(overallStats['totalCustomers']);
    final int paidCust  = _int(overallStats['paidCustomers']);
    final int notPaidCust = totalCust - paidCust;


    final int newCust = _int(overallStats['newCustomers']);
    final int referredCust = _int(overallStats['referredCustomers']);


    // final int newCust = _int(overallStats['newCustomers']);
    // final int referredCust = _int(overallStats['referredCustomers']);

    // final int newCust = (overallStats['newCustomers'] ?? 0) is num
    //     ? (overallStats['newCustomers'] ?? 0) as int
    //     : int.tryParse(overallStats['newCustomers']?.toString() ?? '0') ?? 0;
    // final int referredCust =
    // (overallStats['referredCustomers'] ?? 0) is num
    //     ? (overallStats['referredCustomers'] ?? 0) as int
    //     : int.tryParse(
    //     overallStats['referredCustomers']?.toString() ?? '0') ??
    //     0;

    // ---------- 4. Layout helpers ----------
    final bool isVeryCompact = maxWidth < 360;

    Widget statBox({
      required String label,
      required String value,
      required Color color,
      required IconData icon,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isVeryCompact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Row (Overview + month pill) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Summary for $_overviewMonthLabel',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _pickOverviewMonth,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.divider.withOpacity(0.9),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.date_range,
                            size: 14,
                            color: AppTheme.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _overviewMonthLabel,
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

              const SizedBox(height: 16),

              // --- Row 1: Customers ---
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    statBox(
                      label: 'Customers',
                      value: '$totalCust',
                      color: AppTheme.primary,
                      icon: Icons.group,
                    ),
                    const SizedBox(width: 8),
                    statBox(
                      label: 'Paid',
                      value: '$paidCust',
                      color: Colors.green,
                      icon: Icons.check_circle,
                    ),
                    const SizedBox(width: 8),
                    statBox(
                      label: 'Not Paid',
                      value: '$notPaidCust',
                      color: Colors.redAccent,
                      icon: Icons.error_outline,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // --- Row 2: Stats (new + referred) ---
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    statBox(
                      label: 'New',
                      value: '$newCust',
                      color: Colors.blueAccent,
                      icon: Icons.fiber_new,
                    ),
                    const SizedBox(width: 8),
                    statBox(
                      label: 'Referred',
                      value: '$referredCust',
                      color: Colors.purple,
                      icon: Icons.person_add_alt_1,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),

              // --- Bottom: Financials ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Customer Payable',
                          style: TextStyle(fontSize: 11, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${currencyFormat.format(totalAmt)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMiniAmountRow('Paid', paidAmt, Colors.green),
                        const SizedBox(height: 4),
                        _buildMiniAmountRow(
                          'Not Paid',
                          notPaidAmt,
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for the bottom right amounts to prevent repetition
  Widget _buildMiniAmountRow(String label, num amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${currencyFormat.format(amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworksList(double maxWidth) {
    final networks = _getNetworks();
    final metrics = _getNetworkMetricsFromStats();
    final finMap = _getNetworkFinancialMap();

    if (statsLoading || financeLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (networks.isEmpty) {
      return DecoratedCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No networks configured',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap "Manage" to add up to 5 networks.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _SmallGradientButton(
                  enabled: true,
                  icon: Icons.add,
                  label: 'Add network',
                  onPressed: _navigateToManageNetworks,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      // grid layout for wide screens
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(networks.length, (i) {
          final n = networks[i];
          return _buildNetworkCard(n, i, metrics, finMap, maxWidth / 2 - 12);
        }),
      );
    }

    // list layout for mobile
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Networks (${networks.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            _SmallGradientButton(
              enabled: true,
              icon: Icons.edit,
              label: 'Manage',
              onPressed: _navigateToManageNetworks,
            ),
          ],
        ),

        const SizedBox(height: 8),

        ...List.generate(networks.length, (i) {
          final n = networks[i];
          return _buildNetworkCard(n, i, metrics, finMap, maxWidth);
        }),
      ],
    );
  }

  Widget _buildNetworkCard(
    Map<String, dynamic> n,
    int i,
    Map<String, Map<String, int>> metrics,
    Map<String, Map<String, dynamic>> finMap,
    double maxWidth,
  ) {
    // selection logic kept in memory, but no checkbox in UI anymore
    final nid = _networkId(n);

    final counts = metrics[nid] ?? {'total': 0, 'paid': 0, 'notPaid': 0};
    final total = counts['total'] ?? 0;
    final paid = counts['paid'] ?? 0;
    final notPaid = counts['notPaid'] ?? 0;
    final pctPaid = total > 0 ? (paid / total) : 0.0;

    final fin = finMap[nid] ?? {};
    final totalAmt = _num(fin['totalAmountRupees']);
    final paidAmt = _num(fin['paidAmountRupees']);

    final bool isCompact = maxWidth < 380;
    final name = (n['networkName'] ?? '-').toString();
    final avatarInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget badge(String label, {Color? color, Color? bg}) {
      final c = color ?? AppTheme.muted;
      final b = bg ?? c.withOpacity(0.1);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: b,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500),
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final lcoRefId = widget.lco['_id'] ?? widget.lco['id'];
        final networkId = _networkId(n);
        if (networkId.isEmpty || lcoRefId == null) return;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NetworkDetailPage(
              lcoId: lcoRefId.toString(),
              network: Map<String, dynamic>.from(n),
              period: _resolvePeriodForApi(),
            ),
          ),
        );
        if (result == true) {
          final period = _resolvePeriodForApi();
          await Future.wait([
            _loadStats(period: period),
            _loadFinancials(period: period),
          ]);
        }
      },
      child: DecoratedCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + name + id + chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryLight.withOpacity(0.18),
                    child: Text(
                      avatarInitial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              nid.isNotEmpty ? nid : '-',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (total > 0)
                              badge(
                                '$paid / $total paid',
                                color: Colors.green.shade700,
                                bg: Colors.green.withOpacity(0.08),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.muted,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Progress + percentage
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pctPaid,
                        minHeight: 7,
                        backgroundColor: AppTheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(pctPaid * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Counts row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, size: 14, color: AppTheme.muted),
                      const SizedBox(width: 4),
                      Text(
                        'Total: $total',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Paid: $paid',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Unpaid: $notPaid',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Amounts row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total billed',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${currencyFormat.format(totalAmt)}',
                        style: TextStyle(
                          fontSize: isCompact ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Paid amount',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${currencyFormat.format(paidAmt)}',
                        style: TextStyle(
                          fontSize: isCompact ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (n['website'] != null && (n['website'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.language,
                        size: 14,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Website: ${n['website']}',
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getNetworkFinancialTotals(String lcoId) {
    if (financials == null) return {};
    final nets = financials!['networks'];
    if (nets is List) {
      for (final e in nets) {
        if (e is Map) {
          final key =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          if (key == lcoId) return Map<String, dynamic>.from(e);
        }
      }
    }
    final unknown = financials!['unknown'];
    if (unknown is List) {
      for (final e in unknown) {
        if (e is Map) {
          final key =
              (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
                  .toString();
          if (key == lcoId) return Map<String, dynamic>.from(e);
        }
      }
    }
    return {};
  }

  /// Try keys in candidateKeys. Paise keys converted -> rupees. Returns rupees.
  double _numFromFinancials(
    Map<String, dynamic>? src,
    List<String> candidateKeys,
  ) {
    if (src == null) return 0.0;

    // helper: returns nullable double; null => not found, otherwise rupees value (can be 0.0)
    double? tryMap(Map<String, dynamic> m, List<String> keysToTry) {
      for (final k in keysToTry) {
        if (!m.containsKey(k)) continue;
        final v = m[k];
        if (v == null) return 0.0; // key present but null -> treat as zero
        // if key name suggests paise, convert -> rupees
        if (k.toLowerCase().contains('paise')) {
          final n = (v is num)
              ? v.toDouble()
              : double.tryParse(v.toString()) ?? 0.0;
          return n / 100.0;
        }
        // otherwise treat as rupees
        final n = (v is num)
            ? v.toDouble()
            : double.tryParse(v.toString()) ?? 0.0;
        return n;
      }
      return null;
    }

    // 1) direct check at root
    final direct = tryMap(src, candidateKeys);
    if (direct != null) return direct;

    // 2) check top-level 'overall' object if present
    if (src['overall'] is Map) {
      final overallVal = tryMap(
        (src['overall'] as Map).cast<String, dynamic>(),
        candidateKeys,
      );
      if (overallVal != null) return overallVal;
    }

    // 3) check 'periods' object (values may be period->summary maps)
    if (src['periods'] is Map) {
      final periods = (src['periods'] as Map).cast<String, dynamic>();
      for (final periodKey in periods.keys) {
        final p = periods[periodKey];
        if (p is Map) {
          final v = tryMap(p.cast<String, dynamic>(), candidateKeys);
          if (v != null) return v;
        }
      }
    }

    // 4) check top-level 'networks' array entries (each network may include paid/fee fields)
    if (src['networks'] is List) {
      final nets = (src['networks'] as List).cast<dynamic>();
      for (final n in nets) {
        if (n is Map) {
          final v = tryMap(n.cast<String, dynamic>(), candidateKeys);
          if (v != null) return v;
        }
      }
    }

    // 5) shallow scan: look for matching keys anywhere one level deep (best-effort)
    for (final k in src.keys) {
      final val = src[k];
      if (val == null) continue;
      if (val is Map) {
        final v = tryMap(val.cast<String, dynamic>(), candidateKeys);
        if (v != null) return v;
      } else if (val is List) {
        for (final item in val) {
          if (item is Map) {
            final v = tryMap(item.cast<String, dynamic>(), candidateKeys);
            if (v != null) return v;
          }
        }
      }
    }

    // fallback: not found
    return 0.0;
  }

  double _computeNetworkFeeFromLcoAndFinancials() {
    if (lcoDetails == null || financials == null) return 0.0;

    final List ldNetsRaw = (lcoDetails!['networks'] ?? []) as List;
    final List finNetsRaw = (financials!['networks'] ?? []) as List;

    // Build a map: lcoId -> fin entry
    final Map<String, Map<String, dynamic>> finById = {};
    for (final e in finNetsRaw) {
      if (e is Map) {
        final id = (e['lcoId'] ?? e['networkId'] ?? e['_id'] ?? e['id'] ?? '')
            .toString();
        if (id.isNotEmpty) finById[id] = Map<String, dynamic>.from(e);
      }
    }

    double totalNetworkFeeRupees = 0.0;

    for (final n in ldNetsRaw) {
      if (n is! Map) continue;
      final nm = Map<String, dynamic>.from(n);
      final nid = (nm['lcoId'] ?? nm['networkCode'] ?? nm['rawLcoId'] ?? '')
          .toString();
      if (nid.isEmpty) continue;

      final fin = finById[nid] ?? {};
      // paid customers
      final paidCustomers = (fin['paidCustomers'] is int)
          ? fin['paidCustomers'] as int
          : (fin['paidCustomers'] is num
                ? (fin['paidCustomers'] as num).toInt()
                : 0);

      // paid amount (rupees) for percent-based fee
      final paidAmountRupees = _numFromFinancials(fin.cast<String, dynamic>(), [
        'paidAmountPaise',
        'paidAmountRupees',
        'paidAmount',
      ]);

      // If explicit settlementFeePaise provided on network (preferred)
      if (nm['settlementFeePaise'] != null) {
        final feePerPaise = (nm['settlementFeePaise'] is num)
            ? (nm['settlementFeePaise'] as num).toDouble()
            : double.tryParse(nm['settlementFeePaise'].toString()) ?? 0.0;
        final feePerRupees = feePerPaise / 100.0;
        totalNetworkFeeRupees += feePerRupees * paidCustomers;
      } else if (nm['settlementSharePercent'] != null) {
        final pct = (nm['settlementSharePercent'] is num)
            ? (nm['settlementSharePercent'] as num).toDouble()
            : double.tryParse(nm['settlementSharePercent'].toString()) ?? 0.0;
        totalNetworkFeeRupees += (paidAmountRupees * pct / 100.0);
      } else {
        // fallback: if network has fixedPrice but no settlement fee, treat as 0 (admin must set settlement fee)
      }
    }

    // clamp small negatives
    if (totalNetworkFeeRupees.isNegative && totalNetworkFeeRupees > -0.01)
      totalNetworkFeeRupees = 0.0;
    return totalNetworkFeeRupees;
  }

  Map<String, dynamic> _currentPeriodFinancials() {
    final fin = financials;
    if (fin == null) return {};

    final periods = fin['periods'];
    if (periods is! Map) return {};

    // ALWAYS try selected month first
    if (_overviewPeriodKey.isNotEmpty && periods[_overviewPeriodKey] is Map) {
      return Map<String, dynamic>.from(periods[_overviewPeriodKey]);
    }

    // If user explicitly selected a month → DO NOT fallback
    if (_overviewMonth != null) {
      return {};
    }

    // Otherwise fallback to latest available period
    final keys =
        periods.keys
            .map((e) => e.toString())
            .where((e) => RegExp(r'^\d{4}-\d{2}$').hasMatch(e))
            .toList()
          ..sort();

    if (keys.isNotEmpty) {
      final latest = keys.last;
      final p = periods[latest];
      if (p is Map) return Map<String, dynamic>.from(p);
    }

    return {};
  }

  Map<String, double> _calculateSettlementNumbers() {
    final periodFin = _currentPeriodFinancials();

    final totalReceived = _numFromFinancials(periodFin, [
      'incomePaise',
      'incomeRupees',
    ]);

    final platformCommission = _numFromFinancials(periodFin, [
      'platformCommissionPaise',
      'platformCommissionRupees',
    ]);

    final referralPayout = _numFromFinancials(periodFin, [
      'referralPayoutPaise',
      'referralPayoutRupees',
    ]);

    final networkFee = _numFromFinancials(periodFin, [
      'networkFeePaise',
      'networkFeeRupees',
    ]);

    final settlement = _numFromFinancials(periodFin, [
      'settlementPaise',
      'settlementRupees',
    ]);

    final paidSoFar = _numFromFinancials(periodFin, [
      'paidSoFarPaise',
      'paidSoFarRupees',
    ]);

    final remaining = _numFromFinancials(periodFin, [
      'remainingPaise',
      'remainingRupees',
    ]);

    return {
      'totalReceived': totalReceived,
      'platformCommission': platformCommission,
      'referralPayout': referralPayout,
      'networkFee': networkFee,

      // payout fields
      'settlement': settlement,
      'paidSoFar': paidSoFar,
      'remaining': remaining,
    };
  }

  Widget _buildNetworkFeeCard(double maxWidth) {
    final networks = _getNetworks();
    final settlementData = _calculateSettlementNumbers();
    final double networkFee = settlementData['networkFee'] ?? 0.0;

    // If there are no networks and no fee, don't render anything
    if (networks.isEmpty && networkFee <= 0) {
      return const SizedBox.shrink();
    }

    // Limit to first 5 networks
    final displayNetworks = networks.take(5).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───────── LEFT COLUMN: Info + Auto-wrapping Chips ─────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hub_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Network fee',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Description
                      const Text(
                        'Fee payable to your TV networks for active paid boxes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Chips: Changed to WRAP to fix the overflow error
                      if (displayNetworks.isEmpty)
                        const Text(
                          'No networks configured.',
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: displayNetworks.map((n) {
                            final name =
                                (n['networkName'] ?? n['name'] ?? 'Network')
                                    .toString();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(
                                  30,
                                ), // Pill shape
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tv_rounded,
                                    size: 14,
                                    color: AppTheme.text.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Vertical Divider
                Container(width: 1, color: Colors.grey.withOpacity(0.1)),
                const SizedBox(width: 16),

                // ───────── RIGHT COLUMN: Professional Amount Display ─────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Network fee',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Total payable',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${currencyFormat.format(networkFee)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text,
                        letterSpacing: -0.5,
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

  Widget _buildSettlementCard(double maxWidth) {
    final data = _calculateSettlementNumbers();
    final totalReceived = data['totalReceived'] ?? 0.0;
    final platformCommission = data['platformCommission'] ?? 0.0;
    final referralPayout = data['referralPayout'] ?? 0.0;
    final networkFee = data['networkFee'] ?? 0.0;
    final settlement = data['settlement'] ?? 0.0;

    final paidSoFar = data['paidSoFar'] ?? 0.0;
    final remaining = data['remaining'] ?? 0.0;

    final bool isCompact = maxWidth < 380;

    Widget rowLabelValue(
      String label,
      String value, {
      Color? valueColor,
      bool emphasize = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: emphasize ? (isCompact ? 14 : 15) : 13,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? AppTheme.text,
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settlement summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'This month\'s payout breakdown',
                          style: TextStyle(fontSize: 11, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.divider.withOpacity(0.9),
                      ),
                    ),
                    // child: const Text(
                    //   'Platform: 10%',
                    //   style: TextStyle(
                    //     fontSize: 11,
                    //     color: AppTheme.muted,
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Breakdown rows
              rowLabelValue(
                'Total received (paid customers)',
                '₹${currencyFormat.format(totalReceived)}',
              ),
              const SizedBox(height: 4),
              rowLabelValue(
                'Platform service fees ',
                '₹${currencyFormat.format(platformCommission)}',
                valueColor: Colors.orange.shade700,
              ),
              const SizedBox(height: 4),
              rowLabelValue(
                'Referral payouts',
                '₹${currencyFormat.format(referralPayout)}',
                valueColor: Colors.purple,
              ),
              const SizedBox(height: 4),
              rowLabelValue(
                'Network fees',
                '₹${currencyFormat.format(networkFee)}',
                valueColor: Colors.blueGrey,
              ),

              const SizedBox(height: 10),
              const Divider(height: 20),

              // Highlighted settlement row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.25),
                    width: 0.8,
                  ),
                ),
                child: rowLabelValue(
                  'Settlement payable to LCO',
                  '₹${currencyFormat.format(settlement)}',
                  valueColor: Colors.green.shade700,
                  emphasize: true,
                ),
              ),

              const SizedBox(height: 8),

              // const SizedBox(height: 6),
              rowLabelValue(
                'Paid so far',
                '₹${currencyFormat.format(paidSoFar)}',
                valueColor: Colors.green.shade600,
              ),

              const SizedBox(height: 4),

              rowLabelValue(
                'Balance payable',
                '₹${currencyFormat.format(remaining)}',
                valueColor: remaining > 0 ? Colors.redAccent : Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleName = (widget.lco['businessName'] ?? widget.lco['name'] ?? '')
        .toString()
        .trim();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final maxContentWidth = isWide ? 900.0 : double.infinity;

    // Prefer the name from details if already loaded
    final displayName = (lcoDetails?['name'] ?? widget.lco['name'] ?? '')
        .toString()
        .trim();
    final avatarInitial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (titleName.isNotEmpty ? titleName[0].toUpperCase() : '-');

    // Optional chips (district / pincode) if present
    final district = (lcoDetails?['district'] ?? widget.lco['district'] ?? '')
        .toString()
        .trim();
    final pincode = (lcoDetails?['pincode'] ?? widget.lco['pincode'] ?? '')
        .toString()
        .trim();

    final phonesRaw = lcoDetails?['phones'] ?? widget.lco['phones'];
    final phoneText = (() {
      if (phonesRaw is List) {
        return phonesRaw
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .join(', ');
      }
      if (phonesRaw is String && phonesRaw.trim().isNotEmpty) {
        return phonesRaw.trim();
      }
      return '-';
    })();

    // NEW: master LCO id
    final masterLcoId =
        (lcoDetails?['masterLcoId'] ?? widget.lco['masterLcoId'] ?? '')
            .toString()
            .trim();

    final settlementData = _calculateSettlementNumbers();
    final settlementAmount = settlementData['settlement'] ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,

      drawer: LcoSideMenu(lco: lcoDetails ?? widget.lco, onLogout: _logout),

      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 1,
        automaticallyImplyLeading: false,
        // leadingWidth: 40,
        // titleSpacing: 0,
        leading: Builder(
          builder: (ctx) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              color: AppTheme.onPrimary,
              padding: EdgeInsets.zero,
            );
          },
        ),
        title: Text(
          titleName.isNotEmpty ? 'LCO Dashboard' : 'LCO',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onPrimary,
          ),
        ),
        // masterLcoId in AppBar right corner
        actions: [
          if (masterLcoId.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    masterLcoId,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          IconButton(
            icon: const Icon(Icons.notifications_none),
            color: AppTheme.onPrimary,
            onPressed: () {
              // TODO: notification screen
            },
          ),

          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppTheme.primary,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // ───────── LCO header card ─────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.20),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT COLUMN: LCO details (takes remaining space)
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: Colors.white
                                              .withOpacity(0.16),
                                          child: Text(
                                            avatarInitial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName.isNotEmpty
                                                    ? displayName
                                                    : '-',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                (lcoDetails?['businessName'] ??
                                                            titleName)
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty
                                                    ? (lcoDetails?['businessName'] ??
                                                              titleName)
                                                          .toString()
                                                    : '-',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withOpacity(0.85),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.phone,
                                                    size: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.85),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      phoneText,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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

                                  const SizedBox(width: 8),

                                  // RIGHT COLUMN: Settlement mini card (fixed max width, no flex)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth:
                                          150, // safe on mobile, prevents overflow
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.24),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Row 1: icon + "Settlement"
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons
                                                    .account_balance_wallet_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Settlement',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),

                                          // Row 2: subtitle
                                          const Text(
                                            'payable to you',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Row 3: Amount (auto-fits inside 150px)
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '₹${currencyFormat.format(settlementAmount)}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // ───── chips row: district, PIN ─────
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (district.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            district,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (pincode.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.markunread_mailbox_outlined,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'PIN $pincode',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
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

                        const SizedBox(height: 16),

                        _buildHeaderCard(maxContentWidth),
                        const SizedBox(height: 14),

                        _buildNetworksList(maxContentWidth),
                        const SizedBox(height: 14),

                        _buildNetworkFeeCard(maxContentWidth),
                        const SizedBox(height: 14),

                        _buildSettlementCard(maxContentWidth),
                        const SizedBox(height: 12),

                        const Text(
                          'LCO dashboard: tap Manage to edit networks. Use per-network metrics above.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallGradientButton extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SmallGradientButton({
    Key? key,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = enabled
        ? AppTheme.primary
        : AppTheme.primary.withOpacity(0.45);

    return Opacity(
      opacity: enabled ? 1.0 : 0.7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: AppTheme.onPrimary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DecoratedCard extends StatelessWidget {
  final Widget child;
  const DecoratedCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: AppTheme.divider.withOpacity(0.8),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}
