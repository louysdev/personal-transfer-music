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
  bool get isSignedIn => _currentUser != null;

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
      
      // Fetch the server client ID from the backend
      final clientId = await _apiService.getGoogleClientId();
      
      if (clientId != null) {
        _serverClientId = clientId;
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

  Future<bool> signInWithGoogle() async {
    if (_googleSignIn == null) {
      return false;
    }

    try {
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      
      if (account != null) {
        _currentUser = account;
        
        if (account.serverAuthCode != null) {
          final success = await _apiService.sendGoogleAuthCode(account.serverAuthCode!);
          return success;
        } else {
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error signing in with Google: $e');
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
