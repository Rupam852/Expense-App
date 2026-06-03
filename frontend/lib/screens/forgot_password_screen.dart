import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_provider.dart';
import '../widgets/custom_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // Step 1: Email, Step 2: OTP, Step 3: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Resend Timer logic
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _canResend = false;
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

  void _sendOtp() async {
    if (!_formKey1.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = _emailController.text.trim();

    final success = await userProvider.sendForgotPasswordOtp(email);
    if (success && mounted) {
      CustomToast.show(context, 'OTP verification code sent to your email.');
      setState(() {
        _currentStep = 2;
      });
      _startTimer();
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'Failed to send OTP code.',
        isError: true,
      );
    }
  }

  void _verifyOtp() async {
    if (!_formKey2.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    final success = await userProvider.verifyForgotPasswordOtp(email, otp);
    if (success && mounted) {
      CustomToast.show(context, 'OTP verified successfully.');
      setState(() {
        _currentStep = 3;
      });
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'OTP verification failed.',
        isError: true,
      );
    }
  }

  void _resetPassword() async {
    if (!_formKey3.currentState!.validate()) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final password = _newPasswordController.text;

    final success = await userProvider.resetUserPassword(email, otp, password);
    if (success && mounted) {
      CustomToast.show(context, 'Password reset completed! Please log in.');
      Navigator.of(context).pop(); // Back to Login Screen
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'Failed to reset password.',
        isError: true,
      );
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = _emailController.text.trim();

    final success = await userProvider.sendForgotPasswordOtp(email);
    if (success && mounted) {
      CustomToast.show(context, 'Verification code resent to your email.');
      _startTimer();
    } else if (mounted) {
      CustomToast.show(
        context,
        userProvider.errorMessage ?? 'Failed to resend code.',
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
          'Password Recovery',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Progress Line Indicator
              Row(
                children: [
                  _buildStepIndicator(1, 'Email'),
                  _buildStepDivider(),
                  _buildStepIndicator(2, 'OTP'),
                  _buildStepDivider(),
                  _buildStepIndicator(3, 'Reset'),
                ],
              ),
              const SizedBox(height: 40),

              // Form fields based on current step
              if (_currentStep == 1) _buildEmailStep(userProvider),
              if (_currentStep == 2) _buildOtpStep(userProvider),
              if (_currentStep == 3) _buildPasswordStep(userProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, String label) {
    bool isActive = _currentStep >= stepNumber;
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? primaryColor : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.grey.withOpacity(0.2),
      ),
    );
  }

  Widget _buildEmailStep(UserProvider userProvider) {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Forgot Password?',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your registered email address and we will mail you a 6-digit verification code.',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: userProvider.isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: userProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Send Verification OTP',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(UserProvider userProvider) {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter OTP Code',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              children: [
                const TextSpan(text: 'We sent a 6-digit OTP verification code to '),
                TextSpan(
                  text: _emailController.text,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.inter(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '000000',
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
          const SizedBox(height: 16),
          // Resend Timer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _canResend ? 'Didn\'t receive OTP?' : 'Resend code in ${_secondsRemaining}s',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              TextButton(
                onPressed: _canResend ? _resendOtp : null,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _canResend ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: userProvider.isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: userProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Verify Code',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep(UserProvider userProvider) {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset Password',
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your new password to successfully secure and recover your account.',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),
          // New Password Field
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              hintText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_clock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value != _newPasswordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: userProvider.isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: userProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Reset and Update Password',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
