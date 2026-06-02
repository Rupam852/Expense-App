import express from 'express';
import multer from 'multer';
import xlsx from 'xlsx';
import pdfParse from 'pdf-parse';
import crypto from 'crypto';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

const logBuffer = [];
function logDiagnostic(msg) {
  console.log(msg);
  logBuffer.push(`[${new Date().toISOString()}] ${msg}`);
  if (logBuffer.length > 200) {
    logBuffer.shift();
  }
}

// Resilient helper to extract floating numbers from formatted currency text (e.g., "₹1,863.34" -> 1863.34)
function cleanAmount(val) {
  if (val === null || val === undefined) return 0.0;
  if (typeof val === 'number') return Math.abs(val);
  const cleanStr = String(val).replace(/[₹$€£\s,]/g, '').trim();
  const num = parseFloat(cleanStr);
  return isNaN(num) ? 0.0 : Math.abs(num);
}

// Robust helper to parse different bank statement date formats (DD/MM/YYYY, DD-MMM-YYYY, Excel serial numbers)
function parseRobustDate(rawVal) {
  if (rawVal === null || rawVal === undefined) return new Date();
  
  if (rawVal instanceof Date && !isNaN(rawVal.getTime())) {
    return rawVal;
  }

  if (typeof rawVal === 'number') {
    if (rawVal > 30000 && rawVal < 60000) {
      const utc_days  = Math.floor(rawVal - 25569);
      const utc_value = utc_days * 86400;
      const date_info = new Date(utc_value * 1000);
      return date_info;
    }
    const d = new Date(rawVal);
    if (!isNaN(d.getTime())) return d;
  }

  const str = String(rawVal).trim();
  if (!str) return new Date();

  // Try standard parsing
  const d = new Date(str);
  if (!isNaN(d.getTime())) return d;

  // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
  const dmyRegex = /^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/;
  const match = str.match(dmyRegex);
  if (match) {
    const day = parseInt(match[1], 10);
    const month = parseInt(match[2], 10) - 1;
    const year = parseInt(match[3], 10);
    const dateObj = new Date(year, month, day);
    if (!isNaN(dateObj.getTime())) return dateObj;
  }

  // DD/MM/YY (two-digit year)
  const dmyShortRegex = /^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2})$/;
  const matchShort = str.match(dmyShortRegex);
  if (matchShort) {
    const day = parseInt(matchShort[1], 10);
    const month = parseInt(matchShort[2], 10) - 1;
    let year = parseInt(matchShort[3], 10);
    year = year < 50 ? 2000 + year : 1900 + year;
    const dateObj = new Date(year, month, day);
    if (!isNaN(dateObj.getTime())) return dateObj;
  }

  // DD-MMM-YYYY or DD-MMM-YY (e.g. 25-Jan-2026, 05-Apr-26, 12-APR-26)
  const monthsMap = {
    jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
    jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11
  };
  const dMmmYRegex = /^(\d{1,2})[\/\-\.]([a-zA-Z]{3})[\/\-\.](\d{2,4})$/;
  const matchMmm = str.match(dMmmYRegex);
  if (matchMmm) {
    const day = parseInt(matchMmm[1], 10);
    const mStr = matchMmm[2].toLowerCase().substring(0, 3);
    const month = monthsMap[mStr];
    let year = parseInt(matchMmm[3], 10);
    if (month !== undefined) {
      if (String(year).length === 2) {
        year = year < 50 ? 2000 + year : 1900 + year;
      }
      const dateObj = new Date(year, month, day);
      if (!isNaN(dateObj.getTime())) return dateObj;
    }
  }

  return new Date();
}

// Helper to detect if a JSON string returned by LLM is truncated/incomplete before parsing or repairing
function isJsonTruncated(str) {
  if (!str) return true;
  const trimmed = str.trim().replace(/```(json)?$/i, '').trim();
  return !trimmed.endsWith(']') && !trimmed.endsWith('}');
}

// Helper to dynamically query, filter, and sort supported generative models for this specific API Key
async function getDynamicModels(userApiKey) {
  const defaultModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash-lite',
    'gemini-pro-latest'
  ];
  try {
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${userApiKey}`);
    if (!listRes.ok) {
      return defaultModels;
    }
    const listData = await listRes.json();
    if (!listData.models || !Array.isArray(listData.models)) {
      return defaultModels;
    }
    
    // Filter models that support content generation and are gemini models (exclude tiny open gemma models)
    const filtered = listData.models
      .filter(m => {
        const name = m.name.toLowerCase();
        const supportsGen = m.supportedGenerationMethods?.includes('generateContent');
        const isGemini = name.includes('gemini');
        const isExcluded = name.includes('embedding') || name.includes('image') || name.includes('tts') || name.includes('robotics') || name.includes('veo') || name.includes('imagen') || name.includes('lyria') || name.includes('nano') || name.includes('aqa') || name.includes('computer-use') || name.includes('deep-research') || name.includes('antigravity');
        return supportsGen && isGemini && !isExcluded;
      })
      .map(m => m.name.replace(/^models\//, '')); // Strip "models/" prefix

    if (filtered.length === 0) {
      return defaultModels;
    }

    // Sort to prioritize the best models
    const priorityOrder = [
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemini-pro-latest'
    ];

    function getPriorityIndex(modelName) {
      const name = modelName.toLowerCase();
      for (let i = 0; i < priorityOrder.length; i++) {
        if (name.includes(priorityOrder[i])) {
          return i;
        }
      }
      return 999;
    }

    filtered.sort((a, b) => {
      const idxA = getPriorityIndex(a);
      const idxB = getPriorityIndex(b);
      return idxA - idxB;
    });

    logDiagnostic(`[DynamicModels] Sorted models chain: ${JSON.stringify(filtered)}`);
    return filtered;
  } catch (err) {
    logDiagnostic(`[DynamicModels] Exception: ${err.message}`);
    return defaultModels;
  }
}

// Resilient utility to repair truncated JSON arrays/objects from LLMs
function repairTruncatedJson(str) {
  str = str.trim();
  if (!str) return str;

  // If already valid JSON, return directly
  try {
    JSON.parse(str);
    return str;
  } catch (e) {
    // Attempting to repair
  }

  console.log('Detecting truncated or malformed JSON from LLM. Attempting to repair...');

  let insideQuotes = false;
  let escaped = false;
  const bracketStack = [];
  
  const firstBracket = str.indexOf('[');
  const firstCurly = str.indexOf('{');
  let startIdx = 0;
  
  if (firstBracket !== -1 && (firstCurly === -1 || firstBracket < firstCurly)) {
    startIdx = firstBracket;
  } else if (firstCurly !== -1) {
    startIdx = firstCurly;
  }

  const workingStr = str.substring(startIdx);
  let repaired = '';
  let lastValidStateStr = '';
  
  for (let i = 0; i < workingStr.length; i++) {
    const char = workingStr[i];
    
    if (escaped) {
      repaired += char;
      escaped = false;
      continue;
    }
    
    if (char === '\\') {
      repaired += char;
      escaped = true;
      continue;
    }
    
    if (char === '"') {
      insideQuotes = !insideQuotes;
      repaired += char;
      continue;
    }
    
    if (insideQuotes) {
      if (char === '\n') {
        repaired += ' ';
      } else if (char === '\r') {
        // Skip
      } else {
        repaired += char;
      }
      continue;
    }
    
    if (char === '[') {
      bracketStack.push('[');
      repaired += char;
    } else if (char === '{') {
      bracketStack.push('{');
      repaired += char;
    } else if (char === ']') {
      if (bracketStack[bracketStack.length - 1] === '[') {
        bracketStack.pop();
        repaired += char;
        if (bracketStack.length === 0) {
          lastValidStateStr = repaired;
        }
      }
    } else if (char === '}') {
      if (bracketStack[bracketStack.length - 1] === '{') {
        bracketStack.pop();
        repaired += char;
        if (bracketStack.length === 0 || (bracketStack.length === 1 && bracketStack[0] === '[')) {
          lastValidStateStr = repaired;
        }
      }
    } else {
      repaired += char;
    }
  }

  if (bracketStack.length === 0) {
    try {
      JSON.parse(repaired);
      return repaired;
    } catch (e) {}
  }

  if (lastValidStateStr) {
    let finalStr = lastValidStateStr.replace(/,\s*$/, '');
    if (workingStr.startsWith('[') && !finalStr.endsWith(']')) {
      finalStr += ']';
    }
    try {
      JSON.parse(finalStr);
      console.log('Successfully repaired JSON to last valid complete object/array!');
      return finalStr;
    } catch (e) {}
  }

  let fallbackStr = repaired;
  if (insideQuotes) {
    fallbackStr += '"';
  }
  
  fallbackStr = fallbackStr.replace(/,\s*$/, '');
  fallbackStr = fallbackStr.replace(/:\s*[^,}\]]*$/, '');
  fallbackStr = fallbackStr.replace(/,\s*$/, '');

  while (bracketStack.length > 0) {
    const lastOpen = bracketStack.pop();
    if (lastOpen === '[') fallbackStr += ']';
    if (lastOpen === '{') fallbackStr += '}';
  }

  try {
    JSON.parse(fallbackStr);
    console.log('Successfully repaired JSON via stack closing fallback!');
    return fallbackStr;
  } catch (e) {
    console.warn('Failed to parse repaired JSON:', e.message);
  }

  return str;
}

