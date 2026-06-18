import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'biometric_service.dart';
import 'supabase_service.dart';

class UserProvider with ChangeNotifier {
  final _supabase = SupabaseService.instance;
  final _biometricService = BiometricService.instance;
  final _googleSignIn = GoogleSignIn(
    serverClientId: '570982599451-4u24qllrvum0an48hp9vktj8ba5g49ul.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

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

  UserProvider() {
    _init();
  }

  Future<void> _init() async {
    _biometricsEnabled = await _biometricService.isBiometricsEnabled();

    // Load locally cached profile for instant boot
    try {
      final prefs = await SharedPreferences.getInstance();
      _userGeminiApiKey = prefs.getString('user_gemini_api_key');
      _userGeminiApiKeySecondary = prefs.getString('user_gemini_api_key_secondary');
      final cachedProfileStr = prefs.getString('cached_user_profile');
      if (cachedProfileStr != null) {
        _userProfile = Map<String, dynamic>.from(json.decode(cachedProfileStr));
        _isAuthenticated = true;
      }
    } catch (_) {}

    // Check Supabase session
    final session = _supabase.currentSession;
    if (session != null) {
      _isAuthenticated = true;
      _fetchProfileQuietly();
    }

    // Listen for auth state changes (login/logout/token-refresh)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _isAuthenticated = true;
        _fetchProfileQuietly();
      } else if (event == AuthChangeEvent.signedOut) {
        _isAuthenticated = false;
        _userProfile = null;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // LOCAL CACHE
  // ──────────────────────────────────────────────────────

  Future<void> _saveProfileLocally() async {
    if (_userProfile == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', json.encode(_userProfile));
    } catch (_) {}
  }

  Future<void> _fetchProfileQuietly() async {
    try {
      final profile = await _supabase.fetchProfile();
      final user = _supabase.currentUser;
      if (user == null) return;

      _userProfile = {
        'id': user.id,
        'email': user.email,
        'name': profile?['name'] ?? user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? 'User',
        'photo_url': profile?['photo_url'] ?? user.userMetadata?['avatar_url'],
        'gemini_api_key': profile?['gemini_api_key'],
        'gemini_api_key_secondary': profile?['gemini_api_key_secondary'],
      };
      _isAuthenticated = true;

      // Cache Gemini keys locally
      final prefs = await SharedPreferences.getInstance();
      final key = _userProfile!['gemini_api_key']?.toString().trim();
      final keySec = _userProfile!['gemini_api_key_secondary']?.toString().trim();
      if (key != null && key.isNotEmpty) {
        await prefs.setString('user_gemini_api_key', key);
        _userGeminiApiKey = key;
      }
      if (keySec != null && keySec.isNotEmpty) {
        await prefs.setString('user_gemini_api_key_secondary', keySec);
        _userGeminiApiKeySecondary = keySec;
      }

      await _saveProfileLocally();
      notifyListeners();
    } catch (e) {
      print('[UserProvider] Quiet profile fetch failed (offline?): $e');
    }
  }

  // ──────────────────────────────────────────────────────
  // 1. REGISTER (Email + Password)
  // ──────────────────────────────────────────────────────
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
      final response = await _supabase.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );

      if (response.user != null) {
        // If session is already present → Supabase "Confirm Email" is OFF
        // User is logged in directly, no OTP screen needed
        if (response.session != null) {
          await _fetchProfileQuietly();
          _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
          _isLoading = false;
          notifyListeners();
          return true;
        }
        // Session is null → Supabase "Confirm Email" is ON, OTP required
        _needsVerification = true;
        _unverifiedEmail = email;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }


  // ──────────────────────────────────────────────────────
  // 2. LOGIN (Email + Password)
  // ──────────────────────────────────────────────────────
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
      final response = await _supabase.signInWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _fetchProfileQuietly();
        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Login failed. Check your credentials.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _needsVerification = true;
        _unverifiedEmail = email;
        _errorMessage = 'Email not verified. Please check your inbox.';
      } else {
        _errorMessage = _getFriendlyErrorMessage(e);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 3. GOOGLE SIGN IN
  // ──────────────────────────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _errorMessage = 'Google sign-in cancelled.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        _errorMessage = 'Google authentication failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Sign in to Supabase with the Google ID token
      final response = await _supabase.signInWithGoogleIdToken(
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        await _fetchProfileQuietly();
        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Google sign-in failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google sign-in error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 4. BIOMETRICS
  // ──────────────────────────────────────────────────────
  Future<bool> performBiometricUnlock() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    if (!enabled) return true;
    final active = await _biometricService.isHardwareSupported();
    if (!active) return true;
    return await _biometricService.authenticate();
  }

  Future<bool> toggleBiometrics(bool value) async {
    final supported = await _biometricService.isHardwareSupported();
    if (!supported && value) {
      _errorMessage = 'Biometric hardware not supported on this device.';
      notifyListeners();
      return false;
    }
    if (value) {
      final success = await _biometricService.authenticate();
      if (!success) return false;
    }
    await _biometricService.setBiometricsEnabled(value);
    _biometricsEnabled = value;
    notifyListeners();
    return true;
  }

  // ──────────────────────────────────────────────────────
  // 5. UPDATE PROFILE
  // ──────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    String? photoUrl,
    String? geminiApiKey,
    String? geminiApiKeySecondary,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Instant local update
    if (_userProfile != null) {
      _userProfile = {
        ..._userProfile!,
        'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (geminiApiKey != null) 'gemini_api_key': geminiApiKey,
        if (geminiApiKeySecondary != null) 'gemini_api_key_secondary': geminiApiKeySecondary,
      };
      await _saveProfileLocally();
      notifyListeners();
    }

    try {
      await _supabase.upsertProfile({
        'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (geminiApiKey != null) 'gemini_api_key': geminiApiKey,
        if (geminiApiKeySecondary != null) 'gemini_api_key_secondary': geminiApiKeySecondary,
      });
    } catch (e) {
      print('[UserProvider] Profile update deferred (offline): $e');
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ──────────────────────────────────────────────────────
  // 6. GEMINI KEY MANAGEMENT
  // ──────────────────────────────────────────────────────
  Future<void> saveUserGeminiApiKey(String? key) async {
    await saveUserGeminiApiKeys(primary: key, secondary: _userGeminiApiKeySecondary);
  }

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

      if (_isAuthenticated) {
        await updateProfile(
          name: _userProfile?['name'] ?? 'User',
          photoUrl: _userProfile?['photo_url'],
          geminiApiKey: cleanPrimary,
          geminiApiKeySecondary: cleanSecondary,
        );
      }
    } catch (e) {
      print('[UserProvider] Error saving Gemini keys: $e');
    }
  }

