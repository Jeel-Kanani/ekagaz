import 'package:flutter/material.dart';
import '../folders/home_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import '../family/join_family_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  // Deep linking variables
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // The 3 main screens of your app
  final List<Widget> _screens = [
    const HomeScreen(),   // 0: Dashboard
    const SearchScreen(), // 1: Search
    const SettingsScreen() // 2: Settings
  ];

  @override
  void initState() {
    super.initState();
    _initDeepLinks(); // Initialize link listener on startup
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Clean up listener to prevent memory leaks
    super.dispose();
  }

  /// Initialize the Deep Linking listener
  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 1. Handle links when the app is already open (foreground/background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep link received: $uri');
      _handleIncomingLink(uri);
    });

    // 2. Handle the link that opened the app from a completely terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('Initial deep link received: $uri');
        _handleIncomingLink(uri);
      }
    });
  }

  /// Logic to navigate based on the link content
  void _handleIncomingLink(Uri uri) {
    // Check if the link matches your scheme: famvault://join/<id>
    if (uri.scheme == 'famvault' && uri.host == 'join') {
      if (mounted) {
        // Navigate to the Join Family Screen if a link is detected
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const JoinFamilyScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // Using IndexedStack preserves state of screens when switching tabs
        index: _currentIndex,
        children: _screens,
      ),
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