// Custom page render function for pdf-parse to inject page breaks
function pageRender(pageData) {
  return pageData.getTextContent({
    normalizeWhitespace: false,
    disableCombineTextItems: false
  }).then(function(textContent) {
    let lastY, text = '';
    for (let item of textContent.items) {
      if (lastY == item.transform[5] || !lastY) {
        text += item.str;
      } else {
        text += '\n' + item.str;
      }
      lastY = item.transform[5];
    }
    return text + '\n---PAGE_BREAK---';
  });
}

// Generate dynamic system rules prompt injecting user name and merchant extraction rules
function getSystemRulesText(userName) {
  const nameUpper = String(userName || '').toUpperCase().trim();
  const firstName = nameUpper.split(' ')[0];
  
  return `You are a professional financial assistant. Analyze raw text/data extracted from a bank statement (from any bank like SBI, HDFC, ICICI, Axis, PNB, etc.). Extract all money-out transactions (outflows/debits/transfers).

  CRITICAL OUTFLOW EXTRACTION RULES:
  1. ONLY extract transactions where money is leaving the account (money-out / debits / withdrawals / transfers).
  2. Extract all of the following debit/transfer transactions:
     - UPI Payments / UPI-DR / UPI-OUT / Merchant payments (e.g., GPay, PhonePe, Paytm, BharatPe transfers)
     - Transfers to vendors, merchants, or other individuals (e.g., "TRANSFER TO...", "TO TRANSFER...", "TRFR TO...", "SENT TO...")
     - IMPS / NEFT / RTGS debit transfers (e.g., "IMPS-OUT...", "IMPS/DR...", "NEFT DR...")
     - Card spends / POS purchases / Online shopping spends (e.g., "POS DEBIT...")
     - Cash withdrawals / ATM withdrawals
     - Bank fees, charges, interest debits, or SMS alert fees
  3. COMPLETELY IGNORE all credits, deposits, refunds, salary, cashback, or incoming money (e.g., any transaction containing "CASHBACK", "REFUND", "INTEREST CREDITED", "CR", "DEPOSIT", "SALARY", "INWARD", "RECEIVED", or under the Credit/CR/Deposit columns). Do not extract cashback transfers, refunds, or interest credits even if they contain the word "TRANSFER" or "TRFR".
  4. STRICT LAZYNESS PREVENTION: Never use placeholders, three dots ('...'), or 'etc.' in the JSON response. You MUST extract absolutely EVERY SINGLE money-out/debit/transfer transaction item present in the text, no matter how many there are. Do not stop until the entire text is fully parsed.
  5. COMPLETELY IGNORE AND EXCLUDE all self-transfers or transfers between the user's own accounts (inter-account transfers). These are transactions where the description or narration indicates moving money to another account belonging to the same user (e.g., transfers containing "SELF", "SELF TRANSFER", "OWN A/C", "OWN ACCOUNT", "TRANSFER TO OWN A/C", or direct bank-to-bank self-transfers like "SBI TO HDFC", "TO HDFC A/C", "TRANSFER TO ICICI", "TRFR TO SELF"). These do not represent external expenses and MUST NOT be extracted or included in the output JSON array.
  6. SELF-TRANSFER EXCLUSION FOR USER "${nameUpper}": You MUST completely ignore and exclude any transaction where the description/narration indicates a self-transfer to "${nameUpper}" or is a transfer under your name (e.g., containing "${nameUpper}" or "${firstName}"). For example, "TRANSFER TO ${nameUpper}" or "TRFR TO ${firstName}" is a self-transfer and MUST NOT be extracted.
  7. MERCHANT/VENDORS CLEAN DESCRIPTION: Clean up raw bank narration/description text to extract the clean, human-readable merchant, vendor, or individual name. Strip out transaction reference IDs, technical prefixes/suffixes (e.g., 'UPI-DR/', 'UPI/', 'IMPS/', '/GPAY', '/okbizaxis', '/UPIIntent', phonepe/gpay handles like '@ybl', '@okaxis', etc., reference numbers, phone numbers, or dates embedded in descriptions). The description returned in the JSON must represent the clean merchant/vendor name (e.g., convert "UPI-DR-MUKTER PRINT HUB-GPAY-122..." to "Mukter Print Hub", "UPI-DR-Indian Railways-..." to "Indian Railways", "UPI-DR-KEYA ADHIKARY-..." to "Keya Adhikary", etc.).
  8. CATEGORY MAPPING & MCC PARSING: Categorize each transaction into precisely one of these values: Travel, Meals, Entertainment, Car / Mileage, Office Supplies, Software / Subscriptions, Fees, Utilities, UPI Transfers, Others.
     - If the narration contains a Merchant Category Code (MCC) (e.g., MCC 5812, MCC 5411, MCC 4814), parse the MCC to accurately identify the category.
     - Travel: Flights, lodging, hotels, accommodation (MCC 4511, 4112).
     - Meals: Restaurants, eating places, fast food, cafe (MCC 5812, 5814).
     - Entertainment: Movie theaters, amusement parks, recreation, bars, drinking places (MCC 7832, 7996, 7999, 5813).
     - Car / Mileage: Cabs, taxi, local transport passenger, fuel/petrol/diesel (MCC 4111, 4121, 5541, 5542).
     - Office Supplies: Supermarkets, grocery stores, clothing/apparel, office equipment, paper, pens (MCC 5411, 5311, 5611-5699).
     - Software / Subscriptions: Cloud servers, SaaS tools, software licenses, website hosting.
     - Fees: Bank fees, SMS alerts, legal charges, penalty, interest charged.
     - Utilities: Rent, electricity, water, telecom/wifi/mobile recharges, medical/hospital spends, insurance (MCC 4900, 4814, 4812, 6300).
     - UPI Transfers: Use this category for personal peer-to-peer UPI transfers to individuals' names (e.g. "UPI Transfer to Anil Kumar", "UPI Transfer to Keya Adhikary" - that are not business/merchant accounts).
     - Others: A generic fallback category to capture any miscellaneous expenses that do not fall into the primary defined categories.

  How to identify debits in tabular statement text/data:
  - Look for entries in columns named "Debit", "Withdrawal", "DR", "Amount (Dr)", or "Debits".
  - If the statement does not have distinct columns, identify debits via keywords like "UPI-DR", "IMPS-OUT", "TRFR TO", "Paid to", or negative numbers.

  Ensure your response is ONLY a JSON array of arrays (tuple format) to save output token space, without markdown wrapper blocks or text.
  Structure:
  [
    ["YYYY-MM-DD", amount, "description", "category", "currency"]
  ]
  
  Example:
  [
    ["2026-05-25T12:00:00.000Z", 450.00, "Zomato", "Meals", "INR"],
    ["2026-05-26T14:30:00.000Z", 1500.00, "UPI Transfer to Anil Kumar", "UPI Transfers", "INR"]
  ]`;
}

