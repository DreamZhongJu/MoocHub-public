import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  final List<_ChatItem> _privateChats = [
    _ChatItem(
      id: 'p1',
      title: '澄空海',
      lastMessage: '收到，我等下补充。',
      time: '20:18',
      unread: 2,
      avatar:
          'https://picsum.photos/seed/moochub_user1/80',
      isGroup: false,
    ),
    _ChatItem(
      id: 'p2',
      title: 'ProfessorLeo65',
      lastMessage: '下节课记得带实验报告。',
      time: '19:55',
      unread: 0,
      avatar:
          'https://picsum.photos/seed/moochub_user2/80',
      isGroup: false,
    ),
  ];

  final List<_ChatItem> _groupChats = [
    _ChatItem(
      id: 'g1',
      title: 'MoocHub 前端组',
      lastMessage: 'UI 我今晚改完。',
      time: '20:12',
      unread: 5,
      avatar:
          'https://picsum.photos/seed/moochub_group1/80',
      isGroup: true,
    ),
    _ChatItem(
      id: 'g2',
      title: '毕业设计讨论群',
      lastMessage: '下周五答辩流程发群里了。',
      time: '18:40',
      unread: 0,
      avatar:
          'https://picsum.photos/seed/moochub_group2/80',
      isGroup: true,
    ),
  ];

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TDSearchBar(
        placeHolder: '搜索联系人 / 群聊',
        onTextChanged: (_) {},
        onSubmitted: (_) {},
      ),
    );
  }

  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TDNoticeBar(
        content: '当前为前端演示页面，暂未接入实时服务',
        prefixIcon: TDIcons.error_circle_filled,
      ),
    );
  }

  Widget _buildChatList(List<_ChatItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无会话'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildChatItem(items[index]),
    );
  }

  Widget _buildChatItem(_ChatItem item) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chatDetail',
          arguments: {
            'conversationId': item.id,
            'title': item.title,
            'isGroup': item.isGroup,
          },
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TDImage(
                imgUrl: item.avatar,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if (item.unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.unread > 99 ? '99+' : '${item.unread}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TDButton(
        text: '发起群聊',
        type: TDButtonType.outline,
        size: TDButtonSize.large,
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildSearch(),
            _buildNotice(),
            const SizedBox(height: 6),
            const TDTabBar(
              tabs: [TDTab(text: '私信'), TDTab(text: '群聊')],
              showIndicator: true,
            ),
            Expanded(
              child: TDTabBarView(
                children: [
                  _buildChatList(_privateChats),
                  Column(
                    children: [
                      Expanded(child: _buildChatList(_groupChats)),
                      _buildGroupAction(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem {
  final String id;
  final String title;
  final String lastMessage;
  final String time;
  final int unread;
  final String avatar;
  final bool isGroup;

  const _ChatItem({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.avatar,
    required this.isGroup,
  });
}
