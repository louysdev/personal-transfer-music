import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/transfer_all_provider.dart';
import '../providers/transfer_provider.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../models/transfer_models.dart';

class TransferAllScreen extends StatefulWidget {
  const TransferAllScreen({super.key});

  @override
  State<TransferAllScreen> createState() => _TransferAllScreenState();
}

class _TransferAllScreenState extends State<TransferAllScreen> {
  final _spotifyTokenController = TextEditingController();
  final _authHeadersController = TextEditingController();
  bool _showHeaders = false;

  @override
  void dispose() {
    _spotifyTokenController.dispose();
    _authHeadersController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard(TextEditingController controller, String field) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      controller.text = data!.text!;
      final provider = context.read<TransferAllProvider>();
      if (field == 'token') {
        provider.setSpotifyToken(data.text!);
      } else if (field == 'headers') {
        provider.setAuthHeaders(data.text!);
      }
    }
  }

  Future<void> _loginWithSpotify(TransferAllProvider provider) async {
    // Get base URL from settings
    final baseUrl = context.read<TransferProvider>().baseUrl;
    final authUrl = '$baseUrl${AppConfig.spotifyAuthEndpoint}';
    
    // Show instructions dialog first
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.music_note, color: Color(0xFF1DB954)),
              SizedBox(width: 8),
              Text('Spotify Login'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A browser will open for Spotify login.'),
              SizedBox(height: 16),
              Text('After logging in:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Copy the token shown on the page'),
              Text('2. Return to this app'),
              Text('3. Paste the token using the paste button'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final uri = Uri.parse(authUrl);
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && mounted) {
                    _showErrorSnackbar('Could not open browser. URL: $authUrl');
                  }
                } catch (e) {
                  if (mounted) {
                    _showErrorSnackbar('Error opening browser: $e');
                  }
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open Browser'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer All Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Consumer<TransferAllProvider>(
        builder: (context, provider, child) {
          // Show transfer progress dialog if transferring
          if (provider.isTransferring || provider.transferProgress != null) {
            return _buildTransferProgressView(provider);
          }

          // Show playlist selection if playlists are loaded
          if (provider.hasPlaylists) {
            return _buildPlaylistSelectionView(provider);
          }

          // Show initial input form
          return _buildInputForm(provider);
        },
      ),
    );
  }

  Widget _buildInputForm(TransferAllProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                      Icon(Icons.library_music, 
                          color: AppTheme.primaryColor, size: 32),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 24),
                      const SizedBox(width: 8),
                      Icon(Icons.queue_music, 
                          color: AppTheme.secondaryColor, size: 32),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Transfer All Playlists',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transfer multiple playlists from Spotify to YouTube Music',
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

          // Spotify Login Section
          Card(
            color: const Color(0xFF1DB954).withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spotify Account',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              provider.spotifyToken.isEmpty 
                                  ? 'Not connected' 
                                  : 'Connected ✓',
                              style: TextStyle(
                                color: provider.spotifyToken.isEmpty 
                                    ? Colors.grey 
                                    : AppTheme.successColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _loginWithSpotify(provider),
                      icon: const Icon(Icons.login),
                      label: Text(
                        provider.spotifyToken.isEmpty 
                            ? 'Login with Spotify' 
                            : 'Re-authenticate',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Opens browser to authenticate with Spotify',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  // Token input (collapsible for manual paste)
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: const Text('Or paste token manually', 
                        style: TextStyle(fontSize: 13)),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    children: [
                      TextFormField(
                        controller: _spotifyTokenController,
                        decoration: InputDecoration(
                          hintText: 'Paste your Spotify access token...',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste),
                            onPressed: () => _pasteFromClipboard(_spotifyTokenController, 'token'),
                            tooltip: 'Paste from clipboard',
                          ),
                        ),
                        maxLines: 1,
                        obscureText: true,
                        onChanged: provider.setSpotifyToken,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                icon: Icon(_showHeaders ? Icons.visibility_off : Icons.visibility),
                label: Text(_showHeaders ? 'Hide' : 'Show'),
                onPressed: () => setState(() => _showHeaders = !_showHeaders),
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
                onPressed: () => _pasteFromClipboard(_authHeadersController, 'headers'),
                tooltip: 'Paste from clipboard',
              ),
            ),
            maxLines: _showHeaders ? 6 : 1,
            obscureText: !_showHeaders,
            onChanged: provider.setAuthHeaders,
          ),
          const SizedBox(height: 32),

          // Load Playlists Button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.loadPlaylists();
                      if (!success && mounted) {
                        _showErrorSnackbar(provider.errorMessage ?? 'Failed to load playlists');
                      }
                    },
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download),
              label: Text(
                provider.isLoading ? 'Loading...' : 'Load Playlists from Spotify',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          // Error message
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistSelectionView(TransferAllProvider provider) {
    return Column(
      children: [
        // Header with selection controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${provider.selectedCount}/${provider.totalCount} selected',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: provider.toggleSelectAll,
                        child: Text(provider.allSelected ? 'Deselect All' : 'Select All'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                        onPressed: provider.reset,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Playlist list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.playlists.length,
            itemBuilder: (context, index) {
              final playlist = provider.playlists[index];
              final isSelected = provider.selectedPlaylistIds.contains(playlist.id);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: playlist.image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            playlist.image!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[800],
                              child: const Icon(Icons.music_note),
                            ),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.music_note),
                        ),
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${playlist.trackCount} tracks'),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => provider.togglePlaylistSelection(playlist.id),
                    activeColor: AppTheme.primaryColor,
                  ),
                  onTap: () => provider.togglePlaylistSelection(playlist.id),
                ),
              );
            },
          ),
        ),

        // Transfer button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: provider.hasSelection
                  ? () async {
                      final success = await provider.startTransfer();
                      if (!success && mounted) {
                        _showErrorSnackbar(provider.errorMessage ?? 'Failed to start transfer');
                      }
                    }
                  : null,
              icon: const Icon(Icons.sync_alt),
              label: Text(
                'Transfer ${provider.selectedCount} Playlists',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),

        // Error message
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildErrorBanner(provider),
          ),
      ],
    );
  }

  Widget _buildTransferProgressView(TransferAllProvider provider) {
    final progress = provider.transferProgress;

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Text(
                provider.isTransferring ? 'Transferring...' : 'Transfer Complete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (progress != null) ...[
                // Progress bar
                LinearProgressIndicator(
                  value: progress.totalPlaylists > 0
                      ? progress.processed / progress.totalPlaylists
                      : 0,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.isCompleted ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.processed}/${progress.totalPlaylists} playlists processed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(Icons.check_circle, '${progress.successful}', AppTheme.successColor),
                    const SizedBox(width: 16),
                    _buildStatChip(Icons.error, '${progress.failed}', AppTheme.errorColor),
                    const SizedBox(width: 16),
                    _buildStatChip(Icons.skip_next, '${progress.skipped}', AppTheme.warningColor),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Playlist status list
        if (progress != null)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: progress.playlists.length,
              itemBuilder: (context, index) {
                final playlist = progress.playlists[index];
                return _buildPlaylistStatusTile(playlist);
              },
            ),
          ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (provider.isTransferring) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.cancelTransfer,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Transfer More'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistStatusTile(PlaylistTransferStatus playlist) {
    IconData icon;
    Color color;

    switch (playlist.status) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.grey;
        break;
      case 'processing':
      case 'fetching_details':
      case 'searching_songs':
      case 'checking_existing':
      case 'creating':
      case 'updating':
        icon = Icons.sync;
        color = AppTheme.primaryColor;
        break;
      case 'created':
      case 'updated':
      case 'up_to_date':
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case 'failed':
      case 'error':
        icon = Icons.error;
        color = AppTheme.errorColor;
        break;
      case 'skipped':
        icon = Icons.skip_next;
        color = AppTheme.warningColor;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: playlist.image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  playlist.image!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, size: 20),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note, size: 20),
              ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _getStatusText(playlist.status),
          style: TextStyle(color: color),
        ),
        trailing: playlist.status.contains('ing') && playlist.status != 'pending'
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, color: color),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting...';
      case 'processing':
        return 'Processing...';
      case 'fetching_details':
        return 'Fetching details...';
      case 'searching_songs':
        return 'Searching songs...';
      case 'checking_existing':
        return 'Checking if exists...';
      case 'creating':
        return 'Creating playlist...';
      case 'updating':
        return 'Updating playlist...';
      case 'created':
        return 'Created successfully';
      case 'updated':
        return 'Updated successfully';
      case 'up_to_date':
        return 'Already up to date';
      case 'failed':
      case 'error':
        return 'Failed';
      case 'skipped':
        return 'Skipped';
      default:
        return status;
    }
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildErrorBanner(TransferAllProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.errorColor, size: 18),
            onPressed: provider.clearError,
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Transfer All Playlists'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection('Getting Spotify Token'),
              _buildHelpStep(1, 'Login with Spotify via the web app'),
              _buildHelpStep(2, 'Copy the access token from /auth/token'),
              const SizedBox(height: 16),
              _buildHelpSection('Getting YouTube Headers'),
              _buildHelpStep(1, 'Open Developer Tools on music.youtube.com'),
              _buildHelpStep(2, 'Go to Network tab, filter by "/browse"'),
              _buildHelpStep(3, 'Copy request headers from a POST request'),
              const SizedBox(height: 16),
              const Text(
                'Note: Both credentials are required to transfer all playlists.',
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

  Widget _buildHelpSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
