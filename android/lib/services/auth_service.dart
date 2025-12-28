import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  
  // This should be the Web Client ID from Google Cloud Console
  String? _serverClientId;
  
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

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> initialize() async {
    try {
      print('[DEBUG AuthService] Starting initialization...');
      
      // Setup deep link listener
      _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      });
      
      // Check for initial link (app opened via deep link)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
      
      // Fetch the server client ID from the backend
      print('[DEBUG AuthService] Fetching Google Client ID from backend...');
      final clientId = await _apiService.getGoogleClientId();
      print('[DEBUG AuthService] Got Client ID: ${clientId != null ? "YES" : "NO"}');
      
      if (clientId != null) {
        _serverClientId = clientId;
        print('[DEBUG AuthService] Initializing GoogleSignIn with serverClientId...');
        _googleSignIn = GoogleSignIn(
          serverClientId: _serverClientId,
          scopes: [
            'https://www.googleapis.com/auth/youtube.force-ssl',
            'https://www.googleapis.com/auth/youtubepartner',
            'email',
            'profile',
          ],
        );
        
        // Listen to user changes
        _googleSignIn!.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
          _currentUser = account;
        });
        
        // Try to sign in silently
        await _googleSignIn!.signInSilently();
        print('[DEBUG AuthService] Initialization complete!');
      } else {
        print('[DEBUG AuthService] FAILED - No Client ID received from backend');
      }
    } catch (e) {
      print('[DEBUG AuthService] Error initializing: $e');
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

  Future<bool> signInWithGoogle() async {
    if (_googleSignIn == null) {
      print('[DEBUG] GoogleSignIn not initialized');
      return false;
    }

    try {
      print('[DEBUG] Starting Google Sign-In...');
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      
      print('[DEBUG] Sign-In result: ${account != null ? account.email : 'null'}');
      
      if (account != null) {
        _currentUser = account;
        
        if (account.serverAuthCode != null) {
          print('[DEBUG] Got serverAuthCode, sending to backend...');
          final success = await _apiService.sendGoogleAuthCode(account.serverAuthCode!);
          print('[DEBUG] Backend response: $success');
          return success;
        } else {
          print('[DEBUG] No serverAuthCode received.');
          return false;
        }
      }
      print('[DEBUG] Account is null after sign-in');
      return false;
    } catch (e) {
      print('[DEBUG] Error signing in with Google: $e');
      return false;
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
    if (_googleSignIn != null) {
      await _googleSignIn!.disconnect();
      _currentUser = null;
    }
  }
  
  void dispose() {
    _linkSubscription?.cancel();
  }
}
