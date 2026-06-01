import express from 'express';
import multer from 'multer';
import xlsx from 'xlsx';
import pdfParse from 'pdf-parse';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

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
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'OpenRouter API key is not configured.' });
    }

    // Convert file buffer to base64
    const base64Image = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    console.log(`Sending receipt image to OpenRouter using Gemini 2.5 Flash (${req.file.size} bytes)...`);

    // Call OpenRouter with base64 image data
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/Rupam852/Expense-App',
        'X-Title': 'Expense Tracker App'
      },
      body: JSON.stringify({
        model: 'google/gemini-2.5-flash',
        max_tokens: 1000,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
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
                type: 'image_url',
                image_url: {
                  url: `data:${mimeType};base64,${base64Image}`
                }
              }
            ]
          }
        ]
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('OpenRouter API error response:', errText);
      return res.status(500).json({ error: `OCR Service failed: ${response.statusText}` });
    }

    const data = await response.json();
    const messageContent = data.choices?.[0]?.message?.content;

    if (!messageContent) {
      return res.status(500).json({ error: 'No data returned from OCR Service.' });
    }

    // Clean JSON wrapper markdown blocks like ```json ... ``` if returned by the LLM
    let cleanJson = messageContent.trim();
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.replace(/^```json\s*/, '').replace(/```$/, '').trim();
    }

    console.log('Extracted OCR Result:', cleanJson);
    const parsedData = JSON.parse(cleanJson);

    res.status(200).json({
      message: 'Receipt parsed successfully.',
      data: parsedData
    });
  } catch (error) {
    console.error('Receipt Scan OCR Error:', error);
    res.status(500).json({ error: 'Server error processing receipt scanner OCR.' });
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
      const textContent = pdfData.text;

      if (!textContent || textContent.trim().length === 0) {
        return res.status(400).json({ error: 'Uploaded PDF file has no readable text.' });
      }

      console.log(`Parsing PDF text (${textContent.length} chars) using Gemini 2.5 Flash via OpenRouter...`);

      const apiKey = process.env.OPENROUTER_API_KEY;
      if (!apiKey) {
        return res.status(500).json({ error: 'OpenRouter API key is not configured.' });
      }

      // We send the PDF text content directly to the LLM to parse it into an array of structured expenses!
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/Rupam852/Expense-App',
          'X-Title': 'Expense Tracker App'
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash',
          max_tokens: 2500,
          messages: [
            {
              role: 'user',
              content: `Analyze this raw text extracted from a bank statement, digital payment receipt list, or invoice PDF. Extract a list of transactions.
              
              Raw PDF text content:
              ---------------------
              ${textContent.slice(0, 15000)}  // Limit size to protect token usage
              ---------------------

              Tasks:
              1. Extract all transaction items (specifically payments/expenses, ignoring credits/deposits where possible).
              2. For each transaction, extract:
                 - amount (numeric positive float)
                 - currency (3-letter ISO code, e.g. INR, USD)
                 - category (Precisely categorize into: Food, Travel, Shopping, Bills, Entertainment, Health, Investment, Others)
                 - description (Clear merchant/detail from transaction text)
                 - transaction_date (ISO 8601 string, parse/estimate from date logs)
              
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
        })
      });

      if (!response.ok) {
        const errText = await response.text();
        console.error('OpenRouter Statement API error response:', errText);
        return res.status(500).json({ error: `AI processing of statement PDF failed: ${errText}` });
      }

      const data = await response.json();
      let rawContent = data.choices?.[0]?.message?.content?.trim();

      if (!rawContent) {
        return res.status(500).json({ error: 'No data extracted from PDF statement.' });
      }

      if (rawContent.startsWith('```')) {
        rawContent = rawContent.replace(/^```json\s*/, '').replace(/```$/, '').trim();
      }

      const parsedArray = JSON.parse(rawContent);

      const mappedExpenses = parsedArray.map(item => ({
        id: crypto.randomUUID(),
        amount: parseFloat(item.amount) || 0.0,
        currency: item.currency || 'INR',
        category: item.category || 'Others',
        description: item.description || 'Imported Transaction',
        transaction_date: item.transaction_date || new Date().toISOString(),
        is_recurring: false,
        recurrence_period: 'none'
      })).filter(e => e.amount > 0);

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
