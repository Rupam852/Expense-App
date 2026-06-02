import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/expense_provider.dart';
import '../services/user_provider.dart';
import 'expense_entry_screen.dart';
import 'package:file_picker/file_picker.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Category Icon Mapper
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'travel':
        return Icons.directions_transit;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.electric_bolt_outlined;
      case 'entertainment':
        return Icons.local_play_outlined;
      case 'health':
        return Icons.healing_outlined;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.help_outline;
    }
  }

  // Category Color Mapper
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return const Color(0xFFFF5A5F);
      case 'travel':
        return const Color(0xFF2F80ED);
      case 'shopping':
        return const Color(0xFFF2C94C);
      case 'bills':
        return const Color(0xFF9B51E0);
      case 'entertainment':
        return const Color(0xFF27AE60);
      case 'health':
        return const Color(0xFFEB5757);
      case 'investment':
        return const Color(0xFF00D09C);
      default:
        return Colors.grey;
    }
  }

  void _triggerFileImport(BuildContext context) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.userGeminiApiKey == null || userProvider.userGeminiApiKey!.trim().isEmpty) {
      _showGeminiKeyDialog(context, userProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Google AI Studio API Key to parse PDF statements.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final isPdf = path.toLowerCase().endsWith('.pdf');
      
      // Step 1: Show warm-up message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isPdf
                    ? '⏳ Waking up AI server... (PDF import may take 30-60 sec)'
                    : '⏳ Processing spreadsheet import...',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(minutes: 4), // Stay visible during entire process
          backgroundColor: const Color(0xFF1A1A2E),
        ),
      );

      final success = await expenseProvider.importStatement(path);

      if (mountedContext(context)) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? '✅ Transactions imported successfully!' 
                : '❌ ${expenseProvider.syncErrorMessage ?? 'Failed to parse file. Please try again.'}',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: success ? const Color(0xFF00D09C) : Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }


  void _triggerCSVExport(BuildContext context) async {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final expenses = expenseProvider.expenses;

    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction logs to export.')),
      );
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

      // 3. Save as local file in app documents directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Expense_Statement_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);

      // 4. Trigger share sheet using share_plus
      await Share.shareXFiles([XFile(file.path)], text: 'My Grow Expense Statement');

      if (mountedContext(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spreadsheet statement generated and shared successfully!'),
            backgroundColor: Color(0xFF00D09C),
          ),
        );
      }
    } catch (e) {
      print('CSV export error: $e');
      if (mountedContext(context)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hasKey = userProvider.userGeminiApiKey != null && userProvider.userGeminiApiKey!.isNotEmpty;
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apna Google AI Studio (Gemini) API key enter karein. PDF import aur receipt scan ke liye use hoga:',
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(
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
                  TextFormField(
                    controller: keyController,
                    obscureText: isObscured,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
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
                  const SizedBox(height: 12),
                  SelectableText(
                    'Free key generate karein:\naistudio.google.com',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasKey)
                  TextButton(
                    onPressed: () async {
                      await userProvider.saveUserGeminiApiKey(null);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Custom API Key cleared successfully!')),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(
                      'Clear Key',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final keyVal = keyController.text.trim();
                    await userProvider.saveUserGeminiApiKey(keyVal.isEmpty ? null : keyVal);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            keyVal.isEmpty
                                ? 'Switched back to shared server key!'
                                : 'API Key saved successfully!',
                          ),
                        ),
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
                    'Save Key',
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
                      title: const Text('Biometric Authentication Lock'),
                      subtitle: const Text('Lock expense ledger with fingerprint / Face ID'),
                      value: userProvider.biometricsEnabled,
                      onChanged: (val) async {
                        final success = await userProvider.toggleBiometrics(val);
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(userProvider.errorMessage ?? 'Failed to enable biometrics.')),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-prompt custom Gemini API Key popup if missing right after login!
    if (userProvider.showApiKeyPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGeminiKeyDialog(context, userProvider);
        userProvider.dismissApiKeyPrompt();
      });
    }

    // Filter expenses for current month to display sum
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final monthlyExpenses = expenseProvider.expenses.where((e) =>
      DateFormat('yyyy-MM').format(e.transactionDate) == currentMonthStr
    ).toList();

    final totalSpentThisMonth = monthlyExpenses.fold<double>(
      0.0, (sum, item) => sum + item.amount
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success 
                              ? 'Cloud recovery sync completed!' 
                              : expenseProvider.syncErrorMessage ?? 'Sync failed.'),
                          backgroundColor: success ? const Color(0xFF00D09C) : Colors.amber[800],
                        ),
                      );
                    }
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
                      'TOTAL SPENT THIS MONTH',
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
                                '${expenseProvider.expenses.length} Total records',
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
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ExpenseEntryScreen(openCameraScanner: true),
                          ),
                        );
                      },
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
                  Text(
                    'RECENT TRANSACTIONS',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  if (expenseProvider.expenses.isNotEmpty)
                    Text(
                      'Swipe left to delete',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
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
              else if (expenseProvider.expenses.isEmpty)
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
                        'No transactions recorded yet.',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the + button to add manual expense, scan a receipt with camera, or upload statement.',
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
                  itemCount: expenseProvider.expenses.length > 10 ? 10 : expenseProvider.expenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final exp = expenseProvider.expenses[index];
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction deleted.')),
                        );
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
                                  '₹${exp.amount.toStringAsFixed(2)}',
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
