import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import '../../core/app_theme.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool loading = true;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiConfig.get('/api/notifications/my');
      final list = (res['body'] as List?) ?? [];

      if (!mounted) return;

      setState(() {
        items = list;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(child: Text('No notifications'))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final n = items[i] as Map<String, dynamic>;

            return ListTile(
              leading: Icon(
                Icons.notifications,
                color: n['read'] == true
                    ? Colors.grey
                    : AppTheme.primary,
              ),
              title: Text(
                n['title'] ?? '',
                style: TextStyle(
                  fontWeight: n['read'] == true
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Text(n['body'] ?? ''),
              onTap: () async {
                if (n['read'] != true) {
                  await ApiConfig.post(
                    '/api/notifications/${n['_id']}/read',
                    {},
                  );
                  setState(() {
                    n['read'] = true;
                  });
                }
              },
            );
          },
        ),
      ),
    );
  }
}
