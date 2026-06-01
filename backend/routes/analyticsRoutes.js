import express from 'express';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Get spending trends and category budgets
router.get('/summary', authenticateToken, async (req, res) => {
  const userId = req.user.userId;
  const currentMonthYear = new Date().toISOString().substring(0, 7); // Format: 'YYYY-MM'

  try {
    // 1. Fetch category spending sums for the current month
    const categorySpendingQuery = await query(
      `SELECT category, SUM(amount) as spent 
       FROM expenses 
       WHERE user_id = $1 
         AND is_deleted = FALSE 
         AND TO_CHAR(transaction_date, 'YYYY-MM') = $2 
       GROUP BY category`,
      [userId, currentMonthYear]
    );

    // 2. Fetch category budgets for the current month
    const budgetsQuery = await query(
      `SELECT category, amount_limit 
       FROM budgets 
       WHERE user_id = $1 
         AND month_year = $2`,
      [userId, currentMonthYear]
    );

    // 3. Compile category limits and spending comparisons
    const budgetsMap = {};
    budgetsQuery.rows.forEach(b => {
      budgetsMap[b.category] = parseFloat(b.amount_limit);
    });

    const categorySummary = categorySpendingQuery.rows.map(row => {
      const spent = parseFloat(row.spent) || 0.0;
      const limit = budgetsMap[row.category] || null;
      return {
        category: row.category,
        spent,
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

    // 4. Fetch 30-day daily transaction trends for charting
    const trendsQuery = await query(
      `SELECT TO_CHAR(transaction_date, 'YYYY-MM-DD') as date, SUM(amount) as amount 
       FROM expenses 
       WHERE user_id = $1 
         AND is_deleted = FALSE 
         AND transaction_date >= NOW() - INTERVAL '30 days' 
       GROUP BY TO_CHAR(transaction_date, 'YYYY-MM-DD') 
       ORDER BY date ASC`,
      [userId]
    );

    const trends = trendsQuery.rows.map(t => ({
      date: t.date,
      amount: parseFloat(t.amount) || 0.0
    }));

    // 5. Total budget vs total spent this month
    const totalSpentThisMonth = categorySpendingQuery.rows.reduce((sum, item) => sum + (parseFloat(item.spent) || 0), 0);
    const totalBudgetThisMonth = budgetsQuery.rows.reduce((sum, item) => sum + (parseFloat(item.amount_limit) || 0), 0);

    res.status(200).json({
      month: currentMonthYear,
      total_spent: totalSpentThisMonth,
      total_budget: totalBudgetThisMonth,
      categories: categorySummary,
      trends
    });
  } catch (error) {
    console.error('Analytics Fetch Error:', error);
    res.status(500).json({ error: 'Server error generating analytics summary.' });
  }
});

export default router;
