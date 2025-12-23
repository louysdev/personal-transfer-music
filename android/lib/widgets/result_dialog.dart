import 'package:flutter/material.dart';
import '../models/transfer_models.dart';
import '../config/theme.dart';

class ResultDialog extends StatelessWidget {
  final String title;
  final String message;
  final MissedTracksResult missedTracks;
  final VoidCallback onClose;

  const ResultDialog({
    super.key,
    required this.title,
    required this.message,
    required this.missedTracks,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasMissedTracks = missedTracks.count > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasMissedTracks ? Icons.warning_amber : Icons.check_circle,
            color: hasMissedTracks ? AppTheme.warningColor : AppTheme.successColor,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (hasMissedTracks) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${missedTracks.count} tracks could not be found',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...missedTracks.tracks.take(10).map((track) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.music_off, 
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  track,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (missedTracks.tracks.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${missedTracks.tracks.length - 10} more',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, color: AppTheme.successColor),
                    SizedBox(width: 8),
                    Text(
                      'All tracks transferred successfully!',
                      style: TextStyle(color: AppTheme.successColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: onClose,
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Dialog to show when playlist already exists
class PlaylistExistsDialog extends StatelessWidget {
  final String playlistName;
  final VoidCallback onClose;

  const PlaylistExistsDialog({
    super.key,
    required this.playlistName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('Playlist Exists'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The playlist "$playlistName" already exists in your YouTube Music library.',
          ),
          const SizedBox(height: 12),
          const Text(
            'No changes were made since all tracks are already present.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: onClose,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
