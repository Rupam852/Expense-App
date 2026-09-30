class ParsedBankSms {
  final double amount;
  final String payee;
  final String bankName;
  final String? accountLast4;
  final DateTime transactionDate;
  final String category;
  final String rawSms;

  ParsedBankSms({
    required this.amount,
    required this.payee,
    required this.bankName,
    this.accountLast4,
    required this.transactionDate,
    required this.category,
    required this.rawSms,
  });
}

class SmsParserService {
  static final RegExp _amountRegex = RegExp(
    r'(?:rs\.?|inr|debited(?:\s+by)?|spent)\s*[:\.]?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _altAmountRegex = RegExp(
    r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:debited|spent|paid)',
    caseSensitive: false,
  );

  static final RegExp _accountRegex = RegExp(
    r'(?:a\/c|acct|ac|card|ending|xx|\*\*)\s*[:\.]?\s*([0-9xX\*]{3,6})',
    caseSensitive: false,
  );

  static final RegExp _upiPayeeRegex = RegExp(
    r'(?:to|at|vpa|info[:\s]|towards|paid to)\s+([a-zA-Z0-9\.\-_@\s]{2,30}?)(?:\s+on|\s+ref|\s+upi|\s+avl|\s+bal|\.|\n|$)',
    caseSensitive: false,
  );

  static ParsedBankSms? parse(String smsText) {
    if (smsText.trim().isEmpty) return null;

    final lower = smsText.toLowerCase();

    // Check if debit transaction
    final isDebit = lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('transferred');

    if (!isDebit) return null;

    // 1. Extract Amount
    double? extractedAmount;
    var match = _amountRegex.firstMatch(smsText);
    if (match != null && match.group(1) != null) {
      final clean = match.group(1)!.replaceAll(',', '');
      extractedAmount = double.tryParse(clean);
    }

    if (extractedAmount == null) {
      match = _altAmountRegex.firstMatch(smsText);
      if (match != null && match.group(1) != null) {
        final clean = match.group(1)!.replaceAll(',', '');
        extractedAmount = double.tryParse(clean);
      }
    }

    if (extractedAmount == null || extractedAmount <= 0) return null;

    // 2. Extract Bank Name
    String bankName = 'Bank Account';
    if (lower.contains('sbi') || lower.contains('state bank')) {
      bankName = 'SBI';
    } else if (lower.contains('hdfc')) {
      bankName = 'HDFC Bank';
    } else if (lower.contains('icici')) {
      bankName = 'ICICI Bank';
    } else if (lower.contains('axis')) {
      bankName = 'Axis Bank';
    } else if (lower.contains('kotak')) {
      bankName = 'Kotak Bank';
    } else if (lower.contains('pnb') || lower.contains('punjab national')) {
      bankName = 'PNB';
    } else if (lower.contains('bob') || lower.contains('bank of baroda')) {
      bankName = 'Bank of Baroda';
    } else if (lower.contains('paytm')) {
      bankName = 'Paytm Payments Bank';
    } else if (lower.contains('cred')) {
      bankName = 'CRED';
    } else if (lower.contains('indusind')) {
      bankName = 'IndusInd Bank';
    } else if (lower.contains('canara')) {
      bankName = 'Canara Bank';
    }

    // 3. Extract Account digits
    String? accountLast4;
    final accMatch = _accountRegex.firstMatch(smsText);
    if (accMatch != null && accMatch.group(1) != null) {
      final acc = accMatch.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (acc.isNotEmpty) {
        accountLast4 = acc.length >= 4 ? acc.substring(acc.length - 4) : acc;
      }
    }

    // 4. Extract Payee / Merchant
    String payee = 'Merchant / Transfer';
    final payeeMatch = _upiPayeeRegex.firstMatch(smsText);
    if (payeeMatch != null && payeeMatch.group(1) != null) {
      var rawPayee = payeeMatch.group(1)!.trim();
      rawPayee = rawPayee.replaceAll(RegExp(r'^(the|a|an)\s+', caseSensitive: false), '');
      if (rawPayee.length > 1 && !rawPayee.toLowerCase().startsWith('rs')) {
        payee = _cleanMerchantName(rawPayee);
      }
    }

    // 5. Auto Categorization
    final category = _categorize(payee, smsText);

    return ParsedBankSms(
      amount: extractedAmount,
      payee: payee,
      bankName: bankName,
      accountLast4: accountLast4,
      transactionDate: DateTime.now(),
      category: category,
      rawSms: smsText,
    );
  }

  static String _cleanMerchantName(String raw) {
    var clean = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\s\.\-_]'), ' ').trim();
    if (clean.length > 28) clean = clean.substring(0, 28);
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _categorize(String payee, String rawSms) {
    final text = '$payee $rawSms'.toLowerCase();

    if (text.contains('swiggy') ||
        text.contains('zomato') ||
        text.contains('mcdonald') ||
        text.contains('burger') ||
        text.contains('pizza') ||
        text.contains('restaurant') ||
        text.contains('cafe') ||
        text.contains('starbucks') ||
        text.contains('chai') ||
        text.contains('dhaba') ||
        text.contains('food')) {
      return 'Food & dining';
    }

    if (text.contains('blinkit') ||
        text.contains('zepto') ||
        text.contains('instamart') ||
        text.contains('bigbasket') ||
        text.contains('grocery') ||
        text.contains('supermarket') ||
        text.contains('dmart') ||
        text.contains('vegetables') ||
        text.contains('fruits')) {
      return 'Groceries';
    }

    if (text.contains('uber') ||
        text.contains('ola') ||
        text.contains('rapido') ||
        text.contains('metro') ||
        text.contains('irctc') ||
        text.contains('railway') ||
        text.contains('petrol') ||
        text.contains('fuel') ||
        text.contains('hpcl') ||
        text.contains('bpcl') ||
        text.contains('ioc') ||
        text.contains('toll') ||
        text.contains('fastag')) {
      return 'Transport';
    }

    if (text.contains('amazon') ||
        text.contains('flipkart') ||
        text.contains('myntra') ||
        text.contains('ajio') ||
        text.contains('meesho') ||
        text.contains('nykaa') ||
        text.contains('zara') ||
        text.contains('shopping') ||
        text.contains('clothing')) {
      return 'Shopping';
    }

    if (text.contains('netflix') ||
        text.contains('spotify') ||
        text.contains('prime') ||
        text.contains('hotstar') ||
        text.contains('youtube') ||
        text.contains('cinema') ||
        text.contains('pvr') ||
        text.contains('inox') ||
        text.contains('bookmyshow') ||
        text.contains('subscription')) {
      return 'Entertainment';
    }

    if (text.contains('airtel') ||
        text.contains('jio') ||
        text.contains('vi') ||
        text.contains('broadband') ||
        text.contains('electricity') ||
        text.contains('water') ||
        text.contains('gas') ||
        text.contains('recharge') ||
        text.contains('bill')) {
      return 'Bills & recharges';
    }

    if (text.contains('apollo') ||
        text.contains('pharmeasy') ||
        text.contains('1mg') ||
        text.contains('hospital') ||
        text.contains('doctor') ||
        text.contains('clinic') ||
        text.contains('pharmacy') ||
        text.contains('medplus') ||
        text.contains('medical')) {
      return 'Medical';
    }

    if (text.contains('rent') || text.contains('landlord') || text.contains('pg')) {
      return 'Rent';
    }

    if (text.contains('groww') ||
        text.contains('zerodha') ||
        text.contains('sip') ||
        text.contains('mutual fund') ||
        text.contains('invest')) {
      return 'Investment';
    }

    return 'Transfers';
  }
}
