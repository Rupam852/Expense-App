import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../models/expense.dart';
import '../services/supabase_service.dart';
import 'pdf_unicode_helper.dart';

class BusinessExportHelper {
  // ══════════════════════════════════════════════════════════════════════
  // 1. CUSTOMER TAX INVOICE PDF GENERATOR
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateCustomerInvoicePdf(
    BusinessSale sale,
    BusinessProfile? profile,
  ) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final primaryColor = PdfColor.fromHex('#2563EB'); // Royal Blue
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Business Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      if (prof.address != null && prof.address!.trim().isNotEmpty)
                        pw.Text(prof.address!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (prof.phone != null && prof.phone!.trim().isNotEmpty)
                        pw.Text('Phone: ${prof.phone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (prof.gstin != null && prof.gstin!.trim().isNotEmpty)
                        pw.Text('GSTIN: ${prof.gstin!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      if (prof.upiId != null && prof.upiId!.trim().isNotEmpty)
                        pw.Text('UPI ID: ${prof.upiId!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Invoice #: ${sale.invoiceNo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(sale.saleDate)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            // Billed To & Payment Status Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text(sale.customerName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                        pw.Text('Mobile: ${sale.customerPhone}', style: const pw.TextStyle(fontSize: 9)),
                      if (sale.customerAddress != null && sale.customerAddress!.isNotEmpty)
                        pw.Text('Address: ${sale.customerAddress}', style: const pw.TextStyle(fontSize: 9)),
                      if (sale.customerGstin != null && sale.customerGstin!.isNotEmpty)
                        pw.Text('GSTIN: ${sale.customerGstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Payment Mode: ${sale.paymentMode.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: sale.balanceDue <= 0 ? PdfColors.green100 : PdfColors.red100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: sale.balanceDue <= 0 ? PdfColors.green800 : PdfColors.red800, width: 0.5),
                        ),
                        child: pw.Text(
                          sale.paymentStatus.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: sale.balanceDue <= 0 ? PdfColors.green800 : PdfColors.red800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Itemized Bill Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rate (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('GST %', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ],
                ),
                ...sale.items.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  final item = e.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} ${item.unit}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.taxRate.toStringAsFixed(0)}%', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rs. ${item.totalPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 14),

            // Financial Breakdown Summary
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  child: pw.Column(
                    children: [
                      _buildRow('Taxable Subtotal:', 'Rs. ${sale.totalAmount.toStringAsFixed(2)}'),
                      if (sale.taxAmount > 0)
                        _buildRow('Total GST Tax:', 'Rs. ${sale.taxAmount.toStringAsFixed(2)}'),
                      if (sale.discountAmount > 0)
                        _buildRow('Discount:', '- Rs. ${sale.discountAmount.toStringAsFixed(2)}', color: PdfColors.green800),
                      pw.Divider(thickness: 1, color: PdfColors.grey400),
                      _buildRow('Grand Total:', 'Rs. ${sale.finalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 11),
                      _buildRow('Amount Received:', 'Rs. ${sale.paidAmount.toStringAsFixed(2)}', color: PdfColors.green800),
                      if (sale.balanceDue > 0)
                        _buildRow('Balance Due:', 'Rs. ${sale.balanceDue.toStringAsFixed(2)}', isBold: true, color: PdfColors.red800),
                    ],
                  ),
                ),
              ],
            ),

            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Notes: ${sale.notes}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],

            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Generated via Groww Expense App',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${sale.invoiceNo}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: '${sale.invoiceNo}.pdf',
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Invoice PDF Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 2. EXPENSE PAYMENT VOUCHER / PURCHASE RECEIPT PDF
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateExpenseVoucherPdf(
    Expense expense,
    BusinessProfile? profile,
  ) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final orangeAccent = PdfColor.fromHex('#EA580C'); // Amber / Orange for Expenses
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');
      final voucherNo = 'PV-${expense.id.replaceAll(RegExp(r'[^0-9]'), '').padRight(6, '0').substring(0, 6)}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: orangeAccent),
                      ),
                      if (prof.address != null && prof.address!.trim().isNotEmpty)
                        pw.Text(prof.address!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (prof.phone != null && prof.phone!.trim().isNotEmpty)
                        pw.Text('Phone: ${prof.phone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (prof.gstin != null && prof.gstin!.trim().isNotEmpty)
                        pw.Text('GSTIN: ${prof.gstin!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: orangeAccent,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'PAYMENT VOUCHER',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Voucher Meta info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Voucher #: $voucherNo', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${DateFormat('dd MMMM yyyy, hh:mm a').format(expense.transactionDate)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Voucher Body Box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildVoucherRow('Expense Category:', expense.category, isBold: true),
                    pw.SizedBox(height: 8),
                    _buildVoucherRow('Description / Paid For:', expense.description.isNotEmpty ? expense.description : 'Business Operational Expense'),
                    pw.SizedBox(height: 8),
                    _buildVoucherRow('Currency:', expense.currency),
                    if (expense.recurrencePeriod != 'none') ...[
                      pw.SizedBox(height: 8),
                      _buildVoucherRow('Recurrence:', expense.recurrencePeriod.toUpperCase()),
                    ],
                    pw.Divider(thickness: 0.8, color: PdfColors.grey300),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Amount Paid:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          'Rs. ${expense.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: orangeAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Paid By (Accountant / Manager)', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey500),
                      pw.SizedBox(height: 4),
                      pw.Text('Receiver / Vendor Signature', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Voucher_$voucherNo.pdf');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: 'Voucher_$voucherNo.pdf',
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Voucher to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Expense Voucher PDF Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 3. TAX & P&L STATEMENT PDF REPORT
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateTaxAndPnLReportPdf({
    required List<BusinessSale> sales,
    required List<Expense> expenses,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final primaryColor = PdfColor.fromHex('#047857'); // Emerald Green
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      // Filter sales & expenses for date range
      final filteredSales = sales.where((s) => s.saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && s.saleDate.isBefore(endDate.add(const Duration(days: 1)))).toList();
      final filteredExpenses = expenses.where((e) => e.transactionDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && e.transactionDate.isBefore(endDate.add(const Duration(days: 1)))).toList();

       final totalSales = filteredSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      final totalGstOutput = filteredSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);
      final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final totalGoodsCost = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalPurchaseCost);
      final netProfit = totalGoodsCost > 0
          ? (totalSales - totalGoodsCost - totalExpenses)
          : (totalSales - totalExpenses);
      final totalBalanceDue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.balanceDue);

      // Tax slabs breakup
      final Map<double, double> gstBreakup = {0.0: 0.0, 5.0: 0.0, 12.0: 0.0, 18.0: 0.0, 28.0: 0.0};
      for (var s in filteredSales) {
        for (var item in s.items) {
          final tRate = item.taxRate;
          final itemTax = (item.quantity * item.unitPrice) * (tRate / 100.0);
          gstBreakup[tRate] = (gstBreakup[tRate] ?? 0.0) + itemTax;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Business & Report Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    if (prof.address != null && prof.address!.trim().isNotEmpty)
                      pw.Text(prof.address!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.phone != null && prof.phone!.trim().isNotEmpty)
                      pw.Text('Phone: ${prof.phone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.gstin != null && prof.gstin!.trim().isNotEmpty)
                      pw.Text('GSTIN: ${prof.gstin!.trim()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    if (prof.upiId != null && prof.upiId!.trim().isNotEmpty)
                      pw.Text('UPI: ${prof.upiId!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX & P&L STATEMENT',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd/MM/yyyy, hh:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Executive Summary Cards
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildPdfSummaryCell('TOTAL SALES REVENUE', 'Rs. ${totalSales.toStringAsFixed(2)}', PdfColors.green800),
                    _buildPdfSummaryCell('TOTAL BUSINESS EXPENSES', 'Rs. ${totalExpenses.toStringAsFixed(2)}', PdfColors.orange800),
                    _buildPdfSummaryCell(
                      'NET PROFIT / LOSS',
                      'Rs. ${netProfit.toStringAsFixed(2)}',
                      netProfit >= 0 ? PdfColors.green800 : PdfColors.red800,
                      isBold: true,
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildPdfSummaryCell('TOTAL GST COLLECTED', 'Rs. ${totalGstOutput.toStringAsFixed(2)}', PdfColors.blue800),
                    _buildPdfSummaryCell('OUTSTANDING DUES (KHATA)', 'Rs. ${totalBalanceDue.toStringAsFixed(2)}', PdfColors.red800),
                    _buildPdfSummaryCell('TOTAL BILLS ISSUED', '${filteredSales.length} Invoices', PdfColors.grey800),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // GST Tax Slabs Breakdown Table
            pw.Text('GST TAX BREAKDOWN (OUTPUT GST)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('GST Slab Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('CGST (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('SGST / UTGST (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total Tax (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ],
                ),
                ...gstBreakup.entries.map((entry) {
                  final rate = entry.key;
                  final taxVal = entry.value;
                  final halfTax = taxVal / 2.0;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${rate.toStringAsFixed(0)}% GST Slab', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(halfTax.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(halfTax.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(taxVal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 18),

            // Top Recent Sales Register (first 10)
            pw.Text('SALES INVOICES REGISTER (SUMMARY)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Inv #', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Taxable (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('GST (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Status', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                ...filteredSales.take(15).map((s) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.invoiceNo, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(DateFormat('dd/MM/yy').format(s.saleDate), style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.customerName, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.totalAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.taxAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.finalAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(s.paymentStatus.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: s.balanceDue <= 0 ? PdfColors.green800 : PdfColors.red800))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),

            // Footer
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated via Groww Expense App', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text('Authorized Auditor / Manager Signatory', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Tax_Report_$dateSlug.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Tax PDF to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Tax Statement PDF Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 4. TAX & P&L EXCEL WORKBOOK GENERATOR (.xlsx)
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateTaxAndPnLReportExcel({
    required List<BusinessSale> sales,
    required List<Expense> expenses,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      // Filter sales & expenses
      final filteredSales = sales.where((s) => s.saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && s.saleDate.isBefore(endDate.add(const Duration(days: 1)))).toList();
      final filteredExpenses = expenses.where((e) => e.transactionDate.isAfter(startDate.subtract(const Duration(seconds: 1))) && e.transactionDate.isBefore(endDate.add(const Duration(days: 1)))).toList();

      final totalSales = filteredSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      final totalTaxable = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
      final totalGst = filteredSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);
      final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final totalGoodsCost = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalPurchaseCost);
      final netProfit = totalGoodsCost > 0
          ? (totalSales - totalGoodsCost - totalExpenses)
          : (totalSales - totalExpenses);

      // ── SHEET 1: Tax & P&L Summary ──────────────────────────────
      final summarySheet = excel['Tax_PnL_Summary'];
      excel.setDefaultSheet('Tax_PnL_Summary');

      summarySheet.appendRow([TextCellValue('BUSINESS TAX & P&L FINANCIAL REPORT')]);
      summarySheet.appendRow([TextCellValue('Business Name:'), TextCellValue(prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business')]);
      if (prof.gstin != null && prof.gstin!.trim().isNotEmpty) summarySheet.appendRow([TextCellValue('GSTIN:'), TextCellValue(prof.gstin!.trim())]);
      if (prof.phone != null && prof.phone!.trim().isNotEmpty) summarySheet.appendRow([TextCellValue('Phone:'), TextCellValue(prof.phone!.trim())]);
      if (prof.address != null && prof.address!.trim().isNotEmpty) summarySheet.appendRow([TextCellValue('Address:'), TextCellValue(prof.address!.trim())]);
      summarySheet.appendRow([TextCellValue('Report Period:'), TextCellValue('${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}')]);
      summarySheet.appendRow([TextCellValue('')]);

      summarySheet.appendRow([TextCellValue('METRIC'), TextCellValue('AMOUNT (INR)')]);
      summarySheet.appendRow([TextCellValue('Gross Sales Revenue'), DoubleCellValue(totalSales)]);
      summarySheet.appendRow([TextCellValue('Taxable Sales (Pre-Tax)'), DoubleCellValue(totalTaxable)]);
      summarySheet.appendRow([TextCellValue('Total GST Output Tax Collected'), DoubleCellValue(totalGst)]);
      if (totalGoodsCost > 0) {
        summarySheet.appendRow([TextCellValue('Cost of Goods Sold (Item Buy Cost)'), DoubleCellValue(totalGoodsCost)]);
      }
      summarySheet.appendRow([TextCellValue('Total Business Expenses'), DoubleCellValue(totalExpenses)]);
      summarySheet.appendRow([TextCellValue('Net Operating Profit / Loss'), DoubleCellValue(netProfit)]);
      summarySheet.appendRow([TextCellValue('Total Invoices Count'), IntCellValue(filteredSales.length)]);
      summarySheet.appendRow([TextCellValue('Total Expense Entries'), IntCellValue(filteredExpenses.length)]);

      // ── SHEET 2: Sales Invoices Register ────────────────────────
      final salesSheet = excel['Sales_Register'];
      salesSheet.appendRow([
        TextCellValue('Invoice No'),
        TextCellValue('Sale Date'),
        TextCellValue('Customer Name'),
        TextCellValue('Phone'),
        TextCellValue('GSTIN'),
        TextCellValue('Taxable Subtotal (Rs)'),
        TextCellValue('GST Tax (Rs)'),
        TextCellValue('Discount (Rs)'),
        TextCellValue('Final Amount (Rs)'),
        TextCellValue('Paid Amount (Rs)'),
        TextCellValue('Balance Due (Rs)'),
        TextCellValue('Payment Mode'),
        TextCellValue('Payment Status'),
      ]);

      for (var s in filteredSales) {
        salesSheet.appendRow([
          TextCellValue(s.invoiceNo),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(s.saleDate)),
          TextCellValue(s.customerName),
          TextCellValue(s.customerPhone ?? ''),
          TextCellValue(s.customerGstin ?? ''),
          DoubleCellValue(s.totalAmount),
          DoubleCellValue(s.taxAmount),
          DoubleCellValue(s.discountAmount),
          DoubleCellValue(s.finalAmount),
          DoubleCellValue(s.paidAmount),
          DoubleCellValue(s.balanceDue),
          TextCellValue(s.paymentMode),
          TextCellValue(s.paymentStatus),
        ]);
      }

      // ── SHEET 3: Business Expenses Register ──────────────────────
      final expSheet = excel['Expense_Register'];
      expSheet.appendRow([
        TextCellValue('Expense ID'),
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Description'),
        TextCellValue('Amount (Rs)'),
        TextCellValue('Currency'),
      ]);

      for (var e in filteredExpenses) {
        expSheet.appendRow([
          TextCellValue(e.id),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(e.transactionDate)),
          TextCellValue(e.category),
          TextCellValue(e.description),
          DoubleCellValue(e.amount),
          TextCellValue(e.currency),
        ]);
      }

      // Remove default empty Sheet1 if present
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Tax_Report_$dateSlug.xlsx';
      final file = File('${tempDir.path}/$fileName');
      final u8Bytes = Uint8List.fromList(fileBytes);
      await file.writeAsBytes(u8Bytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: u8Bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Tax Excel to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Excel Export Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 5. DETAILED BUSINESS SALES REPORT PDF (With Cost Price 🔒 & Profit)
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateSalesReportPdf({
    required List<BusinessSale> sales,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final primaryColor = PdfColor.fromHex('#2563EB'); // Royal Blue
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      // Filter sales for date range
      final filteredSales = sales.where((s) =>
        s.saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        s.saleDate.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      final totalRevenue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      final totalCost = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalPurchaseCost);
      final totalGrossProfit = totalCost > 0 ? (totalRevenue - totalCost) : totalRevenue;
      final totalDue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.balanceDue);
      final totalTax = filteredSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            // Business Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor),
                    ),
                    if (prof.address != null && prof.address!.trim().isNotEmpty)
                      pw.Text(prof.address!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.phone != null && prof.phone!.trim().isNotEmpty)
                      pw.Text('Phone: ${prof.phone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.gstin != null && prof.gstin!.trim().isNotEmpty)
                      pw.Text('GSTIN: ${prof.gstin!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'BUSINESS SALES & PROFIT REPORT',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Performance KPI Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryCell('TOTAL SALES INVOICES', '${filteredSales.length}', primaryColor, isBold: true),
                  _buildPdfSummaryCell('GROSS SALES REVENUE', 'Rs. ${totalRevenue.toStringAsFixed(2)}', PdfColors.blue800, isBold: true),
                  if (totalCost > 0)
                    _buildPdfSummaryCell('GOODS COST (COGS)', 'Rs. ${totalCost.toStringAsFixed(2)}', PdfColors.grey800),
                  _buildPdfSummaryCell('EST. GROSS PROFIT', 'Rs. ${totalGrossProfit.toStringAsFixed(2)}', PdfColors.green800, isBold: true),
                  _buildPdfSummaryCell('TOTAL GST COLLECTED', 'Rs. ${totalTax.toStringAsFixed(2)}', PdfColors.orange800),
                  _buildPdfSummaryCell('TOTAL BALANCE DUE', 'Rs. ${totalDue.toStringAsFixed(2)}', totalDue > 0 ? PdfColors.red800 : PdfColors.green800, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Sales Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Inv #
                1: const pw.FlexColumnWidth(1.1), // Date
                2: const pw.FlexColumnWidth(1.8), // Customer
                3: const pw.FlexColumnWidth(2.5), // Items
                4: const pw.FlexColumnWidth(1.1), // Cost
                5: const pw.FlexColumnWidth(1.1), // Taxable
                6: const pw.FlexColumnWidth(1.0), // GST
                7: const pw.FlexColumnWidth(1.2), // Final
                8: const pw.FlexColumnWidth(1.1), // Profit
                9: const pw.FlexColumnWidth(1.0), // Due
                10: const pw.FlexColumnWidth(1.1), // Status
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Inv #', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Items (Qty)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Cost (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Taxable', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('GST', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Profit (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Due (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Status', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                ...filteredSales.map((s) {
                  final itemsSummary = s.items.map((i) => '${i.itemName} (x${i.quantity.toInt()})').join(', ');
                  final cost = s.totalPurchaseCost;
                  final profit = s.grossProfit;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.invoiceNo, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat('dd/MM/yy').format(s.saleDate), style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.customerName, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(itemsSummary.isEmpty ? 'General Sale' : itemsSummary, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(cost > 0 ? cost.toStringAsFixed(1) : '-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.totalAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.taxAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.finalAmount.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(profit.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: profit >= 0 ? PdfColors.green800 : PdfColors.red800))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.balanceDue.toStringAsFixed(1), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, color: s.balanceDue > 0 ? PdfColors.red800 : PdfColors.green800))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(s.paymentStatus.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: s.balanceDue <= 0 ? PdfColors.green800 : PdfColors.orange800))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Footer
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Internal Business Report - Strictly Confidential', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text('Grow Expense Business Suite', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Sales_Report_$dateSlug.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Sales PDF to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Sales Report PDF Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 6. DETAILED BUSINESS SALES EXCEL SPREADSHEET (.xlsx)
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateSalesReportExcel({
    required List<BusinessSale> sales,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      final filteredSales = sales.where((s) =>
        s.saleDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        s.saleDate.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      final totalRevenue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      final totalCost = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalPurchaseCost);
      final totalGrossProfit = totalCost > 0 ? (totalRevenue - totalCost) : totalRevenue;
      final totalDue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.balanceDue);
      final totalTax = filteredSales.fold<double>(0.0, (sum, s) => sum + s.taxAmount);

      // Sheet 1: Sales Summary
      final summarySheet = excel['Sales_Summary'];
      excel.setDefaultSheet('Sales_Summary');
      summarySheet.appendRow([TextCellValue('BUSINESS SALES & PERFORMANCE REPORT')]);
      summarySheet.appendRow([TextCellValue('Business Name:'), TextCellValue(prof.businessName)]);
      if (prof.gstin != null) summarySheet.appendRow([TextCellValue('GSTIN:'), TextCellValue(prof.gstin!)]);
      summarySheet.appendRow([TextCellValue('Period:'), TextCellValue('${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}')]);
      summarySheet.appendRow([TextCellValue('')]);
      summarySheet.appendRow([TextCellValue('METRIC'), TextCellValue('AMOUNT (INR)')]);
      summarySheet.appendRow([TextCellValue('Total Invoices Count'), IntCellValue(filteredSales.length)]);
      summarySheet.appendRow([TextCellValue('Gross Sales Revenue'), DoubleCellValue(totalRevenue)]);
      summarySheet.appendRow([TextCellValue('Confidential Goods Cost (COGS)'), DoubleCellValue(totalCost)]);
      summarySheet.appendRow([TextCellValue('Est. Gross Profit'), DoubleCellValue(totalGrossProfit)]);
      summarySheet.appendRow([TextCellValue('Total GST Collected'), DoubleCellValue(totalTax)]);
      summarySheet.appendRow([TextCellValue('Total Balance Due (Udhar)'), DoubleCellValue(totalDue)]);

      // Sheet 2: Detailed Sales Register
      final salesSheet = excel['Sales_Register'];
      salesSheet.appendRow([
        TextCellValue('Invoice No'),
        TextCellValue('Sale Date'),
        TextCellValue('Customer Name'),
        TextCellValue('Customer Phone'),
        TextCellValue('Customer GSTIN'),
        TextCellValue('Items Summary'),
        TextCellValue('Confidential Buy Cost (Rs)'),
        TextCellValue('Taxable Amount (Rs)'),
        TextCellValue('GST Amount (Rs)'),
        TextCellValue('Discount Amount (Rs)'),
        TextCellValue('Final Amount (Rs)'),
        TextCellValue('Est. Gross Profit (Rs)'),
        TextCellValue('Paid Amount (Rs)'),
        TextCellValue('Balance Due (Rs)'),
        TextCellValue('Payment Mode'),
        TextCellValue('Payment Status'),
      ]);

      for (var s in filteredSales) {
        final itemsStr = s.items.map((i) => '${i.itemName} (x${i.quantity.toInt()} @ Rs.${i.unitPrice})').join(', ');
        salesSheet.appendRow([
          TextCellValue(s.invoiceNo),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(s.saleDate)),
          TextCellValue(s.customerName),
          TextCellValue(s.customerPhone ?? ''),
          TextCellValue(s.customerGstin ?? ''),
          TextCellValue(itemsStr),
          DoubleCellValue(s.totalPurchaseCost),
          DoubleCellValue(s.totalAmount),
          DoubleCellValue(s.taxAmount),
          DoubleCellValue(s.discountAmount),
          DoubleCellValue(s.finalAmount),
          DoubleCellValue(s.grossProfit),
          DoubleCellValue(s.paidAmount),
          DoubleCellValue(s.balanceDue),
          TextCellValue(s.paymentMode),
          TextCellValue(s.paymentStatus),
        ]);
      }

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Sales_Report_$dateSlug.xlsx';
      final file = File('${tempDir.path}/$fileName');
      final u8Bytes = Uint8List.fromList(fileBytes);
      await file.writeAsBytes(u8Bytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: u8Bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Sales Excel to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Sales Excel Export Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 7. BUSINESS OPERATING EXPENSES REPORT PDF
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateExpenseReportPdf({
    required List<Expense> expenses,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final orangeAccent = PdfColor.fromHex('#EA580C'); // Amber/Orange
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      final filteredExpenses = expenses.where((e) =>
        e.transactionDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        e.transactionDate.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Business Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      prof.businessName.trim().isNotEmpty ? prof.businessName.trim() : 'My Business',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: orangeAccent),
                    ),
                    if (prof.address != null && prof.address!.trim().isNotEmpty)
                      pw.Text(prof.address!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.phone != null && prof.phone!.trim().isNotEmpty)
                      pw.Text('Phone: ${prof.phone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.gstin != null && prof.gstin!.trim().isNotEmpty)
                      pw.Text('GSTIN: ${prof.gstin!.trim()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: orangeAccent,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'BUSINESS EXPENSES REGISTER',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryCell('TOTAL EXPENSE ENTRIES', '${filteredExpenses.length}', orangeAccent, isBold: true),
                  _buildPdfSummaryCell('TOTAL OPERATING EXPENSES', 'Rs. ${totalExpenses.toStringAsFixed(2)}', orangeAccent, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Expenses Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Date
                1: const pw.FlexColumnWidth(1.8), // Category
                2: const pw.FlexColumnWidth(3.0), // Description
                3: const pw.FlexColumnWidth(1.4), // Amount
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Description / Note', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                ...filteredExpenses.map((e) => pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(DateFormat('dd/MM/yyyy').format(e.transactionDate), style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(e.category, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(e.description.isEmpty ? '-' : e.description, style: const pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(e.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: orangeAccent))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),

            // Footer
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Grow Expense Business Management Suite', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text('Authorized Auditor Signatory', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Expenses_Report_$dateSlug.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: pdfBytes,
            mimeType: 'application/pdf',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Expense PDF to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Expense Report PDF Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // 8. BUSINESS OPERATING EXPENSES EXCEL SPREADSHEET (.xlsx)
  // ══════════════════════════════════════════════════════════════════════
  static Future<File?> generateExpenseReportExcel({
    required List<Expense> expenses,
    required BusinessProfile? profile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final excel = Excel.createExcel();
      final prof = profile ?? BusinessProfile(id: 'default', businessName: 'Grow Expense Business');

      final filteredExpenses = expenses.where((e) =>
        e.transactionDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        e.transactionDate.isBefore(endDate.add(const Duration(days: 1)))
      ).toList();

      final totalExpenses = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

      final summarySheet = excel['Expense_Summary'];
      excel.setDefaultSheet('Expense_Summary');
      summarySheet.appendRow([TextCellValue('BUSINESS EXPENSES FINANCIAL REPORT')]);
      summarySheet.appendRow([TextCellValue('Business Name:'), TextCellValue(prof.businessName)]);
      summarySheet.appendRow([TextCellValue('Period:'), TextCellValue('${DateFormat('dd-MM-yyyy').format(startDate)} to ${DateFormat('dd-MM-yyyy').format(endDate)}')]);
      summarySheet.appendRow([TextCellValue('')]);
      summarySheet.appendRow([TextCellValue('METRIC'), TextCellValue('AMOUNT (INR)')]);
      summarySheet.appendRow([TextCellValue('Total Expense Entries'), IntCellValue(filteredExpenses.length)]);
      summarySheet.appendRow([TextCellValue('Total Operating Expenses'), DoubleCellValue(totalExpenses)]);

      final expSheet = excel['Expense_Register'];
      expSheet.appendRow([
        TextCellValue('Expense ID'),
        TextCellValue('Transaction Date'),
        TextCellValue('Category'),
        TextCellValue('Description / Vendor'),
        TextCellValue('Amount (Rs)'),
        TextCellValue('Currency'),
      ]);

      for (var e in filteredExpenses) {
        expSheet.appendRow([
          TextCellValue(e.id),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(e.transactionDate)),
          TextCellValue(e.category),
          TextCellValue(e.description),
          DoubleCellValue(e.amount),
          TextCellValue(e.currency),
        ]);
      }

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final dateSlug = '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
      final fileName = 'Business_Expenses_Report_$dateSlug.xlsx';
      final file = File('${tempDir.path}/$fileName');
      final u8Bytes = Uint8List.fromList(fileBytes);
      await file.writeAsBytes(u8Bytes);

      if (Platform.isAndroid) {
        try {
          await SupabaseService.saveFileToDownloads(
            fileName: fileName,
            bytes: u8Bytes,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
        } catch (e) {
          debugPrint('[BusinessExportHelper] Save Expense Excel to Downloads fallback: $e');
        }
      }

      return file;
    } catch (e) {
      debugPrint('[BusinessExportHelper] Expense Excel Export Error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPER PDF WIDGETS
  // ══════════════════════════════════════════════════════════════════════
  static pw.Widget _buildRow(String label, String value, {bool isBold = false, double fontSize = 9, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildVoucherRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 140, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal))),
      ],
    );
  }

  static pw.Widget _buildPdfSummaryCell(String title, String val, PdfColor color, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(val, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
