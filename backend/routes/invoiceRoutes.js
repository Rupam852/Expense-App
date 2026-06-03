import express from 'express';
import PDFDocument from 'pdfkit';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Generate PDF invoice/billing statement for chosen expense IDs
router.get('/generate', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  const { ids } = req.query; // Comma-separated list of expense IDs

  if (!ids) {
    return res.status(400).json({ error: 'No expense IDs provided. Please specify `ids` query parameter.' });
  }

  const idList = ids.split(',').map(id => id.trim());

  if (idList.length === 0) {
    return res.status(400).json({ error: 'Invalid expense IDs parameter format.' });
  }

  try {
    // 1. Fetch Selected Expenses
    const expensesRes = await query(
      `SELECT * FROM expenses 
       WHERE user_id = $1 AND id = ANY($2) AND is_deleted = FALSE
       ORDER BY transaction_date DESC`,
      [userId, idList]
    );

    if (expensesRes.rows.length === 0) {
      return res.status(404).json({ error: 'No valid expenses found for the specified IDs.' });
    }

    // 2. Fetch User Profile Details
    const userRes = await query('SELECT name, email FROM users WHERE id = $1', [userId]);
    const user = userRes.rows[0];

    // 3. Fetch User's Default Payment details (UPI for repayment invoice)
    const paymentRes = await query('SELECT upi_id FROM payment_details WHERE user_id = $1 LIMIT 1', [userId]);
    const upiId = paymentRes.rows[0]?.upi_id || 'Not specified';

    // 4. Initialize PDF Document
    const doc = new PDFDocument({ margin: 50 });

    // Set Response Headers to download/view the PDF
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=Expense_Statement_${Date.now()}.pdf`);

    // Stream PDF directly to client response
    doc.pipe(res);

    // -- Header Section --
    doc.fillColor('#00D09C') // Beautiful Groww Green Accent Color
       .fontSize(22)
       .text('GROW EXPENSE', { align: 'left' });

    doc.fillColor('#777777')
       .fontSize(10)
       .text('Official Reimbursement & Billing Statement', { align: 'left' })
       .moveDown();

    // Horizontal Rule Divider
    doc.strokeColor('#e2e8f0')
       .lineWidth(1)
       .moveTo(50, 100)
       .lineTo(550, 100)
       .stroke()
       .moveDown(1.5);

    // -- Profile Details --
    doc.fillColor('#1a202c')
       .fontSize(11)
       .text(`Issued By: ${user?.name || 'Valued Member'}`, { bullet: false })
       .text(`Email: ${user?.email || 'N/A'}`)
       .text(`Date of Issue: ${new Date().toLocaleDateString()}`)
       .moveDown(1.5);

    // -- Table Header --
    const tableTop = 200;
    doc.fontSize(10).fillColor('#4a5568');
    
    // Draw columns titles
    doc.text('Date', 50, tableTop);
    doc.text('Category', 140, tableTop);
    doc.text('Description', 230, tableTop);
    doc.text('Amount', 480, tableTop, { width: 70, align: 'right' });

    // Draw solid line under headers
    doc.strokeColor('#cbd5e1')
       .lineWidth(1.5)
       .moveTo(50, tableTop + 15)
       .lineTo(550, tableTop + 15)
       .stroke();

    // -- Render Table Rows --
    let currentY = tableTop + 25;
    let totalSum = 0.0;

    // Fetch rates to convert other currencies to INR
    let rates = { INR: 1.0, USD: 0.012, EUR: 0.011, GBP: 0.0094, AUD: 0.018, CAD: 0.016 };
    try {
      const response = await fetch('https://open.er-api.com/v6/latest/INR');
      if (response.ok) {
        const data = await response.json();
        if (data.result === 'success' && data.rates) {
          rates = data.rates;
        }
      }
    } catch (err) {
      console.warn('[PDF Invoice] Failed to fetch live exchange rates, using defaults:', err.message);
    }

    expensesRes.rows.forEach(exp => {
      // If we are getting close to page end, start a new page
      if (currentY > 700) {
        doc.addPage();
        currentY = 50;
      }

      const dateStr = new Date(exp.transaction_date).toLocaleDateString();
      const amountNum = parseFloat(exp.amount) || 0.0;
      const amountStr = `${amountNum.toFixed(2)} ${exp.currency}`;
      
      const rate = rates[exp.currency.toUpperCase()] || 1.0;
      const amountInINR = rate !== 0 ? (amountNum / rate) : amountNum;
      totalSum += amountInINR;

      doc.fillColor('#2d3748').fontSize(9);
      doc.text(dateStr, 50, currentY);
      doc.text(exp.category, 140, currentY);
      
      // Handle multi-line descriptions elegantly
      const descVal = exp.description || 'N/A';
      doc.text(descVal, 230, currentY, { width: 240, height: 25, ellipsis: true });
      
      doc.text(amountStr, 480, currentY, { width: 70, align: 'right' });

      // Draw light divider lines under each row
      doc.strokeColor('#f1f5f9')
         .lineWidth(0.5)
         .moveTo(50, currentY + 18)
         .lineTo(550, currentY + 18)
         .stroke();

      currentY += 25;
    });

    // -- Total Statement Summary --
    if (currentY > 680) {
      doc.addPage();
      currentY = 50;
    }

    doc.moveDown(1.5);
    doc.strokeColor('#a7f3d0')
       .lineWidth(1.5)
       .moveTo(350, currentY + 5)
       .lineTo(550, currentY + 5)
       .stroke();

    doc.fillColor('#1a202c')
       .fontSize(12)
       .text('Total Expenses:', 300, currentY + 15, { align: 'right', width: 140 })
       .fillColor('#00D09C') // Highlight final sum in Groww Green
       .text(`${totalSum.toFixed(2)} INR`, 450, currentY + 15, { align: 'right', width: 100 })
       .moveDown(2);

    // -- Simple Clean Footer --
    const footerY = doc.page.height - 80;
    doc.strokeColor('#e2e8f0')
       .lineWidth(1)
       .moveTo(50, footerY - 15)
       .lineTo(550, footerY - 15)
       .stroke();

    doc.fillColor('#718096')
       .fontSize(8)
       .text('Generated instantly by Grow Expense App. For any discrepancies, contact issuer above.', 50, footerY, { align: 'center' });

    // End and output file stream
    doc.end();

  } catch (error) {
    console.error('Invoice PDF generation error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to generate invoice PDF statement.' });
    }
  }
});

export default router;
