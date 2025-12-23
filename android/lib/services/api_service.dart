import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../config/app_config.dart';

/// Crea un cliente HTTP que acepta todos los certificados (solo para desarrollo)
http.Client createHttpClient() {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  return IOClient(httpClient);
}

/// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    required this.statusCode,
  });
}

/// Service class for API calls to the backend
class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? createHttpClient();

  /// Test connection to the server
  Future<ApiResponse<Map<String, dynamic>>> testConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: jsonDecode(response.body),
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Connection error: $e',
        statusCode: 0,
      );
    }
  }

  /// Create/transfer a single playlist from Spotify to YouTube Music
  Future<ApiResponse<Map<String, dynamic>>> createPlaylist({
    required String playlistUrl,
    required String authHeaders,
  }) async {
    try {
      print('Making request to: $baseUrl${AppConfig.createPlaylistEndpoint}');
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.createPlaylistEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'playlist_link': playlistUrl,
          'auth_headers': authHeaders,
        }),
      ).timeout(const Duration(minutes: 5));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.body.isEmpty) {
        return ApiResponse(
          success: false,
          message: 'Empty response from server',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Failed to create playlist',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  /// Get all playlists from Spotify
  Future<ApiResponse<List<dynamic>>> getSpotifyPlaylists({
    required String spotifyToken,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.playlistsEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'spotify_token': spotifyToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data['playlists'] as List<dynamic>,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Failed to get playlists',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  /// Transfer all playlists to YouTube Music
  Future<ApiResponse<Map<String, dynamic>>> transferAllPlaylists({
    required String spotifyToken,
    required String authHeaders,
    List<String>? playlistIds,
  }) async {
    try {
      final body = {
        'spotify_token': spotifyToken,
        'auth_headers': authHeaders,
      };
      
      if (playlistIds != null && playlistIds.isNotEmpty) {
        body['playlist_ids'] = playlistIds as dynamic;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.transferAllEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 202) {
        return ApiResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Failed to start transfer',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  /// Get transfer status
  Future<ApiResponse<Map<String, dynamic>>> getTransferStatus({
    required String transferId,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl${AppConfig.transferStatusEndpoint}/$transferId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Transfer not found',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  /// Cancel transfer
  Future<ApiResponse<Map<String, dynamic>>> cancelTransfer({
    required String transferId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.transferCancelEndpoint}/$transferId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      return ApiResponse(
        success: response.statusCode == 200,
        data: data,
        message: data['message'],
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  /// Get YouTube Music playlists
  Future<ApiResponse<List<dynamic>>> getYtmPlaylists({
    required String authHeaders,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl${AppConfig.ytmPlaylistsEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'auth_headers': authHeaders}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: data['playlists'] as List<dynamic>,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Failed to get playlists',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Error: $e',
        statusCode: 0,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
