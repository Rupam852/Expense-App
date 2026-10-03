import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../models/khata_entry.dart';
import '../services/database_helper.dart';
import '../utils/pdf_unicode_helper.dart';
import '../widgets/custom_toast.dart';

class AddBusinessSaleScreen extends StatefulWidget {
  final BusinessSale? existingSale;

  const AddBusinessSaleScreen({super.key, this.existingSale});

  @override
  State<AddBusinessSaleScreen> createState() => _AddBusinessSaleScreenState();
}

class _AddBusinessSaleScreenState extends State<AddBusinessSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isWalkIn = true;
  final TextEditingController _customerNameController = TextEditingController(text: 'Walk-in Customer');
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerGstinController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _saleDate = DateTime.now();
  String _paymentMode = 'Cash'; // Cash, UPI, Bank Transfer, Credit
  String _paymentStatus = 'Paid'; // Paid, Partial, Unpaid
  bool _autoAddToKhata = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _itemRows = [];
  BusinessProfile? _businessProfile;

  static const List<double> _taxSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];
  static const List<String> _units = ['pcs', 'kg', 'g', 'ltr', 'ml', 'box', 'pkt', 'm', 'nos'];

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();

    if (widget.existingSale != null) {
      final s = widget.existingSale!;
      _isWalkIn = s.customerName == 'Walk-in Customer' && (s.customerPhone == null || s.customerPhone!.isEmpty);
      _customerNameController.text = s.customerName;
      _customerPhoneController.text = s.customerPhone ?? '';
      _customerGstinController.text = s.customerGstin ?? '';
      _customerAddressController.text = s.customerAddress ?? '';
      _discountController.text = s.discountAmount.toStringAsFixed(0);
      _paidAmountController.text = s.paidAmount.toStringAsFixed(0);
      _notesController.text = s.notes ?? '';
      _saleDate = s.saleDate;
      _paymentMode = s.paymentMode;
      _paymentStatus = s.paymentStatus;

      for (var item in s.items) {
        _itemRows.add({
          'name': TextEditingController(text: item.itemName),
          'qty': TextEditingController(text: item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)),
          'unit': item.unit,
          'price': TextEditingController(text: item.unitPrice.toStringAsFixed(2)),
          'tax': item.taxRate,
        });
      }
    } else {
      _addNewItemRow();
    }
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final prof = await DatabaseHelper.instance.getBusinessProfile();
      if (mounted) {
        setState(() => _businessProfile = prof);
      }
    } catch (_) {}
  }

  void _addNewItemRow() {
    setState(() {
      _itemRows.add({
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'unit': 'pcs',
        'price': TextEditingController(text: '0'),
        'tax': 0.0,
      });
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length <= 1) {
      CustomToast.show(context, 'At least 1 item is required');
      return;
    }
    setState(() {
      _itemRows[index]['name'].dispose();
      _itemRows[index]['qty'].dispose();
      _itemRows[index]['price'].dispose();
      _itemRows.removeAt(index);
    });
  }

  double get _subtotal {
    double total = 0.0;
    for (var row in _itemRows) {
      final q = double.tryParse(row['qty'].text.trim()) ?? 0.0;
      final p = double.tryParse(row['price'].text.trim()) ?? 0.0;
      total += (q * p);
    }
    return total;
  }

  double get _taxTotal {
    double taxSum = 0.0;
    for (var row in _itemRows) {
      final q = double.tryParse(row['qty'].text.trim()) ?? 0.0;
      final p = double.tryParse(row['price'].text.trim()) ?? 0.0;
      final t = (row['tax'] as double?) ?? 0.0;
      final itemTotal = q * p;
      taxSum += (itemTotal * (t / 100.0));
    }
    return taxSum;
  }

  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0.0;

  double get _grandTotal {
    final t = (_subtotal + _taxTotal) - _discount;
    return t < 0 ? 0.0 : t;
  }

  double get _paidAmount {
    if (_paymentStatus == 'Paid') return _grandTotal;
    if (_paymentStatus == 'Unpaid') return 0.0;
    return double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
  }

  double get _balanceDue {
    final bal = _grandTotal - _paidAmount;
    return bal < 0 ? 0.0 : bal;
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerGstinController.dispose();
    _customerAddressController.dispose();
    _discountController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    for (var row in _itemRows) {
      row['name'].dispose();
      row['qty'].dispose();
      row['price'].dispose();
    }
    super.dispose();
  }

  Future<void> _saveSale({bool generatePdf = false, bool shareWhatsApp = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_itemRows.isEmpty) {
      CustomToast.show(context, 'Please add at least one item');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final saleId = widget.existingSale?.id ?? 'sale_${DateTime.now().millisecondsSinceEpoch}';
      final invoiceNo = widget.existingSale?.invoiceNo ?? 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

      final List<BusinessSaleItem> items = [];
      for (var row in _itemRows) {
        final itemName = row['name'].text.trim().isEmpty ? 'Item' : row['name'].text.trim();
        final qty = double.tryParse(row['qty'].text.trim()) ?? 1.0;
        final unit = row['unit'].toString();
        final price = double.tryParse(row['price'].text.trim()) ?? 0.0;
        final tax = (row['tax'] as double?) ?? 0.0;
        final itemTotal = (qty * price) + ((qty * price) * (tax / 100.0));

        items.add(BusinessSaleItem(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}_${items.length}',
          saleId: saleId,
          itemName: itemName,
          quantity: qty,
          unit: unit,
          unitPrice: price,
          taxRate: tax,
          totalPrice: itemTotal,
        ));
      }

      final custName = _isWalkIn ? 'Walk-in Customer' : _customerNameController.text.trim();
      final custPhone = _isWalkIn ? '' : _customerPhoneController.text.trim();

      final sale = BusinessSale(
        id: saleId,
        customerName: custName,
        customerPhone: custPhone.isNotEmpty ? custPhone : null,
        customerAddress: _customerAddressController.text.trim().isNotEmpty ? _customerAddressController.text.trim() : null,
        customerGstin: _customerGstinController.text.trim().isNotEmpty ? _customerGstinController.text.trim() : null,
        totalAmount: _subtotal,
        taxAmount: _taxTotal,
        discountAmount: _discount,
        finalAmount: _grandTotal,
        paidAmount: _paidAmount,
        balanceDue: _balanceDue,
        paymentMode: _paymentMode,
        paymentStatus: _paymentStatus,
        saleDate: _saleDate,
        invoiceNo: invoiceNo,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        items: items,
      );

      await DatabaseHelper.instance.insertBusinessSale(sale);

      // Auto-add to Customer Khata if there is a pending balance
      if (_balanceDue > 0 && _autoAddToKhata && custName.isNotEmpty && custName != 'Walk-in Customer') {
        try {
          final khataEntry = KhataEntry(
            id: 'khata_${DateTime.now().millisecondsSinceEpoch}',
            personName: custName,
            phoneNumber: custPhone,
            amount: _balanceDue,
            type: 'lent', // Customer owes you (You will get)
            entryDate: _saleDate,
            note: 'Sale Bill #$invoiceNo: Total ₹${_grandTotal.toStringAsFixed(0)}, Paid ₹${_paidAmount.toStringAsFixed(0)}',
            isSettled: false,
          );
          await DatabaseHelper.instance.insertKhataEntry(khataEntry);
        } catch (e) {
          debugPrint('[AddBusinessSale] Khata auto-add note: $e');
        }
      }

      if (mounted) {
        CustomToast.show(context, '✅ Sale #$invoiceNo recorded successfully!');
      }

      if (generatePdf || shareWhatsApp) {
        final pdfFile = await _createInvoicePdf(sale);
        if (shareWhatsApp && custPhone.isNotEmpty) {
          await _shareOnWhatsApp(sale, pdfFile);
        } else if (generatePdf && pdfFile != null) {
          await OpenFile.open(pdfFile.path);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error saving sale: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<File?> _createInvoicePdf(BusinessSale sale) async {
    try {
      final pdfTheme = await PdfUnicodeHelper.getUnicodePdfTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final mintColor = PdfColor.fromHex('#3B82F6'); // Business Blue Accent
      final prof = _businessProfile ?? BusinessProfile(id: 'def', businessName: 'Grow Expense Business');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      prof.businessName,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: mintColor),
                    ),
                    if (prof.address != null && prof.address!.isNotEmpty)
                      pw.Text(prof.address!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.phone != null && prof.phone!.isNotEmpty)
                      pw.Text('Phone: ${prof.phone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (prof.gstin != null && prof.gstin!.isNotEmpty)
                      pw.Text('GSTIN: ${prof.gstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                    pw.Text('Invoice #: ${sale.invoiceNo}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(sale.saleDate)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            // Bill To
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Billed To:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.Text(sale.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
                      pw.Text(
                        'Status: ${sale.paymentStatus.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: sale.balanceDue <= 0 ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Items Table
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
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tax %', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
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

            // Totals Breakup
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      _buildPdfTotalRow('Subtotal:', 'Rs. ${sale.totalAmount.toStringAsFixed(2)}'),
                      if (sale.taxAmount > 0)
                        _buildPdfTotalRow('GST / Tax Total:', 'Rs. ${sale.taxAmount.toStringAsFixed(2)}'),
                      if (sale.discountAmount > 0)
                        _buildPdfTotalRow('Discount:', '- Rs. ${sale.discountAmount.toStringAsFixed(2)}'),
                      pw.Divider(thickness: 1, color: PdfColors.grey400),
                      _buildPdfTotalRow('Grand Total:', 'Rs. ${sale.finalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 11),
                      _buildPdfTotalRow('Paid Amount:', 'Rs. ${sale.paidAmount.toStringAsFixed(2)}', color: PdfColors.green800),
                      if (sale.balanceDue > 0)
                        _buildPdfTotalRow('Balance Due:', 'Rs. ${sale.balanceDue.toStringAsFixed(2)}', isBold: true, color: PdfColors.red800),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Footer
            pw.Divider(thickness: 0.8, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${sale.invoiceNo}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      debugPrint('[AddBusinessSale] PDF Error: $e');
      return null;
    }
  }

  pw.Widget _buildPdfTotalRow(String label, String value, {bool isBold = false, double fontSize = 9, PdfColor? color}) {
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

  Future<void> _shareOnWhatsApp(BusinessSale sale, File? pdfFile) async {
    final cleanPhone = sale.customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final msg = Uri.encodeComponent(
      '🧾 *Invoice #${sale.invoiceNo}*\n'
      'From: *${_businessProfile?.businessName ?? 'Grow Expense Business'}*\n\n'
      'Dear ${sale.customerName},\n'
      'Total Bill: *₹${sale.finalAmount.toStringAsFixed(2)}*\n'
      'Paid: ₹${sale.paidAmount.toStringAsFixed(2)}\n'
      '${sale.balanceDue > 0 ? "⚠️ Balance Due: *₹${sale.balanceDue.toStringAsFixed(2)}*\n" : "✅ Status: *Fully Paid*\n"}'
      '\nThank you for choosing us! 🙏',
    );

    if (pdfFile != null) {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Invoice #${sale.invoiceNo} from ${_businessProfile?.businessName ?? 'Business'} - Total: ₹${sale.finalAmount.toStringAsFixed(2)}',
          files: [XFile(pdfFile.path)],
        ),
      );
    } else if (formattedPhone.isNotEmpty) {
      final url = 'https://wa.me/$formattedPhone?text=$msg';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF3B82F6); // Sapphire Blue for Business

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingSale != null ? 'Edit Sale Bill' : '➕ New Sale / Tax Invoice',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Save & Generate PDF',
            onPressed: _isSaving ? null : () => _saveSale(generatePdf: true),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grand Total', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                    Text(
                      '₹${_grandTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveSale(shareWhatsApp: true),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Save & Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _saveSale(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Sale'),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── CUSTOMER CARD ──────────────────────────────────
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Customer Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Walk-in'),
                            selected: _isWalkIn,
                            onSelected: (val) => setState(() => _isWalkIn = true),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Regular'),
                            selected: !_isWalkIn,
                            onSelected: (val) => setState(() => _isWalkIn = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_isWalkIn) ...[
                    TextFormField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number (for WhatsApp Bill)',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customerGstinController,
                            decoration: const InputDecoration(
                              labelText: 'GSTIN (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _customerAddressController,
                            decoration: const InputDecoration(
                              labelText: 'City / Address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      '⚡ Walk-in / Cash Counter Customer (No contact required)',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── ITEMS CARD ─────────────────────────────────────
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Billing Items (${_itemRows.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _addNewItemRow,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ..._itemRows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: primaryColor.withOpacity(0.15),
                                child: Text('${idx + 1}', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: row['name'],
                                  decoration: const InputDecoration(
                                    hintText: 'Item Name (e.g. Rice, Shirt)',
                                    isDense: true,
                                    border: UnderlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeItemRow(idx),
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: row['qty'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              DropdownButton<String>(
                                value: row['unit'],
                                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (u) => setState(() => row['unit'] = u ?? 'pcs'),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: row['price'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              DropdownButton<double>(
                                value: row['tax'],
                                items: _taxSlabs.map((t) => DropdownMenuItem(value: t, child: Text('${t.toStringAsFixed(0)}% GST', style: const TextStyle(fontSize: 11)))).toList(),
                                onChanged: (t) => setState(() => row['tax'] = t ?? 0.0),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── TOTALS & DISCOUNT BREAKUP ─────────────────────
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill Summary & Taxes', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                  _buildSummaryRow('GST / Tax Total', '₹${_taxTotal.toStringAsFixed(2)}', color: Colors.blueAccent),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount (₹):'),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow('Grand Total', '₹${_grandTotal.toStringAsFixed(2)}', isBold: true, fontSize: 16, color: primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── PAYMENT STATUS & UDHAR KHATA ──────────────────
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Collection', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                          items: ['Cash', 'UPI', 'Bank Transfer', 'Credit / Udhar'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _paymentMode = v ?? 'Cash'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentStatus,
                          decoration: const InputDecoration(labelText: 'Payment Status', border: OutlineInputBorder()),
                          items: ['Paid', 'Partial', 'Unpaid'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _paymentStatus = v ?? 'Paid';
                              if (_paymentStatus == 'Partial') {
                                _paidAmountController.text = (_grandTotal / 2).toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_paymentStatus == 'Partial') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Received Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_balanceDue > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remaining Due: ₹${_balanceDue.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-record this balance in Customer Udhar Khata', style: TextStyle(fontSize: 12)),
                            value: _autoAddToKhata,
                            onChanged: (val) => setState(() => _autoAddToKhata = val ?? true),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.outfit(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
