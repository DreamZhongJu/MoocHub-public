import 'package:flutter/material.dart';
import 'package:flutter_jdshop/pages/tabs/Cart.dart';
import 'package:flutter_jdshop/pages/tabs/Category.dart';
import 'package:flutter_jdshop/pages/tabs/User.dart';
import 'package:flutter_jdshop/pages/tabs/Home.dart';

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final GlobalKey<CartPageState> _cartKey = GlobalKey<CartPageState>();
  late final List<Widget> _pageList;
  final List<String> _titles = const ['首页', '分类', '购物车', '我的'];

  @override
  void initState() {
    _pageController = PageController(initialPage: _currentIndex);
    _pageList = [
      const HomePage(),
      const CategoryPage(),
      CartPage(key: _cartKey),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cartKey.currentState?.refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: PageView(
        controller: _pageController,
        children: _pageList,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 2) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _cartKey.currentState?.refresh();
            });
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        fixedColor: Colors.red,
        currentIndex: _currentIndex,
        onTap: _handleTabChange,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: '分类',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: '购物车',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
