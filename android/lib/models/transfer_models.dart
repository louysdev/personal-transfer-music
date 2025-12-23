/// Model for missed tracks result
class MissedTracksResult {
  final int count;
  final List<String> tracks;
  final bool playlistExists;
  final bool playlistUpdated;
  final String? playlistName;

  MissedTracksResult({
    required this.count,
    required this.tracks,
    this.playlistExists = false,
    this.playlistUpdated = false,
    this.playlistName,
  });

  factory MissedTracksResult.fromJson(Map<String, dynamic> json) {
    return MissedTracksResult(
      count: json['count'] ?? 0,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      playlistExists: json['playlist_exists'] ?? false,
      playlistUpdated: json['playlist_updated'] ?? false,
      playlistName: json['playlist_name'],
    );
  }
}

/// Model for create playlist response
class CreatePlaylistResponse {
  final String message;
  final MissedTracksResult missedTracks;

  CreatePlaylistResponse({
    required this.message,
    required this.missedTracks,
  });

  factory CreatePlaylistResponse.fromJson(Map<String, dynamic> json) {
    return CreatePlaylistResponse(
      message: json['message'] ?? '',
      missedTracks: MissedTracksResult.fromJson(
        json['missed_tracks'] ?? {},
      ),
    );
  }
}

/// Model for a Spotify playlist
class SpotifyPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? image;
  final int trackCount;

  SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.image,
    required this.trackCount,
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) {
    return SpotifyPlaylist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      image: json['image'],
      trackCount: json['tracks'] ?? 0,
    );
  }
}

/// Transfer status enum
enum TransferStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
  skipped,
}

/// Model for transfer progress
class TransferProgress {
  final String status;
  final int totalPlaylists;
  final int processed;
  final int successful;
  final int failed;
  final int skipped;
  final List<PlaylistTransferStatus> playlists;
  final String? error;

  TransferProgress({
    required this.status,
    required this.totalPlaylists,
    required this.processed,
    required this.successful,
    required this.failed,
    required this.skipped,
    required this.playlists,
    this.error,
  });

  factory TransferProgress.fromJson(Map<String, dynamic> json) {
    return TransferProgress(
      status: json['status'] ?? 'unknown',
      totalPlaylists: json['total_playlists'] ?? 0,
      processed: json['processed'] ?? 0,
      successful: json['successful'] ?? 0,
      failed: json['failed'] ?? 0,
      skipped: json['skipped'] ?? 0,
      playlists: (json['playlists'] as List<dynamic>?)
              ?.map((e) => PlaylistTransferStatus.fromJson(e))
              .toList() ??
          [],
      error: json['error'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get hasError => status == 'error';
  bool get isCancelled => status == 'cancelled';
}

/// Model for individual playlist transfer status
class PlaylistTransferStatus {
  final String id;
  final String name;
  final String status;
  final String? image;
  final String? error;

  PlaylistTransferStatus({
    required this.id,
    required this.name,
    required this.status,
    this.image,
    this.error,
  });

  factory PlaylistTransferStatus.fromJson(Map<String, dynamic> json) {
    return PlaylistTransferStatus(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'pending',
      image: json['image'],
      error: json['error'],
    );
  }
}
