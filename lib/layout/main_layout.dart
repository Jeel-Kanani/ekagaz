import 'package:flutter/material.dart';
import '../folders/home_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // The 3 main screens of your app
  final List<Widget> _screens = [
    const HomeScreen(),   // 0: Dashboard
    const SearchScreen(), // 1: Search
    const SettingsScreen() // 2: Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined), 
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home'
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined), 
            selectedIcon: Icon(Icons.search),
            label: 'Search'
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined), 
            selectedIcon: Icon(Icons.settings),
            label: 'Settings'
          ),
        ],
      ),
    );
  }
}