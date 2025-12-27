/// App configuration constants
class AppConfig {
  // API Base URL - Change this to your backend URL
  static const String apiBaseUrl = 'https://personal-transfer-music.onrender.com'; // Android emulator localhost
  // static const String apiBaseUrl = 'http://localhost:8080'; // iOS simulator
  // static const String apiBaseUrl = 'https://your-backend.com'; // Production
  
  // App Info
  static const String appName = 'Music Transfer';
  static const String appVersion = '1.0.0';
  
  // API Endpoints
  static const String createPlaylistEndpoint = '/create';
  static const String playlistsEndpoint = '/playlists';
  static const String transferAllEndpoint = '/transfer-all';
  static const String transferStatusEndpoint = '/transfer-status';
  static const String transferCancelEndpoint = '/transfer-cancel';
  static const String ytmPlaylistsEndpoint = '/ytm-playlists';
  static const String deleteAllPlaylistsEndpoint = '/delete-all-playlists';
  static const String deleteStatusEndpoint = '/delete-status';
  
  // Spotify Auth Endpoints
  static const String spotifyAuthEndpoint = '/auth/mobile/spotify';
  static const String spotifyTokenEndpoint = '/auth/mobile/token';
  
  // Spotify URL pattern for validation
  static final RegExp spotifyPlaylistPattern = 
    RegExp(r'^(?:https?:\/\/)?open\.spotify\.com\/playlist\/.+');
}
