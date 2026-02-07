import 'package:MoocHub/pages/tabs/Category.dart';
import 'package:MoocHub/pages/tabs/Home.dart';
import 'package:MoocHub/pages/tabs/Learn.dart';
import 'package:MoocHub/pages/tabs/User.dart';
import 'package:flutter/material.dart';

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int _currentIndex = 0;
  late final PageController _pageController;
  late final List<Widget> _pageList;
  final List<String> _titles = const ['首页', '分类', '学习', '我的'];

  @override
  void initState() {
    _pageController = PageController(initialPage: _currentIndex);
    _pageList = [
      const HomePage(),
      const CategoryPage(),
      const LearnPage(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: PageView(
        controller: _pageController,
        children: _pageList,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.red,
        currentIndex: _currentIndex,
        onTap: _handleTabChange,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: '分类'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '学习'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '我的'),
        ],
      ),
    );
  }
}

