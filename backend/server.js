import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import { initDB } from './db.js';

// Route Imports
import authRoutes from './routes/authRoutes.js';
import expenseRoutes from './routes/expenseRoutes.js';
import analyticsRoutes from './routes/analyticsRoutes.js';
import invoiceRoutes from './routes/invoiceRoutes.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Enable Cross-Origin Resource Sharing (CORS) for Flutter client connections
app.use(cors());

// Configure built-in body parsers for JSON and URL-encoded payloads
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// General API rate limiter (max 300 requests per 15 minutes)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300,
  message: { error: 'Too many API requests from this IP, please try again after 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter rate limiter for Auth (max 50 attempts per 15 minutes)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 50,
  message: { error: 'Too many authentication attempts from this IP, please try again after 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Health check endpoint
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'online',
    message: 'Secure Offline-First Expense Tracker Backend running successfully.',
    time: new Date().toISOString()
  });
});

// Fallback health checks to support custom external cron ping URLs (e.g. cron-job.org)
app.get('/api/auth/health', (req, res) => {
  res.status(200).json({ status: 'online', time: new Date().toISOString() });
});
app.get('/auth/health', (req, res) => {
  res.status(200).json({ status: 'online', time: new Date().toISOString() });
});

// Register API Routes with Rate Limiters applied
app.use('/auth', authLimiter, authRoutes);
app.use('/expenses', apiLimiter, expenseRoutes);
app.use('/analytics', apiLimiter, analyticsRoutes);
app.use('/invoices', apiLimiter, invoiceRoutes);

// Global Error Handler Middleware
app.use((err, req, res, next) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({ error: 'Internal Server Error' });
});

// Initialize database tables, then start listening
const startServer = async () => {
  try {
    await initDB();
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`=========================================`);
      console.log(`SERVER RUNNING IN DEVELOPMENT/PROD MODE`);
      console.log(`Local Access: http://localhost:${PORT}`);
      console.log(`Network Access: http://0.0.0.0:${PORT}`);
      console.log(`=========================================`);
    });
  } catch (error) {
    console.error('Failed to start backend server:', error);
    process.exit(1);
  }
};

// 10-Minute Self-Pinging Cron Job to prevent Render instance sleeping
const pingSelf = () => {
  const selfUrl = 'https://expense-tracker-backend-5pc1.onrender.com/';
  console.log(`[Cron Job] Pinging self at ${selfUrl} to stay warm...`);
  fetch(selfUrl)
    .then(res => console.log(`[Cron Job] Ping response: ${res.status}`))
    .catch(err => console.error(`[Cron Job] Ping failed:`, err.message));
};

// Ping every 10 minutes (600,000 milliseconds)
setInterval(pingSelf, 10 * 60 * 1000);

startServer();
