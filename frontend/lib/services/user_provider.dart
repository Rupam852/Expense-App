import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'biometric_service.dart';
import 'supabase_service.dart';
import 'ai_config_service.dart';
import 'notification_service.dart';

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
  bool _highRefreshRateEnabled = true; // Default ON for smooth 90Hz/120Hz/144Hz
  bool _showSpendingPredictionInBudget = false; // Default OFF: only shown in Budgets if enabled
  bool _isBusinessMode = false;
  String? _errorMessage;
  String? _userGeminiApiKey;
  bool _showApiKeyPrompt = false;
  bool _needsVerification = false;
  String? _unverifiedEmail;
  ThemeMode _themeMode = ThemeMode.system;
  String _appLanguage = 'en'; // 'en', 'hi', 'bn'

  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get highRefreshRateEnabled => _highRefreshRateEnabled;
  bool get showSpendingPredictionInBudget => _showSpendingPredictionInBudget;
  bool get isBusinessMode => _isBusinessMode;
  String? get errorMessage => _errorMessage;
  String? get userGeminiApiKey => _userGeminiApiKey;
  String? get userNvidiaApiKey => _userProfile?['nvidia_api_key'];
  String? get userGeminiApiKeySecondary => AiConfigService.instance.hasSecondaryConfig ? 'active' : null;
  bool get showApiKeyPrompt => _showApiKeyPrompt;
  bool get needsVerification => _needsVerification;
  String? get unverifiedEmail => _unverifiedEmail;
  ThemeMode get themeMode => _themeMode;
  String get appLanguage => _appLanguage;
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setAppLanguage(String langCode) async {
    if (langCode != 'en' && langCode != 'hi' && langCode != 'bn') return;
    _appLanguage = langCode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_display_language', langCode);
      // Synchronize notification language
      await NotificationService.instance.setNotificationLanguage(langCode);

      // Synchronize AI Chat response language
      final aiLang = langCode == 'hi' ? 'Hindi' : (langCode == 'bn' ? 'Bengali' : 'English');
      await AiConfigService.instance.setResponseLanguage(aiLang);
    } catch (e) {
      debugPrint('[UserProvider] Error saving app language: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', themeModeString);
    } catch (_) {}
  }

  Future<void> toggleHighRefreshRate(bool enabled) async {
    _highRefreshRateEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('high_refresh_rate', enabled);
      await _applyRefreshRate(enabled);
    } catch (e) {
      debugPrint('[UserProvider] Error toggling refresh rate: $e');
    }
  }

  Future<void> toggleSpendingPredictionInBudget(bool enabled) async {
    _showSpendingPredictionInBudget = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_spending_prediction_in_budget', enabled);
    } catch (e) {
      debugPrint('[UserProvider] Error saving spending prediction pref: $e');
    }
  }

  Future<void> toggleAppMode(bool isBusiness) async {
    _isBusinessMode = isBusiness;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_working_mode', isBusiness ? 'business' : 'personal');

      if (_userProfile != null) {
        _userProfile!['app_mode'] = isBusiness ? 'business' : 'personal';
        await _saveProfileLocally();
      }

      if (_isAuthenticated) {
        _supabase.upsertProfile({
          'app_mode': isBusiness ? 'business' : 'personal',
        }).catchError((e) {
          debugPrint('[UserProvider] Error syncing app_mode to cloud: $e');
        });
      }
    } catch (e) {
      debugPrint('[UserProvider] Error saving app mode: $e');
    }
  }

  Future<void> _applyRefreshRate(bool highRate) async {
    if (!Platform.isAndroid) return;
    try {
      if (highRate) {
        await FlutterDisplayMode.setHighRefreshRate();
      } else {
        await FlutterDisplayMode.setLowRefreshRate();
      }
    } catch (e) {
      debugPrint('[UserProvider] Could not apply display mode: $e');
    }
  }

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

    // Load locally cached profile & preferences for instant boot
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('app_theme_mode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      final savedMode = prefs.getString('app_working_mode');
      _isBusinessMode = savedMode == 'business';

      _highRefreshRateEnabled = prefs.getBool('high_refresh_rate') ?? true;
      _applyRefreshRate(_highRefreshRateEnabled);
      _showSpendingPredictionInBudget = prefs.getBool('show_spending_prediction_in_budget') ?? false;

      _appLanguage = prefs.getString('app_display_language') ?? 'en';
      NotificationService.instance.setNotificationLanguage(_appLanguage);

      _userGeminiApiKey = prefs.getString('user_gemini_api_key');
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

      final prefs = await SharedPreferences.getInstance();
      final cloudAppMode = profile?['app_mode']?.toString().trim();
      if (cloudAppMode != null && (cloudAppMode == 'business' || cloudAppMode == 'personal')) {
        _isBusinessMode = cloudAppMode == 'business';
        await prefs.setString('app_working_mode', cloudAppMode);
      }

      _userProfile = {
        'id': user.id,
        'email': user.email,
        'name': profile?['name'] ?? user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? 'User',
        'photo_url': profile?['photo_url'] ?? user.userMetadata?['avatar_url'],
        'ai_mode': profile?['ai_mode'] ?? 'default',
        'app_mode': cloudAppMode ?? (prefs.getString('app_working_mode') ?? 'personal'),
        'gemini_api_key': profile?['gemini_api_key'],
        'nvidia_api_key': profile?['nvidia_api_key'],
        'gemini_model': profile?['gemini_model'],
        'nvidia_model': profile?['nvidia_model'],
        'primary_provider': profile?['primary_provider'],
        'response_language': profile?['response_language'],
      };
      _isAuthenticated = true;

      // Sync AI Keys & Configuration into AiConfigService
      if (profile != null) {
        await AiConfigService.instance.syncFromCloudProfile(profile);
      }

      // Cache Gemini keys locally
      final key = _userProfile!['gemini_api_key']?.toString().trim();
      if (key != null && key.isNotEmpty) {
        await prefs.setString('user_gemini_api_key', key);
        _userGeminiApiKey = key;
      }

      await _saveProfileLocally();
      // Sync device FCM token with user profile in Supabase
      NotificationService.instance.syncFcmTokenToCloud();
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
    String? nvidiaApiKey,
    String? aiMode,
    String? appMode,
    String? geminiModel,
    String? nvidiaModel,
    String? primaryProvider,
    String? responseLanguage,
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
        if (nvidiaApiKey != null) 'nvidia_api_key': nvidiaApiKey,
        if (aiMode != null) 'ai_mode': aiMode,
        if (appMode != null) 'app_mode': appMode,
        if (geminiModel != null) 'gemini_model': geminiModel,
        if (nvidiaModel != null) 'nvidia_model': nvidiaModel,
        if (primaryProvider != null) 'primary_provider': primaryProvider,
        if (responseLanguage != null) 'response_language': responseLanguage,
      };
      await _saveProfileLocally();
      notifyListeners();
    }

    try {
      await _supabase.upsertProfile({
        'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (geminiApiKey != null) 'gemini_api_key': geminiApiKey,
        if (nvidiaApiKey != null) 'nvidia_api_key': nvidiaApiKey,
        if (aiMode != null) 'ai_mode': aiMode,
        if (appMode != null) 'app_mode': appMode,
        if (geminiModel != null) 'gemini_model': geminiModel,
        if (nvidiaModel != null) 'nvidia_model': nvidiaModel,
        if (primaryProvider != null) 'primary_provider': primaryProvider,
        if (responseLanguage != null) 'response_language': responseLanguage,
      });
    } catch (e) {
      print('[UserProvider] Profile update deferred (offline): $e');
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ──────────────────────────────────────────────────────
  // 6. GEMINI & NVIDIA KEY MANAGEMENT
  // ──────────────────────────────────────────────────────
  Future<void> saveUserGeminiApiKey(String? key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPrimary = (key == null || key.trim().isEmpty) ? '' : key.trim();

      if (cleanPrimary.isEmpty) {
        _userGeminiApiKey = null;
        await prefs.remove('user_gemini_api_key');
      } else {
        _userGeminiApiKey = cleanPrimary;
        await prefs.setString('user_gemini_api_key', cleanPrimary);
      }
      notifyListeners();

      if (_isAuthenticated) {
        await updateProfile(
          name: _userProfile?['name'] ?? 'User',
          photoUrl: _userProfile?['photo_url'],
          geminiApiKey: cleanPrimary,
        );
      }
    } catch (e) {
      print('[UserProvider] Error saving Gemini key: $e');
    }
  }

  Future<void> saveUserNvidiaApiKey(String? key) async {
    try {
      final clean = (key == null || key.trim().isEmpty) ? '' : key.trim();
      if (_isAuthenticated) {
        await updateProfile(
          name: _userProfile?['name'] ?? 'User',
          photoUrl: _userProfile?['photo_url'],
          nvidiaApiKey: clean,
        );
      }
    } catch (e) {
      print('[UserProvider] Error saving NVIDIA key: $e');
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
      await AiConfigService.instance.clearConfig();
    } catch (_) {}

    _userProfile = null;
    _userGeminiApiKey = null;
    _showApiKeyPrompt = false;
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
        await AiConfigService.instance.clearConfig();
      } catch (_) {}

      _userProfile = null;
      _userGeminiApiKey = null;
      _showApiKeyPrompt = false;
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
