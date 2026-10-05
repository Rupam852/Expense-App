import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/groww_theme.dart';
import 'services/user_provider.dart';
import 'services/expense_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'widgets/app_logo.dart';
import 'widgets/custom_toast.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM Background] Handling message: ${message.messageId}');
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Attach global navigator key to NotificationService for 1-tap deep link navigation
  NotificationService.instance.navigatorKey = appNavigatorKey;

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register FCM Background Handler for closed/killed state notifications
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Local Notifications & FCM foreground listeners
  await NotificationService.instance.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseService.supabaseUrl,
    anonKey: SupabaseService.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: const GrowExpenseApp(),
    ),
  );
}


class GrowExpenseApp extends StatelessWidget {
  const GrowExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Grow Expense',
          debugShowCheckedModeBanner: false,
          theme: GrowwTheme.lightTheme,
          darkTheme: GrowwTheme.darkTheme,
          themeMode: userProvider.themeMode, // System Default (Device Default), Dark, or Light
          locale: Locale(userProvider.appLanguage, 'IN'),
          supportedLocales: const [
            Locale('en', 'IN'),
            Locale('en', 'US'),
            Locale('hi', 'IN'),
            Locale('bn', 'IN'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _biometricVerified = false;
  bool _checkingBiometric = false;

  @override
  void initState() {
    super.initState();
    _triggerBiometricVerification();
  }

  // Trigger Biometric Lock if enabled
  Future<void> _triggerBiometricVerification() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Wait for provider authentication state to initialize
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!userProvider.isAuthenticated) return;

    if (userProvider.biometricsEnabled) {
      setState(() {
        _checkingBiometric = true;
      });

      final success = await userProvider.performBiometricUnlock();
      
      setState(() {
        _biometricVerified = success;
        _checkingBiometric = false;
      });

      if (!success && mounted) {
        CustomToast.show(
          context,
          'Biometric authentication failed. Tap the button to try again.',
          isError: true,
        );
      }
    } else {
      setState(() {
        _biometricVerified = true;
      });
    }
  }

  void _manualBiometricRetry() async {
    CustomToast.dismissAll();
    await _triggerBiometricVerification();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        // CASE 0: Still checking authentication & session state on startup
        if (!userProvider.isInitialized) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            body: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Color(0xFF00D09C),
                  strokeWidth: 2.5,
                ),
              ),
            ),
          );
        }

        // CASE A: User is not logged in: Route to Login/Register screen
        if (!userProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // CASE B: User is authenticated but biometric lock is active and unverified
        if (userProvider.biometricsEnabled && !_biometricVerified) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppLogo(size: 72),
                    const SizedBox(height: 24),
                    
                    Text(
                      'LEDGER IS LOCKED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Biometric authentication is required to access your financial details.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),

                    // Manual Unlock Trigger Button
                    ElevatedButton.icon(
                      onPressed: _checkingBiometric ? null : _manualBiometricRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.fingerprint),
                      label: Text(
                        _checkingBiometric ? 'Authenticating...' : 'Tap to Unlock',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () async {
                        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                        await expenseProvider.clearAllDataOnSignout();
                        await userProvider.logout();
                      },
                      child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // CASE C: User is authenticated & verified: Route to main bottom navigation shell
        return const MainNavigation();
      },
    );
  }
}
