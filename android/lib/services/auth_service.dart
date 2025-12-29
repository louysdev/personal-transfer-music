import 'dart:async';

import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;

  
  // Spotify Config
  static const String _redirectUriScheme = 'personal-transfer-music';
  static const String _redirectUriHost = 'callback';
  
  // Deep link handling
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Completer<String?>? _spotifyAuthCompleter;

  AuthService(this._apiService) {
    _appLinks = AppLinks();
  }



  Future<void> initialize() async {
    try {
      // Setup deep link listener
      _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      });
      
      // Check for initial link (app opened via deep link)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('Error initializing: $e');
    }
  }
  
  void _handleDeepLink(Uri uri) {
    // Check if this is a Spotify callback
    if (uri.scheme == _redirectUriScheme && uri.host == _redirectUriHost) {
      final code = uri.queryParameters['code'];
      if (code != null && _spotifyAuthCompleter != null && !_spotifyAuthCompleter!.isCompleted) {
        _spotifyAuthCompleter!.complete(code);
      } else if (_spotifyAuthCompleter != null && !_spotifyAuthCompleter!.isCompleted) {
        // Error case - no code
        final error = uri.queryParameters['error'];
        print('Spotify auth error: $error');
        _spotifyAuthCompleter!.complete(null);
      }
    }
  }


  
  Future<String?> signInWithSpotify() async {
    try {
      // 1. Get Spotify Client ID from backend
      final spotifyClientId = await _apiService.getSpotifyClientId();
      if (spotifyClientId == null) {
        print('Could not get Spotify Client ID');
        return null;
      }

      // 2. Construct Auth URL
      final redirectUri = '$_redirectUriScheme://$_redirectUriHost';
      const scope = 'playlist-read-private playlist-read-collaborative';
      final state = DateTime.now().millisecondsSinceEpoch.toString();

      final url = Uri.https('accounts.spotify.com', '/authorize', {
        'response_type': 'code',
        'client_id': spotifyClientId,
        'redirect_uri': redirectUri,
        'scope': scope,
        'state': state,
      });

      // 3. Setup completer for callback
      _spotifyAuthCompleter = Completer<String?>();

      // 4. Launch browser for auth
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        print('Could not launch URL');
        _spotifyAuthCompleter = null;
        return null;
      }

      // 5. Wait for callback (with timeout)
      final code = await _spotifyAuthCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => null,
      );
      
      _spotifyAuthCompleter = null;
      
      if (code == null) {
        print('No code received from Spotify');
        return null;
      }

      // 6. Send code to backend to exchange for token
      final token = await _apiService.exchangeSpotifyCode(code, redirectUri);
      return token;

    } catch (e) {
      print('Error signing in with Spotify: $e');
      _spotifyAuthCompleter = null;
      return null;
    }
  }

  Future<void> signOut() async {
    // No-op for now as Google Sign-In is removed
  }
  
  void dispose() {
    _linkSubscription?.cancel();
  }
}
