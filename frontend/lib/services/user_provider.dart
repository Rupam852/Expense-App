import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import 'biometric_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

class UserProvider with ChangeNotifier {
  final _apiService = ApiService.instance;
  final _biometricService = BiometricService.instance;

  Map<String, dynamic>? _userProfile;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _biometricsEnabled = false;
  String? _errorMessage;
  String? _userGeminiApiKey;
  String? _userGeminiApiKeySecondary;
  bool _showApiKeyPrompt = false;
  bool _needsVerification = false;
  String? _unverifiedEmail;

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get biometricsEnabled => _biometricsEnabled;
  String? get errorMessage => _errorMessage;
  String? get userGeminiApiKey => _userGeminiApiKey;
  String? get userGeminiApiKeySecondary => _userGeminiApiKeySecondary;
  bool get showApiKeyPrompt => _showApiKeyPrompt;
  bool get needsVerification => _needsVerification;
  String? get unverifiedEmail => _unverifiedEmail;

  void dismissApiKeyPrompt() {
    _showApiKeyPrompt = false;
    notifyListeners();
  }

  void clearVerificationState() {
    _needsVerification = false;
    _unverifiedEmail = null;
  }

  fb.FirebaseAuth? _firebaseAuth;
  GoogleSignIn? _googleSignIn;

  UserProvider() {
    _initFirebaseAndPrefs();
  }

