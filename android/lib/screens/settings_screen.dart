import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../config/app_config.dart';
import '../config/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  bool _testingConnection = false;
  bool? _connectionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransferProvider>();
      _serverUrlController.text = provider.baseUrl;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionStatus = null;
    });

    final provider = context.read<TransferProvider>();
    await provider.saveBaseUrl(_serverUrlController.text);
    final success = await provider.testConnection();

    setState(() {
      _testingConnection = false;
      _connectionStatus = success;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Connected successfully!' 
              : 'Connection failed: ${provider.errorMessage}'),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _clearAuthHeaders() async {
    final provider = context.read<TransferProvider>();
    await provider.saveAuthHeaders('');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auth headers cleared'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Server Configuration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dns_outlined),
                          const SizedBox(width: 8),
                          Text(
                            'Server Configuration',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Backend Server URL',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _serverUrlController,
                        decoration: InputDecoration(
                          hintText: 'http://localhost:5000',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: _connectionStatus != null
                              ? Icon(
                                  _connectionStatus!
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _connectionStatus!
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                )
                              : null,
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'For Android emulator use: http://10.0.2.2:5000\n'
                        'For iOS simulator use: http://localhost:5000\n'
                        'For physical device use your computer\'s IP',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testingConnection
                                  ? null
                                  : _testConnection,
                              icon: _testingConnection
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.wifi_find),
                              label: Text(_testingConnection
                                  ? 'Testing...'
                                  : 'Test Connection'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await provider.saveBaseUrl(
                                    _serverUrlController.text);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Settings saved'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Auth Headers Management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security_outlined),
                          const SizedBox(width: 8),
                          Text(
                            'YouTube Music Authentication',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save your auth headers here to use across the entire app',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: provider.authHeaders.isNotEmpty
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: provider.authHeaders.isNotEmpty
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              provider.authHeaders.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: provider.authHeaders.isNotEmpty
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                provider.authHeaders.isNotEmpty
                                    ? 'Headers saved (${provider.authHeaders.length} characters)'
                                    : 'No headers saved - paste below',
                                style: TextStyle(
                                  color: provider.authHeaders.isNotEmpty
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Auth headers input
                      TextFormField(
                        initialValue: provider.authHeaders,
                        decoration: InputDecoration(
                          hintText: 'Paste your YouTube Music auth headers here...',
                          prefixIcon: const Icon(Icons.vpn_key),
                          helperText: 'Get from Developer Tools → Network → Copy request headers',
                          helperStyle: const TextStyle(fontSize: 11),
                        ),
                        maxLines: 5,
                        onChanged: (value) {
                          provider.saveAuthHeaders(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: provider.authHeaders.isNotEmpty
                                  ? _clearAuthHeaders
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear Headers'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null) {
                                  await provider.saveAuthHeaders(data!.text!);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Headers pasted and saved!'),
                                        backgroundColor: AppTheme.successColor,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.content_paste),
                              label: const Text('Paste & Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Text(
                            'About',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Music Transfer'),
                        subtitle: Text(
                          'Version ${AppConfig.appVersion}\n'
                          'Transfer playlists from Spotify to YouTube Music',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
