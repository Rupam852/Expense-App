import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../services/expense_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/custom_toast.dart';

enum ExportFormat { pdf, excel, csv }

class ExportStatementDialog extends StatefulWidget {
  const ExportStatementDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ExportStatementDialog(),
    );
  }

  @override
  State<ExportStatementDialog> createState() => _ExportStatementDialogState();
}

class _ExportStatementDialogState extends State<ExportStatementDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isCustomRange = false;
  DateTimeRange? _customDateRange;
  bool _isExporting = false;

  List<Expense> _getFilteredExpenses(List<Expense> allExpenses, DateTime selectedMonth) {
    final monthExpenses = allExpenses.where((e) {
      return e.transactionDate.year == selectedMonth.year && e.transactionDate.month == selectedMonth.month;
    }).toList();

    if (_isCustomRange && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      return monthExpenses.where((e) {
        return e.transactionDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            e.transactionDate.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }

    return monthExpenses;
  }

  String _getRangeLabel(DateTime selectedMonth) {
    if (_isCustomRange && _customDateRange != null) {
      return '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}';
    }
    return DateFormat('MMMM yyyy').format(selectedMonth);
  }

  Future<void> _handleExport(List<Expense> filteredExpenses, DateTime selectedMonth) async {
    if (filteredExpenses.isEmpty) {
      CustomToast.show(context, 'No transactions found for ${DateFormat('MMMM yyyy').format(selectedMonth)}.', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final rangeLabel = _getRangeLabel(selectedMonth).replaceAll(' ', '_').replaceAll(',', '');
      final timeStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      Uint8List fileBytes;
      String fileName;
      String mimeType;

      switch (_selectedFormat) {
        case ExportFormat.pdf:
          fileName = 'Expense_Statement_${rangeLabel}_$timeStamp.pdf';
          mimeType = 'application/pdf';
          fileBytes = await _generatePdfBytes(filteredExpenses, _getRangeLabel(selectedMonth));
          break;

        case ExportFormat.excel:
          fileName = 'Expense_Ledger_${rangeLabel}_$timeStamp.xlsx';
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          fileBytes = await _generateExcelBytes(filteredExpenses, _getRangeLabel(selectedMonth));
          break;

        case ExportFormat.csv:
          fileName = 'Expense_Statement_${rangeLabel}_$timeStamp.csv';
          mimeType = 'text/csv';
          fileBytes = _generateCsvBytes(filteredExpenses);
          break;
      }

      // Save locally to Temp cache for preview/share
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes);

      // Save directly to device's Public Downloads folder
      await SupabaseService.saveFileToDownloads(
        fileName: fileName,
        bytes: fileBytes,
        mimeType: mimeType,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);
      Navigator.of(context).pop(); // Close selector sheet

      // Show Success Dialog
      _showSuccessDialog(fileName, tempFile.path, mimeType);
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        CustomToast.show(context, 'Export failed: $e', isError: true);
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // CSV GENERATOR
  // ────────────────────────────────────────────────────────────
  Uint8List _generateCsvBytes(List<Expense> expenses) {
    final List<List<dynamic>> rows = [
      ['Date', 'Category', 'Amount (INR)', 'Description', 'Recurring', 'Period'],
      ...expenses.map((e) => [
        DateFormat('yyyy-MM-dd HH:mm').format(e.transactionDate),
        e.category,
        e.amount,
        e.description,
        e.isRecurring ? 'Yes' : 'No',
        e.recurrencePeriod,
      ]),
    ];
    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(csvString.codeUnits);
  }

  // ────────────────────────────────────────────────────────────
  // EXCEL GENERATOR (.xlsx)
  // ────────────────────────────────────────────────────────────
  Future<Uint8List> _generateExcelBytes(List<Expense> expenses, String periodLabel) async {
    final excel = xls.Excel.createExcel();
    final sheetName = 'Expenses';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Title Row
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        xls.TextCellValue('Expense Statement - $periodLabel');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        xls.TextCellValue('Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}');

    // Headers
    final headers = ['Date', 'Category', 'Description', 'Amount (INR)', 'Recurring', 'Period'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = xls.TextCellValue(headers[i]);
    }

    // Data Rows
    double totalAmount = 0;
    int rowIndex = 4;
    for (final exp in expenses) {
      totalAmount += exp.amount;
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
          xls.TextCellValue(DateFormat('yyyy-MM-dd').format(exp.transactionDate));
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
          xls.TextCellValue(exp.category);
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
          xls.TextCellValue(exp.description);
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
          xls.DoubleCellValue(exp.amount);
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
          xls.TextCellValue(exp.isRecurring ? 'Yes' : 'No');
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
          xls.TextCellValue(exp.recurrencePeriod);
      rowIndex++;
    }

    // Total Row
    rowIndex++;
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
        xls.TextCellValue('TOTAL EXPENSES:');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
        xls.DoubleCellValue(totalAmount);

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  // ────────────────────────────────────────────────────────────
  // PDF GENERATOR (.pdf)
  // ────────────────────────────────────────────────────────────
  Future<Uint8List> _generatePdfBytes(List<Expense> expenses, String periodLabel) async {
    final pdf = pw.Document();
    final double total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EXPENSE STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: $periodLabel',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total: Rs. ${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.Text(
                        '${expenses.length} Transactions',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.teal800),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Description', 'Recurring', 'Amount (INR)'],
              data: expenses.map((e) {
                return [
                  DateFormat('dd MMM yyyy').format(e.transactionDate),
                  e.category,
                  e.description.isEmpty ? '-' : e.description,
                  e.isRecurring ? 'Yes (${e.recurrencePeriod})' : 'No',
                  'Rs. ${e.amount.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                4: pw.Alignment.centerRight,
              },
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.teal50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.teal800),
                  ),
                  child: pw.Text(
                    'Grand Total: Rs. ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                      color: PdfColors.teal900,
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}  •  Generated by Expense App',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ────────────────────────────────────────────────────────────
  // SUCCESS POPUP DIALOG
  // ────────────────────────────────────────────────────────────
  void _showSuccessDialog(String fileName, String localFilePath, String mimeType) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E232E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Export Successful!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File saved to your phone\'s Downloads folder:\n',
                style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A3142) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF384358) : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.firaCode(fontSize: 11.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '📁 Saved to Downloads folder.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Share.shareXFiles(
                  [XFile(localFilePath, mimeType: mimeType)],
                  text: 'Here is my exported Expense Statement.',
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D09C),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final result = await OpenFile.open(localFilePath);
                if (result.type != ResultType.done && mounted) {
                  CustomToast.show(context, 'Could not open file viewer: ${result.message}', isError: true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00D09C);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final selectedMonth = expenseProvider.selectedMonthYear;
    final allExpenses = expenseProvider.expenses;
    final filteredExpenses = _getFilteredExpenses(allExpenses, selectedMonth);
    final totalAmount = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final monthLabel = _getRangeLabel(selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A23) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E384D) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.file_download_outlined, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Expense Statement',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Download $monthLabel ledger to phone',
                          style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Month Date Range Filter (Full Month vs Custom Days inside month)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_isCustomRange) {
                          setState(() {
                            _isCustomRange = false;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: !_isCustomRange
                              ? primaryColor
                              : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isCustomRange
                                ? primaryColor
                                : (isDark ? const Color(0xFF2A344A) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: !_isCustomRange ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Full Month',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: !_isCustomRange ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
                        final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: monthStart,
                          lastDate: monthEnd,
                          initialDateRange: _customDateRange ??
                              DateTimeRange(
                                start: monthStart,
                                end: DateTime.now().isBefore(monthEnd) ? DateTime.now() : monthEnd,
                              ),
                          helpText: 'Select range in ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                          builder: (context, child) {
                            return Theme(
                              data: isDark
                                  ? ThemeData.dark().copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF00D09C),
                                        onPrimary: Colors.black,
                                        surface: Color(0xFF1A1F2C),
                                      ),
                                    )
                                  : ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF00D09C),
                                        onPrimary: Colors.white,
                                      ),
                                    ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _isCustomRange = true;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isCustomRange
                              ? primaryColor
                              : (isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isCustomRange
                                ? primaryColor
                                : (isDark ? const Color(0xFF2A344A) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 16,
                              color: _isCustomRange ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _isCustomRange && _customDateRange != null
                                    ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
                                    : 'Custom Days',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isCustomRange ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Active Month Summary Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2433) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A344A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
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
                            '${filteredExpenses.length} transactions included',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##,##0').format(totalAmount)}',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Choose Format Header
              Text(
                'CHOOSE EXPORT FORMAT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildFormatCard(
                      format: ExportFormat.pdf,
                      title: 'PDF File',
                      ext: '.pdf',
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFEF4444),
                      desc: 'Print & viewable document',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFormatCard(
                      format: ExportFormat.excel,
                      title: 'Excel',
                      ext: '.xlsx',
                      icon: Icons.table_chart_rounded,
                      color: const Color(0xFF10B981),
                      desc: 'Formatted spreadsheet',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFormatCard(
                      format: ExportFormat.csv,
                      title: 'CSV',
                      ext: '.csv',
                      icon: Icons.text_snippet_rounded,
                      color: const Color(0xFF3B82F6),
                      desc: 'Raw comma-separated',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Export Confirm Button
              ElevatedButton(
                onPressed: _isExporting ? null : () => _handleExport(filteredExpenses, selectedMonth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isExporting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, size: 20, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Download $monthLabel Statement',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required ExportFormat format,
    required String title,
    required String ext,
    required IconData icon,
    required Color color,
    required String desc,
    required bool isDark,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () {
        setState(() => _selectedFormat = format);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.18 : 0.1)
              : (isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF283144) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            Text(
              ext,
              style: GoogleFonts.firaCode(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
