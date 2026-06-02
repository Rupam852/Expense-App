import express from 'express';
import multer from 'multer';
import xlsx from 'xlsx';
import pdfParse from 'pdf-parse';
import crypto from 'crypto';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Helper for Groq API integration (Llama-based lifetime free parsing)
async function callGroq(userKey, prompt, base64Image = null, mimeType = null) {
  console.log('Intelligent detection: Using Groq Cloud API parser...');
  
  const isVision = !!base64Image;
  const model = isVision ? 'meta-llama/llama-4-scout-17b-16e-instruct' : 'llama-3.1-8b-instant';
  
  const messages = [];
  if (isVision) {
    messages.push({
      role: 'user',
      content: [
        { type: 'text', text: prompt },
        {
          type: 'image_url',
          image_url: {
            url: `data:${mimeType};base64,${base64Image}`
          }
        }
      ]
    });
  } else {
    messages.push({
      role: 'user',
      content: prompt
    });
  }

  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${userKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: model,
      messages: messages,
      response_format: { type: 'json_object' },
      temperature: 0.1
    })
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Groq API failed: ${errText}`);
  }

  const data = await response.json();
  const rawContent = data.choices?.[0]?.message?.content?.trim();
  return rawContent;
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
      return res.status(400).json({ error: 'Google AI Studio or Groq API Key is required. Please set your key in Settings.' });
    }

    // Convert file buffer to base64
    const base64Image = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    let rawContent = null;

    if (userGeminiKey.startsWith('gsk_')) {
      try {
        const prompt = `Analyze this image (which could be a store receipt, utility bill, restaurant invoice, or a screenshot of a UPI transaction like GPay, PhonePe, Paytm). 
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
        }`;
        rawContent = await callGroq(userGeminiKey, prompt, base64Image, mimeType);
      } catch (err) {
        console.error('Groq scan-receipt error:', err);
        return res.status(500).json({ error: `Groq OCR scan failed: ${err.message}` });
      }
    } else {
      const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-3.5-flash', 'gemini-1.5-flash-latest', 'gemini-1.5-flash', 'gemini-1.5-pro'];
      let lastError = null;
      let usedModel = null;

      for (const model of models) {
        try {
          console.log(`Sending receipt image to Google Gemini Native REST API using model ${model} (${req.file.size} bytes)...`);

          const apiVersion = model.startsWith('gemini-1.5') ? 'v1' : 'v1beta';
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
                responseMimeType: 'application/json',
                maxOutputTokens: 1000
              }
            })
          });

          if (response.ok) {
            const data = await response.json();
            rawContent = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
            if (rawContent) {
              usedModel = model;
              break;
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

    // CASE 1: Excel spreadsheets (.xlsx, .xls)
    if (filename.endsWith('.xlsx') || filename.endsWith('.xls')) {
      const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];
      const rows = xlsx.utils.sheet_to_json(worksheet);

      // Attempt to map typical headers to standard schema
      parsedExpenses = rows.map((row, idx) => {
        // Search for dynamic header values case-insensitively
        const findVal = (keys) => {
          const matchedKey = Object.keys(row).find(k => 
            keys.some(key => k.toLowerCase().includes(key))
          );
          return matchedKey ? row[matchedKey] : null;
        };

        const amount = parseFloat(findVal(['amount', 'price', 'val', 'cost', 'total']));
        const category = findVal(['category', 'cat', 'type']) || 'Others';
        const description = findVal(['description', 'desc', 'particulars', 'remark', 'vendor', 'name']) || `Row ${idx + 1} Import`;
        const rawDate = findVal(['date', 'time', 'tx_date']);
        
        let transaction_date = new Date();
        if (rawDate) {
          const parsedD = new Date(rawDate);
          if (!isNaN(parsedD.getTime())) {
            transaction_date = parsedD;
          }
        }

        // Force to current month and year to ensure they are added to current month's expenses
        const now = new Date();
        transaction_date.setFullYear(now.getFullYear());
        transaction_date.setMonth(now.getMonth());

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
        message: `Parsed ${parsedExpenses.length} transactions from Excel sheet.`,
        expenses: parsedExpenses
      });
    }

    // CASE 2: PDF statement import (uses pdf-parse & Gemini parsing)
    if (filename.endsWith('.pdf')) {
      const pdfData = await pdfParse(req.file.buffer);
      const rawText = pdfData.text || '';

      if (!rawText || rawText.trim().length === 0) {
        return res.status(400).json({ error: 'Uploaded PDF file has no readable text.' });
      }

      const userGeminiKey = req.headers['x-user-gemini-key'];
      if (!userGeminiKey) {
        return res.status(400).json({ error: 'Google AI Studio or Groq API Key is required. Please set your key in Settings.' });
      }

      const isGroq = userGeminiKey.startsWith('gsk_');
      
      // Adaptive slicing: Groq has a tiny 6000 TPM limit, so we slice to 5000 chars to be 100% safe.
      // Gemini has a huge 1,000,000 TPM free tier limit, so we slice to 30,000 chars to fetch maximum history!
      const sliceLimit = isGroq ? 5000 : 30000;
      
      const textContent = rawText
        .replace(/[ \t]+/g, ' ')
        .replace(/\r/g, '')
        .replace(/\n\s*\n+/g, '\n')
        .trim()
        .slice(0, sliceLimit);

      console.log(`Parsing PDF text (${textContent.length} chars) using ${isGroq ? 'Groq' : 'Gemini'}...`);

      let rawContent = null;

      if (isGroq) {
        try {
          // Extremely compact prompt for Groq to stay well below the 6000 TPM limit!
          const prompt = `Extract ONLY debit/expense/payment transactions (ignore all credits/deposits/salary/refunds) from this bank statement text.
          
          Text:
          ${textContent}

          For each debit transaction, extract:
          - amount (positive float)
          - currency (3-letter code, e.g. INR)
          - category (Food, Travel, Shopping, Bills, Entertainment, Health, Investment, Others)
          - description (Merchant/payment details)
          - transaction_date (ISO 8601 string)
          
          Return ONLY a JSON array of objects.
          Structure:
          [{"amount": 450.0,"currency": "INR","category": "Shopping","description": "Amazon","transaction_date": "2026-05-25T12:00:00.000Z"}]`;

          rawContent = await callGroq(userGeminiKey, prompt);
        } catch (err) {
          console.error('Groq statement import error:', err);
          return res.status(500).json({ error: `Groq Import failed: ${err.message}` });
        }
      } else {
        const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-3.5-flash', 'gemini-1.5-flash-latest', 'gemini-1.5-flash', 'gemini-1.5-pro'];
        let lastError = null;
        let usedModel = null;

        for (const model of models) {
          try {
            console.log(`Sending PDF text to Google Gemini Native REST API using model ${model} (${textContent.length} chars)...`);

            const apiVersion = model.startsWith('gemini-1.5') ? 'v1' : 'v1beta';
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
                        text: `Analyze this raw text extracted from a bank statement. Extract a list of transactions.
                        
                        Raw PDF text content:
                        ---------------------
                        ${textContent}
                        ---------------------

                        CRITICAL RULE:
                        - ONLY extract debit/expense/payment transactions (where money is spent/withdrawn/Dr).
                        - COMPLETELY IGNORE all credit/deposit/income/salary/refund transactions (where money is received/credited/Cr).

                        Tasks:
                        1. Extract at most the 30 most recent debit transaction items.
                        2. For each transaction, extract:
                           - amount (numeric positive float)
                           - currency (3-letter ISO code, e.g. INR)
                           - category (Precisely: Food, Travel, Shopping, Bills, Entertainment, Health, Investment, Others)
                           - description (Clear merchant/receiver detail)
                           - transaction_date (ISO 8601 string)
                        
                        Ensure your response is ONLY a JSON array of objects, without markdown wrapper blocks or text.
                        Structure:
                        [
                          {
                            "amount": 450.00,
                            "currency": "INR",
                            "category": "Shopping",
                            "description": "Amazon Purchase",
                            "transaction_date": "2026-05-25T12:00:00.000Z"
                          }
                        ]`
                      }
                    ]
                  }
                ],
                generationConfig: {
                  responseMimeType: 'application/json',
                  maxOutputTokens: 8192
                }
              })
            });

            if (response.ok) {
              const data = await response.json();
              rawContent = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
              if (rawContent) {
                usedModel = model;
                break;
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
          return res.status(500).json({ error: `AI processing of statement PDF failed: ${lastError ? lastError.message : 'No response from models'}` });
        }
      }

      let cleanJson = rawContent.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replace(/^```json\s*/, '').replace(/```$/, '').trim();
      }

      const parsedArray = JSON.parse(cleanJson);

      const mappedExpenses = parsedArray.map(item => {
        let txDate = new Date(item.transaction_date || new Date());
        if (isNaN(txDate.getTime())) {
          txDate = new Date();
        }

        // Force to current month and year to ensure they are added to current month's expenses
        const now = new Date();
        txDate.setFullYear(now.getFullYear());
        txDate.setMonth(now.getMonth());

        return {
          id: crypto.randomUUID(),
          amount: parseFloat(item.amount) || 0.0,
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
    console.error('File batch import error:', error);
    res.status(500).json({ error: 'Failed to process file import.' });
  }
});

export default router;
