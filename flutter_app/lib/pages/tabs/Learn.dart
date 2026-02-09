import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:flutter/material.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => LearnPageState();
}

class LearnPageState extends State<LearnPage>
    with AutomaticKeepAliveClientMixin<LearnPage>, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  bool _loading = true;
  bool _loggedIn = false;
  int _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  final List<int> _thresholds = const [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshFromParent();
    }
  }

  void refreshFromParent() {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
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
      final balanceResp = await _api.get<Map<String, dynamic>>(
        '/points/balance',
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
      );
      final txResp = await _api.get<Map<String, dynamic>>(
        '/points/transactions',
        queryParameters: const {'page': 1, 'page_size': 20},
        fromJson: (data) => Map<String, dynamic>.from(data as Map),
      );

      final balance =
          (balanceResp.data['points_balance'] as num?)?.toInt() ?? 0;
      final rawItems = txResp.data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted) {
        setState(() {
          _loggedIn = true;
          _balance = balance;
          _transactions = items;
          _loading = false;
        });
      }
      await _maybeShowThresholdDialog(balance);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loggedIn = true;
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('积分加载失败: $e')));
      }
    }
  }

  Future<void> _maybeShowThresholdDialog(int balance) async {
    final shown = await _storage.getShownPointThresholds();
    final lastBalance = await _storage.getLastPointsBalance() ?? 0;
    int? hit;
    for (final t in _thresholds) {
      if (balance >= t && lastBalance < t && !shown.contains(t)) {
        hit = t;
        break;
      }
    }
    await _storage.saveLastPointsBalance(balance);
    if (hit == null || !mounted) return;

    shown.add(hit);
    await _storage.saveShownPointThresholds(shown);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('积分达成'),
        content: Text('恭喜你达成 $hit 积分！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
        child: Row(
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
                  const SizedBox(height: 6),
                  Text(
                    '$_balance',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _loadData, child: const Text('刷新')),
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
            const Text('登录后查看积分与学习记录'),
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
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_loggedIn) {
      return _buildLoginPrompt();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        children: [
          _buildBalanceCard(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '积分流水',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _buildTransactions(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '后续功能：学习计划 / 成就 / 课程目标',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
