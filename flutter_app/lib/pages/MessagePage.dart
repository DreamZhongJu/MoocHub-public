import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSystemNotice() {
    return _buildCard(
      children: [
        TDCell(
          title: '系统通知',
          description: '[1条] 亲爱的同学，课程更新提醒',
          note: '4小时前',
          leftIcon: TDIcons.sound,
          arrow: false,
          showBottomBorder: false,
        ),
      ],
    );
  }

  Widget _buildChatCell({
    required String name,
    required String preview,
    required String time,
    bool showBottomBorder = true,
  }) {
    return TDCell(
      title: name,
      description: preview,
      note: time,
      leftIcon: TDIcons.user_circle,
      arrow: true,
      showBottomBorder: showBottomBorder,
    );
  }

  Widget _buildChatList() {
    return _buildCard(
      children: [
        _buildChatCell(
          name: '清风讲师',
          preview: '资料已更新到课程页，记得查收～',
          time: '2月2日',
        ),
        _buildChatCell(
          name: '算法小站',
          preview: '你的提问我看到了，稍后给你详细回复。',
          time: '2月1日',
        ),
        _buildChatCell(
          name: '学习助手',
          preview: '[自动回复] 已收到你的消息，稍后处理。',
          time: '1月31日',
          showBottomBorder: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(TDIcons.home),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle('系统通知'),
          _buildSystemNotice(),
          const SizedBox(height: 12),
          _buildSectionTitle('私信'),
          _buildChatList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
