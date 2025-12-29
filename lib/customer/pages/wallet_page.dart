// lib/customer/pages/wallet_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/customer_service.dart';

class MonthGroup {
  final String key; // e.g. '2025-12'
  final String label; // e.g. 'December 2025'
  final List<Map<String, dynamic>> items;
  final int totalCreditPaise;
  final int totalDebitPaise;

  MonthGroup({
    required this.key,
    required this.label,
    required this.items,
    required this.totalCreditPaise,
    required this.totalDebitPaise,
  });
}

class WalletPage extends StatefulWidget {
  final Map<String, dynamic> customer;

  const WalletPage({Key? key, required this.customer}) : super(key: key);

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  int _page = 1;
  final int _limit = 20;

  // wallet summary
  int _walletPaise = 0;
  DateTime? _walletUpdatedAt;

  // transactions list (normalized)
  List<Map<String, dynamic>> _transactions = [];
  bool _hasMore = true;
  String? _error;

  final DateFormat _dateTimeFmt = DateFormat.yMMMd().add_jm();
  final DateFormat _monthLabelFmt = DateFormat('MMMM yyyy');

  String get _customerId {
    final c = widget.customer;
    return (c['_id'] ?? c['id'] ?? c['uid'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    if (_customerId.isEmpty) {
      _loading = false;
      _error = 'Invalid customer id';
    } else {
      _loadAll(firstLoad: true);
    }
  }

  Future<void> _loadAll({bool firstLoad = false}) async {
    if (firstLoad) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }
    try {
      await _fetchWalletSummary();
      _page = 1;
      _transactions = [];
      _hasMore = true;
      await _fetchTransactions(page: _page);
    } catch (e) {
      _error = 'Failed to load wallet: $e';
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _fetchWalletSummary() async {
    final id = _customerId;
    if (id.isEmpty) {
      setState(() {
        _error = 'Invalid customer id';
      });
      return;
    }

    final res = await CustomerService.getWallet(id);
    if (res['statusCode'] == 200 && res['data'] != null) {
      final body = res['data'] as Map<String, dynamic>;
      setState(() {
        final rawPaise = body['walletPaise'] ?? 0;
        _walletPaise = (rawPaise is int) ? rawPaise : int.tryParse('$rawPaise') ?? 0;
        final tu = body['walletUpdatedAt'];
        _walletUpdatedAt = tu != null ? DateTime.tryParse(tu.toString()) : null;
      });
    } else {
      if (res['statusCode'] != 200) {
        setState(() {
          _error ??= 'Failed to load wallet summary';
        });
      }
    }
  }

  Map<String, dynamic> _normalizeTx(Map<String, dynamic> raw) {
    final tx = Map<String, dynamic>.from(raw);

    // type
    final type = (tx['type'] ?? 'credit').toString();

    // parse amounts
    int amountPaise;
    {
      final rawAmt = tx['amountPaise'] ?? 0;
      amountPaise =
      (rawAmt is int) ? rawAmt : int.tryParse(rawAmt.toString()) ?? 0;
    }

    int balanceAfterPaise;
    {
      final rawBal = tx['balanceAfterPaise'] ?? 0;
      balanceAfterPaise =
      (rawBal is int) ? rawBal : int.tryParse(rawBal.toString()) ?? 0;
    }

    // createdAt
    DateTime? createdAt;
    try {
      if (tx['createdAt'] != null) {
        createdAt = DateTime.tryParse(tx['createdAt'].toString())?.toLocal();
      }
    } catch (_) {
      createdAt = null;
    }

    final reason = (tx['reason'] ?? '').toString();
    final meta =
    (tx['meta'] is Map) ? Map<String, dynamic>.from(tx['meta']) : <String, dynamic>{};

    // Derive UI title & subtitle based on reason/meta
    String titleUi;
    String subtitleUi = '';

    if (reason == 'referral_payout') {
      titleUi = 'Referral reward';
      final referredName = (meta['referredName'] ?? meta['referredCustomerName'] ?? '').toString().trim();
      final referredPhone = (meta['referredPhone'] ?? '').toString().trim();
      if (referredName.isNotEmpty || referredPhone.isNotEmpty) {
        subtitleUi = [
          if (referredName.isNotEmpty) referredName,
          if (referredPhone.isNotEmpty) referredPhone,
        ].join(' • ');
      } else {
        subtitleUi = 'Credit added to wallet';
      }
    } else if (reason == 'payment_consumed' ||
        reason == 'bill_payment' ||
        reason == 'payment_wallet') {
      titleUi = 'Bill payment from wallet';

      final setupBox = (meta['setupBoxNumber'] ??
          meta['boxNumber'] ??
          meta['stbNumber'] ??
          '')
          .toString()
          .trim();
      final period = (meta['period'] ?? '').toString().trim();
      final planName = (meta['planName'] ?? meta['network'] ?? '').toString().trim();

      final parts = <String>[];
      if (setupBox.isNotEmpty) parts.add('STB $setupBox');
      if (planName.isNotEmpty) parts.add(planName);
      if (period.isNotEmpty) parts.add(period);
      subtitleUi = parts.isNotEmpty ? parts.join(' • ') : 'Wallet used for cable bill';
    } else if (reason == 'manual_adjustment') {
      titleUi = type == 'credit' ? 'Manual credit' : 'Manual debit';
      subtitleUi = (meta['note'] ?? '').toString();
    } else if (reason == 'promo_credit') {
      titleUi = 'Promotional credit';
      subtitleUi = (meta['campaign'] ?? 'Offer applied').toString();
    } else {
      // generic fallback
      if (type == 'credit') {
        titleUi = 'Wallet credit';
      } else {
        titleUi = 'Wallet debit';
      }
      if (meta.isNotEmpty) {
        // quick human-readable meta if label/note present
        final label = (meta['label'] ?? meta['note'] ?? '').toString().trim();
        if (label.isNotEmpty) {
          subtitleUi = label;
        }
      }
    }

    tx['type'] = type;
    tx['amountPaise'] = amountPaise;
    tx['balanceAfterPaise'] = balanceAfterPaise;
    tx['createdAtDt'] = createdAt;
    tx['titleUi'] = titleUi;
    tx['subtitleUi'] = subtitleUi;

    return tx;
  }

  Future<void> _fetchTransactions({required int page}) async {
    if (!_hasMore && page != 1) return;

    if (page == 1) {
      _loadingMore = false;
    } else {
      setState(() {
        _loadingMore = true;
      });
    }

    final id = _customerId;
    if (id.isEmpty) {
      setState(() {
        _error = 'Invalid customer id';
        _hasMore = false;
        _loadingMore = false;
      });
      return;
    }

    final res =
    await CustomerService.getWalletHistory(id, page: page, limit: _limit);
    if (res['statusCode'] == 200 && res['data'] != null) {
      final body = res['data'] as Map<String, dynamic>;
      final rawItems = (body['items'] is List)
          ? List<Map<String, dynamic>>.from(body['items'])
          : <Map<String, dynamic>>[];

      final items = rawItems.map(_normalizeTx).toList();

      setState(() {
        if (page == 1) {
          _transactions = items;
        } else {
          _transactions.addAll(items);
        }
        final totalReturned = items.length;
        final totalExpected =
        body['total'] is int ? body['total'] as int : null;
        _hasMore = totalReturned == _limit &&
            (totalExpected == null || _transactions.length < totalExpected);
      });
    } else {
      setState(() {
        if (page == 1) _transactions = [];
        _hasMore = false;
        _error ??= 'Failed to fetch wallet history';
      });
    }

    setState(() {
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _page += 1;
    await _fetchTransactions(page: _page);
  }

  String _paiseToRupeesString(int paise) {
    final rupees = paise / 100.0;
    return NumberFormat.currency(symbol: '₹').format(rupees);
  }

  List<MonthGroup> _buildMonthGroups() {
    if (_transactions.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> byKey = {};
    final Map<String, int> creditTotals = {};
    final Map<String, int> debitTotals = {};

    for (final tx in _transactions) {
      final createdAt = tx['createdAtDt'] as DateTime?;
      if (createdAt == null) continue;
      final key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
      byKey.putIfAbsent(key, () => []).add(tx);

      final type = (tx['type'] ?? 'credit').toString();
      final amount = tx['amountPaise'] is int ? tx['amountPaise'] as int : 0;
      if (type == 'credit') {
        creditTotals[key] = (creditTotals[key] ?? 0) + amount;
      } else {
        debitTotals[key] = (debitTotals[key] ?? 0) + amount;
      }
    }

    final keys = byKey.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest month first

    final List<MonthGroup> groups = [];
    for (final key in keys) {
      final items = byKey[key]!;
      final sampleDt = items.first['createdAtDt'] as DateTime?;
      final label = sampleDt != null ? _monthLabelFmt.format(sampleDt) : key;
      groups.add(
        MonthGroup(
          key: key,
          label: label,
          items: items,
          totalCreditPaise: creditTotals[key] ?? 0,
          totalDebitPaise: debitTotals[key] ?? 0,
        ),
      );
    }
    return groups;
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet,
                size: 28, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet balance', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 6),
                Text(
                  _paiseToRupeesString(_walletPaise),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                if (_walletUpdatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Updated ${_dateTimeFmt.format(_walletUpdatedAt!.toLocal())}',
                      style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Wallet info'),
                  content: const Text(
                    'Wallet credits come from referrals, promotions, or manual adjustments. '
                        'When you pay your monthly cable bill, available wallet balance is applied automatically '
                        'if enabled on the payment screen.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    )
                  ],
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final type = (tx['type'] ?? 'credit').toString();
    final amountPaise = tx['amountPaise'] is int ? tx['amountPaise'] as int : 0;
    final createdAt = tx['createdAtDt'] as DateTime?;
    final title = (tx['titleUi'] ?? '').toString();
    final subtitle = (tx['subtitleUi'] ?? '').toString();

    final isCredit = type == 'credit';
    final amountStr =
        '${isCredit ? '+' : '-'}${_paiseToRupeesString(amountPaise)}';

    final color = isCredit ? Colors.green.shade700 : Colors.red.shade700;
    final bgColor = isCredit
        ? Colors.green.withOpacity(0.10)
        : Colors.red.withOpacity(0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: bgColor,
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (createdAt != null)
              Text(
                _dateTimeFmt.format(createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Text(
          amountStr,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final monthGroups = _buildMonthGroups();

    return RefreshIndicator(
      onRefresh: () => _loadAll(firstLoad: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 18),
          const Text(
            'Wallet history',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _error ?? 'No wallet transactions found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else ...[
            for (final group in monthGroups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      group.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      // GPay-like header: Spent / Added for the month
                      'Spent ${_paiseToRupeesString(group.totalDebitPaise)} • Added ${_paiseToRupeesString(group.totalCreditPaise)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ...group.items.map(_buildTransactionTile),
              const Divider(height: 20),
            ]
          ],
          if (_hasMore)
            TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: _loadingMore
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Load more'),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: AppTheme.primary,
      ),
      body: _buildBody(),
    );
  }
}
