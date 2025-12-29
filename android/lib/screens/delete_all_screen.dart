import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/delete_all_provider.dart';
import '../providers/transfer_provider.dart';
import '../config/theme.dart';
import '../models/transfer_models.dart';

class DeleteAllScreen extends StatefulWidget {
  const DeleteAllScreen({super.key});

  @override
  State<DeleteAllScreen> createState() => _DeleteAllScreenState();
}

class _DeleteAllScreenState extends State<DeleteAllScreen> {






  @override
  Widget build(BuildContext context) {
    // Listen for URL changes and Auth Headers from TransferProvider
    final transferProvider = context.watch<TransferProvider>();
    final currentUrl = transferProvider.baseUrl;
    final savedHeaders = transferProvider.authHeaders;
    
    final deleteAllProvider = context.read<DeleteAllProvider>();
    
    // Schedule state updates for after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deleteAllProvider.updateBaseUrl(currentUrl);
      
      // Auto-populate auth headers if saved in settings
      if (savedHeaders.isNotEmpty && deleteAllProvider.authHeaders.isEmpty) {
        deleteAllProvider.setAuthHeaders(savedHeaders);
      }
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Consumer<DeleteAllProvider>(
        builder: (context, provider, child) {
          // Show delete progress view if deleting
          if (provider.isDeleting || provider.deleteProgress != null) {
            return _buildDeleteProgressView(provider);
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

  Widget _buildInputForm(DeleteAllProvider provider) {
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_forever, 
                        color: Colors.red, size: 48),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delete YouTube Music Playlists',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Permanently delete playlists from your YouTube Music account',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Warning banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ Warning: This action will permanently delete the selected playlists. This cannot be undone!',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // YouTube Music Auth Section (Status from Settings)
          Card(
            color: const Color(0xFFFF0000).withValues(alpha: 0.1),
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
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YouTube Music',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              provider.authHeaders.isNotEmpty 
                                  ? 'Headers loaded from Settings ✓' 
                                  : 'No headers configured',
                              style: TextStyle(
                                color: provider.authHeaders.isNotEmpty
                                    ? AppTheme.successColor
                                    : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.authHeaders.isEmpty)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go to Settings'),
                        ),
                    ],
                  ),
                  if (provider.authHeaders.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please configure YouTube Music headers in Settings first.',
                              style: TextStyle(color: Colors.orange, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                provider.isLoading ? 'Loading...' : 'Load Playlists from YouTube Music',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
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

  Widget _buildPlaylistSelectionView(DeleteAllProvider provider) {
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
                  subtitle: Text('${playlist.count} tracks'),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => provider.togglePlaylistSelection(playlist.id),
                    activeColor: Colors.red,
                  ),
                  onTap: () => provider.togglePlaylistSelection(playlist.id),
                ),
              );
            },
          ),
        ),

        // Delete button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: provider.hasSelection
                  ? () => _showDeleteConfirmation(provider)
                  : null,
              icon: const Icon(Icons.delete_forever),
              label: Text(
                'Delete ${provider.selectedCount} Playlists',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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

  Widget _buildDeleteProgressView(DeleteAllProvider provider) {
    final progress = provider.deleteProgress;

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Text(
                provider.isDeleting ? 'Deleting...' : 'Deletion Complete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (progress != null) ...[
                // Progress bar
                LinearProgressIndicator(
                  value: progress.totalPlaylists > 0
                      ? (progress.deleted + progress.failed) / progress.totalPlaylists
                      : 0,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.isCompleted ? AppTheme.successColor : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.deleted + progress.failed}/${progress.totalPlaylists} playlists processed',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(Icons.check_circle, '${progress.deleted}', AppTheme.successColor),
                    const SizedBox(width: 16),
                    _buildStatChip(Icons.error, '${progress.failed}', AppTheme.errorColor),
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
              if (provider.isDeleting) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.cancelDelete,
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
                    label: const Text('Delete More'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistStatusTile(PlaylistDeleteStatus playlist) {
    IconData icon;
    Color color;

    switch (playlist.status) {
      case 'pending':
        icon = Icons.hourglass_empty;
        color = Colors.grey;
        break;
      case 'deleting':
        icon = Icons.sync;
        color = Colors.red;
        break;
      case 'deleted':
        icon = Icons.check_circle;
        color = AppTheme.successColor;
        break;
      case 'failed':
        icon = Icons.error;
        color = AppTheme.errorColor;
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
        subtitle: playlist.reason != null
            ? Text(
                playlist.reason!,
                style: TextStyle(color: color, fontSize: 12),
              )
            : Text(
                _getStatusText(playlist.status),
                style: TextStyle(color: color),
              ),
        trailing: playlist.status == 'deleting'
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
      case 'deleting':
        return 'Deleting...';
      case 'deleted':
        return 'Deleted successfully';
      case 'failed':
        return 'Failed';
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

  Widget _buildErrorBanner(DeleteAllProvider provider) {
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

  void _showDeleteConfirmation(DeleteAllProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${provider.selectedCount} playlist${provider.selectedCount != 1 ? 's' : ''}?\n\nThis action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.startDelete();
              if (!success && mounted) {
                _showErrorSnackbar(provider.errorMessage ?? 'Failed to start deletion');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete ${provider.selectedCount} Playlists'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Delete Playlists'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection('Connect to YouTube Music'),
              _buildHelpStep(1, 'Tap "Connect YouTube Music" to sign in'),
              _buildHelpStep(2, 'Or paste auth headers manually'),
              const SizedBox(height: 16),
              _buildHelpSection('Delete Playlists'),
              _buildHelpStep(1, 'Load your YouTube Music playlists'),
              _buildHelpStep(2, 'Select the playlists you want to delete'),
              _buildHelpStep(3, 'Confirm deletion'),
              const SizedBox(height: 16),
              const Text(
                'Warning: Deleted playlists cannot be recovered!',
                style: TextStyle(fontSize: 12, color: Colors.red),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              color: AppTheme.secondaryColor,
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
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
