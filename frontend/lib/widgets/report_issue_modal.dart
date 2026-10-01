import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/support_service.dart';
import '../services/user_provider.dart';
import '../services/supabase_service.dart';
import 'custom_toast.dart';

class ReportIssueModal extends StatefulWidget {
  final String? initialCategory;
  final String? initialError;
  final String? initialMessage;

  const ReportIssueModal({
    super.key,
    this.initialCategory,
    this.initialError,
    this.initialMessage,
  });

  /// Convenient static helper to show the Help & Report Modal from anywhere
  static Future<void> show(
    BuildContext context, {
    String? category,
    String? initialError,
    String? initialMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportIssueModal(
        initialCategory: category,
        initialError: initialError,
        initialMessage: initialMessage,
      ),
    );
  }

  @override
  State<ReportIssueModal> createState() => _ReportIssueModalState();
}

class _ReportIssueModalState extends State<ReportIssueModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _messageController;
  late String _selectedCategory;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;
  bool _showErrorPreview = false;

  final List<String> _categories = [
    'AI Assistant / Models',
    'Cloud Sync & Database',
    'Payment Cards & QR',
    'Receipt OCR & Scanner',
    'Voice Expense Parsing',
    'Invoices & Statement Export',
    'Login / Authentication',
    'General Bug / Feedback',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? _categories.first;
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.first;
    }

    _messageController = TextEditingController(text: widget.initialMessage ?? '');
    _nameController = TextEditingController();
    _emailController = TextEditingController();

    // Fill user details from UserProvider / Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final profile = userProvider.userProfile;
      final currentEmail = SupabaseService.instance.currentUser?.email ??
          profile?['email']?.toString() ??
          '';
      final currentName = profile?['full_name']?.toString() ??
          profile?['name']?.toString() ??
          '';

      if (mounted) {
        setState(() {
          if (_emailController.text.isEmpty) {
            _emailController.text = currentEmail;
          }
          if (_nameController.text.isEmpty) {
            _nameController.text = currentName;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await SupportService.instance.sendIssueReport(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        category: _selectedCategory,
        message: _messageController.text.trim(),
        errorDetails: (_includeDiagnostics && widget.initialError != null)
            ? widget.initialError
            : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();

        if (success) {
          CustomToast.show(
            context,
            '📧 Opening Email app with pre-filled report to rupambairagya08@gmail.com!',
          );
        } else {
          CustomToast.show(
            context,
            'Your report has been logged and sent to developer.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        CustomToast.show(
          context,
          'Failed to send report. Please check internet connection.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF00D09C);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset + 16 : 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D09C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF00D09C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Problem Report',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Send direct feedback or error logs to the developer',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Issue Category Selector
              Text(
                'CATEGORY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E232E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3242) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E232E) : Colors.white,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // User Info Row (Name & Email)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'Optional',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Valid email required'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Your Email *',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Problem Description Input
              Text(
                'PROBLEM DESCRIPTION *',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Please write a brief description of the problem'
                    : null,
                decoration: InputDecoration(
                  hintText: 'Explain what went wrong or how we can help you...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E232E) : const Color(0xFFFAFAFA),
                ),
                style: GoogleFonts.inter(fontSize: 13.5),
              ),
              const SizedBox(height: 12),

              // Diagnostic Log Box (if error exists)
              if (widget.initialError != null && widget.initialError!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bug_report_rounded, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Technical Error Log Attached',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _includeDiagnostics,
                            activeTrackColor: const Color(0xFFEF4444),
                            onChanged: (val) => setState(() => _includeDiagnostics = val),
                          ),
                        ],
                      ),
                      if (_includeDiagnostics) ...[
                        InkWell(
                          onTap: () => setState(() => _showErrorPreview = !_showErrorPreview),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  _showErrorPreview ? 'Hide Log Preview' : 'Show Log Preview',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                Icon(
                                  _showErrorPreview
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showErrorPreview)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black45 : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.initialError!,
                                style: GoogleFonts.firaCode(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Send Problem Report',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    'Direct delivery to rupambairagya08@gmail.com',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
