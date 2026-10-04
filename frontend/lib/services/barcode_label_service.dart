import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class BarcodeLabelService {
  BarcodeLabelService._();
  static final BarcodeLabelService instance = BarcodeLabelService._();

  /// Generates a printable A4 PDF Document with standard sticker grid labels
  Future<Uint8List> generateLabelsPdf({
    required String productName,
    required String barcodeData,
    required String barcodeType, // 'barcode' or 'qr'
    required double price,
    required int quantity,
    required int columnsCount, // 3 or 4
    String? shopName,
    bool showShopName = true,
    bool showPrice = true,
    bool showBarcodeText = true,
    bool showCutBorders = true,
  }) async {
    final pdf = pw.Document();

    // Standard A4 dimensions
    const pageFormat = PdfPageFormat.a4;
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final priceStr = currencyFmt.format(price);

    // Calculate items per page based on columns
    // 3 columns: 8 rows per page = 24 labels per page
    // 4 columns: 10 rows per page = 40 labels per page
    final int rowsCount = columnsCount == 3 ? 8 : 10;
    final int itemsPerPage = columnsCount * rowsCount;
    final int totalPages = (quantity / itemsPerPage).ceil();

    final isQr = barcodeType.toLowerCase() == 'qr';
    final barcodeWidgetType = isQr ? pw.Barcode.qrCode() : pw.Barcode.code128();

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final startIndex = pageIdx * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage < quantity) ? startIndex + itemsPerPage : quantity;
      final pageItemsCount = endIndex - startIndex;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Header (Shop / Generation Info)
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        shopName != null && shopName.isNotEmpty
                            ? shopName.toUpperCase()
                            : 'PRODUCT STICKER LABELS',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Page ${pageIdx + 1} of $totalPages • $productName ($quantity Labels)',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Labels Grid
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: columnsCount,
                    childAspectRatio: columnsCount == 3 ? 1.9 : 1.35,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    children: List.generate(pageItemsCount, (i) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          border: showCutBorders
                              ? pw.Border.all(
                                  color: PdfColors.grey400,
                                  width: 0.6,
                                  style: pw.BorderStyle.dashed,
                                )
                              : null,
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (showShopName && shopName != null && shopName.trim().isNotEmpty) ...[
                              pw.Text(
                                shopName.trim(),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: pw.TextStyle(
                                  fontSize: columnsCount == 3 ? 6.5 : 5.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                            ],

                            // Product Name
                            pw.Text(
                              productName,
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: columnsCount == 3 ? 8.0 : 7.0,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.SizedBox(height: 2),

                            // Barcode / QR Code
                            pw.Expanded(
                              child: pw.Container(
                                alignment: pw.Alignment.center,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                                child: pw.BarcodeWidget(
                                  barcode: barcodeWidgetType,
                                  data: barcodeData.isNotEmpty ? barcodeData : '00000000',
                                  drawText: false,
                                  color: PdfColors.black,
                                  height: isQr ? 40 : 26,
                                  width: isQr ? 40 : (columnsCount == 3 ? 140 : 100),
                                ),
                              ),
                            ),

                            if (showBarcodeText && barcodeData.isNotEmpty) ...[
                              pw.Text(
                                barcodeData,
                                style: pw.TextStyle(
                                  fontSize: columnsCount == 3 ? 6.5 : 5.5,
                                  letterSpacing: 0.8,
                                  color: PdfColors.grey900,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                            ],

                            if (showPrice && price > 0) ...[
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                                ),
                                child: pw.Text(
                                  'MRP: $priceStr',
                                  style: pw.TextStyle(
                                    fontSize: columnsCount == 3 ? 7.5 : 6.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Saves the PDF to temporary file system and returns file path
  Future<File> savePdfToFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${tempDir.path}/$sanitizedName.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the PDF with default PDF viewer
  Future<void> openPdf(File file) async {
    await OpenFile.open(file.path);
  }

  /// Shares the PDF via standard system sharing sheet
  Future<void> sharePdf(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject ?? 'Product Barcode Sticker Sheet',
    );
  }
}
