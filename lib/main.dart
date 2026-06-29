import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// ADMOB CONFIGURATION
// ---------------------------------------------------------------------------

class AdHelper {
  // ---------------- SCANNER PAGE ----------------
  static String get scannerBannerAdUnitId =>
      'ca-app-pub-6120680228939302/9172404703'; // ID Banner A

  // ---------------- GENERATOR PAGE TOP ----------------
  static String get generatorBannerTopAdUnitId =>
      'ca-app-pub-6120680228939302/4317880888'; // ID Banner B

  // ---------------- SETTINGS PAGE ----------------
  static String get settingsBannerAdUnitId =>
      'ca-app-pub-6120680228939302/4912777257'; // ID Banner C

  // APP OPEN AD (Already working)
  static String get appOpenAdUnitId => 'ca-app-pub-6120680228939302/5171975160';
}

// Inline Adaptive Banner Ad Unit ID
final String _InlineAdaptiveBannerAdUnitId =
    'ca-app-pub-6120680228939302/4030283886'; // ID Banner inline adaptive ad

// ---------------------------------------------------------------------------
// APP OPEN AD MANAGER  (Same style as Status Saver)
// - App resume / foreground pe ad show karega
// ---------------------------------------------------------------------------
class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  final Duration maxCacheDuration = const Duration(hours: 4);

  String get adUnitId => AdHelper.appOpenAdUnitId;

  void loadAd() {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AppOpenAdManager: Ad Loaded');
          _appOpenLoadTime = DateTime.now();
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAdManager: Failed to Load -> $error');
        },
      ),
    );
  }

  bool get isAdAvailable {
    return _appOpenAd != null &&
        _appOpenLoadTime != null &&
        DateTime.now().difference(_appOpenLoadTime!) < maxCacheDuration;
  }

  void showAdIfAvailable() {
    if (!isAdAvailable) {
      loadAd();
      return;
    }

    if (_isShowingAd) {
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        debugPrint('AppOpenAdManager: Ad showed full screen');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAdManager: Ad dismissed');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAdManager: Failed to show -> $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
    );

    _appOpenAd!.show();
  }
}

// ---------------------------------------------------------------------------
// APP LIFECYCLE REACTOR (Background → Foreground par AppOpenAd)
// ---------------------------------------------------------------------------
class AppLifecycleReactor {
  final AppOpenAdManager appOpenAdManager;

  AppLifecycleReactor({required this.appOpenAdManager});

  void listenToAppStateChanges() {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream
        .forEach((state) => _onAppStateChanged(state));
  }

  void _onAppStateChanged(AppState appState) {
    if (appState == AppState.foreground) {
      appOpenAdManager.showAdIfAvailable();
    }
  }
}

// ---------------------------------------------------------------------------
// APP CONFIG & LINKS (Google Sheet se remote config)
// ---------------------------------------------------------------------------
class AppLinks {
  static const String csvUrl =
      "https://docs.google.com/spreadsheets/d/e/2PACX-1vSvz3uNBTZBh-79FtD04o1wboC0nLUF1WZl8M9zCIGs73_syPf5RCv25XE8jOyk06WzLQ6QqkeM2RlO/pub?gid=0&single=true&output=csv";

  static String rateUs =
      "https://play.google.com/store/apps/details?id=com.sktechstudio.qr_scan_generate";
  static String privacyPolicy = "https://www.google.com";
  static String termsConditions = "https://www.google.com";
  static String disclaimer = "https://www.google.com";
  static String shareMessage =
      "Check out this amazing QR Scanner app: https://play.google.com/store/apps/details?id=com.sktechstudio.qr_scan_generate";

