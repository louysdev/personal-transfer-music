import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  
  // This should be the Web Client ID from Google Cloud Console
  // We will fetch it from the backend to keep it centralized or configured there
  String? _serverClientId;

  AuthService(this._apiService);

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> initialize() async {
    try {
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
      print('Error initializing AuthService: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    if (_googleSignIn == null) {
      print('GoogleSignIn not initialized');
      return false;
    }

    try {
      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      
      if (account != null) {
        _currentUser = account;
        
        // Only valid if we requested serverAuthCode
        if (account.serverAuthCode != null) {
          // Send the code to the backend
          final success = await _apiService.sendGoogleAuthCode(account.serverAuthCode!);
          return success;
        } else {
             print('No serverAuthCode received. Make sure you are using the Web Client ID.');
             // Fallback or just return true if we don't strictly need backend access immediately
             // but here we DO need backend access.
             return false;
        }
      }
      return false;
    } catch (e) {
      print('Error signing in with Google: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.disconnect();
      _currentUser = null;
    }
  }
}
