import express from 'express';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Get spending trends and category budgets
router.get('/summary', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  const currentMonthYear = new Date().toISOString().substring(0, 7); // Format: 'YYYY-MM'

  try {
    // 1. Fetch live exchange rates relative to INR
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
      console.warn('[Analytics API] Failed to fetch live exchange rates, using defaults:', err.message);
    }

    const convertToINR = (amount, currency) => {
      const amountNum = parseFloat(amount) || 0.0;
      const rate = rates[String(currency || 'INR').toUpperCase()] || 1.0;
      if (rate === 0) return amountNum;
      return amountNum / rate;
    };

    // 2. Fetch raw category expenses for the current month
    const categorySpendingQuery = await query(
      `SELECT category, amount, currency 
       FROM expenses 
       WHERE user_id = $1 
         AND is_deleted = FALSE 
         AND TO_CHAR(transaction_date, 'YYYY-MM') = $2`,
      [userId, currentMonthYear]
    );

    // Aggregate category spent in memory converting to INR
    const categorySpentMap = {};
    categorySpendingQuery.rows.forEach(exp => {
      const amtInINR = convertToINR(exp.amount, exp.currency);
      categorySpentMap[exp.category] = (categorySpentMap[exp.category] || 0.0) + amtInINR;
    });

    // 3. Fetch category budgets for the current month
    const budgetsQuery = await query(
      `SELECT category, amount_limit 
       FROM budgets 
       WHERE user_id = $1 
         AND month_year = $2
         AND is_deleted = FALSE`,
      [userId, currentMonthYear]
    );

    // 4. Compile category limits and spending comparisons
    const budgetsMap = {};
    budgetsQuery.rows.forEach(b => {
      budgetsMap[b.category] = parseFloat(b.amount_limit);
    });

    const categorySummary = Object.keys(categorySpentMap).map(category => {
      const spent = categorySpentMap[category];
      const limit = budgetsMap[category] || null;
      return {
        category,
        spent: parseFloat(spent.toFixed(2)),
        limit,
        percentage: limit ? Math.round((spent / limit) * 100) : 0
      };
    });

    // Add categories that have budgets set but no transactions yet this month
    budgetsQuery.rows.forEach(b => {
      const found = categorySummary.some(c => c.category === b.category);
      if (!found) {
        categorySummary.push({
          category: b.category,
          spent: 0.0,
          limit: parseFloat(b.amount_limit),
          percentage: 0
        });
      }
    });

    // 5. Fetch 30-day raw transactions for charting
    const trendsQuery = await query(
      `SELECT TO_CHAR(transaction_date, 'YYYY-MM-DD') as date, amount, currency 
       FROM expenses 
       WHERE user_id = $1 
         AND is_deleted = FALSE 
         AND transaction_date >= NOW() - INTERVAL '30 days'`,
      [userId]
    );

    // Aggregate trends in memory converting to INR
    const dailySpentMap = {};
    trendsQuery.rows.forEach(t => {
      const amtInINR = convertToINR(t.amount, t.currency);
      dailySpentMap[t.date] = (dailySpentMap[t.date] || 0.0) + amtInINR;
    });

    const trends = Object.keys(dailySpentMap)
      .sort()
      .map(date => ({
        date,
        amount: parseFloat(dailySpentMap[date].toFixed(2))
      }));

    // 6. Total budget vs total spent this month
    const totalSpentThisMonth = Object.values(categorySpentMap).reduce((sum, spent) => sum + spent, 0.0);
    const totalBudgetThisMonth = budgetsQuery.rows.reduce((sum, item) => sum + (parseFloat(item.amount_limit) || 0), 0);

    res.status(200).json({
      month: currentMonthYear,
      total_spent: parseFloat(totalSpentThisMonth.toFixed(2)),
      total_budget: parseFloat(totalBudgetThisMonth.toFixed(2)),
      categories: categorySummary,
      trends
    });
  } catch (error) {
    console.error('Analytics Fetch Error:', error);
    res.status(500).json({ error: 'Server error generating analytics summary.' });
  }
});

export default router;
