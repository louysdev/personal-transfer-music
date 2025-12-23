import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../config/theme.dart';
import '../widgets/result_dialog.dart';

class SinglePlaylistScreen extends StatefulWidget {
  const SinglePlaylistScreen({super.key});

  @override
  State<SinglePlaylistScreen> createState() => _SinglePlaylistScreenState();
}

class _SinglePlaylistScreenState extends State<SinglePlaylistScreen> {
  final _playlistUrlController = TextEditingController();
  final _authHeadersController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showHeaders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransferProvider>();
      _authHeadersController.text = provider.authHeaders;
    });
  }

  @override
  void dispose() {
    _playlistUrlController.dispose();
    _authHeadersController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      controller.text = data!.text!;
      if (controller == _authHeadersController) {
        context.read<TransferProvider>().setAuthHeaders(data.text!);
      } else if (controller == _playlistUrlController) {
        context.read<TransferProvider>().setPlaylistUrl(data.text!);
      }
    }
  }

  Future<void> _transferPlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransferProvider>();
    provider.setPlaylistUrl(_playlistUrlController.text);
    provider.setAuthHeaders(_authHeadersController.text);

    final success = await provider.transferSinglePlaylist();

    if (mounted) {
      if (success) {
        _showSuccessDialog(provider);
      } else {
        _showErrorSnackbar(provider.errorMessage ?? 'Transfer failed');
      }
    }
  }

  void _showSuccessDialog(TransferProvider provider) {
    final response = provider.lastResponse;
    if (response == null) return;

    showDialog(
      context: context,
      builder: (context) => ResultDialog(
        title: response.missedTracks.playlistUpdated
            ? 'Playlist Updated!'
            : 'Playlist Created!',
        message: response.message,
        missedTracks: response.missedTracks,
        onClose: () {
          Navigator.pop(context);
          provider.reset();
          _playlistUrlController.clear();
        },
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Playlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note, 
                                  color: AppTheme.primaryColor, size: 32),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 24),
                              const SizedBox(width: 8),
                              Icon(Icons.play_circle_filled, 
                                  color: AppTheme.secondaryColor, size: 32),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Spotify to YouTube Music',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transfer a single playlist with all its tracks',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Spotify Playlist URL
                  Text(
                    'Spotify Playlist URL',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _playlistUrlController,
                    decoration: InputDecoration(
                      hintText: 'https://open.spotify.com/playlist/...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste),
                        onPressed: () => _pasteFromClipboard(_playlistUrlController),
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Spotify playlist URL';
                      }
                      if (!provider.isValidPlaylistUrl(value)) {
                        return 'Invalid Spotify playlist URL';
                      }
                      return null;
                    },
                    onChanged: provider.setPlaylistUrl,
                  ),
                  const SizedBox(height: 24),

                  // YouTube Music Auth Headers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YouTube Music Auth Headers',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton.icon(
                        icon: Icon(_showHeaders 
                            ? Icons.visibility_off 
                            : Icons.visibility),
                        label: Text(_showHeaders ? 'Hide' : 'Show'),
                        onPressed: () {
                          setState(() {
                            _showHeaders = !_showHeaders;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _authHeadersController,
                    decoration: InputDecoration(
                      hintText: 'Paste your auth headers here...',
                      prefixIcon: const Icon(Icons.security),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste),
                        onPressed: () => _pasteFromClipboard(_authHeadersController),
                        tooltip: 'Paste from clipboard',
                      ),
                    ),
                    maxLines: _showHeaders ? 6 : 1,
                    obscureText: !_showHeaders,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter YouTube Music auth headers';
                      }
                      return null;
                    },
                    onChanged: provider.setAuthHeaders,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get headers from YouTube Music website (see Help)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Transfer Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : _transferPlaylist,
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_alt),
                      label: Text(
                        provider.isLoading ? 'Transferring...' : 'Transfer Playlist',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  // Error message
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, 
                              color: AppTheme.errorColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, 
                                color: AppTheme.errorColor, size: 18),
                            onPressed: provider.clearError,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to get Auth Headers'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpStep(1, 'Open Developer Tools in your browser'),
              _buildHelpStep(2, 'Go to music.youtube.com and sign in'),
              _buildHelpStep(3, 'Go to the Network tab'),
              _buildHelpStep(4, 'Filter by "/browse"'),
              _buildHelpStep(5, 'Find a POST request with status 200'),
              _buildHelpStep(6, 'Copy the request headers'),
              const SizedBox(height: 16),
              const Text(
                'Firefox: Right click → Copy → Copy request headers\n\n'
                'Chrome: Click request → Headers tab → Copy "Request Headers"',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
