import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';

class PointsDetailPage extends StatefulWidget {
  const PointsDetailPage({super.key});

  @override
  State<PointsDetailPage> createState() => _PointsDetailPageState();
}

class _PointsDetailPageState extends State<PointsDetailPage> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _loggedIn = false;
  int _balance = 0;
  int? _rank;
  int? _totalUsers;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final token = await _storage.getUserToken();
    final loggedIn =
        token != null && token.toString().isNotEmpty && token != 'null';
    if (!loggedIn) {
      if (mounted) {
        setState(() {
          _loggedIn = false;
          _loading = false;
          _balance = 0;
          _transactions = [];
        });
      }
      return;
    }

    try {
      final results = await Future.wait([
        _api.get<Map<String, dynamic>>(
          '/points/balance',
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
        ),
        _api.get<Map<String, dynamic>>(
          '/points/transactions',
          queryParameters: const {'page': 1, 'page_size': 50},
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
        ),
        _api.get<Map<String, dynamic>>(
          '/points/rank',
          fromJson: (data) => Map<String, dynamic>.from(data as Map),
        ),
      ]);

      final balance =
          (results[0].data['points_balance'] as num?)?.toInt() ?? 0;
      final rawItems = results[1].data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final rank = (results[2].data['rank'] as num?)?.toInt();
      final total = (results[2].data['total_users'] as num?)?.toInt();

      if (mounted) {
        setState(() {
          _loggedIn = true;
          _balance = balance;
          _rank = rank;
          _totalUsers = total;
          _transactions = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loggedIn = true;
          _loading = false;
        });
      }
    }
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'login':
        return '每日登录';
      case 'comment':
        return '评论';
      case 'video_complete':
        return '学习完成';
      case 'favorite':
        return '收藏';
      case 'admin_award':
        return '系统奖励';
      case 'admin_deduct':
        return '系统扣分';
      default:
        return eventType;
    }
  }

  Widget _buildBalanceCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.stars, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前积分',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_balance',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _loadData, child: const Text('刷新')),
              ],
            ),
            if (_rank != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: '排名第 ',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                        TextSpan(
                          text: '$_rank',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                        if (_totalUsers != null)
                          TextSpan(
                            text: ' / $_totalUsers 名用户',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('暂无积分流水')),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: _transactions.map((item) {
          final points = (item['points'] as num?)?.toInt() ?? 0;
          final eventType = item['event_type']?.toString() ?? '';
          final createdAt = item['created_at']?.toString() ?? '';
          final isPositive = points >= 0;
          return ListTile(
            title: Text(_eventLabel(eventType)),
            subtitle: Text(createdAt),
            trailing: Text(
              '${isPositive ? '+' : ''}$points',
              style: TextStyle(
                color: isPositive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('登录后查看积分明细'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                _loadData();
              },
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('积分明细'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_loggedIn
          ? _buildLoginPrompt()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  _buildBalanceCard(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '积分流水',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildTransactions(),
                ],
              ),
            ),
    );
  }
}
