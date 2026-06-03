import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._init();
  final LocalAuthentication _auth = LocalAuthentication();

  BiometricService._init();

  // Check if hardware biometrics are supported and active on the device
  Future<bool> isHardwareSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print('Biometrics support query error: $e');
      return false;
    }
  }

  // Get user preference (whether biometric lock is active or toggled off)
  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometrics_enabled') ?? false;
  }

  // Set user preference
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', enabled);
  }

  // Prompt native biometric sheet
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to view your Expense ledger',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      print('Native biometric lock prompt error: $e');
      return false;
    }
  }
}
