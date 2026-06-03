import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_provider.dart';
import '../services/expense_provider.dart';
import '../widgets/custom_toast.dart';
import '../main.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Resend Timer logic
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          _resendTimer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final otp = _otpController.text.trim();

    final success = await userProvider.verifyUserSignup(widget.email, otp);
    if (success && mounted) {
      CustomToast.show(context, 'Email verified successfully. Welcome!');
      
      // Load offline data and sync
      await expenseProvider.loadLocalData();
      await expenseProvider.triggerQuietSync();

      // Navigate to AuthWrapper, resetting back stack so dashboard becomes root
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'Email verification failed.',
        isError: true,
      );
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final success = await userProvider.resendSignupVerificationOtp(widget.email);
    if (success && mounted) {
      CustomToast.show(context, 'Verification code resent to your email.');
      _startTimer();
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'Failed to resend verification code.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Email Verification',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // Clear verification state on user backing out to prevent residue
            userProvider.clearVerificationState();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Email Address',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 14, height: 1.5),
                    children: [
                      const TextSpan(text: 'We have emailed a 6-digit OTP verification code to:\n'),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const TextSpan(text: '\nPlease enter the code below to verify your account.'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // OTP Field
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(
                    fontSize: 22, 
                    letterSpacing: 12, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: Colors.grey, letterSpacing: 12),
                    prefixIcon: Icon(Icons.password_outlined),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.length != 6 || int.tryParse(value) == null) {
                      return 'Please enter a valid 6-digit OTP.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _canResend ? 'Didn\'t receive OTP?' : 'Resend code in ${_secondsRemaining}s',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: _canResend ? _resendOtp : null,
                      child: Text(
                        'Resend OTP',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _canResend ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Submit Button
                ElevatedButton(
                  onPressed: userProvider.isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: userProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Verify & Access Dashboard',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