  static Future<void> fetchConfig() async {
    if (csvUrl.isEmpty) return;
    try {
      final HttpClient client = HttpClient();
      final Uri uri = Uri.parse(csvUrl);
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final String content = await response.transform(utf8.decoder).join();
        final List<String> lines = content.split('\n');

        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          final List<String> parts = line.split(',');
          if (parts.length >= 2) {
            final String key = parts[0].trim().toLowerCase();
            final String value = parts.sublist(1).join(',').trim();

            if (key.contains("rate")) {
              rateUs = value;
            } else if (key.contains("privacy")) {
              privacyPolicy = value;
            } else if (key.contains("terms")) {
              termsConditions = value;
            } else if (key.contains("disclaimer")) {
              disclaimer = value;
            } else if (key.contains("share")) {
              shareMessage = value;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching config: $e");
    }
  }
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
/*                               MAIN ENTRY                                */
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await MobileAds.instance.initialize();
  runApp(const SkQrApp());
}

class SkQrApp extends StatefulWidget {
  const SkQrApp({super.key});

  @override
  State<SkQrApp> createState() => _SkQrAppState();
}

class _SkQrAppState extends State<SkQrApp> {
  late AppOpenAdManager _appOpenAdManager;
  late AppLifecycleReactor _appLifecycleReactor;

  @override
  void initState() {
    super.initState();
    _appOpenAdManager = AppOpenAdManager();
    _appLifecycleReactor =
        AppLifecycleReactor(appOpenAdManager: _appOpenAdManager);

    // App start par App Open ad load
    _appOpenAdManager.loadAd();

    // Background → foreground par App Open ad
    _appLifecycleReactor.listenToAppStateChanges();
  }

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
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
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
// NEW: INLINE ADAPTIVE BANNER (Bada Wala Ad)
// ---------------------------------------------------------------------------

class InlineAdaptiveBannerAd extends StatefulWidget {
  const InlineAdaptiveBannerAd({super.key});

  @override
  State<InlineAdaptiveBannerAd> createState() => _InlineAdaptiveBannerAdState();
}

class _InlineAdaptiveBannerAdState extends State<InlineAdaptiveBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize; // Asli size load hone ke baad milega

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  void _loadAd() async {
    // Current screen width nikalo
    final double screenWidth = MediaQuery.of(context).size.width;

    // Inline Adaptive Size calculate karo (ye standard se bada hota hai)
    final AdSize size = AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
      screenWidth.truncate(),
    );

    _bannerAd = BannerAd(
      adUnitId: _InlineAdaptiveBannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) async {
          // IMPORTANT: Load hone ke baad exact height milti hai
          BannerAd bannerAd = ad as BannerAd;
          final AdSize? platformSize = await bannerAd.getPlatformAdSize();

          setState(() {
            _bannerAd = bannerAd;
            _adSize = platformSize; // Height ab update hogi
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('Inline Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null && _adSize != null) {
      return Container(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // Jab tak load na ho, jagah khali rakho (0 height)
    return const SizedBox();
  }
}

// ---------------------------------------------------------------------------
// BANNER AD WIDGET (Adaptive full width)
// ---------------------------------------------------------------------------
class MyBannerAd extends StatefulWidget {
  final String adUnitId; // <-- Add this

  const MyBannerAd({super.key, required this.adUnitId});

  @override
  State<MyBannerAd> createState() => _MyBannerAdState();
}

class _MyBannerAdState extends State<MyBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return;

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId, // <-- Now uses correct ID per page
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// SPLASH SCREEN  (Same logic style as Status Saver)
// - Yaha se FIRST TIME App Open ad show hota hai
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  AppOpenAd? _appOpenAd;
  bool _isAdAvailable = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Remote config
    AppLinks.fetchConfig();

    // Splash specific AppOpen load
    _loadAppOpenAd();

    // Splash delay
    await Future.delayed(const Duration(seconds: 4));

    if (_isAdAvailable && _appOpenAd != null) {
      _appOpenAd!.show();
    } else {
      _navigateToHome();
    }
  }

  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('SplashScreen AppOpenAd loaded');
          _appOpenAd = ad;
          _isAdAvailable = true;

          _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _navigateToHome();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint(
                  'SplashScreen AppOpenAd failed to show full screen: $error');
              ad.dispose();
              _navigateToHome();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('SplashScreen AppOpenAd failed to load: $error');
          _isAdAvailable = false;
        },
      ),
    );
  }

