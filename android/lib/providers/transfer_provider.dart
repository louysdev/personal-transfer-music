import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/transfer_models.dart';
import '../config/app_config.dart';

/// State for transfer operations
enum TransferState {
  idle,
  validating,
  transferring,
  completed,
  error,
}

/// Provider for managing transfer state and operations
class TransferProvider extends ChangeNotifier {
  // ignore: unused_field - kept for future use
  ApiService _apiService;
  AuthService? _authService;
  
  // State
  TransferState _state = TransferState.idle;
  String _playlistUrl = '';
  String _authHeaders = '';
  String _baseUrl = AppConfig.apiBaseUrl;
  bool _isServerOnline = false;
  String? _errorMessage;
  CreatePlaylistResponse? _lastResponse;
  bool _isLoading = false;
  bool _isGoogleConnected = false;

  // Getters
  TransferState get state => _state;
  String get playlistUrl => _playlistUrl;
  String get authHeaders => _authHeaders;
  String get baseUrl => _baseUrl;
  bool get isServerOnline => _isServerOnline;
  String? get errorMessage => _errorMessage;
  CreatePlaylistResponse? get lastResponse => _lastResponse;
  bool get isLoading => _isLoading;
  bool get isGoogleConnected => _isGoogleConnected;

  TransferProvider({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService() {
    _initAuthService();
  }
  
  Future<void> _initAuthService() async {
    _authService = AuthService(_apiService);
    await _authService!.initialize();
    _isGoogleConnected = _authService!.isSignedIn;
    notifyListeners();
  }

  /// Sign in with Google for YouTube Music access
  Future<bool> signInWithGoogle() async {
    if (_authService == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final success = await _authService!.signInWithGoogle();
      _isGoogleConnected = success;
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign out from Google
  Future<void> signOutFromGoogle() async {
    if (_authService == null) return;
    
    await _authService!.signOut();
    _isGoogleConnected = false;
    notifyListeners();
  }

  /// Load saved settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _authHeaders = prefs.getString('auth_headers') ?? '';
    _baseUrl = prefs.getString('base_url') ?? AppConfig.apiBaseUrl;
    notifyListeners();
  }

  /// Save auth headers to SharedPreferences
  Future<void> saveAuthHeaders(String headers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_headers', headers);
    _authHeaders = headers;
    notifyListeners();
  }

  /// Save base URL to SharedPreferences
  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
    _baseUrl = url;
    notifyListeners();
  }

  /// Update playlist URL
  void setPlaylistUrl(String url) {
    _playlistUrl = url;
    _errorMessage = null;
    notifyListeners();
  }

  /// Update auth headers (not saved until explicitly saved)
  void setAuthHeaders(String headers) {
    _authHeaders = headers;
    notifyListeners();
  }

  /// Validate Spotify playlist URL
  bool isValidPlaylistUrl(String url) {
    return AppConfig.spotifyPlaylistPattern.hasMatch(url);
  }

  /// Test connection to server
  Future<bool> testConnection() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = ApiService(baseUrl: _baseUrl);
      final response = await service.testConnection();
      
      _isServerOnline = response.success;
      if (!response.success) {
        _errorMessage = response.message;
      }
      
      return response.success;
    } catch (e) {
      _isServerOnline = false;
      _errorMessage = 'Connection failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Transfer a single playlist
  Future<bool> transferSinglePlaylist() async {
    // Validate inputs
    if (_playlistUrl.isEmpty) {
      _errorMessage = 'Please enter a Spotify playlist URL';
      notifyListeners();
      return false;
    }

    if (!isValidPlaylistUrl(_playlistUrl)) {
      _errorMessage = 'Invalid Spotify playlist URL';
      notifyListeners();
      return false;
    }

    if (_authHeaders.isEmpty) {
      _errorMessage = 'Please enter YouTube Music auth headers';
      notifyListeners();
      return false;
    }

    _state = TransferState.transferring;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = ApiService(baseUrl: _baseUrl);
      final response = await service.createPlaylist(
        playlistUrl: _playlistUrl,
        authHeaders: _authHeaders,
      );

      if (response.success && response.data != null) {
        _lastResponse = CreatePlaylistResponse.fromJson(response.data!);
        _state = TransferState.completed;
        
        // Save auth headers on successful transfer
        await saveAuthHeaders(_authHeaders);
        
        return true;
      } else {
        _state = TransferState.error;
        _errorMessage = response.message ?? 'Failed to transfer playlist';
        return false;
      }
    } catch (e) {
      _state = TransferState.error;
      _errorMessage = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset state to idle
  void reset() {
    _state = TransferState.idle;
    _errorMessage = null;
    _lastResponse = null;
    _playlistUrl = '';
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