// Smart helper to auto-categorize transactions based on merchant/description keywords
function autoCategorizeDescription(description) {
  const desc = String(description || '').toLowerCase();

  // Parse Merchant Category Code (MCC) if present in narration (e.g. MCC 5812, MCC:4814, MCC-5411)
  const mccMatch = desc.match(/mcc[:\-\s]?(\d{4})/i);
  if (mccMatch) {
    const mcc = parseInt(mccMatch[1], 10);
    
    // 1. Meals (5812: Restaurants, 5814: Fast Food)
    if (mcc === 5812 || mcc === 5814) {
      return 'Meals';
    }
    // 2. Travel (4511: Airlines, 4112: Passenger Railways)
    if (mcc === 4511 || mcc === 4112) {
      return 'Travel';
    }
    // 3. Entertainment (7832: Motion Picture, 7996: Amusement Parks, 7999: Recreation, 5813: Drinking places/Bars)
    if (mcc === 7832 || mcc === 7996 || mcc === 7999 || mcc === 5813) {
      return 'Entertainment';
    }
    // 4. Car / Mileage (4111: Local Transport Passenger, 4121: Taxicabs, 5541/5542: Fuel Stations)
    if (mcc === 4111 || mcc === 4121 || mcc === 5541 || mcc === 5542) {
      return 'Car / Mileage';
    }
    // 5. Office Supplies (5411: Grocery Stores, 5311: Department Stores, 5611-5699: Clothing)
    if (mcc === 5411 || mcc === 5311 || (mcc >= 5611 && mcc <= 5699) || mcc === 5941 || mcc === 5942 || mcc === 5944) {
      return 'Office Supplies';
    }
    // 6. Utilities (4900: Utilities-Electric/Gas/Water, 4814: Telecom, 4812: Phones, 6300: Insurance)
    if (mcc === 4900 || mcc === 4814 || mcc === 4812 || mcc === 6300) {
      return 'Utilities';
    }
  }

  // Check if it's a UPI transfer to an individual/person's name
  if (desc.includes('upi transfer to') || desc.includes('upi transfer')) {
    return 'UPI Transfers';
  }
  
  // 1. Meals
  if (
    desc.includes('zomato') || desc.includes('swiggy') || desc.includes('ubereats') ||
    desc.includes('restaurant') || desc.includes('cafe') || desc.includes('hotel') ||
    desc.includes('food') || desc.includes('dining') || desc.includes('canteen') ||
    desc.includes('bakery') || desc.includes('pizza') || desc.includes('burger') ||
    desc.includes('starbucks') || desc.includes('kfc') || desc.includes('mcdonald') ||
    desc.includes('dhaba') || desc.includes('chai') || desc.includes('tea') || desc.includes('coffee') ||
    desc.includes('meals') || desc.includes('meal')
  ) {
    return 'Meals';
  }
  
  // 2. Travel (flights, hotels/lodging)
  if (
    desc.includes('flight') || desc.includes('airline') || desc.includes('airways') ||
    desc.includes('hotel') || desc.includes('lodging') || desc.includes('accommodation') ||
    desc.includes('booking.com') || desc.includes('airbnb') || desc.includes('makemytrip') ||
    desc.includes('yatra') || desc.includes('travel') || desc.includes('goibibo')
  ) {
    return 'Travel';
  }
  
  // 3. Entertainment
  if (
    desc.includes('netflix') || desc.includes('prime video') || desc.includes('disney') ||
    desc.includes('hotstar') || desc.includes('spotify') || desc.includes('youtube') ||
    desc.includes('bookmyshow') || desc.includes('cinema') || desc.includes('movie') ||
    desc.includes('theatre') || desc.includes('entertainment') || desc.includes('game') ||
    desc.includes('steam') || desc.includes('playstation') || desc.includes('xbox') ||
    desc.includes('nintendo') || desc.includes('pub') || desc.includes('bar') ||
    desc.includes('club') || desc.includes('liquor') || desc.includes('wine')
  ) {
    return 'Entertainment';
  }
  
  // 4. Car / Mileage (local transport, cabs, fuel)
  if (
    desc.includes('uber') || desc.includes('ola') || desc.includes('rapido') ||
    desc.includes('irctc') || desc.includes('railway') || desc.includes('metro') ||
    desc.includes('bus') || desc.includes('cab') || desc.includes('taxi') ||
    desc.includes('fuel') || desc.includes('petrol') || desc.includes('diesel') ||
    desc.includes('shell') || desc.includes('hpcl') || desc.includes('bpcl') ||
    desc.includes('iocl') || desc.includes('cng') || desc.includes('toll') || desc.includes('fastag') ||
    desc.includes('mileage') || desc.includes('transit')
  ) {
    return 'Car / Mileage';
  }
  
  // 5. Office Supplies (formerly Shopping)
  if (
    desc.includes('amazon') || desc.includes('flipkart') || desc.includes('myntra') ||
    desc.includes('meesho') || desc.includes('ajio') || desc.includes('nykaa') ||
    desc.includes('groceries') || desc.includes('grocery') || desc.includes('supermarket') ||
    desc.includes('mart') || desc.includes('jiomart') || desc.includes('blinkit') ||
    desc.includes('instamart') || desc.includes('zepto') || desc.includes('bigbasket') ||
    desc.includes('reliance') || desc.includes('dmart') || desc.includes('spencer') ||
    desc.includes('shopping') || desc.includes('retail') || desc.includes('clothing') ||
    desc.includes('apparel') || desc.includes('footwear') || desc.includes('decathlon') ||
    desc.includes('stationery') || desc.includes('paper') || desc.includes('pen') ||
    desc.includes('supplies') || desc.includes('office') || desc.includes('equipment')
  ) {
    return 'Office Supplies';
  }

  // 6. Software / Subscriptions
  if (
    desc.includes('slack') || desc.includes('zoom') || desc.includes('microsoft') ||
    desc.includes('google cloud') || desc.includes('aws') || desc.includes('github') ||
    desc.includes('saas') || desc.includes('software') || desc.includes('subscription') ||
    desc.includes('hosting') || desc.includes('domain') || desc.includes('figma') ||
    desc.includes('adobe')
  ) {
    return 'Software / Subscriptions';
  }

  // 7. Fees (Bank fees, charges, etc.)
  if (
    desc.includes('fees') || desc.includes('charge') || desc.includes('fee') ||
    desc.includes('interest charged') || desc.includes('bank fees') ||
    desc.includes('sms charges') || desc.includes('tax') || desc.includes('fine') ||
    desc.includes('penalty') || desc.includes('commission')
  ) {
    return 'Fees';
  }
  
  // 8. Utilities (including health spends/rent)
  if (
    desc.includes('bill') || desc.includes('utility') || desc.includes('electricity') ||
    desc.includes('water') || desc.includes('gas') || desc.includes('recharge') ||
    desc.includes('jio') || desc.includes('airtel') || desc.includes('vodafone') ||
    desc.includes('idea') || desc.includes('bsnl') || desc.includes('broadband') ||
    desc.includes('wifi') || desc.includes('telecom') || desc.includes('rent') ||
    desc.includes('landlord') || desc.includes('maintenance') ||
    desc.includes('insurance') || desc.includes('lic') || desc.includes('premium') ||
    desc.includes('loan') || desc.includes('emi') ||
    desc.includes('hospital') || desc.includes('pharmacy') || desc.includes('medical') ||
    desc.includes('chemist') || desc.includes('apollo') || desc.includes('medplus') ||
    desc.includes('doctor') || desc.includes('clinic') || desc.includes('dentist') ||
    desc.includes('health') || desc.includes('medicine') || desc.includes('pharmeasy') ||
    desc.includes('diagnostic') || desc.includes('lab') || desc.includes('gym') ||
    desc.includes('fitness') || desc.includes('salon') || desc.includes('spa')
  ) {
    return 'Utilities';
  }
  
  // If description has any merchant keyword, default to 'Office Supplies'
  const isMerchant = desc.includes('store') || 
                     desc.includes('mart') || 
                     desc.includes('shop') || 
                     desc.includes('enterprise') || 
                     desc.includes('retail') || 
                     desc.includes('pvt') || 
                     desc.includes('ltd') ||
                     desc.includes('merchant') ||
                     desc.includes('pos');
  if (isMerchant) {
    return 'Office Supplies';
  }
  
  return 'Others';
}

