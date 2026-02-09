import 'package:MoocHub/pages/tabs/Category.dart';
import 'package:MoocHub/pages/tabs/Home.dart';
import 'package:MoocHub/pages/tabs/Learn.dart';
import 'package:MoocHub/pages/tabs/User.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

Widget? _selectedIcon;

Widget? _unSelectedIcon;

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final List<Widget> _pageList;
  final GlobalKey<LearnPageState> _learnKey = GlobalKey<LearnPageState>();
  final List<String> _titles = const ['首页', '分类', '学习', '我的'];
  final List<IconData> _selectedIcons = const [
    TDIcons.home, // 首页
    TDIcons.app, // 分类
    TDIcons.book, // 学习
    TDIcons.user, // 我的
  ];
  final List<IconData> _unselectedIcons = const [
    TDIcons.home, // 首页
    TDIcons.app, // 分类
    TDIcons.book, // 学习
    TDIcons.user, // 我的
  ];
  @override
  void initState() {
    _pageController = PageController(initialPage: _currentIndex);
    _pageList = [
      const HomePage(),
      const CategoryPage(),
      LearnPage(key: _learnKey),
      const UserPage(),
    ];
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleTabChange(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(_currentIndex);
    });
    if (index == 2) {
      _learnKey.currentState?.refreshFromParent();
    }
  }

  Widget _weakSelectIconTextTabBar(BuildContext context) {
    return TDBottomTabBar(
      TDBottomTabBarBasicType.iconText,
      componentType: TDBottomTabBarComponentType.normal,
      useVerticalDivider: false,
      navigationTabs: List.generate(_titles.length, (index) {
        final label = _titles[index];
        return TDBottomTabBarTabConfig(
          selectedIcon: Icon(
            _selectedIcons[index],
            size: 24,
            color: TDTheme.of(context).brandNormalColor,
          ),
          unselectedIcon: Icon(
            _unselectedIcons[index],
            size: 24,
            color: TDTheme.of(context).textColorPrimary,
          ),
          tabText: label,
          onTap: () {
            _handleTabChange(index);
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 2) {
            _learnKey.currentState?.refreshFromParent();
          }
        },
        children: _pageList,
      ),
      bottomNavigationBar: _weakSelectIconTextTabBar(context),
    );
  }
}
