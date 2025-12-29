import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/transfer_models.dart';
import 'dart:async';

/// Provider for managing delete all playlists state
class DeleteAllProvider extends ChangeNotifier {
  // State
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;
  List<YTMPlaylist> _playlists = [];
  Set<String> _selectedPlaylistIds = {};
  String? _deleteId;
  DeleteProgress? _deleteProgress;
  Timer? _pollingTimer;
  String _authHeaders = '';


  // Getters
  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  String? get errorMessage => _errorMessage;
  List<YTMPlaylist> get playlists => _playlists;
  Set<String> get selectedPlaylistIds => _selectedPlaylistIds;
  String? get deleteId => _deleteId;
  DeleteProgress? get deleteProgress => _deleteProgress;
  String get authHeaders => _authHeaders;

  
  bool get hasPlaylists => _playlists.isNotEmpty;
  bool get hasSelection => _selectedPlaylistIds.isNotEmpty;
  int get selectedCount => _selectedPlaylistIds.length;
  int get totalCount => _playlists.length;
  bool get allSelected => _selectedPlaylistIds.length == _playlists.length;

  ApiService _apiService;
  late AuthService _authService;
  String _currentBaseUrl;

  DeleteAllProvider({ApiService? apiService, String? baseUrl}) 
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
      await _initAuth();
    }
  }



  /// Set auth headers
  void setAuthHeaders(String headers) {
    _authHeaders = headers;
    notifyListeners();
  }

  /// Load playlists from YouTube Music
  Future<bool> loadPlaylists() async {
    if (_authHeaders.isEmpty) {
      _errorMessage = 'YouTube Music auth headers are required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getYtmPlaylists(
        authHeaders: _authHeaders,
      );

      if (response.success && response.data != null) {
        _playlists = response.data!
            .map((json) => YTMPlaylist.fromJson(json))
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

  /// Start deletion of selected playlists
  Future<bool> startDelete() async {
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

    _isDeleting = true;
    _errorMessage = null;
    _deleteProgress = null;
    notifyListeners();

    try {
      final response = await _apiService.deleteSelectedPlaylists(
        authHeaders: _authHeaders,
        playlistIds: _selectedPlaylistIds.toList(),
      );

      if (response.success && response.data != null) {
        _deleteId = response.data!['delete_id'];
        _startPolling();
        return true;
      } else {
        _errorMessage = response.message ?? 'Failed to start deletion';
        _isDeleting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error starting deletion: $e';
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  /// Start polling for delete status
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _pollStatus();
    });
  }

  /// Poll delete status
  Future<void> _pollStatus() async {
    if (_deleteId == null) return;

    try {
      final response = await _apiService.getDeleteStatus(
        deleteId: _deleteId!,
      );

      if (response.success && response.data != null) {
        _deleteProgress = DeleteProgress.fromJson(response.data!);
        notifyListeners();

        // Stop polling if deletion is complete
        if (_deleteProgress!.isCompleted || 
            _deleteProgress!.hasError ||
            _deleteProgress!.isCancelled) {
          _stopPolling();
          _isDeleting = false;
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

  /// Cancel ongoing deletion
  Future<void> cancelDelete() async {
    _stopPolling();

    if (_deleteId != null) {
      try {
        await _apiService.cancelDelete(deleteId: _deleteId!);
      } catch (e) {
        print('Error cancelling deletion: $e');
      }
    }

    _isDeleting = false;
    _deleteProgress = null;
    _deleteId = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _stopPolling();
    _isLoading = false;
    _isDeleting = false;
    _errorMessage = null;
    _playlists = [];
    _selectedPlaylistIds = {};
    _deleteId = null;
    _deleteProgress = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