  // ──────────────────────────────────────────────────────
  // 7. LOGOUT
  // ──────────────────────────────────────────────────────
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await _supabase.signOut(); } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_profile');
      await prefs.remove('user_gemini_api_key');
      await prefs.remove('user_gemini_api_key_secondary');
      await prefs.remove('last_sync_time');
    } catch (_) {}

    _userProfile = null;
    _userGeminiApiKey = null;
    _userGeminiApiKeySecondary = null;
    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // 7b. DELETE ACCOUNT
  // ──────────────────────────────────────────────────────
  Future<bool> deleteUserAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      try { await _googleSignIn.signOut(); } catch (_) {}
      await _supabase.deleteAccount();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_user_profile');
        await prefs.remove('user_gemini_api_key');
        await prefs.remove('user_gemini_api_key_secondary');
        await prefs.remove('last_sync_time');
      } catch (_) {}

      _userProfile = null;
      _userGeminiApiKey = null;
      _userGeminiApiKeySecondary = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Account deletion failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 8. FORGOT PASSWORD (Supabase sends reset link/OTP)
  // ──────────────────────────────────────────────────────
  Future<bool> sendForgotPasswordOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.resetPasswordForEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error sending reset email: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 9. VERIFY OTP (for password reset)
  // ──────────────────────────────────────────────────────
  Future<bool> verifyForgotPasswordOtp(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.verifyOtp(
        email: email,
        token: otp,
        type: OtpType.recovery,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'OTP verification error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 10. RESET PASSWORD
  // ──────────────────────────────────────────────────────
  Future<bool> resetUserPassword(String email, String otp, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // The OTP was already verified in Step 2 (verifyForgotPasswordOtp) to establish the session.
      // So we can directly update the password now.
      await _supabase.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password reset error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 11. VERIFY SIGNUP OTP
  // ──────────────────────────────────────────────────────
  Future<bool> verifyUserSignup(String email, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.verifyOtp(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
      if (response.user != null) {
        _isAuthenticated = true;
        _needsVerification = false;
        _unverifiedEmail = null;
        await _fetchProfileQuietly();
        _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Verification failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Verification error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // 12. RESEND SIGNUP OTP
  // ──────────────────────────────────────────────────────
  Future<bool> resendSignupVerificationOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabase.resendSignupOtp(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _getFriendlyErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Resend error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────
  // GUEST MODE
  // ──────────────────────────────────────────────────────
  void enterAsGuest() async {
    _userProfile = {
      'id': 'guest-user-uuid',
      'email': 'guest@growexpense.local',
      'name': 'Guest Member',
      'photo_url': null,
    };
    _isAuthenticated = true;
    _showApiKeyPrompt = (_userGeminiApiKey == null || _userGeminiApiKey!.isEmpty);
    await _saveProfileLocally();
    notifyListeners();
  }

  // Helper for friendly error messages
  String _getFriendlyErrorMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Server is busy. Please try again after some time.';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Invalid email or password.';
    }
    return e.message;
  }
}
