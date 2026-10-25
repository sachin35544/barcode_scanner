import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'main.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
