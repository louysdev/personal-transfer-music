import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/transfer_models.dart';
import 'dart:async';

/// Provider for managing transfer all playlists state
class TransferAllProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  bool _isTransferring = false;
  String? _errorMessage;
  List<SpotifyPlaylist> _playlists = [];
  Set<String> _selectedPlaylistIds = {};
  String? _transferId;
  TransferProgress? _transferProgress;
  Timer? _pollingTimer;
  String _authHeaders = '';
  String _spotifyToken = '';


  // Getters
  bool get isLoading => _isLoading;
  bool get isTransferring => _isTransferring;
  String? get errorMessage => _errorMessage;
  List<SpotifyPlaylist> get playlists => _playlists;
  Set<String> get selectedPlaylistIds => _selectedPlaylistIds;
  String? get transferId => _transferId;
  TransferProgress? get transferProgress => _transferProgress;
  String get authHeaders => _authHeaders;
  String get spotifyToken => _spotifyToken;

  
  bool get hasPlaylists => _playlists.isNotEmpty;
  bool get hasSelection => _selectedPlaylistIds.isNotEmpty;
  int get selectedCount => _selectedPlaylistIds.length;
  int get totalCount => _playlists.length;
  bool get allSelected => _selectedPlaylistIds.length == _playlists.length;

  ApiService _apiService;
  late AuthService _authService;
  String _currentBaseUrl;

  TransferAllProvider({ApiService? apiService, String? baseUrl}) 
      : _apiService = apiService ?? ApiService(baseUrl: baseUrl),
        _currentBaseUrl = baseUrl ?? '' {
        _authService = AuthService(_apiService);
        _initAuth();
      }

  Future<void> _initAuth() async {
    await _authService.initialize();
  }

  /// Update API base URL and reinitialize services
  Future<void> updateBaseUrl(String newUrl) async {
    if (_currentBaseUrl != newUrl) {
      _currentBaseUrl = newUrl;
      _authService.dispose();
      _apiService = ApiService(baseUrl: newUrl);
      _authService = AuthService(_apiService);
      await _initAuth(); // Wait for initialization to complete
    }
  }



  /// Set auth headers
  void setAuthHeaders(String headers) {
    _authHeaders = headers;
    notifyListeners();
  }

  /// Set Spotify token
  void setSpotifyToken(String token) {
    _spotifyToken = token;
    notifyListeners();
  }

  /// Load playlists from Spotify
  Future<bool> loadPlaylists() async {
    if (_spotifyToken.isEmpty) {
      _errorMessage = 'Spotify token is required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getSpotifyPlaylists(
        spotifyToken: _spotifyToken,
      );

      if (response.success && response.data != null) {
        _playlists = response.data!
            .map((json) => SpotifyPlaylist.fromJson(json))
            .toList();
        // Select all by default
        _selectedPlaylistIds = _playlists.map((p) => p.id).toSet();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Failed to load playlists';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error loading playlists: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle playlist selection
  void togglePlaylistSelection(String playlistId) {
    if (_selectedPlaylistIds.contains(playlistId)) {
      _selectedPlaylistIds.remove(playlistId);
    } else {
      _selectedPlaylistIds.add(playlistId);
    }
    notifyListeners();
  }

  /// Select all playlists
  void selectAll() {
    _selectedPlaylistIds = _playlists.map((p) => p.id).toSet();
    notifyListeners();
  }

  /// Deselect all playlists
  void deselectAll() {
    _selectedPlaylistIds.clear();
    notifyListeners();
  }

  /// Toggle select all
  void toggleSelectAll() {
    if (allSelected) {
      deselectAll();
    } else {
      selectAll();
    }
  }

  /// Start transfer of selected playlists
  Future<bool> startTransfer() async {
    if (_authHeaders.isEmpty) {
      _errorMessage = 'YouTube Music auth headers are required';
      notifyListeners();
      return false;
    }

    if (_selectedPlaylistIds.isEmpty) {
      _errorMessage = 'Please select at least one playlist';
      notifyListeners();
      return false;
    }

    _isTransferring = true;
    _errorMessage = null;
    _transferProgress = null;
    notifyListeners();

    try {
      final response = await _apiService.transferAllPlaylists(
        spotifyToken: _spotifyToken,
        authHeaders: _authHeaders,
        playlistIds: _selectedPlaylistIds.toList(),
      );

      if (response.success && response.data != null) {
        _transferId = response.data!['transfer_id'];
        _startPolling();
        return true;
      } else {
        _errorMessage = response.message ?? 'Failed to start transfer';
        _isTransferring = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error starting transfer: $e';
      _isTransferring = false;
      notifyListeners();
      return false;
    }
  }

  /// Start polling for transfer status
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _pollStatus();
    });
  }

  /// Poll transfer status
  Future<void> _pollStatus() async {
    if (_transferId == null) return;

    try {
      final response = await _apiService.getTransferStatus(
        transferId: _transferId!,
      );

      if (response.success && response.data != null) {
        _transferProgress = TransferProgress.fromJson(response.data!);
        notifyListeners();

        // Stop polling if transfer is complete
        if (_transferProgress!.isCompleted || 
            _transferProgress!.hasError ||
            _transferProgress!.isCancelled) {
          _stopPolling();
          _isTransferring = false;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error polling status: $e');
    }
  }

  /// Stop polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Cancel ongoing transfer
  Future<void> cancelTransfer() async {
    _stopPolling();

    if (_transferId != null) {
      try {
        await _apiService.cancelTransfer(transferId: _transferId!);
      } catch (e) {
        print('Error cancelling transfer: $e');
      }
    }

    _isTransferring = false;
    _transferProgress = null;
    _transferId = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _stopPolling();
    _isLoading = false;
    _isTransferring = false;
    _errorMessage = null;
    _playlists = [];
    _selectedPlaylistIds = {};
    _transferId = null;
    _transferProgress = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sign in with Spotify (Native)
  Future<void> signInWithSpotify() async {
    _isLoading = true;
    notifyListeners();
    
    final token = await _authService.signInWithSpotify();
    
    if (token != null) {
      _spotifyToken = token;
      await loadPlaylists(); // Auto load playlists after login
    } else {
      _errorMessage = 'Failed to sign in with Spotify';
    }
    
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
