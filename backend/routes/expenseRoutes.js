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

// Helper to detect if a JSON string returned by LLM is truncated/incomplete before parsing or repairing
function isJsonTruncated(str) {
  if (!str) return true;
  const trimmed = str.trim().replace(/```(json)?$/i, '').trim();
  return !trimmed.endsWith(']') && !trimmed.endsWith('}');
}

// Helper to dynamically query, filter, and sort supported generative models for this specific API Key
async function getDynamicModels(userApiKey) {
  const defaultModels = ['gemini-2.5-flash', 'gemini-2.0-flash-lite', 'gemini-flash-latest', 'gemini-pro-latest', 'gemini-3.5-flash'];
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
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemini-pro-latest',
      'gemini-3.5-flash'
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
router.post('/import', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Excel or PDF file is required.' });
  }

  const filename = req.file.originalname.toLowerCase();

  try {
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

        const textContent = csvText
          .trim()
          .slice(0, 150000); // 150,000 chars slice limit to avoid model overload

        logDiagnostic(`[Spreadsheet Import] Excel/CSV converted to CSV text (length=${textContent.length}).`);

        let rawContent = null;
        const models = await getDynamicModels(userApiKey);
        let lastError = null;
        let usedModel = null;

        const systemRulesText = `You are a professional financial assistant. Analyze raw spreadsheet CSV/text extracted from a bank statement (from any bank like SBI, HDFC, ICICI, Axis, PNB, etc.). Extract all money-out transactions (outflows/debits/transfers).

        CRITICAL OUTFLOW EXTRACTION RULES:
        1. ONLY extract transactions where money is leaving the account (money-out / debits / withdrawals / transfers).
        2. Extract all of the following debit/transfer transactions:
           - UPI Payments / UPI-DR / UPI-OUT / Merchant payments (e.g., GPay, PhonePe, Paytm, BharatPe transfers)
           - Transfers to vendors, merchants, or other individuals (e.g., "TRANSFER TO...", "TO TRANSFER...", "TRFR TO...", "SENT TO...")
           - IMPS / NEFT / RTGS debit transfers (e.g., "IMPS-OUT...", "IMPS/DR...", "NEFT DR...")
           - Card spends / POS purchases / Online shopping spends (e.g., "POS DEBIT...")
           - Cash withdrawals / ATM withdrawals
           - Bank fees, charges, interest debits, or SMS alert fees
        3. COMPLETELY IGNORE all credits, deposits, refunds, salary, or incoming money (e.g., "IMPS-IN...", "UPI-IN...", "BY TRANSFER...", "TRANSFER FROM...", "interest credited", or any entry under Credit/Deposit/CR columns).
        4. STRICT LAZYNESS PREVENTION: Never use placeholders, three dots ('...'), or 'etc.' in the JSON response. You MUST extract absolutely EVERY SINGLE money-out/debit/transfer transaction item present in the spreadsheet text, no matter how many there are. Do not stop until the entire text is fully parsed.
        
        How to identify debits in tabular spreadsheet data:
        - Spreadsheets may contain header metadata rows at the top (like Account number, Bank name, Address, Balance). Ignore those metadata rows and find where the transaction table rows start.
        - Look for entries in columns representing outflows (e.g., "Debit", "Withdrawal", "DR", "Amount (Dr)", "Debits", or negative numbers in a single "Amount" column).
        - If the statement does not have distinct columns, identify debits via negative numbers or keywords like "UPI-DR", "IMPS-OUT", "TRFR TO", "Paid to".

        Ensure your response is ONLY a JSON array of objects, without markdown wrapper blocks or text.
        Structure:
        [
          {
            "amount": 450.00,
            "currency": "INR",
            "category": "Shopping",
            "description": "Amazon UPI Transfer",
            "transaction_date": "2026-05-25T12:00:00.000Z"
          }
        ]`;

        for (const model of models) {
          try {
            logDiagnostic(`Sending spreadsheet text to Google Gemini Native REST API using model ${model}...`);
            const apiVersion = 'v1beta';

            const bodyPayload = {
              systemInstruction: {
                parts: [{ text: systemRulesText }]
              },
              contents: [
                {
                  parts: [
                    {
                      text: `Raw spreadsheet/CSV text content:
                      ---------------------
                      ${textContent}
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
                maxOutputTokens: 4096
              }
            };

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 35000);

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
                logDiagnostic(`[Spreadsheet Import] Model ${model} returned output (length=${text.length}, finishReason=${finishReason || 'STOP'}, isTruncated=${truncated})`);
                
                if (!truncated || model === models[models.length - 1]) {
                  rawContent = text;
                  usedModel = model;
                  break;
                } else {
                  logDiagnostic(`[Spreadsheet Import] Model ${model} output was truncated. Falling back to the next model...`);
                }
              }
            } else {
              const errText = await response.text();
              logDiagnostic(`Gemini model ${model} failed with status ${response.status}: ${errText}`);
              lastError = new Error(errText);
            }
          } catch (err) {
            logDiagnostic(`Gemini model ${model} exception: ${err.message}`);
            lastError = err;
          }
        }

        if (!rawContent) {
          return res.status(500).json({ error: `AI processing of spreadsheet statement failed: ${lastError ? lastError.message : 'No response from models'}` });
        }

        logDiagnostic(`[Spreadsheet Import] Raw LLM content (length=${rawContent.length}):\n${rawContent}`);

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

        let parsedArray = [];
        try {
          const parsedJson = JSON.parse(cleanJson);
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
        } catch (jsonErr) {
          console.error('JSON parsing failed. Raw LLM content was:', rawContent);
          throw new Error(`JSON Error: ${jsonErr.message}. Content: ${cleanJson ? cleanJson.substring(0, 500) : 'null'}`);
        }

        if (!Array.isArray(parsedArray) || parsedArray.length === 0) {
          return res.status(422).json({ error: 'No valid transactions could be extracted from this spreadsheet.' });
        }

        parsedExpenses = parsedArray.map(item => {
          let txDate = new Date(item.transaction_date || new Date());
          if (isNaN(txDate.getTime())) {
            txDate = new Date();
          }

          return {
            id: crypto.randomUUID(),
            amount: cleanAmount(item.amount),
            currency: item.currency || 'INR',
            category: item.category || 'Others',
            description: item.description || 'Imported Spreadsheet Transaction',
            transaction_date: txDate.toISOString(),
            is_recurring: false,
            recurrence_period: 'none'
          };
        }).filter(e => e.amount > 0);

        return res.status(200).json({
          message: `Parsed ${parsedExpenses.length} transactions from spreadsheet statement using Gemini AI.`,
          expenses: parsedExpenses
        });

      } else {
        logDiagnostic(`[Spreadsheet Import] Gemini API Key not found. Falling back to rule-based parser.`);
        
        const rows = xlsx.utils.sheet_to_json(worksheet);

        // Attempt to map typical headers to standard schema using fallback rules
        parsedExpenses = rows.map((row, idx) => {
          // Search for dynamic header values case-insensitively
          const findVal = (keys) => {
            const matchedKey = Object.keys(row).find(k => 
              keys.some(key => k.toLowerCase().includes(key))
            );
            return matchedKey ? row[matchedKey] : null;
          };

          const amount = cleanAmount(findVal(['debit', 'withdrawal', 'amount', 'spent', 'dr', 'outflow', 'price', 'val', 'cost', 'total']));
          const category = findVal(['category', 'cat', 'type']) || 'Others';
          const description = findVal(['description', 'desc', 'particulars', 'remark', 'narration', 'vendor', 'name', 'details']) || `Row ${idx + 1} Import`;
          const rawDate = findVal(['date', 'time', 'tx_date', 'transaction date', 'txn date', 'value date']);
          
          let transaction_date = new Date();
          if (rawDate) {
            const parsedD = new Date(rawDate);
            if (!isNaN(parsedD.getTime())) {
              transaction_date = parsedD;
            }
          }

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
        }).filter(e => e.amount > 0); // Exclude blank or negative entries

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
        pdfData = await pdfParse(pdfBuffer);
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

      logDiagnostic(`[PDF Import] Parsed: filename=${req.file.originalname}, pages=${pdfData.numpages}, textLength=${rawText.length}`);
      logDiagnostic(`[PDF Import] Sample raw text:\n${rawText.substring(0, 1200)}`);

      if (!rawText || rawText.trim().length === 0) {
        return res.status(400).json({ error: 'Uploaded PDF file has no readable text.' });
      }

      const userApiKey = req.headers['x-user-gemini-key'];
      if (!userApiKey) {
        return res.status(400).json({ error: 'Gemini API Key required. Please set your Google Gemini API Key in Settings.' });
      }

      // Increase slice limit to 150,000 characters to support massive multi-page statements without cutting off late-month transactions
      const sliceLimit = 150000;
      
      const textContent = rawText
        .replace(/[ \t]+/g, ' ')
        .replace(/\r/g, '')
        .replace(/\n\s*\n+/g, '\n')
        .trim()
        .slice(0, sliceLimit);

      console.log(`Parsing PDF text (${textContent.length} chars) using Google Gemini Native REST API...`);

      let rawContent = null;
      const models = await getDynamicModels(userApiKey);
      let lastError = null;
      let usedModel = null;

      for (const model of models) {
        try {
          logDiagnostic(`Sending PDF text to Google Gemini Native REST API using model ${model} (${textContent.length} chars)...`);

          const apiVersion = 'v1beta';

          const systemRulesText = `You are a professional financial assistant. Analyze raw text extracted from a bank statement (from any bank like SBI, HDFC, ICICI, Axis, PNB, etc.). Extract all money-out transactions (outflows/debits/transfers).

          CRITICAL OUTFLOW EXTRACTION RULES:
          1. ONLY extract transactions where money is leaving the account (money-out / debits / withdrawals / transfers).
          2. Extract all of the following debit/transfer transactions:
             - UPI Payments / UPI-DR / UPI-OUT / Merchant payments (e.g., GPay, PhonePe, Paytm, BharatPe transfers)
             - Transfers to vendors, merchants, or other individuals (e.g., "TRANSFER TO...", "TO TRANSFER...", "TRFR TO...", "SENT TO...")
             - IMPS / NEFT / RTGS debit transfers (e.g., "IMPS-OUT...", "IMPS/DR...", "NEFT DR...")
             - Card spends / POS purchases / Online shopping spends (e.g., "POS DEBIT...")
             - Cash withdrawals / ATM withdrawals
             - Bank fees, charges, interest debits, or SMS alert fees
          3. COMPLETELY IGNORE all credits, deposits, refunds, salary, or incoming money (e.g., "IMPS-IN...", "UPI-IN...", "BY TRANSFER...", "TRANSFER FROM...", "interest credited", or any entry under Credit/Deposit/CR columns).
          4. STRICT LAZYNESS PREVENTION: Never use placeholders, three dots ('...'), or 'etc.' in the JSON response. You MUST extract absolutely EVERY SINGLE money-out/debit/transfer transaction item present in the text, no matter how many there are. Do not stop until the entire text is fully parsed.
          
          How to identify debits in tabular statement text:
          - Look for entries in columns named "Debit", "Withdrawal", "DR", "Amount (Dr)", or "Debits".
          - If the statement does not have distinct columns, identify debits via keywords like "UPI-DR", "IMPS-OUT", "TRFR TO", "Paid to", or negative numbers.

          Ensure your response is ONLY a JSON array of objects, without markdown wrapper blocks or text.
          Structure:
          [
            {
              "amount": 450.00,
              "currency": "INR",
              "category": "Shopping",
              "description": "Amazon UPI Transfer",
              "transaction_date": "2026-05-25T12:00:00.000Z"
            }
          ]`;

          const bodyPayload = {
            systemInstruction: {
              parts: [{ text: systemRulesText }]
            },
            contents: [
              {
                parts: [
                  {
                    text: `Raw PDF text content:
                    ---------------------
                    ${textContent}
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
              maxOutputTokens: 4096
            }
          };

          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 35000); // 35 seconds timeout per model attempt

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
              logDiagnostic(`[PDF Import] Model ${model} returned output (length=${text.length}, finishReason=${finishReason || 'STOP'}, isTruncated=${truncated})`);
              
              if (!truncated || model === models[models.length - 1]) {
                rawContent = text;
                usedModel = model;
                break;
              } else {
                logDiagnostic(`[PDF Import] Model ${model} output was truncated. Falling back to the next model...`);
              }
            }
          } else {
            const errText = await response.text();
            logDiagnostic(`Gemini model ${model} failed with status ${response.status}: ${errText}`);
            lastError = new Error(errText);
          }
        } catch (err) {
          logDiagnostic(`Gemini model ${model} exception: ${err.message}`);
          lastError = err;
        }
      }

      if (!rawContent) {
        return res.status(500).json({ error: `AI processing of statement PDF failed: ${lastError ? lastError.message : 'No response from models'}` });
      }

      logDiagnostic(`[PDF Import] Raw LLM content (length=${rawContent.length}):\n${rawContent}`);

      let cleanJson = rawContent.trim();
      
      // Step 1: Remove markdown block wrappers if present
      cleanJson = cleanJson.replace(/```json/gi, '').replace(/```/gi, '').trim();

      // Step 2: Repair truncated JSON if it ends abruptly
      cleanJson = repairTruncatedJson(cleanJson);

      // Step 2: Extract JSON subset using boundaries
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

      // Step 3: Robust Parser - Escape literal newlines inside double-quoted string values (CRITICAL for UPI descriptions with newlines)
      let insideQuotes = false;
      let escaped = false;
      let fixedStr = '';
      for (let i = 0; i < cleanJson.length; i++) {
        const char = cleanJson[i];
        if (char === '"' && !escaped) {
          insideQuotes = !insideQuotes;
        }
        
        if (insideQuotes) {
          if (char === '\n') {
            fixedStr += ' '; // Convert literal newline to safe space
          } else if (char === '\r') {
            // Drop carriage return
          } else {
            fixedStr += char;
          }
        } else {
          fixedStr += char;
        }
        
        if (char === '\\' && !escaped) {
          escaped = true;
        } else {
          escaped = false;
        }
      }
      cleanJson = fixedStr;

      // Step 4: Remove trailing commas in objects or arrays before closing braces
      cleanJson = cleanJson.replace(/,\s*([\]}])/g, '$1');

      // Step 5: Sanitize lazy LLM placeholders (e.g., ..., "...", or , ...)
      cleanJson = cleanJson.replace(/,\s*"\.\.\."\s*/g, '');
      cleanJson = cleanJson.replace(/,\s*\.\.\.\s*/g, '');
      cleanJson = cleanJson.replace(/"\.\.\."\s*/g, '""');
      cleanJson = cleanJson.replace(/\.\.\.\s*/g, '');

      let parsedArray = [];
      try {
        const parsedJson = JSON.parse(cleanJson);
        if (Array.isArray(parsedJson)) {
          parsedArray = parsedJson;
        } else if (parsedJson && typeof parsedJson === 'object') {
          // Look for transaction lists inside root object keys
          const keys = Object.keys(parsedJson);
          for (const k of keys) {
            if (Array.isArray(parsedJson[k])) {
              parsedArray = parsedJson[k];
              break;
            }
          }
        }
      } catch (jsonErr) {
        console.error('JSON parsing failed. Raw LLM content was:', rawContent);
        throw new Error(`JSON Error: ${jsonErr.message}. Content: ${cleanJson ? cleanJson.substring(0, 500) : 'null'}`);
      }

      if (!Array.isArray(parsedArray) || parsedArray.length === 0) {
        return res.status(422).json({ error: 'No valid transactions could be extracted from this statement.' });
      }

      const mappedExpenses = parsedArray.map(item => {
        let txDate = new Date(item.transaction_date || new Date());
        if (isNaN(txDate.getTime())) {
          txDate = new Date();
        }

        return {
          id: crypto.randomUUID(),
          amount: cleanAmount(item.amount),
          currency: item.currency || 'INR',
          category: item.category || 'Others',
          description: item.description || 'Imported Transaction',
          transaction_date: txDate.toISOString(),
          is_recurring: false,
          recurrence_period: 'none'
        };
      }).filter(e => e.amount > 0);

      return res.status(200).json({
        message: `Parsed ${mappedExpenses.length} transactions from PDF statement.`,
        expenses: mappedExpenses
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
