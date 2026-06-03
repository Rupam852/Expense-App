import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import '../services/api_service.dart';
import '../models/expense.dart';
import 'expense_entry_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_toast.dart';

String getCurrencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'USD': return r'$';
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'AUD': return r'A$';
    case 'CAD': return r'C$';
    case 'INR':
    default:
      return '₹';
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _showToast(String message, {bool isError = false, Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    CustomToast.show(context, message, isError: isError, duration: duration);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMonthRolloverAndPrompt();
    });
  }

  Future<void> _checkMonthRolloverAndPrompt() async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    
    // Give a short delay to allow offline data to be loaded/ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastKnown = prefs.getString('last_known_month_year');
    final now = DateTime.now();
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    if (lastKnown == null) {
      // First boot: set it to current month and do nothing
      await prefs.setString('last_known_month_year', currentMonthStr);
      return;
    }
    
    if (lastKnown != currentMonthStr) {
      // Month rolled over! Let's check if we have old expenses
      final oldTotal = expenseProvider.getOldExpensesTotal();
      if (oldTotal > 0) {
        if (!mounted) return;
        
        final parts = lastKnown.split('-');
        String oldMonthLabel = lastKnown;
        if (parts.length == 2) {
          try {
            final oldDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
            oldMonthLabel = DateFormat('MMMM yyyy').format(oldDate);
          } catch (_) {}
        }

        final currentMonthStart = DateTime(now.year, now.month);
        final oldExpenseIds = expenseProvider.expenses
            .where((e) => e.transactionDate.isBefore(currentMonthStart))
            .map((e) => e.id)
            .toList();
        
        _showMonthRolloverDialog(context, oldTotal, oldMonthLabel, oldExpenseIds, currentMonthStr);
      } else {
        // If there were no expenses in previous month, just update the stored month string
        await prefs.setString('last_known_month_year', currentMonthStr);
      }
    }
  }

  void _showMonthRolloverDialog(
    BuildContext context,
    double oldTotal,
    String oldMonthLabel,
    List<String> oldExpenseIds,
    String currentMonthStr,
  ) {
    final formattedTotal = NumberFormat('#,##,###.##').format(oldTotal);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.cleaning_services_outlined, color: Color(0xFF00D09C), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Month Rollover Clear-up',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new month has started! Your total expenses for the previous month ($oldMonthLabel) were:',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '₹$formattedTotal',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Click "Starting new month" to clean up old transactions, or generate a statement bill first.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _generateRolloverBill(context, oldTotal, oldMonthLabel, oldExpenseIds, currentMonthStr);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    'Generate all Expenses bill',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _clearRolloverData(context, currentMonthStr);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(
                    'Starting new month',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _generateRolloverBill(
    BuildContext context,
    double oldTotal,
    String oldMonthLabel,
    List<String> oldExpenseIds,
    String currentMonthStr,
  ) async {
    if (oldExpenseIds.isEmpty) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    
    double progress = 0.0;
    String statusText = 'Compiling transactions...';
    bool apiFinished = false;
    bool popped = false;
    String? localPath;

    expenseProvider.downloadInvoice(oldExpenseIds).then((path) {
      localPath = path;
      apiFinished = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!context.mounted) return;
              if (progress < 0.9) {
                setDialogState(() {
                  progress += 0.08;
                  if (progress > 0.4 && progress < 0.7) {
                    statusText = 'Generating PDF layout...';
                  } else if (progress >= 0.7) {
                    statusText = 'Compiling total expenses...';
                  }
                });
              } else if (apiFinished && !popped) {
                popped = true;
                setDialogState(() {
                  progress = 1.0;
                  statusText = 'Compilation complete!';
                });
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                });
              }
            });

            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Theme.of(context).primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generating Statement',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (localPath != null) {
      _showRolloverStatementActionDialog(context, localPath!, oldTotal, oldMonthLabel, oldExpenseIds, currentMonthStr);
    } else {
      CustomToast.show(
        context,
        'Failed to generate PDF statement. Make sure you are online.',
        isError: true,
      );
      _showMonthRolloverDialog(context, oldTotal, oldMonthLabel, oldExpenseIds, currentMonthStr);
    }
  }

  void _showRolloverStatementActionDialog(
    BuildContext context,
    String localPath,
    double oldTotal,
    String oldMonthLabel,
    List<String> oldExpenseIds,
    String currentMonthStr,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.1)),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        _showMonthRolloverDialog(context, oldTotal, oldMonthLabel, oldExpenseIds, currentMonthStr);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Statement Generated',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      'Your PDF statement for $oldMonthLabel has been compiled containing ${oldExpenseIds.length} transactions.',
                      style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Share.shareXFiles([XFile(localPath)], text: 'Expense statement for $oldMonthLabel');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            foregroundColor: Theme.of(context).primaryColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: Text(
                            'Share PDF',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await OpenFile.open(localPath);
                            if (result.type != ResultType.done && context.mounted) {
                              CustomToast.show(
                                context,
                                'Cannot open PDF: ${result.message}',
                                isError: true,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(
                            'View Statement',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearRolloverData(BuildContext context, String currentMonthStr) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    BuildContext? progressDialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        progressDialogContext = progressCtx;
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final success = await expenseProvider.deleteOldExpenses();

    if (progressDialogContext != null && Navigator.canPop(progressDialogContext!)) {
      Navigator.pop(progressDialogContext!);
    }

    if (success) {
      await prefs.setString('last_known_month_year', currentMonthStr);
    }

    if (context.mounted) {
      CustomToast.show(
        context,
        success
            ? 'Old expenses cleared successfully!'
            : 'Old expenses cleared locally. Cloud deletion pending.',
        isError: !success,
      );
    }
  }


  // Category Icon Mapper
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & drinks':
        return Icons.fastfood_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'recharges & bills':
        return Icons.receipt_long_outlined;
      case 'travel & fuel':
        return Icons.local_gas_station_outlined;
      case 'medical & health':
        return Icons.medical_services_outlined;
      case 'entertainment':
        return Icons.movie_filter_outlined;
      case 'money transfers':
        return Icons.swap_horiz;
      case 'investments & fees':
        return Icons.trending_up;
      default:
        return Icons.help_outline;
    }
  }

  // Category Color Mapper
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food & drinks':
        return const Color(0xFFFF5A5F);
      case 'shopping':
        return const Color(0xFFF2C94C);
      case 'recharges & bills':
        return const Color(0xFF00D09C);
      case 'travel & fuel':
        return const Color(0xFFF2994A);
      case 'medical & health':
        return const Color(0xFFEB5757);
      case 'entertainment':
        return const Color(0xFF27AE60);
      case 'money transfers':
        return const Color(0xFF56CCF2);
      case 'investments & fees':
        return const Color(0xFF9B51E0);
      default:
        return Colors.grey;
    }
  }

  void _triggerFileImport(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.userGeminiApiKey == null || userProvider.userGeminiApiKey!.trim().isEmpty) {
      _showGeminiKeyDialog(context, userProvider);
      CustomToast.show(
        context,
        'Please enter your Google AI Studio API Key to parse PDF statements.',
        isError: true,
      );
      return;
    }

    _showImportInstructionDialog(context);
  }

  void _showImportInstructionDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final primaryColor = const Color(0xFF00D09C);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 36, left: 24, right: 24, bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Import Statement Guide',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please try to import your UPI payment application statement to give accurate details.\n\nUPI payment apps like GPay, PhonePe, and other UPI apps are supported.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Import File',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: ClipOval(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        onTap: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.close_rounded,
                            color: Theme.of(context).iconTheme.color?.withOpacity(0.6) ?? Colors.grey.shade600,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((shouldImport) {
      if (shouldImport == true) {
        _proceedWithFilePicker(context);
      }
    });
  }

  void _proceedWithFilePicker(BuildContext context) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'pdf', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final isPdf = path.toLowerCase().endsWith('.pdf');
      
      if (!context.mounted) return;

      final importResult = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PremiumProgressDialog(
          title: isPdf ? 'Importing PDF Statement' : 'Importing Spreadsheet',
          importTask: () => expenseProvider.importStatement(path),
        ),
      );

      if (mountedContext(context)) {
        if (importResult != null && (importResult == 'success' || importResult.startsWith('Parsed'))) {
          final displayMsg = importResult == 'success'
              ? '✅ Transactions imported successfully!'
              : '✅ $importResult';
          CustomToast.show(
            context,
            displayMsg.replaceAll('✅ ', ''),
          );
        } else if (importResult == 'PasswordRequired' || importResult == 'InvalidPassword') {
          _promptForPasswordAndImport(
            context,
            path,
            initialError: importResult == 'InvalidPassword' ? 'Galat password. Dobara try karein.' : null,
          );
        } else if (importResult == 'NoMatchingTransactions') {
          _showNoMatchingTransactionsDialog(context);
        } else if (importResult != null && importResult != 'cancelled') {
          final errorMsg = expenseProvider.syncErrorMessage ?? 'Failed to parse file. Please try again.';
          _showApiErrorDialog(context, errorMsg, userProvider);
        }
      }
    }
  }

  void _promptForPasswordAndImport(BuildContext context, String path, {String? initialError}) {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final passwordController = TextEditingController();
    String? currentError = initialError;
    bool isObscured = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Password Protected Statement',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aapka statement password-protected hai. Import karne ke liye kripya sahi password enter karein:',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: isObscured,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                      hintText: 'Enter password...',
                      filled: true,
                      fillColor: Theme.of(context).primaryColor.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setStateDialog(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                      errorText: currentError,
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final enteredPassword = passwordController.text.trim();
                    if (enteredPassword.isEmpty) {
                      setStateDialog(() {
                        currentError = 'Password khali nahi ho sakta!';
                      });
                      return;
                    }

                    // Close the dialog to show progress
                    Navigator.of(context).pop();

                    // Show progress loader
                    final result = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => PremiumProgressDialog(
                        title: 'Decrypting & Importing Statement',
                        importTask: () => expenseProvider.importStatement(path, password: enteredPassword),
                      ),
                    );

                    if (mountedContext(context)) {
                      if (result != null && (result == 'success' || result.startsWith('Parsed'))) {
                        final displayMsg = result == 'success'
                            ? '✅ Transactions imported successfully!'
                            : '✅ $result';
                        CustomToast.show(
                          context,
                          displayMsg.replaceAll('✅ ', ''),
                        );
                      } else if (result == 'InvalidPassword' || result == 'PasswordRequired') {
                        // Re-prompt!
                        _promptForPasswordAndImport(
                          context,
                          path,
                          initialError: 'Galat password. Dobara try karein.',
                        );
                      } else if (result == 'NoMatchingTransactions') {
                        _showNoMatchingTransactionsDialog(context);
                      } else if (result != null && result != 'cancelled') {
                        // Other error
                        final errorMsg = expenseProvider.syncErrorMessage ?? 'Failed to parse file. Please try again.';
                        _showApiErrorDialog(context, errorMsg, userProvider);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D09C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Import',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNoMatchingTransactionsDialog(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = months[now.month - 1];
    final currentYear = now.year;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.amber.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No Current Month Data',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aapke statement file mein current month ($currentMonthName $currentYear) ka koi transaction nahi mila.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Grow App dynamic budget tracking ke liye sirf active month ke expense transactions ko hi accept karta hai. Kripya check karein ki aap sahi file upload kar rahe hain.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C), // Groww green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Got It',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _triggerCSVExport(BuildContext context) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final expenses = expenseProvider.expenses;

    if (expenses.isEmpty) {
      CustomToast.show(context, 'No transaction logs to export.', isError: true);
      return;
    }

    try {
      // 1. Prepare CSV headers and rows
      final List<List<dynamic>> csvData = [
        ['ID', 'Date', 'Category', 'Amount (INR)', 'Description', 'Recurring', 'Period'],
        ...expenses.map((e) => [
          e.id,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(e.transactionDate),
          e.category,
          e.amount,
          e.description,
          e.isRecurring ? 'Yes' : 'No',
          e.recurrencePeriod,
        ]),
      ];

      // 2. Convert to CSV string using package:csv
      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName = 'Expense_Statement_${DateTime.now().millisecondsSinceEpoch}.csv';

      // 3. Show info pop-up outlining the benefits of CSV
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            ),
            titlePadding: EdgeInsets.zero,
            title: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 40.0),
                  child: Row(
                    children: [
                      Icon(Icons.table_view_outlined, color: Theme.of(context).primaryColor, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Export CSV Statement',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exporting your data to a CSV file provides you with full control over your financial records:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCsvBenefitItem(
                  context,
                  Icons.grid_on,
                  'Excel & Google Sheets Support',
                  'Edit and analyze raw rows directly on mobile or desktop.',
                ),
                const SizedBox(height: 12),
                _buildCsvBenefitItem(
                  context,
                  Icons.bar_chart,
                  'Custom Graphs & Filters',
                  'Build custom Pivot Tables and compute detailed totals.',
                ),
                const SizedBox(height: 12),
                _buildCsvBenefitItem(
                  context,
                  Icons.receipt_long,
                  'CA & Accountant Friendly',
                  'Share standard logs directly for tax filing and audits.',
                ),
                const SizedBox(height: 12),
                _buildCsvBenefitItem(
                  context,
                  Icons.shield_outlined,
                  'Secure Offline Backup',
                  'Store a clean copy of your transactional ledger offline.',
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close info dialog
                    _executeCSVExportWithProgress(context, csvString, fileName); // Start export flow
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.download_for_offline),
                  label: Text(
                    'Generate CSV',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('CSV setup error: $e');
      if (mountedContext(context)) {
        CustomToast.show(context, 'Export preparation failed: $e', isError: true);
      }
    }
  }

  Widget _buildCsvBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String desc,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _executeCSVExportWithProgress(BuildContext context, String csvString, String fileName) async {
    double progress = 0.0;
    String statusText = 'Structuring spreadsheet columns...';
    bool saveFinished = false;
    bool popped = false;
    bool savedSuccessfully = false;
    String? localTempPath;

    // Start file write process in parallel
    Future.microtask(() async {
      try {
        final bytes = Uint8List.fromList(utf8.encode(csvString));
        
        // 1. Always save to local temporary directory for reliable opening and sharing
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvString);
        localTempPath = file.path;

        // 2. Try to save to public Downloads on Android, or trigger picker on desktop/iOS
        if (Platform.isAndroid) {
          savedSuccessfully = await ApiService.saveFileToDownloads(
            fileName: fileName,
            bytes: bytes,
            mimeType: 'text/csv',
          );
        } else {
          final selectedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV Statement:',
            fileName: fileName,
            bytes: bytes,
          );
          if (selectedPath != null) {
            savedSuccessfully = true;
          }
        }
      } catch (e) {
        print('In-progress write failed: $e');
      } finally {
        saveFinished = true;
      }
    });

    // Show custom progress dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!context.mounted) return;
              if (progress < 0.9) {
                setDialogState(() {
                  progress += 0.1;
                  if (progress > 0.4 && progress < 0.7) {
                    statusText = 'Injecting category rows...';
                  } else if (progress >= 0.7) {
                    statusText = 'Writing file to Downloads...';
                  }
                });
              } else if (saveFinished && !popped) {
                popped = true;
                setDialogState(() {
                  progress = 1.0;
                  statusText = 'Export complete!';
                });
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close progress dialog
                  }
                });
              }
            });

            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.table_chart_outlined,
                        color: Theme.of(context).primaryColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generating CSV Report',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (localTempPath != null) {
      // Show the second popup: View CSV and Share CSV
      _showCSVSuccessDialog(context, localTempPath!, fileName, savedSuccessfully);
    } else {
      if (context.mounted) {
        CustomToast.show(context, 'CSV Export failed.', isError: true);
      }
    }
  }

  void _showCSVSuccessDialog(
    BuildContext context,
    String localPath,
    String fileName,
    bool savedSuccessfully,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          titlePadding: EdgeInsets.zero,
          title: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 20.0, right: 40.0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Theme.of(context).primaryColor, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'CSV Exported!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                savedSuccessfully
                    ? 'Your CSV expense statement has been successfully generated and saved to your default Download folder.'
                    : 'Your CSV expense statement has been successfully generated.',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'File Name: $fileName',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Share.shareXFiles([XFile(localPath)], text: 'My Grow Expense Statement');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Theme.of(context).primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(Icons.share_outlined, color: Theme.of(context).primaryColor, size: 18),
                    label: Text(
                      'Share File',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final result = await OpenFile.open(localPath);
                      if (result.type != ResultType.done && context.mounted) {
                        CustomToast.show(
                          context,
                          'Cannot open CSV: ${result.message}',
                          isError: true,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.grid_on, size: 18),
                    label: Text(
                      'View CSV',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool mountedContext(BuildContext context) {
    try {
      return (context.mounted);
    } catch (_) {
      return true;
    }
  }

  void _showEditProfileDialog(BuildContext context, UserProvider userProvider) {
    final nameController = TextEditingController(text: userProvider.userProfile?['name'] ?? '');
    final photoUrlController = TextEditingController(text: userProvider.userProfile?['photo_url'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Profile Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your name',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Profile Image URL',
                  hintText: 'Paste image link (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final photoUrl = photoUrlController.text.trim();
                if (name.isNotEmpty) {
                  await userProvider.updateProfile(
                    name: name,
                    photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                  );
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showGeminiKeyDialog(BuildContext context, UserProvider userProvider) {
    final keyController = TextEditingController(text: userProvider.userGeminiApiKey ?? '');
    final secondaryKeyController = TextEditingController(text: userProvider.userGeminiApiKeySecondary ?? '');
    bool isObscured = true;
    bool isSecondaryObscured = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hasKeys = (userProvider.userGeminiApiKey != null && userProvider.userGeminiApiKey!.isNotEmpty) ||
                (userProvider.userGeminiApiKeySecondary != null && userProvider.userGeminiApiKeySecondary!.isNotEmpty);
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
              ),
              title: Row(
                children: [
                  Icon(Icons.psychology_outlined, color: Theme.of(context).primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI API Key Settings',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apna Google AI Studio (Gemini) API keys enter karein. Agar primary key fail hoti hai to optional backup key automatically use hogi.',
                      style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🔵 Google Gemini  (AIzaSy...)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('   aistudio.google.com — free, fast', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Primary Key Field
                    TextFormField(
                      controller: keyController,
                      obscureText: isObscured,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Primary API Key',
                        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                        hintText: 'AIzaSy...',
                        filled: true,
                        fillColor: Theme.of(context).primaryColor.withOpacity(0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => isObscured = !isObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Secondary Key Field
                    TextFormField(
                      controller: secondaryKeyController,
                      obscureText: isSecondaryObscured,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Secondary API Key (Optional)',
                        labelStyle: TextStyle(color: Theme.of(context).primaryColor),
                        hintText: 'AIzaSy... (Backup key)',
                        filled: true,
                        fillColor: Theme.of(context).primaryColor.withOpacity(0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isSecondaryObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => isSecondaryObscured = !isSecondaryObscured),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'Free keys generate karein:\naistudio.google.com',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasKeys)
                  TextButton(
                    onPressed: () async {
                      await userProvider.saveUserGeminiApiKeys(primary: null, secondary: null);
                      if (context.mounted) {
                        CustomToast.show(context, 'Custom API Keys cleared successfully!');
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(
                      'Clear Keys',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final keyVal = keyController.text.trim();
                    final secondaryVal = secondaryKeyController.text.trim();
                    await userProvider.saveUserGeminiApiKeys(
                      primary: keyVal.isEmpty ? null : keyVal,
                      secondary: secondaryVal.isEmpty ? null : secondaryVal,
                    );
                    if (context.mounted) {
                      CustomToast.show(
                        context,
                        (keyVal.isEmpty && secondaryVal.isEmpty)
                            ? 'Switched back to shared server key!'
                            : 'API Keys saved successfully!',
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Save Keys',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOcrSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).primaryColor;
        
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: primaryColor.withOpacity(0.1),
            ),
          ),
          title: Stack(
            children: [
              Row(
                children: [
                  Icon(Icons.document_scanner_outlined, color: primaryColor, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Smart OCR Scanner',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receipt scan karne ke liye source choose karein. AI automatic details extract kar lega:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ExpenseEntryScreen(openCameraScanner: true),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt_outlined, color: primaryColor, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Camera',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ExpenseEntryScreen(openGalleryScanner: true),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.photo_library_outlined, color: primaryColor, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showApiErrorDialog(BuildContext context, String actualError, UserProvider userProvider) {
    final hasSecondary = userProvider.userGeminiApiKeySecondary != null &&
        userProvider.userGeminiApiKeySecondary!.isNotEmpty;
    final displayMessage = hasSecondary
        ? actualError
        : 'Your API fail.\n\nDetails: $actualError';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'API Processing Error',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayMessage,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!hasSecondary) ...[
                const SizedBox(height: 16),
                Text(
                  'Tip: You can add an optional backup secondary API key in settings. If the primary key fails, the backup key will automatically keep the AI features working.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            if (!hasSecondary)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showGeminiKeyDialog(context, userProvider);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Add Backup Key',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showSettingsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer2<UserProvider, ExpenseProvider>(
          builder: (context, userProvider, expenseProvider, _) {
            final profile = userProvider.userProfile;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          backgroundImage: profile?['photo_url'] != null
                              ? NetworkImage(profile!['photo_url'])
                              : null,
                          child: profile?['photo_url'] == null
                              ? Text(
                                  (profile?['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?['name'] ?? 'User Member',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                profile?['email'] ?? 'N/A',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Theme.of(context).primaryColor, size: 22),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showEditProfileDialog(context, userProvider);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),

                    // Toggle Biometrics
                    SwitchListTile(
                      activeColor: Theme.of(context).primaryColor,
                      title: const Text('Biometric / Device Lock'),
                      subtitle: const Text('Lock expense ledger with fingerprint / password'),
                      value: userProvider.biometricsEnabled,
                      onChanged: (val) async {
                        final success = await userProvider.toggleBiometrics(val);
                        if (!success && context.mounted) {
                          CustomToast.show(
                            context,
                            userProvider.errorMessage ?? 'Failed to enable biometrics.',
                            isError: true,
                          );
                        }
                      },
                    ),
                    
                    // Custom Gemini API Key Setting Row
                    ListTile(
                      leading: Icon(Icons.vpn_key_outlined, color: Theme.of(context).primaryColor),
                      title: const Text('Google AI Studio API Key'),
                      subtitle: Text(
                        userProvider.userGeminiApiKey != null && userProvider.userGeminiApiKey!.isNotEmpty
                            ? 'Custom Gemini API Key active'
                            : 'Using shared server keys',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).pop();
                        _showGeminiKeyDialog(context, userProvider);
                      },
                    ),
                    
                    const Divider(),
                    const SizedBox(height: 16),

                    // Logout Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await expenseProvider.clearAllDataOnSignout();
                        await userProvider.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    // Delete Account Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDeleteAccountDialog(context, userProvider, expenseProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, UserProvider userProvider, ExpenseProvider expenseProvider) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.redAccent.withOpacity(0.2),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Account?',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warning: This action is permanent and irreversible.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aapka account aur usse juda saara data (transactions, statement history, budgets, UPI settings) cloud database aur local storage se hamesha ke liye delete ho jayega.',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.all(16),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });

                          // Call delete process
                          final success = await userProvider.deleteUserAccount();
                          if (success) {
                            await expenseProvider.clearAllDataOnSignout();
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Close dialog
                              CustomToast.show(
                                context,
                                'Your account and data have been permanently deleted.',
                                isError: false,
                              );
                            }
                          } else {
                            if (context.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                              CustomToast.show(
                                context,
                                userProvider.errorMessage ?? 'Failed to delete account.',
                                isError: true,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Permanently Delete',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteMonth(BuildContext context, ExpenseProvider provider, List<Expense> expensesToDelete, DateTime month) {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.redAccent.withOpacity(0.2),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Month History?',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Kya aap sach me $monthLabel ki poori statement history delete karna chahte hain? Esme total ${expensesToDelete.length} transactions permanently delete ho jayenge.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Show deleting feedback SnackBar
                CustomToast.show(
                  context,
                  'Deleting all ${expensesToDelete.length} records for $monthLabel...',
                  duration: const Duration(seconds: 2),
                );

                // Run fast bulk delete
                final ids = expensesToDelete.map((e) => e.id).toList();
                await provider.deleteMultipleExpenses(ids);

                if (context.mounted) {
                  CustomToast.show(
                    context,
                    '$monthLabel history cleared successfully!',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Delete All',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-prompt custom Gemini API Key popup if missing right after login, with a 1300ms transition delay
    if (userProvider.showApiKeyPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userProvider.dismissApiKeyPrompt();
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted) {
            _showGeminiKeyDialog(context, userProvider);
          }
        });
      });
    }

    final _selectedMonthYear = expenseProvider.selectedMonthYear;
    final selectedMonthStr = DateFormat('yyyy-MM').format(_selectedMonthYear);
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final isSelectedMonthCurrent = selectedMonthStr == currentMonthStr;

    final monthlyExpenses = expenseProvider.expenses.where((e) =>
      DateFormat('yyyy-MM').format(e.transactionDate) == selectedMonthStr
    ).toList();

    final totalSpentThisMonth = monthlyExpenses.fold<double>(
      0.0, (sum, item) => sum + expenseProvider.convertToINR(item.amount, item.currency)
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () => _showSettingsDrawer(context),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                backgroundImage: userProvider.userProfile?['photo_url'] != null
                    ? NetworkImage(userProvider.userProfile!['photo_url'])
                    : null,
                child: userProvider.userProfile?['photo_url'] == null
                    ? Text(
                        (userProvider.userProfile?['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Hello, ${userProvider.userProfile?['name']?.split(' ')[0] ?? 'User'}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Synchronize Controller Badge
          IconButton(
            onPressed: expenseProvider.isSyncing 
                ? null 
                : () async {
                    final success = await expenseProvider.triggerManualSync();
                      CustomToast.show(
                        context,
                        success 
                            ? 'Cloud recovery sync completed!' 
                            : expenseProvider.syncErrorMessage ?? 'Sync failed.',
                        isError: !success,
                      );
                  },
            icon: expenseProvider.isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    expenseProvider.syncErrorMessage != null 
                        ? Icons.cloud_off_outlined 
                        : Icons.cloud_queue_outlined,
                    color: expenseProvider.syncErrorMessage != null 
                        ? Colors.amber[800] 
                        : const Color(0xFF00D09C),
                  ),
          ),
          IconButton(
            onPressed: () => _showSettingsDrawer(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => expenseProvider.triggerManualSync(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Balance Summary Card (Jade Green groww gradients)
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D09C), Color(0xFF05B488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D09C).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSelectedMonthCurrent
                          ? 'TOTAL SPENT THIS MONTH'
                          : 'TOTAL SPENT IN ${DateFormat('MMMM yyyy').format(_selectedMonthYear!).toUpperCase()}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          NumberFormat('#,##,###.##').format(totalSpentThisMonth),
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wallet, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${monthlyExpenses.length} Records',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedMonthYear!).toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Rapid Actions Hub (Imports, OCR Scans, and CSV Statement Export)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showOcrSourceDialog(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF181B22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF00D09C).withOpacity(0.1),
                              child: const Icon(Icons.document_scanner_outlined, color: Color(0xFF00D09C), size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Smart OCR',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Read receipts',
                              style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _triggerFileImport(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF181B22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: const Icon(Icons.file_upload_outlined, color: Colors.blue, size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Import File',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'XLSX / PDF Bank',
                              style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _triggerCSVExport(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF181B22) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.purple.withOpacity(0.1),
                              child: const Icon(Icons.table_view_outlined, color: Colors.purple, size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Export CSV',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Excel statement',
                              style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Recent Activity Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isSelectedMonthCurrent 
                          ? 'RECENT TRANSACTIONS' 
                          : '${DateFormat('MMMM yyyy').format(_selectedMonthYear!).toUpperCase()} TRANSACTIONS',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (monthlyExpenses.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Swipe left to delete',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDeleteMonth(context, expenseProvider, monthlyExpenses, _selectedMonthYear!),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Activity Ledger (List of rows)
              if (expenseProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (monthlyExpenses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B22) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        expenseProvider.expenses.isEmpty
                            ? 'No transactions recorded yet.'
                            : 'No transactions for this month.',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expenseProvider.expenses.isEmpty
                            ? 'Tap the + button to add manual expense, scan a receipt with camera, or upload statement.'
                            : 'Try selecting another month or import data for this statement month.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthlyExpenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final exp = monthlyExpenses[index];
                    final catColor = _getCategoryColor(exp.category);

                    return Dismissible(
                      key: Key(exp.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        expenseProvider.deleteExpense(exp.id);
                        CustomToast.show(context, 'Transaction deleted.');
                      },
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ExpenseEntryScreen(editExpense: exp),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF181B22) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E9F0),
                            ),
                          ),
                        child: Row(
                          children: [
                            // Category Icon Rounded Wrapper
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: catColor.withOpacity(0.1),
                              child: Icon(
                                _getCategoryIcon(exp.category),
                                color: catColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Text Descriptions
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp.description.isNotEmpty 
                                        ? exp.description 
                                        : exp.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        exp.category,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: catColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd MMM').format(exp.transactionDate),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Amount Value Outflow
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${getCurrencySymbol(exp.currency)}${exp.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.red[400],
                                  ),
                                ),
                                if (exp.isRecurring)
                                  const Icon(
                                    Icons.autorenew_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                     ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumProgressDialog extends StatefulWidget {
  final Future<String?> Function() importTask;
  final String title;

  const PremiumProgressDialog({
    super.key,
    required this.importTask,
    required this.title,
  });

  @override
  State<PremiumProgressDialog> createState() => _PremiumProgressDialogState();
}

class _PremiumProgressDialogState extends State<PremiumProgressDialog> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _statusText = 'Preparing file...';
  bool _isCompleted = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startSimulation();
    _executeTask();
  }

  void _startSimulation() async {
    // 0% -> 15% quickly
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _isCancelled) return;
    setState(() {
      _progress = 0.15;
      _statusText = 'Uploading statement securely...';
    });

    // 15% -> 45% over 3 seconds
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.01;
      });
    }

    if (!mounted || _isCompleted || _isCancelled) return;
    setState(() {
      _statusText = 'AI model analyzing transactions...';
    });

    // 45% -> 85% over 10 seconds
    for (int i = 0; i < 80; i++) {
      await Future.delayed(const Duration(milliseconds: 125));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.005;
      });
    }

    if (!mounted || _isCompleted || _isCancelled) return;
    setState(() {
      _statusText = 'De-duplicating and syncing ledger...';
    });

    // 85% -> 95% very slowly
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || _isCompleted || _isCancelled) return;
      setState(() {
        _progress += 0.002;
      });
    }
  }

  void _executeTask() async {
    final result = await widget.importTask();
    if (!mounted || _isCancelled) return;

    setState(() {
      _isCompleted = true;
      _progress = 1.0;
      _statusText = result == 'success' ? 'Import complete!' : 'Error parsing file.';
    });

    // Wait a brief moment for the user to see the 100% completion
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted && !_isCancelled) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00D09C);
    
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main content Column with top padding to keep space for the close button
              Padding(
                padding: const EdgeInsets.only(top: 36, left: 24, right: 24, bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Beautiful glowing icon or logo
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _isCompleted && _progress == 1.0 && _statusText == 'Import complete!'
                              ? Icons.check_circle_outline
                              : Icons.cloud_upload_outlined,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Smooth animated progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Percentage text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Secure Import',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Close button in the top-right corner
              Positioned(
                top: 8,
                right: 8,
                child: ClipOval(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      onTap: () {
                        _isCancelled = true;
                        Navigator.of(context).pop('cancelled');
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).iconTheme.color?.withOpacity(0.6) ?? Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
