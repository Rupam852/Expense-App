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
import 'package:provider/provider.dart';
import '../models/business_sale.dart';
import '../models/business_profile.dart';
import '../models/business_item.dart';
import '../models/khata_entry.dart';
import '../services/database_helper.dart';
import '../services/expense_provider.dart';
import '../utils/pdf_unicode_helper.dart';
import '../widgets/custom_toast.dart';
import 'business_catalog_screen.dart';

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
  final TextEditingController _discountPercentController = TextEditingController(text: '0');
  String _discountType = '₹'; // '₹' or '%'
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
          'cost': TextEditingController(text: item.purchasePrice != null ? item.purchasePrice!.toStringAsFixed(item.purchasePrice! % 1 == 0 ? 0 : 2) : ''),
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
        'cost': TextEditingController(),
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
      _itemRows[index]['cost']?.dispose();
      _itemRows.removeAt(index);
    });
  }

  void _populateItemRowFromCatalog(int index, BusinessItem item) {
    setState(() {
      _itemRows[index]['name'].text = item.name;
      _itemRows[index]['price'].text = item.sellingPrice > 0 ? item.sellingPrice.toStringAsFixed(2) : '0';
      if (item.purchasePrice > 0) {
        _itemRows[index]['cost']?.text = item.purchasePrice.toStringAsFixed(2);
      } else {
        _itemRows[index]['cost']?.text = '';
      }
      _itemRows[index]['unit'] = _units.contains(item.unit.toLowerCase()) ? item.unit.toLowerCase() : 'pcs';
      _itemRows[index]['tax'] = _taxSlabs.contains(item.taxRate) ? item.taxRate : 0.0;
      _updateDiscountFromPercent();
    });
  }

  void _addItemFromCatalog(BusinessItem item) {
    if (_itemRows.length == 1 &&
        _itemRows[0]['name'].text.trim().isEmpty &&
        (_itemRows[0]['price'].text == '0' || _itemRows[0]['price'].text.isEmpty)) {
      _populateItemRowFromCatalog(0, item);
    } else {
      setState(() {
        _itemRows.add({
          'name': TextEditingController(text: item.name),
          'qty': TextEditingController(text: '1'),
          'unit': _units.contains(item.unit.toLowerCase()) ? item.unit.toLowerCase() : 'pcs',
          'price': TextEditingController(text: item.sellingPrice > 0 ? item.sellingPrice.toStringAsFixed(2) : '0'),
          'cost': TextEditingController(text: item.purchasePrice > 0 ? item.purchasePrice.toStringAsFixed(2) : ''),
          'tax': _taxSlabs.contains(item.taxRate) ? item.taxRate : 0.0,
        });
        _updateDiscountFromPercent();
      });
    }
  }

  void _showCatalogPickerModal({int? targetRowIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _CatalogPickerBottomSheet(
          onItemSelected: (item) {
            Navigator.of(ctx).pop();
            if (targetRowIndex != null && targetRowIndex < _itemRows.length) {
              _populateItemRowFromCatalog(targetRowIndex, item);
            } else {
              _addItemFromCatalog(item);
            }
          },
        );
      },
    );
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

  double get _totalCost {
    double total = 0.0;
    for (var row in _itemRows) {
      final q = double.tryParse(row['qty'].text.trim()) ?? 0.0;
      final c = double.tryParse(row['cost']?.text.trim() ?? '') ?? 0.0;
      total += (q * c);
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

  void _updateDiscountFromPercent() {
    if (_discountType == '%') {
      final p = double.tryParse(_discountPercentController.text.trim()) ?? 0.0;
      final calc = _subtotal * (p / 100.0);
      _discountController.text = calc.toStringAsFixed(calc % 1 == 0 ? 0 : 2);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerGstinController.dispose();
    _customerAddressController.dispose();
    _discountController.dispose();
    _discountPercentController.dispose();
    _paidAmountController.dispose();
    _notesController.dispose();
    for (var row in _itemRows) {
      row['name'].dispose();
      row['qty'].dispose();
      row['price'].dispose();
      row['cost']?.dispose();
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
        final costText = row['cost']?.text.trim() ?? '';
        final costPrice = costText.isNotEmpty ? double.tryParse(costText) : null;
        final tax = (row['tax'] as double?) ?? 0.0;
        final itemTotal = (qty * price) + ((qty * price) * (tax / 100.0));

        items.add(BusinessSaleItem(
          id: 'item_${DateTime.now().microsecondsSinceEpoch}_${items.length}',
          saleId: saleId,
          itemName: itemName,
          quantity: qty,
          unit: unit,
          unitPrice: price,
          purchasePrice: costPrice,
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
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E88E5),
                              side: const BorderSide(color: Color(0xFF1E88E5), width: 1.2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showCatalogPickerModal(),
                            icon: const Icon(Icons.inventory_2_outlined, size: 16),
                            label: Text('Catalog', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _addNewItemRow,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Manual'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Consumer<ExpenseProvider>(
                    builder: (context, expProv, _) {
                      final catalog = expProv.businessItems;
                      if (catalog.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: catalog.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (ctx, i) {
                              final it = catalog[i];
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                                side: BorderSide(color: const Color(0xFF1E88E5).withOpacity(0.3)),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      it.name,
                                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E88E5)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('₹${it.sellingPrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                onPressed: () => _addItemFromCatalog(it),
                              );
                            },
                          ),
                        ),
                      );
                    },
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
                                  decoration: InputDecoration(
                                    hintText: 'Item Name (e.g. Rice, Shirt)',
                                    isDense: true,
                                    border: const UnderlineInputBorder(),
                                    suffixIcon: IconButton(
                                      tooltip: 'Pick from Catalog',
                                      icon: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF1E88E5)),
                                      onPressed: () => _showCatalogPickerModal(targetRowIndex: idx),
                                    ),
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
                                  onChanged: (_) {
                                    setState(() {
                                      _updateDiscountFromPercent();
                                    });
                                  },
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
                                  onChanged: (_) {
                                    setState(() {
                                      _updateDiscountFromPercent();
                                    });
                                  },
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: row['cost'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Buy / Cost Price (₹) 🔒',
                                    hintText: 'Purchase cost (Optional)',
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.blueGrey),
                                    border: const OutlineInputBorder(),
                                    helperText: 'Private (Hidden on bill)',
                                    helperStyle: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Builder(builder: (ctx) {
                                final q = double.tryParse(row['qty'].text.trim()) ?? 1.0;
                                final p = double.tryParse(row['price'].text.trim()) ?? 0.0;
                                final c = double.tryParse(row['cost']?.text.trim() ?? '') ?? 0.0;
                                final itemProfit = (p - c) * q;
                                if (c <= 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: (itemProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (itemProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Est. Profit', style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey)),
                                      Text(
                                        '${itemProfit >= 0 ? "+" : ""}₹${itemProfit.toStringAsFixed(0)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: itemProfit >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
                  if (_totalCost > 0) ...[
                    _buildSummaryRow(
                      'Est. Gross Profit (🔒 Internal)',
                      '₹${((_subtotal - _discount) - _totalCost).toStringAsFixed(2)}',
                      color: const Color(0xFF10B981),
                      isBold: true,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Discount:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Container(
                              height: 28,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _discountType = '₹';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _discountType == '₹' ? primaryColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₹ Amount',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _discountType == '₹' ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _discountType = '%';
                                        _updateDiscountFromPercent();
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _discountType == '%' ? primaryColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '% Percent',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _discountType == '%' ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 130,
                          child: _discountType == '%'
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: TextFormField(
                                        controller: _discountPercentController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.end,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          suffixText: '%',
                                          border: UnderlineInputBorder(),
                                        ),
                                        onChanged: (_) {
                                          setState(() {
                                            _updateDiscountFromPercent();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(-₹${_discount.toStringAsFixed(0)})',
                                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              : TextFormField(
                                  controller: _discountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.end,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    prefixText: '₹ ',
                                    border: UnderlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                        ),
                      ],
                    ),
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

class _CatalogPickerBottomSheet extends StatefulWidget {
  final ValueChanged<BusinessItem> onItemSelected;

  const _CatalogPickerBottomSheet({required this.onItemSelected});

  @override
  State<_CatalogPickerBottomSheet> createState() => _CatalogPickerBottomSheetState();
}

class _CatalogPickerBottomSheetState extends State<_CatalogPickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expProv = Provider.of<ExpenseProvider>(context);
    final items = expProv.businessItems.where((it) {
      if (_search.isEmpty) return true;
      return it.name.toLowerCase().contains(_search.toLowerCase()) ||
          (it.category?.toLowerCase().contains(_search.toLowerCase()) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2, color: Color(0xFF1E88E5), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Select from Catalog',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BusinessCatalogScreen()),
                  );
                },
                icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF1E88E5)),
                label: Text(
                  'Manage',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Box
          TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search products or services...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white60 : Colors.black45, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (val) => setState(() => _search = val.trim()),
          ),
          const SizedBox(height: 12),

          // Item List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text(
                          expProv.businessItems.isEmpty
                              ? 'No items in catalog yet.'
                              : 'No matching items found.',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                        ),
                        if (expProv.businessItems.isEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add New Item to Catalog'),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const BusinessCatalogScreen()),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final it = items[i];
                      final hasCost = it.purchasePrice > 0;
                      return InkWell(
                        onTap: () => widget.onItemSelected(it),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle_outline, color: Color(0xFF1E88E5), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        Text(
                                          'Unit: ${it.unit.toUpperCase()}',
                                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                                        ),
                                        Text(
                                          '•',
                                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                                        ),
                                        Text(
                                          it.taxRate > 0 ? 'GST ${it.taxRate.toStringAsFixed(0)}%' : '0% GST',
                                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.purpleAccent),
                                        ),
                                        if (hasCost) ...[
                                          Text('•', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey)),
                                          Text('Cost: ₹${it.purchasePrice.toStringAsFixed(0)} 🔒',
                                              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.amber)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${it.sellingPrice.toStringAsFixed(2)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Tap to select',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF1E88E5)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
