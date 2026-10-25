import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

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
      body: Stack(
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                      if (ctx.mounted) Navigator.pop(ctx);
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
    const double scanBoxSize = 280.0;
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

    const double cornerSize = 30.0;
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