  void _navigateToHome() {
    if (_isNavigating) return;
    _isNavigating = true;

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
    AppLinks.fetchConfig();

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

// ---------------------------------------------------------------------------
// 1. SCANNER PAGE
// ---------------------------------------------------------------------------
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController controller;
  late AnimationController _animationController;
  final ImagePicker _picker = ImagePicker();
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addObserver(this);
    controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _scanFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      controller.stop();
      final BarcodeCapture? barcodes =
          await controller.analyzeImage(image.path);
      if (!mounted) return;

      if (barcodes != null && barcodes.barcodes.isNotEmpty) {
        final Barcode firstBarcode = barcodes.barcodes.first;
        if (firstBarcode.rawValue != null) {
          _showResult(context, firstBarcode.rawValue!, firstBarcode.format);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No Readable QR Found")));
          controller.start();
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No QR code detected")));
        controller.start();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('SK Scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _isFlashOn = !_isFlashOn);
              controller.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (BarcodeCapture capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        controller.stop();
                        _showResult(context, barcode.rawValue!, barcode.format);
                        break;
                      }
                    }
                  },
                ),
                CustomPaint(
                  painter: ScannerOverlayPainter(_animationController),
                  child: Container(),
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Align Code within the Box",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: _scanFromGallery,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SKColors.primaryMedium.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SKColors.primaryBright,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Upload from Gallery",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: MyBannerAd(adUnitId: AdHelper.scannerBannerAdUnitId),
          ),
        ],
      ),
    );
  }

  void _showResult(BuildContext context, String code, BarcodeFormat format) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: SKColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Scanned Result",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: SKColors.primaryDark),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: SKColors.softBorder.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SKColors.softBorder),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 16,
                  color: SKColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SKColors.primaryMedium,
                      side: const BorderSide(color: SKColors.primaryMedium),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Copied to clipboard"),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SKColors.primaryBright,
                    ),
                    onPressed: () async {
                      String scanData = code.trim();
                      Uri? uri;
                      final bool isEmail =
                          RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                              .hasMatch(scanData);

                      if (isEmail) {
                        uri = Uri.parse("mailto:$scanData");
                      } else {
                        uri = Uri.tryParse(scanData);
                        if (uri != null && !uri.hasScheme) {
                          if (scanData.contains('www.') ||
                              scanData.contains('.com')) {
                            uri = Uri.tryParse("https://$scanData");
                          }
                        }
                      }

                      try {
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          throw 'Invalid URI';
                        }
                      } catch (e) {
                        final searchUri = Uri.parse(
                            "https://www.google.com/search?q=$scanData");
                        await launchUrl(
                          searchUri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                      if (mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text("Open"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Scan Again"),
            ),
          ],
        ),
      ),
    ).then((_) {
      controller.start();
    });
  }
}

