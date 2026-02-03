import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage>
    with AutomaticKeepAliveClientMixin<UserPage> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Center(child: Text('用户页面'));
  }

  @override
  bool get wantKeepAlive => true;
}
