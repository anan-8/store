import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:store/My_Products_Screen.dart';
import 'package:store/Orders_Screen.dart';
import 'package:store/Settings_Screen.dart';

class MainLayout extends StatefulWidget {
  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Widget> _pages = [
    MyProductsScreen(),
    StoreOrdersScreen(),
    UserSettingsScreen(isLoggedIn: FirebaseAuth.instance.currentUser != null),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: SalomonBottomBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_auth.currentUser == null && index != 0) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('يجب تسجيل الدخول أولاً')));
              return;
            }
            setState(() => _currentIndex = index);
          },
          items: [
            SalomonBottomBarItem(
              icon: Icon(Icons.shopping_bag, size: 24),
              title: Text("المنتجات", style: TextStyle(fontSize: 14)),
              selectedColor: Colors.green,
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.receipt_long, size: 24),
              title: Text("الطلبات", style: TextStyle(fontSize: 14)),
              selectedColor: Colors.orange,
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.settings, size: 24),
              title: Text("الإعدادات", style: TextStyle(fontSize: 14)),
              selectedColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