// ---------------------------------------------------------------------------
// Scanner overlay decoration
// ---------------------------------------------------------------------------
class ScannerOverlayPainter extends CustomPainter {
  final Animation<double> animation;
  ScannerOverlayPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double scanBoxSize = 280.0;
    final double scanBoxTop = (size.height - scanBoxSize) / 2;
    final double scanBoxLeft = (size.width - scanBoxSize) / 2;
    final Rect scanRect =
        Rect.fromLTWH(scanBoxLeft, scanBoxTop, scanBoxSize, scanBoxSize);

    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6);
    Path path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path boxPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));
    final Path overlayPath =
        Path.combine(PathOperation.difference, path, boxPath);
    canvas.drawPath(overlayPath, backgroundPaint);

    final Paint borderPaint = Paint()
      ..color = SKColors.primaryBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    double cornerSize = 30.0;
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.top + cornerSize)
          ..lineTo(scanRect.left, scanRect.top)
          ..lineTo(scanRect.left + cornerSize, scanRect.top),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - cornerSize, scanRect.top)
          ..lineTo(scanRect.right, scanRect.top)
          ..lineTo(scanRect.right, scanRect.top + cornerSize),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.left, scanRect.bottom - cornerSize)
          ..lineTo(scanRect.left, scanRect.bottom)
          ..lineTo(scanRect.left + cornerSize, scanRect.bottom),
        borderPaint);
    canvas.drawPath(
        Path()
          ..moveTo(scanRect.right - cornerSize, scanRect.bottom)
          ..lineTo(scanRect.right, scanRect.bottom)
          ..lineTo(scanRect.right, scanRect.bottom - cornerSize),
        borderPaint);

    final double laserY = scanRect.top + (scanRect.height * animation.value);
    final Paint laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          SKColors.primaryBright.withOpacity(0),
          SKColors.primaryBright,
          SKColors.primaryBright.withOpacity(0)
        ],
      ).createShader(
        Rect.fromLTWH(scanRect.left, laserY, scanRect.width, 2),
      );

    canvas.drawRect(
      Rect.fromLTWH(scanRect.left + 10, laserY, scanRect.width - 20, 2),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 2. GENERATOR PAGE
// ---------------------------------------------------------------------------
class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final _controller = TextEditingController();
  final GlobalKey _qrRepaintKey = GlobalKey();
  String _data = "";
  String? _lastSavedData;

  Future<void> _downloadQr() async {
    if (_data.isEmpty) return;
    if (_data == _lastSavedData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Already Saved !"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      RenderRepaintBoundary boundary = _qrRepaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        if (androidInfo.version.sdkInt >= 30) {
          Directory downloadDir = Directory('/storage/emulated/0/Download');
          final skFolder = Directory('${downloadDir.path}/QR Scan & Generate');
          if (!await skFolder.exists()) {
            await skFolder.create(recursive: true);
          }
          final fileName = 'QR_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File('${skFolder.path}/$fileName');
          await file.writeAsBytes(pngBytes);
          if (mounted) {
            _lastSavedData = _data;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Saved to Downloads!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          var status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Storage Permission Denied"),
                ),
              );
            }
            return;
          }
          Directory downloadDir = Directory('/storage/emulated/0/Download');
          final fileName = 'QR_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File('${downloadDir.path}/$fileName');
          await file.writeAsBytes(pngBytes);
          if (mounted) {
            _lastSavedData = _data;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Saved to Downloads!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SKAppBar(title: "Generate QR"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: "Enter text, URL or Email",
                  hintText: "e.g., SK Tech Studio",
                  labelStyle: const TextStyle(color: SKColors.primaryMedium),
                  focusedBorder: const OutlineInputBorder(
                    borderSide:
                        BorderSide(color: SKColors.primaryBright, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon:
                      const Icon(Icons.edit, color: SKColors.primaryMedium),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _data = "";
                        _lastSavedData = null;
                      });
                    },
                  ),
                ),
                onChanged: (val) => setState(() {
                  _data = val;
                  _lastSavedData = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "If you want to save image, video or PDF, paste its link here",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            //banner ad

            const SizedBox(height: 10),
            MyBannerAd(adUnitId: AdHelper.generatorBannerTopAdUnitId),
            const SizedBox(height: 30),

            if (_data.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: RepaintBoundary(
                    key: _qrRepaintKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SKColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: SKColors.primaryDark.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                        border: Border.all(color: SKColors.softBorder),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: QrImageView(
                        data: _data,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: SKColors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Inline Adaptive Banner Ad
              const InlineAdaptiveBannerAd(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SKColors.mainGradient.colors.first,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _downloadQr,
                    icon: const Icon(Icons.download),
                    label: const Text("Download PNG"),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Opacity(
                      opacity: 0.6,
                      child: Image.asset(
                        "assets/QR Scan & Generate.png",
                        width: 100,
                        height: 100,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 100,
                          color: SKColors.softBorder,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Type something to generate",
                      style: TextStyle(
                        color: SKColors.primaryMedium.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Inline Adaptive Banner Ad
                    const InlineAdaptiveBannerAd(),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. SETTINGS PAGE
// ---------------------------------------------------------------------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'sktechstudio25@gmail.com',
      query: 'subject=Feedback for QR Scan & Generate App',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  void _shareApp() {
    Share.share(AppLinks.shareMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SKAppBar(title: "Settings"),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: const BoxDecoration(
              gradient: SKColors.mainGradient,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: SKColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    "assets/QR Scan & Generate.png",
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.qr_code_2,
                      size: 50,
                      color: SKColors.primaryMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "QR Scan & Generate",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: SKColors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Powered by SK Tech Studio",
                      style: TextStyle(
                        color: SKColors.softBorder,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.share, color: SKColors.primaryMedium),
            title: const Text("Share App"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _shareApp,
          ),
          ListTile(
            leading: const Icon(Icons.star_rate, color: SKColors.primaryMedium),
            title: const Text("Rate Us"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(AppLinks.rateUs),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined,
                color: SKColors.primaryMedium),
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(AppLinks.privacyPolicy),
          ),
          ListTile(
            leading:
                const Icon(Icons.description, color: SKColors.primaryMedium),
            title: const Text("Terms & Conditions"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(AppLinks.termsConditions),
          ),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded,
                color: SKColors.primaryMedium),
            title: const Text("Disclaimer"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(AppLinks.disclaimer),
          ),
          ListTile(
            leading: const Icon(Icons.feedback, color: SKColors.primaryMedium),
            title: const Text("Feedback"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _sendFeedback,
          ),
          const SizedBox(height: 10),
          MyBannerAd(adUnitId: AdHelper.settingsBannerAdUnitId),
          const SizedBox(height: 10),
          Center(
            child: Text(
              "Version 1.0.0",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
