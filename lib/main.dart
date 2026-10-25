import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generator_page.dart';
import 'scanner_page.dart';
import 'settings_page.dart';

// ---------------------------------------------------------------------------
// APP CONFIG & LINKS
// ---------------------------------------------------------------------------
class AppLinks {
  static const String rateUs =
      "https://play.google.com/store/apps/details?id=com.sktechstudio.qr_scan_generate";
  static const String privacyPolicy =
      "https://sktechstudio.blogspot.com/p/privacy-policy-qr-scan-generate.html";
  static const String termsConditions =
      "https://sktechstudio.blogspot.com/p/qr-scan-generate-terms-conditions.html";
  static const String disclaimer =
      "https://sktechstudio.blogspot.com/p/qr-scan-generate-disclaimer.html";
  static const String shareMessage =
      "Check out this amazing QR Scanner app: https://play.google.com/store/apps/details?id=com.sktechstudio.qr_scan_generate";
}

// ---------------------------------------------------------------------------
// COLORS
// ---------------------------------------------------------------------------
class SKColors {
  static const Color primaryDark = Color(0xFF00004D);
  static const Color primaryMedium = Color(0xFF001A80);
  static const Color primaryBright = Color(0xFF0040FF);
  static const Color softBorder = Color(0xFFAAB8FF);
  static const Color white = Colors.white;

  static const LinearGradient mainGradient = LinearGradient(
    colors: [primaryDark, primaryMedium, primaryBright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ---------------------------------------------------------------------------
// APP BAR WIDGET
// ---------------------------------------------------------------------------
class SKAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const SKAppBar({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: SKColors.mainGradient,
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ---------------------------------------------------------------------------
/*                               MAIN ENTRY                                */
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SkQrApp());
}

class SkQrApp extends StatelessWidget {
  const SkQrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scan & Generate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        colorScheme: ColorScheme.fromSeed(
          seedColor: SKColors.primaryBright,
          primary: SKColors.primaryMedium,
          secondary: SKColors.primaryBright,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: SKColors.primaryDark,
          foregroundColor: SKColors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SKColors.primaryMedium,
            foregroundColor: SKColors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 3,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: SKColors.softBorder.withOpacity(0.5),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: SKColors.primaryDark);
            }
            return IconThemeData(color: Colors.grey[600]);
          }),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// SPLASH SCREEN
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Splash delay
    await Future.delayed(const Duration(seconds: 3));

    _navigateToHome();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayoutScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/QR Scan & Generate.png",
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.qr_code_scanner_rounded,
                size: 100,
                color: SKColors.primaryMedium,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "QR Scan & Generate",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(SKColors.primaryMedium),
            ),
            const SizedBox(height: 10),
            const Text(
              "Loading...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN LAYOUT (Bottom Navigation Tabs)
// ---------------------------------------------------------------------------
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const ScannerPage(),
      const GeneratorPage(),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2),
            label: 'Generate',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
