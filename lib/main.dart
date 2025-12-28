import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme_service.dart';

// --- IMPORTS FOR YOUR SCREENS ---
import 'auth/login_screen.dart';
import 'family/family_setup_screen.dart'; // Check this path matches your folder
import 'layout/main_layout.dart';
import 'core/auth_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    // ✅ WRAP APP IN PROVIDER
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    final themeService = context.watch<ThemeService>(); // ✅ Listen to theme changes

    return MaterialApp(
      title: 'FamVault',
      debugShowCheckedModeBanner: false,
      // ✅ DYNAMIC THEME
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
      home: session != null 
          ? const AuthGuard(child: MainLayout()) 
          : const LoginScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect(); // Call the smart check immediately
  }

  Future<void> _redirect() async {
    // 1. Tiny delay to show logo (optional, keeps UI smooth)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 2. Check if User is Logged In
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // CASE A: Not Logged In -> Go to Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // CASE B: Logged In -> Check if they have a Family
      try {
        final user = Supabase.instance.client.auth.currentUser;
        
        // Query the database to see if this user is in the 'family_members' table
        final data = await Supabase.instance.client
            .from('family_members')
            .select()
            .eq('user_id', user!.id)
            .maybeSingle(); // Returns null if no row is found

        if (!mounted) return;

        if (data != null) {
          // Sub-case B1: HAS Family -> Go to Main Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainLayout()), 
          );
        } else {
          // Sub-case B2: NO Family -> Go to Create/Join Page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FamilySetupScreen()),
          );
        }
      } catch (e) {
        // If internet fails or other error, fallback to Login or show error
        print("Error during splash redirect: $e");
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Good practice to set a background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // If you have a logo image, use Image.asset here instead of Text
            Text(
              'eKagaz',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue, // Or your app color
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(), // Loading spinner
          ],
        ),
      ),
    );
  }
}