import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _appName = 'EVM Rider';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appName = info.appName.isEmpty ? 'EVM Rider' : info.appName;
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icon.png',
                  width: 96,
                  height: 96,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.blueGrey,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'A simple EVM log listening app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The app connects to the configured RPC endpoint, parses the ABI, '
                  'tracks selected events, and displays them in real time. It can '
                  'poll periodically, store recent events locally, and send '
                  'notifications when enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Text(
                  'Version: $_version+$_buildNumber',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: _appName,
                    applicationVersion: '$_version+$_buildNumber',
                    applicationIcon: Image.asset(
                      'assets/icon.png',
                      width: 56,
                      height: 56,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.info_outline);
                      },
                    ),
                  ),
                  icon: const Icon(Icons.description),
                  label: const Text('Licenses'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