  // Resilient Firebase and settings caching setup
  Future<void> _initFirebaseAndPrefs() async {
    try {
      _firebaseAuth = fb.FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    } catch (e) {
      print('Firebase not initialized on target platform: Running in standard Backend API Mode. Details: $e');
    }

    // Load cached profile instantly for fast visual boot
    try {
      final prefs = await SharedPreferences.getInstance();
      _userGeminiApiKey = prefs.getString('user_gemini_api_key');
      _userGeminiApiKeySecondary = prefs.getString('user_gemini_api_key_secondary');
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (cachedProfileStr != null) {
        _userProfile = Map<String, dynamic>.from(json.decode(cachedProfileStr));
        _isAuthenticated = true;
      }
    } catch (e) {
      print('Error restoring cached profile: $e');
    }

    // Load user-scoped biometric preference
    _biometricsEnabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
    
    // Check if we have an active JWT stored already (keeps user logged in)
    final token = await _apiService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      // Fetch user profile from backend quietly
      _fetchProfileQuietly();
    }
    notifyListeners();
  }

  // Local caching helper
  Future<void> _saveProfileLocally() async {
    if (_userProfile != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', json.encode(_userProfile));
      } catch (e) {
        print('Error saving profile locally: $e');
      }
    }
  }

  // Quiet profile fetcher to sync database modifications
  Future<void> _fetchProfileQuietly() async {
    final result = await _fetchProfileDetails();
    if (result != null) {
      _userProfile = result;
      _biometricsEnabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
      _isAuthenticated = true;

      // Automatically sync Gemini key from remote DB to local preferences
      final fetchedApiKey = _userProfile?['gemini_api_key'];
      if (fetchedApiKey != null && fetchedApiKey.toString().trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_gemini_api_key', fetchedApiKey.toString().trim());
        _userGeminiApiKey = fetchedApiKey.toString().trim();
      }

      final fetchedApiKeySec = _userProfile?['gemini_api_key_secondary'];
      if (fetchedApiKeySec != null && fetchedApiKeySec.toString().trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_gemini_api_key_secondary', fetchedApiKeySec.toString().trim());
        _userGeminiApiKeySecondary = fetchedApiKeySec.toString().trim();
      }

      await _saveProfileLocally();
      notifyListeners();
    } else {
      // Token is stale or backend is down, we remain logged in locally (offline first) but log trace
      print('Quiet profile loading unsuccessful. Standing by in offline mode.');
    }
  }

  // 1. Manual Signup (Firebase + Backend sync fallback)
  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _needsVerification = false;
    _unverifiedEmail = null;
    notifyListeners();

    try {
      // Step A: Attempt Firebase registration if initialized
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth!.createUserWithEmailAndPassword(email: email, password: password);
        } catch (fbErr) {
          print('Firebase custom user registration bypassed: $fbErr');
        }
      }

      // Step B: Synchronize with our Express / Postgres backend
      final result = await _apiService.register(
        email: email,
        password: password,
        name: name,
        photoUrl: photoUrl,
      );

      if (result['success'] == true) {
        if (result['needsVerification'] == true) {
          _needsVerification = true;
          _unverifiedEmail = result['email'];
          _isLoading = false;
          _isAuthenticated = false;
          notifyListeners();
          return true; // Success but requires verification
        }

        _userProfile = result['user'];
        _biometricsEnabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
        _isAuthenticated = true;

        final fetchedApiKey = _userProfile?['gemini_api_key'];
        if (fetchedApiKey != null && fetchedApiKey.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key', fetchedApiKey.toString().trim());
          _userGeminiApiKey = fetchedApiKey.toString().trim();
        }

        final fetchedApiKeySec = _userProfile?['gemini_api_key_secondary'];
        if (fetchedApiKeySec != null && fetchedApiKeySec.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key_secondary', fetchedApiKeySec.toString().trim());
          _userGeminiApiKeySecondary = fetchedApiKeySec.toString().trim();
        }

        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        await _saveProfileLocally();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System registration exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 2. Manual Email Login
  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _needsVerification = false;
    _unverifiedEmail = null;
    notifyListeners();

    try {
      // Step A: Try Firebase verification if present
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth!.signInWithEmailAndPassword(email: email, password: password);
        } catch (fbErr) {
          print('Firebase login bypassed: $fbErr');
        }
      }

      // Step B: Authenticate against Express API and obtain JWT
      final result = await _apiService.login(email: email, password: password);

      if (result['success'] == true) {
        _userProfile = result['user'];
        _biometricsEnabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
        _isAuthenticated = true;

        final fetchedApiKey = _userProfile?['gemini_api_key'];
        if (fetchedApiKey != null && fetchedApiKey.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key', fetchedApiKey.toString().trim());
          _userGeminiApiKey = fetchedApiKey.toString().trim();
        }

        final fetchedApiKeySec = _userProfile?['gemini_api_key_secondary'];
        if (fetchedApiKeySec != null && fetchedApiKeySec.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key_secondary', fetchedApiKeySec.toString().trim());
          _userGeminiApiKeySecondary = fetchedApiKeySec.toString().trim();
        }

        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        await _saveProfileLocally();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        if (result['needsVerification'] == true) {
          _needsVerification = true;
          _unverifiedEmail = result['email'];
          _errorMessage = 'Email not verified. Please verify your email first.';
        } else {
          _errorMessage = result['error'];
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System authentication exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 3. Google Sign-In (Firebase + Backend registration synchronizer)
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_googleSignIn == null) {
        _errorMessage = 'Google sign-in is not configured on this device.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google authentication cancelled by user.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Sync with Firebase Auth
      if (_firebaseAuth != null) {
        try {
          final credential = fb.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await _firebaseAuth!.signInWithCredential(credential);
        } catch (fbErr) {
          print('Firebase Google Sync bypassed: $fbErr');
        }
      }

      // Sync Google attributes to our postgres backend
      final result = await _apiService.login(
        email: googleUser.email,
        googleId: googleUser.id,
        name: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
      );

      if (result['success'] == true) {
        _userProfile = result['user'];
        _isAuthenticated = true;

        final fetchedApiKey = _userProfile?['gemini_api_key'];
        if (fetchedApiKey != null && fetchedApiKey.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key', fetchedApiKey.toString().trim());
          _userGeminiApiKey = fetchedApiKey.toString().trim();
        }

        final fetchedApiKeySec = _userProfile?['gemini_api_key_secondary'];
        if (fetchedApiKeySec != null && fetchedApiKeySec.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key_secondary', fetchedApiKeySec.toString().trim());
          _userGeminiApiKeySecondary = fetchedApiKeySec.toString().trim();
        }

        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        await _saveProfileLocally();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Google Authentication exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 4. Biometric Authentication Boot Check
  Future<bool> performBiometricUnlock() async {
    final enabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
    if (!enabled) return true; // Biometrics toggled off: skip

    final active = await _biometricService.isHardwareSupported();
    if (!active) return true;

    return await _biometricService.authenticate();
  }

  // 5. Toggle Biometrics Settings
  Future<bool> toggleBiometrics(bool value) async {
    final supported = await _biometricService.isHardwareSupported();
    if (!supported && value) {
      _errorMessage = 'Biometric security hardware is not supported or active on this device.';
      notifyListeners();
      return false;
    }

    if (value) {
      // Authenticate once before enabling
      final success = await _biometricService.authenticate();
      if (!success) return false;
    }

    await _biometricService.setBiometricsEnabled(value, email: _userProfile?['email']);
    _biometricsEnabled = value;
    notifyListeners();
    return true;
  }

  // 6. Profile modifications
  Future<bool> updateProfile({required String name, String? photoUrl, String? geminiApiKey, String? geminiApiKeySecondary}) async {
    _isLoading = true;
    notifyListeners();

    // Instantly update local state to avoid network lag or offline delays!
    if (_userProfile != null) {
      final updated = Map<String, dynamic>.from(_userProfile!);
      updated['name'] = name;
      if (photoUrl != null) {
        updated['photo_url'] = photoUrl;
      }
      if (geminiApiKey != null || geminiApiKey == '') {
        updated['gemini_api_key'] = geminiApiKey;
      }
      if (geminiApiKeySecondary != null || geminiApiKeySecondary == '') {
        updated['gemini_api_key_secondary'] = geminiApiKeySecondary;
      }
      _userProfile = updated;
      await _saveProfileLocally();
      notifyListeners();
    }

    try {
      final token = await _apiService.getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final res = await httpPutProfile(
        name: name,
        photoUrl: photoUrl,
        geminiApiKey: geminiApiKey,
        geminiApiKeySecondary: geminiApiKeySecondary,
      );
      if (res != null) {
        _userProfile = res;
        await _saveProfileLocally();
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Quiet profile server update deferred (offline active): $e');
      _isLoading = false;
      notifyListeners();
      return true; // Return true as offline update is complete
    }
  }

  // Standard API call helper to fetch profile details
  Future<Map<String, dynamic>?> _fetchProfileDetails() async {
    try {
      final token = await _apiService.getToken();
      if (token == null) return null;

      final response = await httpGetMe(token);
      return response;
    } catch (_) {
      return null;
    }
  }

  // Helper HTTP calls
  Future<Map<String, dynamic>?> httpGetMe(String token) async {
    try {
      final response = await _apiService.fetchUserProfile();
      if (response['success'] == true) {
        return response['user'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> httpPutProfile({
    required String name,
    String? photoUrl,
    String? geminiApiKey,
    String? geminiApiKeySecondary,
  }) async {
    try {
      final response = await _apiService.updateProfileOnServer(
        name: name,
        photoUrl: photoUrl,
        geminiApiKey: geminiApiKey,
        geminiApiKeySecondary: geminiApiKeySecondary,
      );
      if (response['success'] == true) {
        return response['user'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Guest Bypass Login (Enables immediate usage without backend connections)
  void enterAsGuest() async {
    _userProfile = {
      'id': 'guest-user-uuid',
      'email': 'guest@growexpense.local',
      'name': 'Guest Member',
      'photo_url': null,
    };
    _biometricsEnabled = await _biometricService.isBiometricsEnabled(email: _userProfile?['email']);
    _isAuthenticated = true;
    _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
    await _saveProfileLocally();
    notifyListeners();
  }

  // Save/Clear User Custom Gemini API Key
  Future<void> saveUserGeminiApiKey(String? key) async {
    await saveUserGeminiApiKeys(primary: key, secondary: _userGeminiApiKeySecondary);
  }

  // Save/Clear both Primary and Secondary Gemini API Keys
  Future<void> saveUserGeminiApiKeys({String? primary, String? secondary}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPrimary = (primary == null || primary.trim().isEmpty) ? '' : primary.trim();
      final cleanSecondary = (secondary == null || secondary.trim().isEmpty) ? '' : secondary.trim();

      if (cleanPrimary.isEmpty) {
        _userGeminiApiKey = null;
        await prefs.remove('user_gemini_api_key');
      } else {
        _userGeminiApiKey = cleanPrimary;
        await prefs.setString('user_gemini_api_key', cleanPrimary);
      }

      if (cleanSecondary.isEmpty) {
        _userGeminiApiKeySecondary = null;
        await prefs.remove('user_gemini_api_key_secondary');
      } else {
        _userGeminiApiKeySecondary = cleanSecondary;
        await prefs.setString('user_gemini_api_key_secondary', cleanSecondary);
      }
      notifyListeners();

      // Synchronize keys to database
      if (_isAuthenticated && _userProfile != null) {
        await updateProfile(
          name: _userProfile!['name'] ?? 'User',
          photoUrl: _userProfile!['photo_url'],
          geminiApiKey: cleanPrimary,
          geminiApiKeySecondary: cleanSecondary,
        );
      }
    } catch (e) {
      print('Error saving custom Gemini API keys: $e');
    }
  }

  // 7. Clear authentication states
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      if (_firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }
    } catch (_) {}

    await _apiService.deleteToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile');
      await prefs.remove('user_gemini_api_key');
      await prefs.remove('user_gemini_api_key_secondary');
    } catch (_) {}
    _userProfile = null;
    _userGeminiApiKey = null;
    _userGeminiApiKeySecondary = null;
    _isAuthenticated = false;
    _biometricsEnabled = false;
    _isLoading = false;
    notifyListeners();
  }

  // 7b. Delete User Account and Associated Data
  Future<bool> deleteUserAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Delete Firebase User Account if active
      if (_firebaseAuth != null) {
        try {
          final currentUser = _firebaseAuth!.currentUser;
          if (currentUser != null) {
            await currentUser.delete();
            print('[Auth] Firebase Auth user deleted successfully.');
          }
        } catch (fbErr) {
          print('[Auth] Firebase Auth user deletion skipped/failed: $fbErr');
        }
      }

      // 2. Google Sign-Out if active
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (_) {}
      }

      // 3. Call backend delete account API
      final result = await _apiService.deleteAccount();
      if (result['success'] == true) {
        // 4. Wipe local authentication state and keys
        await _apiService.deleteToken();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_user_profile');
          await prefs.remove('user_gemini_api_key');
          await prefs.remove('user_gemini_api_key_secondary');
        } catch (_) {}

        _userProfile = null;
        _userGeminiApiKey = null;
        _userGeminiApiKeySecondary = null;
        _isAuthenticated = false;
        _biometricsEnabled = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Backend deletion failed.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Exception during account deletion: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 8. Forgot Password - Send OTP Email
  Future<bool> sendForgotPasswordOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.forgotPassword(email);
      _isLoading = false;
      if (result['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System forgot password exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 9. Verify OTP code
  Future<bool> verifyForgotPasswordOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.verifyOtp(email, otp);
      _isLoading = false;
      if (result['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System OTP verification exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 10. Reset Password
  Future<bool> resetUserPassword(String email, String otp, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.resetPassword(email, otp, newPassword);
      _isLoading = false;
      if (result['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System password reset exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 11. Verify Signup Email OTP
  Future<bool> verifyUserSignup(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.verifySignup(email, otp);
      _isLoading = false;
      if (result['success'] == true) {
        _userProfile = result['user'];
        _isAuthenticated = true;
        _needsVerification = false;
        _unverifiedEmail = null;

        final fetchedApiKey = _userProfile?['gemini_api_key'];
        if (fetchedApiKey != null && fetchedApiKey.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key', fetchedApiKey.toString().trim());
          _userGeminiApiKey = fetchedApiKey.toString().trim();
        }

        final fetchedApiKeySec = _userProfile?['gemini_api_key_secondary'];
        if (fetchedApiKeySec != null && fetchedApiKeySec.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_gemini_api_key_secondary', fetchedApiKeySec.toString().trim());
          _userGeminiApiKeySecondary = fetchedApiKeySec.toString().trim();
        }

        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        await _saveProfileLocally();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System signup verification exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 12. Resend Signup Verification OTP
  Future<bool> resendSignupVerificationOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.resendSignupVerification(email);
      _isLoading = false;
      if (result['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['error'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'System resend exception: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
