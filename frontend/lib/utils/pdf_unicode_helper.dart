import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfUnicodeHelper {
  static pw.ThemeData? _cachedTheme;

  /// Loads Google Fonts with full Indian/Regional language fallback (Bengali, Hindi/Devanagari, Tamil, Telugu, Gujarati, etc.)
  /// This prevents tofu (☒☒☒) missing glyph boxes in generated PDF statements & invoices.
  static Future<pw.ThemeData> getUnicodePdfTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    try {
      final fontBase = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();
      final fontDevanagari = await PdfGoogleFonts.notoSansDevanagariRegular();
      final fontBengali = await PdfGoogleFonts.notoSansBengaliRegular();
      final fontTamil = await PdfGoogleFonts.notoSansTamilRegular();
      final fontTelugu = await PdfGoogleFonts.notoSansTeluguRegular();
      final fontGujarati = await PdfGoogleFonts.notoSansGujaratiRegular();
      final fontKannada = await PdfGoogleFonts.notoSansKannadaRegular();
      final fontMalayalam = await PdfGoogleFonts.notoSansMalayalamRegular();
      final fontGurmukhi = await PdfGoogleFonts.notoSansGurmukhiRegular();

      _cachedTheme = pw.ThemeData.withFont(
        base: fontBase,
        bold: fontBold,
        fontFallback: [
          fontBengali,
          fontDevanagari,
          fontTamil,
          fontTelugu,
          fontGujarati,
          fontKannada,
          fontMalayalam,
          fontGurmukhi,
        ],
      );
      return _cachedTheme!;
    } catch (e) {
      debugPrint('[PdfUnicodeHelper] Font loading error, using default base theme: $e');
      return pw.ThemeData.base();
    }
  }
}
