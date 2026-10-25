import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

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
          const SizedBox(height: 20),
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
