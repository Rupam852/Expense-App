import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
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

// Health check endpoint
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'online',
    message: 'Secure Offline-First Expense Tracker Backend running successfully.',
    time: new Date().toISOString()
  });
});

// Register API Routes
app.use('/auth', authRoutes);
app.use('/expenses', expenseRoutes);
app.use('/analytics', analyticsRoutes);
app.use('/invoices', invoiceRoutes);

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

startServer();
