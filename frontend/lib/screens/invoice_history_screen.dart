import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final _apiService = ApiService.instance;

  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
    // Listen for connectivity changes in real-time
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOffline = offline);
        if (!offline && _invoices.isEmpty) _loadHistory();
      }
    });
  }

  Future<void> _initAndLoad() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    setState(() => _isOffline = offline);
    if (!offline) await _loadHistory();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; _error = null; });
    final result = await _apiService.fetchInvoiceHistory();
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['invoices'] as List).cast<Map<String, dynamic>>();
      setState(() { _invoices = list; _isLoading = false; });
    } else {
      setState(() { _error = result['error']; _isLoading = false; });
    }
  }

  // ─── Rename ─────────────────────────────────────────────────────────────────
  Future<void> _showRenameDialog(Map<String, dynamic> invoice) async {
    final controller = TextEditingController(text: invoice['file_name'] as String? ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Invoice', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter new file name',
            hintStyle: GoogleFonts.inter(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final res = await _apiService.renameInvoice(invoice['id'] as String, result);
    if (!mounted) return;
    if (res['success'] == true) {
      CustomToast.show(context, '✅ Invoice renamed successfully.');
      await _loadHistory();
    } else {
      CustomToast.show(context, 'Failed to rename: ${res['error']}', isError: true);
    }
  }

  // ─── Download ────────────────────────────────────────────────────────────────
  Future<void> _downloadInvoice(Map<String, dynamic> invoice) async {
    CustomToast.show(context, 'Downloading…');
    final bytes = await _apiService.downloadInvoiceBytes(invoice['id'] as String);
    if (!mounted) return;
    if (bytes == null) {
      CustomToast.show(context, 'Download failed. Check your connection.', isError: true);
      return;
    }
    final fileName = invoice['file_name'] as String? ?? 'Invoice.pdf';
    final safeFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

    // Try native Downloads first
    final saved = await ApiService.saveFileToDownloads(
      fileName: safeFileName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );

    if (!saved) {
      // Fallback: save to app documents dir and open with viewer
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$safeFileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        CustomToast.show(context, 'Saved to: ${file.path}');
      }
    } else {
      if (mounted) CustomToast.show(context, '✅ Saved to Downloads folder!');
    }
  }

  // ─── Share ───────────────────────────────────────────────────────────────────
  Future<void> _shareInvoice(Map<String, dynamic> invoice) async {
    CustomToast.show(context, 'Preparing to share…');
    final bytes = await _apiService.downloadInvoiceBytes(invoice['id'] as String);
    if (!mounted) return;
    if (bytes == null) {
      CustomToast.show(context, 'Share failed. Check your connection.', isError: true);
      return;
    }
    final fileName = invoice['file_name'] as String? ?? 'Invoice.pdf';
    final safeFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$safeFileName');
    await tempFile.writeAsBytes(bytes);
    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(tempFile.path)],
      subject: safeFileName,
      text: 'Grow Expense — Monthly Invoice',
    );
  }

  // ─── Delete ──────────────────────────────────────────────────────────────────
  Future<void> _showDeleteDialog(Map<String, dynamic> invoice) async {
    final monthYear = invoice['month_year'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // back gesture closes popup
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 56, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Delete Invoice?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Do you want to permanently delete the invoice for $monthYear?\n\nThis action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: Colors.grey[600]),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('No', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Yes, Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await _apiService.deleteInvoice(invoice['id'] as String);
    if (!mounted) return;
    if (res['success'] == true) {
      CustomToast.show(context, '🗑️ Invoice deleted successfully.');
      await _loadHistory();
    } else {
      CustomToast.show(context, 'Delete failed: ${res['error']}', isError: true);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _formatMonthYear(String? monthYear) {
    if (monthYear == null || monthYear.isEmpty) return 'Unknown';
    try {
      final parts = monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[month]} $year';
    } catch (_) {
      return monthYear;
    }
  }

  String _formatFileSize(dynamic bytes) {
    final b = (bytes as num?)?.toInt() ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')} '
             '${_formatMonthYear('${dt.year}-${dt.month.toString().padLeft(2, '0')}').split(' ')[0].substring(0, 3)} '
             '${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF181B22) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Invoice History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (!_isOffline)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadHistory,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      body: _buildBody(isDark, primaryColor),
    );
  }

  Widget _buildBody(bool isDark, Color primaryColor) {
    // Offline state
    if (_isOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.orange),
              ),
              const SizedBox(height: 24),
              Text(
                'You are offline',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 10),
              Text(
                'Please turn on your internet connection.\nInvoice history will load automatically once connected.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Failed to load', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_edu_outlined, size: 56, color: primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'No Invoices Yet',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 10),
              Text(
                'Invoices you generate from the\nBilling & Invoicing screen will appear here\nautomatically, saved month-by-month.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    // Invoice list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final inv = _invoices[index];
        final monthLabel = _formatMonthYear(inv['month_year'] as String?);
        final fileName = inv['file_name'] as String? ?? 'Invoice';
        final fileSize = _formatFileSize(inv['file_size_bytes']);
        final createdAt = _formatDate(inv['created_at'] as String?);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // PDF icon badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 26),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(createdAt, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400])),
                          const SizedBox(width: 10),
                          Icon(Icons.insert_drive_file_outlined, size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(fileSize, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ],
                  ),
                ),
                // 3-dot menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: isDark ? const Color(0xFF242936) : Colors.white,
                  elevation: 8,
                  onSelected: (action) async {
                    switch (action) {
                      case 'rename': await _showRenameDialog(inv); break;
                      case 'download': await _downloadInvoice(inv); break;
                      case 'share': await _shareInvoice(inv); break;
                      case 'delete': await _showDeleteDialog(inv); break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(children: [
                        Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 12),
                        Text('Rename File', style: GoogleFonts.inter(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'download',
                      child: Row(children: [
                        Icon(Icons.download_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 12),
                        Text('Download', style: GoogleFonts.inter(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(children: [
                        Icon(Icons.share_outlined, size: 18, color: primaryColor),
                        const SizedBox(width: 12),
                        Text('Share', style: GoogleFonts.inter(fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        const SizedBox(width: 12),
                        Text('Delete', style: GoogleFonts.inter(fontSize: 13, color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