// Clean raw bank narration for fallback parser
function cleanFallbackDescription(rawDesc) {
  let desc = String(rawDesc || '').trim();
  if (!desc) return '';

  const isUpi = /upi/i.test(desc);
  const isImps = /imps/i.test(desc);
  const isNeft = /neft/i.test(desc);

  // Strip technical details from UPI
  let clean = desc
    .replace(/^upi[-/]dr[-/]/i, '')
    .replace(/^upi[-/]out[-/]/i, '')
    .replace(/^upi[-/]/i, '')
    .replace(/[-/]gpay.*$/i, '')
    .replace(/[-/]phonepe.*$/i, '')
    .replace(/[-/]paytm.*$/i, '')
    .replace(/@\w+.*$/, '') // Strip handles
    .replace(/\d{10,}/g, '') // Strip long digits
    .replace(/[\d-]{6,}/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  // Capitalize words
  clean = clean.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');

  if (isUpi) {
    if (clean) {
      // If it looks like a merchant account (contains store/mart/enterprises etc.)
      const cleanLower = clean.toLowerCase();
      const isMerchantName = cleanLower.includes('store') || 
                             cleanLower.includes('mart') || 
                             cleanLower.includes('shop') || 
                             cleanLower.includes('enterprise') || 
                             cleanLower.includes('retail') || 
                             cleanLower.includes('pvt') || 
                             cleanLower.includes('ltd') ||
                             cleanLower.includes('merchant') ||
                             cleanLower.includes('pos') ||
                             rawDesc.toLowerCase().includes('okbiz');
      
      if (isMerchantName) {
        return clean; // Just return clean merchant name
      } else {
        return `UPI Transfer to ${clean}`; // Personal name -> "UPI Transfer to Name"
      }
    }
    return 'UPI Transfer';
  }

  if (isImps) return clean ? `IMPS Transfer to ${clean}` : 'IMPS Transfer';
  if (isNeft) return clean ? `NEFT Transfer to ${clean}` : 'NEFT Transfer';

  return clean || desc;
}

// Shared helper to identify if a transaction is a self-transfer matching user name or general accounts
function isSelfTransferTransaction(description, userName) {
  const lowerDesc = String(description || '').toLowerCase();
  
  // Standard self-transfer keywords
  const isSelf = lowerDesc.includes('self transfer') ||
                 lowerDesc.includes('transfer to self') ||
                 lowerDesc.includes('own account') ||
                 lowerDesc.includes('own a/c') ||
                 lowerDesc.includes('self-transfer') ||
                 /(\bsbi\b|\bhdfc\b|\bicici\b|\baxis\b|\bpnb\b|\bown\b)\s+to\s+(\bsbi\b|\bhdfc\b|\bicici\b|\baxis\b|\bpnb\b|\bown\b)/i.test(lowerDesc);
                 
  // User name matching
  let isNameSelf = false;
  const nameLower = String(userName || '').toLowerCase().trim();
  if (nameLower && nameLower !== 'user') {
    const firstNameLower = nameLower.split(' ')[0];
    if (lowerDesc.includes(nameLower)) {
      isNameSelf = true;
    } else if (firstNameLower && firstNameLower.length > 2 && lowerDesc.includes(firstNameLower)) {
      isNameSelf = true;
    }
  }

  return isSelf || isNameSelf;
}

// Deduplicate parsed transactions by creating a unique key
function deduplicateTransactions(expenses) {
  const unique = [];
  const seen = new Set();
  
  for (const tx of expenses) {
    const amtStr = Number(tx.amount || 0).toFixed(2);
    let dateStr = 'unknown-date';
    try {
      if (tx.transaction_date) {
        dateStr = new Date(tx.transaction_date).toISOString().split('T')[0];
      }
    } catch (_) {
      dateStr = String(tx.transaction_date || '').substring(0, 10);
    }
    const descClean = String(tx.description || '').trim().toLowerCase().replace(/[^a-z0-9]/g, '');
    
    const key = `${dateStr}_${amtStr}_${descClean}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(tx);
    } else {
      logDiagnostic(`[Import Deduplication] Discarded duplicate transaction: Date=${dateStr}, Amount=${amtStr}, Desc="${tx.description}"`);
    }
  }
  
  return unique;
}

// Call Google Gemini Native REST API for a specific text chunk
async function callGeminiForChunk(chunkText, systemRulesText, userApiKey, models) {
  let rawContent = null;
  let lastError = null;
  
  for (const model of models) {
    try {
      const apiVersion = 'v1beta';
      const bodyPayload = {
        systemInstruction: {
          parts: [{ text: systemRulesText }]
        },
        contents: [
          {
            parts: [
              {
                text: `Raw text content:
                ---------------------
                ${chunkText}
                ---------------------`
              }
            ]
          }
        ],
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }
        ],
        generationConfig: {
          maxOutputTokens: 8192,
          responseMimeType: 'application/json'
        }
      };

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 20000); // 20s timeout per model attempt

      const response = await fetch(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent?key=${userApiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(bodyPayload),
        signal: controller.signal
      });
      clearTimeout(timeoutId);

      if (response.ok) {
        const data = await response.json();
        const candidate = data.candidates?.[0];
        const finishReason = candidate?.finishReason;
        const text = candidate?.content?.parts?.[0]?.text?.trim();
        
        if (text) {
          const truncated = isJsonTruncated(text);
          logDiagnostic(`[Chunk Import] Model ${model} returned output (length=${text.length}, finishReason=${finishReason || 'STOP'}, isTruncated=${truncated})`);
          
          if (!truncated || model === models[models.length - 1]) {
            rawContent = text;
            break;
          } else {
            logDiagnostic(`[Chunk Import] Model ${model} output was truncated. Falling back to the next model...`);
          }
        }
      } else {
        const errText = await response.text();
        logDiagnostic(`Gemini model ${model} chunk call failed with status ${response.status}: ${errText}`);
        
        // Short-circuit on fatal key/rate-limit/bad-request errors
        if (response.status === 400 || response.status === 403 || response.status === 429) {
          throw new Error(`Google Gemini API error (${response.status}): ${errText}`);
        }
        lastError = new Error(errText);
      }
    } catch (err) {
      logDiagnostic(`Gemini model ${model} chunk call exception: ${err.message}`);
      lastError = err;
    }
  }

  if (!rawContent) {
    throw lastError || new Error('No response from Gemini API models.');
  }

  let cleanJson = rawContent.trim();
  cleanJson = cleanJson.replace(/```json/gi, '').replace(/```/gi, '').trim();
  cleanJson = repairTruncatedJson(cleanJson);

  const firstCurly = cleanJson.indexOf('{');
  const firstBracket = cleanJson.indexOf('[');
  let startIndex = -1;
  let isObject = false;

  if (firstCurly !== -1 && (firstBracket === -1 || firstCurly < firstBracket)) {
    startIndex = firstCurly;
    isObject = true;
  } else if (firstBracket !== -1) {
    startIndex = firstBracket;
  }

  if (startIndex !== -1) {
    const lastIndex = isObject ? cleanJson.lastIndexOf('}') : cleanJson.lastIndexOf(']');
    if (lastIndex !== -1 && lastIndex > startIndex) {
      cleanJson = cleanJson.substring(startIndex, lastIndex + 1);
    }
  }

  let insideQuotes = false;
  let escaped = false;
  let fixedStr = '';
  for (let i = 0; i < cleanJson.length; i++) {
    const char = cleanJson[i];
    if (char === '"' && !escaped) {
      insideQuotes = !insideQuotes;
    }
    if (insideQuotes) {
      if (char === '\n') fixedStr += ' ';
      else if (char === '\r') {}
      else fixedStr += char;
    } else {
      fixedStr += char;
    }
    if (char === '\\' && !escaped) escaped = true;
    else escaped = false;
  }
  cleanJson = fixedStr;

  cleanJson = cleanJson.replace(/,\s*([\]}])/g, '$1');
  cleanJson = cleanJson.replace(/,\s*"\.\.\."\s*/g, '');
  cleanJson = cleanJson.replace(/,\s*\.\.\.\s*/g, '');
  cleanJson = cleanJson.replace(/"\.\.\."\s*/g, '""');
  cleanJson = cleanJson.replace(/\.\.\.\s*/g, '');

  const parsedJson = JSON.parse(cleanJson);
  let parsedArray = [];
  if (Array.isArray(parsedJson)) {
    parsedArray = parsedJson;
  } else if (parsedJson && typeof parsedJson === 'object') {
    const keys = Object.keys(parsedJson);
    for (const k of keys) {
      if (Array.isArray(parsedJson[k])) {
        parsedArray = parsedJson[k];
        break;
      }
    }
  }
  return parsedArray;
}

// Multer memory storage for serverless-friendly file handling
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

// 1. Get User's Expenses
router.get('/', authenticateToken, async (req, res) => {
  try {
    const expenses = await query(
      `SELECT * FROM expenses 
       WHERE user_id = $1 AND is_deleted = FALSE 
       ORDER BY transaction_date DESC`,
      [req.user.userId]
    );
    res.status(200).json(expenses.rows);
  } catch (error) {
    console.error('Fetch expenses error:', error);
    res.status(500).json({ error: 'Server error fetching expenses.' });
  }
});

// 2. Add Single Expense (Server-Side Create)
router.post('/', authenticateToken, async (req, res) => {
  const { id, amount, currency, category, description, transaction_date, is_recurring, recurrence_period, receipt_url } = req.body;

  if (!amount || !category || !transaction_date) {
    return res.status(400).json({ error: 'Amount, category, and transaction date are required.' });
  }

  // Use provided UUID (client-generated) or generate one if not supplied
  const expenseId = id || crypto.randomUUID();

  try {
    const newExpense = await query(
      `INSERT INTO expenses (id, user_id, amount, currency, category, description, transaction_date, receipt_url, is_recurring, recurrence_period)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (id) DO UPDATE 
       SET amount = EXCLUDED.amount,
           currency = EXCLUDED.currency,
           category = EXCLUDED.category,
           description = EXCLUDED.description,
           transaction_date = EXCLUDED.transaction_date,
           receipt_url = EXCLUDED.receipt_url,
           is_recurring = EXCLUDED.is_recurring,
           recurrence_period = EXCLUDED.recurrence_period,
           updated_at = NOW()
       RETURNING *`,
      [
        expenseId,
        req.user.userId,
        amount,
        currency || 'INR',
        category,
        description || '',
        transaction_date,
        receipt_url || null,
        is_recurring || false,
        recurrence_period || 'none'
      ]
    );

    res.status(201).json(newExpense.rows[0]);
  } catch (error) {
    console.error('Create/Update expense error:', error);
    res.status(500).json({ error: 'Server error saving expense.' });
  }
});

// 3. Batch Synchronization Route (/expenses/sync)
// Pushes SQLite edits (unsynced rows) in bulk, runs upserts, and retrieves all fresh remote changes.
router.post('/sync', authenticateToken, async (req, res) => {
  const { expenses = [], budgets = [], payment_details = [], deleted_records = [], last_sync_time } = req.body;
  const userId = req.user.userId;

  try {
    // Begin transaction for database integrity
    await query('BEGIN');

    // 1. Process deletions uploaded by the client (Hard delete from active tables and log)
    for (const del of deleted_records) {
      if (del.table_name === 'expenses') {
        await query('DELETE FROM expenses WHERE id = $1 AND user_id = $2', [del.id, userId]);
      } else if (del.table_name === 'budgets') {
        await query('DELETE FROM budgets WHERE id = $1 AND user_id = $2', [del.id, userId]);
      } else if (del.table_name === 'payment_details') {
        await query('DELETE FROM payment_details WHERE id = $1 AND user_id = $2', [del.id, userId]);
      }

      // Log in remote deleted_records queue for cross-device sync propagation
      await query(
        `INSERT INTO deleted_records (id, user_id, table_name) 
         VALUES ($1, $2, $3) 
         ON CONFLICT (id) DO NOTHING`,
        [del.id, userId, del.table_name]
      );
    }

    // Sync Expenses (LWW Conflict Resolution)
    for (const exp of expenses) {
      const existing = await query('SELECT updated_at FROM expenses WHERE id = $1', [exp.id]);
      if (existing.rows.length > 0) {
        const existingTime = new Date(existing.rows[0].updated_at).getTime();
        const incomingTime = new Date(exp.updated_at || new Date()).getTime();
        if (incomingTime <= existingTime) {
          console.log(`LWW: Skipping older update for expense ${exp.id}`);
          continue;
        }
      }

      await query(
        `INSERT INTO expenses (id, user_id, amount, currency, category, description, transaction_date, receipt_url, is_recurring, recurrence_period, is_deleted, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, COALESCE($12::timestamp, NOW()))
         ON CONFLICT (id) DO UPDATE 
         SET amount = EXCLUDED.amount,
             currency = EXCLUDED.currency,
             category = EXCLUDED.category,
             description = EXCLUDED.description,
             transaction_date = EXCLUDED.transaction_date,
             receipt_url = EXCLUDED.receipt_url,
             is_recurring = EXCLUDED.is_recurring,
             recurrence_period = EXCLUDED.recurrence_period,
             is_deleted = EXCLUDED.is_deleted,
             updated_at = NOW()`,
        [
          exp.id,
          userId,
          exp.amount,
          exp.currency || 'INR',
          exp.category,
          exp.description || '',
          exp.transaction_date,
          exp.receipt_url || null,
          exp.is_recurring || false,
          exp.recurrence_period || 'none',
          exp.is_deleted || false,
          exp.updated_at
        ]
      );
    }

    // Sync Budgets (LWW Conflict Resolution)
    for (const bud of budgets) {
      const existing = await query('SELECT updated_at FROM budgets WHERE id = $1', [bud.id]);
      if (existing.rows.length > 0) {
        const existingTime = new Date(existing.rows[0].updated_at).getTime();
        const incomingTime = new Date(bud.updated_at || new Date()).getTime();
        if (incomingTime <= existingTime) {
          console.log(`LWW: Skipping older update for budget ${bud.id}`);
          continue;
        }
      }

      await query(
        `INSERT INTO budgets (id, user_id, category, amount_limit, month_year, is_deleted, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7::timestamp, NOW()))
         ON CONFLICT (id) DO UPDATE 
         SET category = EXCLUDED.category,
             amount_limit = EXCLUDED.amount_limit,
             month_year = EXCLUDED.month_year,
             is_deleted = EXCLUDED.is_deleted,
             updated_at = NOW()`,
        [
          bud.id,
          userId,
          bud.category,
          bud.amount_limit,
          bud.month_year,
          bud.is_deleted === 1 || bud.is_deleted === true || false,
          bud.updated_at
        ]
      );
    }

    // Sync Payment Details
    for (const pay of payment_details) {
      await query(
        `INSERT INTO payment_details (id, user_id, upi_id, qr_code_url, updated_at)
         VALUES ($1, $2, $3, $4, COALESCE($5::timestamp, NOW()))
         ON CONFLICT (id) DO UPDATE 
         SET upi_id = EXCLUDED.upi_id,
             qr_code_url = EXCLUDED.qr_code_url,
             updated_at = NOW()`,
        [
          pay.id,
          userId,
          pay.upi_id,
          pay.qr_code_url || null,
          pay.updated_at
        ]
      );
    }

    await query('COMMIT');

    // Retrieve all fresh updates made in the cloud since the last synchronization timestamp
    let freshExpenses, freshBudgets, freshPayments, freshDeletions;
    
    if (last_sync_time) {
      freshExpenses = await query('SELECT * FROM expenses WHERE user_id = $1 AND updated_at > $2', [userId, last_sync_time]);
      freshBudgets = await query('SELECT * FROM budgets WHERE user_id = $1 AND updated_at > $2', [userId, last_sync_time]);
      freshPayments = await query('SELECT * FROM payment_details WHERE user_id = $1 AND updated_at > $2', [userId, last_sync_time]);
      freshDeletions = await query('SELECT id, table_name FROM deleted_records WHERE user_id = $1 AND deleted_at > $2', [userId, last_sync_time]);
    } else {
      freshExpenses = await query('SELECT * FROM expenses WHERE user_id = $1', [userId]);
      freshBudgets = await query('SELECT * FROM budgets WHERE user_id = $1', [userId]);
      freshPayments = await query('SELECT * FROM payment_details WHERE user_id = $1', [userId]);
      freshDeletions = await query('SELECT id, table_name FROM deleted_records WHERE user_id = $1', [userId]);
    }

    res.status(200).json({
      message: 'Sync completed successfully.',
      server_time: new Date().toISOString(),
      expenses: freshExpenses.rows,
      budgets: freshBudgets.rows,
      payment_details: freshPayments.rows,
      deleted_records: freshDeletions.rows
    });
  } catch (error) {
    await query('ROLLBACK');
    console.error('Bulk sync error:', error);
    res.status(500).json({ error: 'Sync failed on server.' });
  }
});

// 4. Smart Receipt Scanning via OpenRouter + Gemini 2.5 Flash Vision
router.post('/scan-receipt', upload.single('receipt'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Receipt image file is required.' });
  }

  try {
        const userGeminiKey = req.headers['x-user-gemini-key'];
    if (!userGeminiKey) {
      return res.status(400).json({ error: 'Google AI Studio API Key is required. Please set your key in Settings.' });
    }

    // Convert file buffer to base64
    const base64Image = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    let rawContent = null;
    const models = await getDynamicModels(userGeminiKey);
    let lastError = null;
    let usedModel = null;

    for (const model of models) {
      try {
        console.log(`Sending receipt image to Google Gemini Native REST API using model ${model} (${req.file.size} bytes)...`);

        const apiVersion = 'v1beta';
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 35000); // 35 seconds timeout per model attempt

        const response = await fetch(`https://generativelanguage.googleapis.com/${apiVersion}/models/${model}:generateContent?key=${userGeminiKey}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: `Analyze this image (which could be a store receipt, utility bill, restaurant invoice, or a screenshot of a UPI transaction like GPay, PhonePe, Paytm). 
                    Extract the following financial details accurately:
                    1. amount (numeric float value)
                    2. currency (3-letter ISO code, e.g. INR, USD, EUR. Default to INR if it seems Indian, like UPI screenshots)
                    3. category (Categorize into precisely one of these values: Food, Travel, Shopping, Bills, Entertainment, Health, Investment, Others)
                    4. description (Brief summary of what was purchased or description of the transaction)
                    5. transaction_date (ISO 8601 string, e.g., '2026-06-01T20:00:00Z'. Extract transaction timestamp, or estimate/use current date if not visible)
                    6. vendor (Name of the shop, store, merchant, or individual who received the money. For UPI, extract the receiver's name)
                    
                    Ensure the response is ONLY a single, clean JSON object without markdown formatting blocks or extra text.
                    JSON structure:
                    {
                      "amount": 150.00,
                      "currency": "INR",
                      "category": "Food",
                      "description": "Lunch at restaurant",
                      "transaction_date": "2026-06-01T13:45:00.000Z",
                      "vendor": "Burger King"
                    }`
                  },
                  {
                    inlineData: {
                      mimeType: mimeType,
                      data: base64Image
                    }
                  }
                ]
              }
            ],
            generationConfig: {
              maxOutputTokens: 1000
            }
          }),
          signal: controller.signal
        });
        clearTimeout(timeoutId);

        if (response.ok) {
          const data = await response.json();
          const candidate = data.candidates?.[0];
          const finishReason = candidate?.finishReason;
          const text = candidate?.content?.parts?.[0]?.text?.trim();
          
          if (text) {
            const truncated = isJsonTruncated(text);
            console.log(`[Receipt Scan] Model ${model} returned output (length=${text.length}, finishReason=${finishReason || 'STOP'}, isTruncated=${truncated})`);
            
            if (!truncated || model === models[models.length - 1]) {
              rawContent = text;
              usedModel = model;
              break;
            } else {
              console.log(`[Receipt Scan] Model ${model} output was truncated. Falling back to the next model...`);
            }
          }
        } else {
          const errText = await response.text();
          console.warn(`Gemini model ${model} failed with status ${response.status}: ${errText}`);
          lastError = new Error(errText);
        }
      } catch (err) {
        console.error(`Gemini model ${model} exception:`, err);
        lastError = err;
      }
    }

    if (!rawContent) {
      return res.status(500).json({ error: `OCR Service failed: ${lastError ? lastError.message : 'No response from models'}` });
    }

    // Clean JSON wrapper markdown blocks like ```json ... ``` if returned by the LLM
    let cleanJson = rawContent.trim();
    
    // Bulletproof JSON extractor: extracts JSON even if there is surrounding text
    const firstCurly = cleanJson.indexOf('{');
    const firstBracket = cleanJson.indexOf('[');
    let startIndex = -1;
    let isObject = false;

    if (firstCurly !== -1 && (firstBracket === -1 || firstCurly < firstBracket)) {
      startIndex = firstCurly;
      isObject = true;
    } else if (firstBracket !== -1) {
      startIndex = firstBracket;
    }

    if (startIndex !== -1) {
      const lastIndex = isObject ? cleanJson.lastIndexOf('}') : cleanJson.lastIndexOf(']');
      if (lastIndex !== -1 && lastIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, lastIndex + 1);
      }
    }

    console.log('Extracted OCR Result:', cleanJson);
    const parsedData = JSON.parse(cleanJson);

    res.status(200).json({
      message: 'Receipt parsed successfully.',
      data: parsedData
    });
  } catch (error) {
    console.error('OCR scanning error:', error);
    res.status(500).json({ error: 'OCR receipt parsing failed.' });
  }
});

// 5. Batch Import transactions via PDF/Excel upload
router.post('/import', authenticateToken, upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Excel or PDF file is required.' });
  }

  const filename = req.file.originalname.toLowerCase();

  try {
    let userName = 'User';
    try {
      const userRes = await query('SELECT name FROM users WHERE id = $1', [req.user.userId]);
      if (userRes.rows.length > 0) {
        userName = userRes.rows[0].name || 'User';
      }
    } catch (err) {
      logDiagnostic(`Error fetching username for filter context: ${err.message}`);
    }

    let parsedExpenses = [];

    // CASE 1: Excel spreadsheets / CSV files (.xlsx, .xls, .csv)
    if (filename.endsWith('.xlsx') || filename.endsWith('.xls') || filename.endsWith('.csv')) {
      const filePassword = req.headers['x-file-password'];
      let excelBuffer = req.file.buffer;

      // Check for password protection in XLSX/XLS files (not CSV)
      if (filename.endsWith('.xlsx') || filename.endsWith('.xls')) {
        try {
          const officeCrypto = await import('officecrypto-tool');
          const isEncrypted = officeCrypto.default.isEncrypted(excelBuffer);
          
          if (isEncrypted) {
            logDiagnostic('[Spreadsheet Import] Excel file is password-protected!');
            if (!filePassword) {
              return res.status(401).json({
                success: false,
                error: 'PasswordRequired',
                message: 'This Excel statement is password-protected. Please enter the password to import.'
              });
            }

            try {
              excelBuffer = Buffer.from(await officeCrypto.default.decrypt(excelBuffer, { password: filePassword }));
              logDiagnostic('[Spreadsheet Import] Excel decryption successful!');
            } catch (decErr) {
              logDiagnostic(`[Spreadsheet Import] Excel decryption failed: ${decErr.message}`);
              return res.status(401).json({
                success: false,
                error: 'InvalidPassword',
                message: 'Incorrect Excel password. Please try again.'
              });
            }
          }
        } catch (err) {
          logDiagnostic(`[Spreadsheet Import] officecrypto-tool processing failed: ${err.message || err}`);
        }
      }

      let workbook;
      try {
        workbook = xlsx.read(excelBuffer, { type: 'buffer' });
      } catch (err) {
        logDiagnostic(`[Spreadsheet Import] Parsing failed: ${err.message || err.description || err || ''}`);
        let errStr = '';
        try {
          errStr = JSON.stringify(err) || '';
          errStr = errStr.toLowerCase();
        } catch (_) {
          errStr = String(err.message || err.description || err || '').toLowerCase();
        }
        const isEncrypted = errStr.includes('password') || 
                            errStr.includes('decrypt') || 
                            errStr.includes('encrypt') ||
                            errStr.includes('secure');
        if (isEncrypted) {
          return res.status(401).json({
            success: false,
            error: 'PasswordRequired',
            message: 'This spreadsheet is password-protected. Please enter the password to import.'
          });
        }
        throw err;
      }

      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];
      const userApiKey = req.headers['x-user-gemini-key'];
      if (userApiKey && userApiKey.trim().length > 0) {
        logDiagnostic(`[Spreadsheet Import] Gemini API Key found. Parsing using Google Gemini AI...`);
        
        let csvText = '';
        if (filename.endsWith('.csv')) {
          csvText = excelBuffer.toString('utf8');
        } else {
          csvText = xlsx.utils.sheet_to_csv(worksheet);
        }

        // Clean out empty rows, dangling commas, and spaces
        const lines = csvText
          .split('\n')
          .map(line => line.trim())
          .filter(line => {
            const cleanLine = line.replace(/[,""''\s\-]/g, '');
            return cleanLine.length > 0;
          });

        logDiagnostic(`[Spreadsheet Import] Total cleaned spreadsheet lines: ${lines.length}`);

        // Group rows into chunks if the spreadsheet is large. Prepend first 8 header lines to retain column schema context.
        const chunks = [];
        if (lines.length > 150) {
          const headerLines = lines.slice(0, 8);
          const dataLines = lines.slice(8);
          const chunkSize = 150;
          
          for (let i = 0; i < dataLines.length; i += chunkSize) {
            const chunkData = dataLines.slice(i, i + chunkSize);
            chunks.push([...headerLines, ...chunkData].join('\n'));
          }
        } else {
          chunks.push(lines.join('\n'));
        }

        logDiagnostic(`[Spreadsheet Import] Grouped spreadsheet into ${chunks.length} chunks.`);

        // userName is already fetched at the start of /import route

        const models = await getDynamicModels(userApiKey);
        const systemRulesText = getSystemRulesText(userName);

        const chunkPromises = chunks.map((chunkText, index) => {
          return callGeminiForChunk(chunkText, systemRulesText, userApiKey, models)
            .then(chunkArray => {
              logDiagnostic(`[Spreadsheet Import] Chunk ${index + 1}/${chunks.length} returned ${chunkArray.length} items.`);
              return chunkArray;
            })
            .catch(chunkErr => {
              logDiagnostic(`[Spreadsheet Import] Error processing chunk ${index + 1}/${chunks.length}: ${chunkErr.message}`);
              return [];
            });
        });

        const chunkResults = await Promise.all(chunkPromises);
        let mergedArray = [];
        for (const res of chunkResults) {
          mergedArray.push(...res);
        }

        if (mergedArray.length === 0) {
          return res.status(422).json({ error: 'No valid transactions could be extracted from this spreadsheet.' });
        }

        parsedExpenses = mergedArray.map(item => {
          let txDate, amount, currency, category, description;
          if (Array.isArray(item)) {
            txDate = parseRobustDate(item[0]);
            amount = cleanAmount(item[1]);
            description = item[2] || 'Imported Spreadsheet Transaction';
            category = item[3] || 'Others';
            currency = item[4] || 'INR';
          } else {
            txDate = parseRobustDate(item.transaction_date);
            amount = cleanAmount(item.amount);
            description = item.description || 'Imported Spreadsheet Transaction';
            category = item.category || 'Others';
            currency = item.currency || 'INR';
          }

          return {
            id: crypto.randomUUID(),
            amount: amount,
            currency: currency,
            category: category,
            description: description,
            transaction_date: txDate.toISOString(),
            is_recurring: false,
            recurrence_period: 'none'
          };
        }).filter(e => e.amount > 0 && !isSelfTransferTransaction(e.description, userName));

        const deduplicated = deduplicateTransactions(parsedExpenses);

        return res.status(200).json({
          message: `Parsed ${deduplicated.length} transactions from spreadsheet statement using Gemini AI (removed ${parsedExpenses.length - deduplicated.length} duplicates).`,
          expenses: deduplicated
        });
      } else {
        logDiagnostic(`[Spreadsheet Import] Gemini API Key not found. Falling back to rule-based parser.`);
        const rowsRaw = xlsx.utils.sheet_to_json(worksheet, { header: 1 });

        let headerRowIdx = -1;
        let colIndices = { date: -1, desc: -1, debit: -1, credit: -1 };

        const dateKeys = ['date', 'time', 'tx_date', 'transaction date', 'txn date', 'value date'];
        const descKeys = ['description', 'desc', 'particulars', 'remark', 'narration', 'vendor', 'name', 'details'];
        const debitKeys = ['debit', 'withdrawal', 'amount', 'spent', 'dr', 'outflow', 'price', 'val', 'cost', 'total'];
        const creditKeys = ['credit', 'deposit', 'cr', 'incoming', 'received', 'cre'];

        for (let r = 0; r < Math.min(rowsRaw.length, 50); r++) {
          const row = rowsRaw[r];
          if (!Array.isArray(row)) continue;

          let matches = 0;
          let tempIndices = { date: -1, desc: -1, debit: -1, credit: -1 };

          for (let c = 0; c < row.length; c++) {
            const cellVal = String(row[c] || '').toLowerCase().trim();
            if (!cellVal) continue;

            if (tempIndices.date === -1 && dateKeys.some(k => cellVal.includes(k))) {
              tempIndices.date = c;
              matches++;
            } else if (tempIndices.desc === -1 && descKeys.some(k => cellVal.includes(k))) {
              tempIndices.desc = c;
              matches++;
            } else if (tempIndices.debit === -1 && debitKeys.some(k => cellVal.includes(k))) {
              tempIndices.debit = c;
              matches++;
            } else if (tempIndices.credit === -1 && creditKeys.some(k => cellVal.includes(k))) {
              tempIndices.credit = c;
              matches++;
            }
          }

          if (tempIndices.date !== -1 && (tempIndices.debit !== -1 || tempIndices.desc !== -1)) {
            headerRowIdx = r;
            colIndices = tempIndices;
            break;
          }
        }

        let parsedRawExpenses = [];

        if (headerRowIdx !== -1) {
          logDiagnostic(`[Spreadsheet Import] Found header row at index ${headerRowIdx} with indices: ${JSON.stringify(colIndices)}`);
          
          for (let r = headerRowIdx + 1; r < rowsRaw.length; r++) {
            const row = rowsRaw[r];
            if (!Array.isArray(row) || row.length === 0) continue;

            const rawDate = colIndices.date !== -1 ? row[colIndices.date] : null;
            const descriptionVal = colIndices.desc !== -1 ? String(row[colIndices.desc] || '').trim() : '';
            const debitVal = colIndices.debit !== -1 ? row[colIndices.debit] : null;
            const creditVal = colIndices.credit !== -1 ? row[colIndices.credit] : null;

            if (!rawDate && !debitVal) continue;

            let amount = cleanAmount(debitVal);
            if (creditVal !== null && creditVal !== undefined && cleanAmount(creditVal) > 0) {
              amount = 0.00;
            }

            const transaction_date = parseRobustDate(rawDate);
            const description = cleanFallbackDescription(descriptionVal || `Row ${r} Import`);

            parsedRawExpenses.push({
              id: crypto.randomUUID(),
              amount: isNaN(amount) ? 0.00 : amount,
              currency: 'INR',
              category: autoCategorizeDescription(description),
              description: description,
              transaction_date: transaction_date.toISOString(),
              is_recurring: false,
              recurrence_period: 'none'
            });
          }
        } else {
          logDiagnostic(`[Spreadsheet Import] Header row not detected in 2D array. Falling back to standard sheet_to_json.`);
          const rows = xlsx.utils.sheet_to_json(worksheet);

          parsedRawExpenses = rows.map((row, idx) => {
            const findVal = (keys) => {
              const matchedKey = Object.keys(row).find(k => 
                keys.some(key => k.toLowerCase().includes(key))
              );
              return matchedKey ? row[matchedKey] : null;
            };

            const debitVal = findVal(['debit', 'withdrawal', 'amount', 'spent', 'dr', 'outflow', 'price', 'val', 'cost', 'total']);
            const creditVal = findVal(['credit', 'deposit', 'cr', 'incoming', 'received', 'cre']);
            
            let amount = cleanAmount(debitVal);
            if (creditVal !== null && creditVal !== undefined && cleanAmount(creditVal) > 0) {
              amount = 0.00;
            }

            const rawDescription = findVal(['description', 'desc', 'particulars', 'remark', 'narration', 'vendor', 'name', 'details']) || `Row ${idx + 1} Import`;
            const description = cleanFallbackDescription(rawDescription);
            let category = findVal(['category', 'cat', 'type']) || 'Others';
            if (category === 'Others' || !category) {
              category = autoCategorizeDescription(description);
            }
            const rawDate = findVal(['date', 'time', 'tx_date', 'transaction date', 'txn date', 'value date']);
            const transaction_date = parseRobustDate(rawDate);

            return {
              id: crypto.randomUUID(),
              amount: isNaN(amount) ? 0.00 : amount,
              currency: findVal(['currency', 'curr']) || 'INR',
              category: category,
              description: description,
              transaction_date: transaction_date.toISOString(),
              is_recurring: false,
              recurrence_period: 'none'
            };
          });
        }

        parsedExpenses = parsedRawExpenses.filter(e => {
          if (e.amount <= 0) return false;
          const lowerDesc = (e.description || '').toLowerCase();
          
          const isIncoming = lowerDesc.includes('cashback') ||
                             lowerDesc.includes('refund') ||
                             lowerDesc.includes('salary') ||
                             lowerDesc.includes('interest received') ||
                             lowerDesc.includes('credited') ||
                             lowerDesc.includes('deposit') ||
                             lowerDesc.includes('cash back') ||
                             lowerDesc.includes('incoming') ||
                             lowerDesc.includes('received');
          if (isIncoming) return false;

          return !isSelfTransferTransaction(e.description, userName);
        });

        return res.status(200).json({
          message: `Parsed ${parsedExpenses.length} transactions from Excel sheet (Rule-based Fallback).`,
          expenses: parsedExpenses
        });
      }
    }

    // CASE 2: PDF statement import (uses pdf-parse & Gemini parsing)
    if (filename.endsWith('.pdf')) {
      const filePassword = req.headers['x-file-password'];
      let pdfBuffer = req.file.buffer;

      if (filePassword) {
        try {
          const { decryptPDF } = await import('@pdfsmaller/pdf-decrypt');
          pdfBuffer = Buffer.from(await decryptPDF(new Uint8Array(pdfBuffer), filePassword));
        } catch (decErr) {
          console.error('[PDF Import] Decryption failed:', decErr);
          return res.status(401).json({
            success: false,
            error: 'InvalidPassword',
            message: 'Incorrect PDF password. Please try again.'
          });
        }
      }

      let pdfData;
      try {
        pdfData = await pdfParse(pdfBuffer, { pagerender: pageRender });
      } catch (err) {
        logDiagnostic(`[PDF Import] Parsing failed: ${err.message || err.description || err || ''}`);
        let errStr = '';
        try {
          errStr = JSON.stringify(err) || '';
          errStr = errStr.toLowerCase();
        } catch (_) {
          errStr = String(err.message || err.description || err || '').toLowerCase();
        }
        const errNameStr = String(err.name || '').toLowerCase();
        const isEncrypted = errNameStr.includes('password') || 
                            errNameStr.includes('decrypt') ||
                            errNameStr.includes('encrypt') ||
                            errStr.includes('password') || 
                            errStr.includes('decrypt') || 
                            errStr.includes('encrypt') ||
                            errStr.includes('secure');

        logDiagnostic(`[PDF Import] isEncrypted check: isEncrypted=${isEncrypted}, errNameStr=${errNameStr}, errStr=${errStr}`);

        if (isEncrypted) {
          return res.status(401).json({
            success: false,
            error: 'PasswordRequired',
            message: 'This bank statement PDF is password-protected. Please enter the password to import.'
          });
        }
        throw err;
      }
      const rawText = pdfData.text || '';

      if (!rawText || rawText.trim().length === 0) {
        return res.status(400).json({ error: 'Uploaded PDF file has no readable text.' });
      }

      const pages = rawText.split('---PAGE_BREAK---').map(p => p.trim()).filter(Boolean);
      logDiagnostic(`[PDF Import] Parsed: filename=${req.file.originalname}, pages=${pdfData.numpages}, actualSplitPages=${pages.length}, textLength=${rawText.length}`);

      const userApiKey = req.headers['x-user-gemini-key'];
      if (!userApiKey) {
        return res.status(400).json({ error: 'Gemini API Key required. Please set your Google Gemini API Key in Settings.' });
      }

      // Group pages into chunks of 9 pages each to avoid large output token requirements and laziness
      const pagesPerChunk = 9;
      const chunks = [];
      for (let i = 0; i < pages.length; i += pagesPerChunk) {
        const chunkPages = pages.slice(i, i + pagesPerChunk);
        chunks.push(chunkPages.join('\n\n--- NEXT PAGE ---\n\n'));
      }

      logDiagnostic(`[PDF Import] Grouped ${pages.length} pages into ${chunks.length} chunks.`);

      // userName is already fetched at the start of /import route

      const models = await getDynamicModels(userApiKey);
      const systemRulesText = getSystemRulesText(userName);

      const chunkPromises = chunks.map((chunkText, index) => {
        return callGeminiForChunk(chunkText, systemRulesText, userApiKey, models)
          .then(chunkArray => {
            logDiagnostic(`[PDF Import] Chunk ${index + 1}/${chunks.length} returned ${chunkArray.length} items.`);
            return chunkArray;
          })
          .catch(chunkErr => {
            logDiagnostic(`[PDF Import] Error processing chunk ${index + 1}/${chunks.length}: ${chunkErr.message}`);
            return []; // Return empty array on failure so other chunks still succeed
          });
      });

      const chunkResults = await Promise.all(chunkPromises);
      let mergedArray = [];
      for (const res of chunkResults) {
        mergedArray.push(...res);
      }

      if (mergedArray.length === 0) {
        return res.status(422).json({ error: 'No valid transactions could be extracted from this PDF.' });
      }

      const mappedExpenses = mergedArray.map(item => {
        let txDate, amount, currency, category, description;
        if (Array.isArray(item)) {
          txDate = parseRobustDate(item[0]);
          amount = cleanAmount(item[1]);
          description = item[2] || 'Imported Transaction';
          category = item[3] || 'Others';
          currency = item[4] || 'INR';
        } else {
          txDate = parseRobustDate(item.transaction_date);
          amount = cleanAmount(item.amount);
          description = item.description || 'Imported Transaction';
          category = item.category || 'Others';
          currency = item.currency || 'INR';
        }

        return {
          id: crypto.randomUUID(),
          amount: amount,
          currency: currency,
          category: category,
          description: description,
          transaction_date: txDate.toISOString(),
          is_recurring: false,
          recurrence_period: 'none'
        };
      }).filter(e => e.amount > 0 && !isSelfTransferTransaction(e.description, userName));

      const deduplicated = deduplicateTransactions(mappedExpenses);

      return res.status(200).json({
        message: `Parsed ${deduplicated.length} transactions from PDF statement (removed ${mappedExpenses.length - deduplicated.length} duplicates).`,
        expenses: deduplicated
      });
    }

    return res.status(400).json({ error: 'Unsupported file format. Please upload .xlsx, .xls, or .pdf' });
  } catch (error) {
    logDiagnostic(`File batch import error: ${error.message || error}`);
    res.status(500).json({ error: `Failed to process file import: ${error.message || error}` });
  }
});

router.get('/debug-logs', (req, res) => {
  res.status(200).json({ logs: logBuffer });
});

export default router;
