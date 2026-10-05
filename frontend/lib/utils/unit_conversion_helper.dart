class UnitConversionHelper {
  // Normalize unit string to lowercase standard code
  static String normalizeUnit(String unit) {
    final u = unit.trim().toLowerCase().replaceAll('.', '');
    switch (u) {
      // Weight
      case 'g':
      case 'gm':
      case 'gms':
      case 'gram':
      case 'grams':
        return 'g';
      case 'kg':
      case 'kgs':
      case 'kilogram':
      case 'kilograms':
      case 'kilo':
        return 'kg';
      case 'mg':
      case 'milligram':
      case 'milligrams':
        return 'mg';
      case 'qtl':
      case 'quintal':
      case 'quintals':
        return 'quintal';
      case 'ton':
      case 'tonne':
      case 'tons':
      case 'tonnes':
      case 'mt':
        return 'ton';
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return 'lb';
      case 'oz':
      case 'ounce':
      case 'ounces':
        return 'oz';

      // Length
      case 'mm':
      case 'millimeter':
      case 'millimeters':
        return 'mm';
      case 'cm':
      case 'centimeter':
      case 'centimeters':
        return 'cm';
      case 'm':
      case 'mtr':
      case 'meter':
      case 'meters':
      case 'metre':
      case 'metres':
        return 'm';
      case 'km':
      case 'kilometer':
      case 'kilometers':
        return 'km';
      case 'in':
      case 'inch':
      case 'inches':
        return 'inch';
      case 'ft':
      case 'feet':
      case 'foot':
        return 'ft';
      case 'yd':
      case 'yard':
      case 'yards':
        return 'yd';

      // Volume
      case 'ml':
      case 'milliliter':
      case 'milliliters':
      case 'millilitre':
        return 'ml';
      case 'cl':
      case 'centiliter':
        return 'cl';
      case 'ltr':
      case 'l':
      case 'liter':
      case 'liters':
      case 'litre':
      case 'litres':
        return 'ltr';
      case 'gal':
      case 'gallon':
      case 'gallons':
        return 'gal';

      // Area
      case 'sqft':
      case 'sq ft':
      case 'sq_ft':
        return 'sq.ft';
      case 'sqm':
      case 'sq m':
      case 'sq_m':
        return 'sq.m';
      case 'acre':
      case 'acres':
        return 'acre';

      // Count / Pack
      case 'pcs':
      case 'pc':
      case 'piece':
      case 'pieces':
      case 'item':
      case 'items':
      case 'nos':
      case 'no':
      case 'unit':
      case 'units':
        return 'pcs';
      case 'doz':
      case 'dz':
      case 'dozen':
      case 'dozens':
        return 'doz';
      case 'pair':
      case 'pairs':
        return 'pair';
      case 'box':
      case 'boxes':
        return 'box';
      case 'pkt':
      case 'packet':
      case 'packets':
        return 'pkt';
      case 'set':
      case 'sets':
        return 'set';
      case 'service':
      case 'services':
        return 'service';

      default:
        return u;
    }
  }

  // Multipliers to Base Unit for each family
  // Weight base: grams (g)
  static final Map<String, double> _weightToBase = {
    'mg': 0.001,
    'g': 1.0,
    'kg': 1000.0,
    'quintal': 100000.0, // 1 quintal = 100 kg = 100,000 g
    'ton': 1000000.0,    // 1 ton = 1000 kg = 1,000,000 g
    'lb': 453.59237,
    'oz': 28.349523125,
  };

  // Length base: meters (m)
  static final Map<String, double> _lengthToBase = {
    'mm': 0.001,
    'cm': 0.01,
    'inch': 0.0254,
    'ft': 0.3048,
    'yd': 0.9144,
    'm': 1.0,
    'km': 1000.0,
  };

  // Volume base: milliliters (ml)
  static final Map<String, double> _volumeToBase = {
    'ml': 1.0,
    'cl': 10.0,
    'ltr': 1000.0,
    'gal': 3785.411784,
  };

  // Area base: square meters (sq.m)
  static final Map<String, double> _areaToBase = {
    'sq.ft': 0.092903,
    'sq.m': 1.0,
    'acre': 4046.8564224,
  };

  // Count base: single piece (pcs)
  static final Map<String, double> _countToBase = {
    'pcs': 1.0,
    'pair': 2.0,
    'doz': 12.0,
  };

  // Determine which family a unit belongs to
  static String? getUnitFamily(String rawUnit) {
    final u = normalizeUnit(rawUnit);
    if (_weightToBase.containsKey(u)) return 'weight';
    if (_lengthToBase.containsKey(u)) return 'length';
    if (_volumeToBase.containsKey(u)) return 'volume';
    if (_areaToBase.containsKey(u)) return 'area';
    if (_countToBase.containsKey(u)) return 'count';
    return null;
  }

  // Check if two units can be converted
  static bool areUnitsCompatible(String fromUnit, String toUnit) {
    final u1 = normalizeUnit(fromUnit);
    final u2 = normalizeUnit(toUnit);
    if (u1 == u2) return true;
    final f1 = getUnitFamily(u1);
    final f2 = getUnitFamily(u2);
    return f1 != null && f1 == f2;
  }

  // Convert quantity from fromUnit to toUnit
  static double convertQuantity({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    if (quantity == 0) return 0.0;
    final uFrom = normalizeUnit(fromUnit);
    final uTo = normalizeUnit(toUnit);

    if (uFrom == uTo) return quantity;

    final family = getUnitFamily(uFrom);
    if (family == null || family != getUnitFamily(uTo)) {
      // Incompatible unit dimensions: fallback to 1-to-1
      return quantity;
    }

    Map<String, double> baseMap;
    switch (family) {
      case 'weight':
        baseMap = _weightToBase;
        break;
      case 'length':
        baseMap = _lengthToBase;
        break;
      case 'volume':
        baseMap = _volumeToBase;
        break;
      case 'area':
        baseMap = _areaToBase;
        break;
      case 'count':
        baseMap = _countToBase;
        break;
      default:
        return quantity;
    }

    final fromFactor = baseMap[uFrom] ?? 1.0;
    final toFactor = baseMap[uTo] ?? 1.0;

    final inBase = quantity * fromFactor;
    return inBase / toFactor;
  }

  // Format a quantity string cleanly (e.g. 5, 0.5, 2.75)
  static String formatQuantity(double qty, [String? unit]) {
    String formatted;
    if (qty == qty.roundToDouble()) {
      formatted = qty.toStringAsFixed(0);
    } else if ((qty * 10).roundToDouble() == (qty * 10)) {
      formatted = qty.toStringAsFixed(1);
    } else if ((qty * 100).roundToDouble() == (qty * 100)) {
      formatted = qty.toStringAsFixed(2);
    } else {
      formatted = qty.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    if (unit != null && unit.isNotEmpty) {
      return '$formatted $unit';
    }
    return formatted;
  }

  // Calculate live remaining stock & deduction info
  static StockDeductionResult calculateRemainingStock({
    required double currentStock,
    required String stockUnit,
    required double sellQty,
    required String sellUnit,
  }) {
    final normStockUnit = normalizeUnit(stockUnit);
    final normSellUnit = normalizeUnit(sellUnit);

    final isDifferentUnit = normStockUnit != normSellUnit && areUnitsCompatible(sellUnit, stockUnit);
    final deductionInStockUnit = convertQuantity(
      quantity: sellQty,
      fromUnit: sellUnit,
      toUnit: stockUnit,
    );

    final remainingStock = currentStock - deductionInStockUnit;

    return StockDeductionResult(
      currentStock: currentStock,
      stockUnit: stockUnit,
      sellQty: sellQty,
      sellUnit: sellUnit,
      deductionInStockUnit: deductionInStockUnit,
      remainingStock: remainingStock,
      isConverted: isDifferentUnit,
    );
  }
}

class StockDeductionResult {
  final double currentStock;
  final String stockUnit;
  final double sellQty;
  final String sellUnit;
  final double deductionInStockUnit;
  final double remainingStock;
  final bool isConverted;

  StockDeductionResult({
    required this.currentStock,
    required this.stockUnit,
    required this.sellQty,
    required this.sellUnit,
    required this.deductionInStockUnit,
    required this.remainingStock,
    required this.isConverted,
  });

  bool get isOutOfStock => remainingStock <= 0;
  bool get isOverSelling => remainingStock < 0;

  String get deductionPreview {
    if (isConverted) {
      final fromStr = UnitConversionHelper.formatQuantity(sellQty, sellUnit);
      final toStr = UnitConversionHelper.formatQuantity(deductionInStockUnit, stockUnit);
      return '$fromStr = $toStr deducted';
    }
    return '${UnitConversionHelper.formatQuantity(deductionInStockUnit, stockUnit)} deducted';
  }
}
