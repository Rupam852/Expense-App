import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

// Generate JWT Helper
const generateToken = (user) => {
  return jwt.sign(
    { userId: user.id, email: user.email, name: user.name },
    process.env.JWT_SECRET || 'fallback_secret',
    { expiresIn: '30d' } // Secure 30-day token for offline sync stability
  );
};

// 1. Register Route
router.post('/register', async (req, res) => {
  const { email, password, name, photo_url, google_id } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    // Check if user already exists
    const userExist = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userExist.rows.length > 0) {
      return res.status(400).json({ error: 'User with this email already exists.' });
    }

    let passwordHash = null;
    if (password) {
      const salt = await bcrypt.genSalt(10);
      passwordHash = await bcrypt.hash(password, salt);
    }

    // Insert user
    const newUser = await query(
      `INSERT INTO users (email, password_hash, name, photo_url, google_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, name, photo_url, google_id, created_at`,
      [email, passwordHash, name || 'User', photo_url || null, google_id || null]
    );

    const user = newUser.rows[0];
    const token = generateToken(user);

    res.status(201).json({
      message: 'User registered successfully.',
      token,
      user
    });
  } catch (error) {
    console.error('Registration Error:', error);
    res.status(500).json({ error: 'Server error during registration.' });
  }
});

// 2. Login Route (supports Email/Password and Google sign-in fallback)
router.post('/login', async (req, res) => {
  const { email, password, google_id, name, photo_url } = req.body;

  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    // 1. Handle Google Login / Sync
    if (google_id) {
      let userRes = await query('SELECT * FROM users WHERE google_id = $1 OR email = $2', [google_id, email]);
      
      let user;
      if (userRes.rows.length === 0) {
        // Create user on-the-fly for Google sign-in
        const newUser = await query(
          `INSERT INTO users (email, name, photo_url, google_id)
           VALUES ($1, $2, $3, $4)
           RETURNING id, email, name, photo_url, google_id, created_at`,
          [email, name || 'Google User', photo_url || null, google_id]
        );
        user = newUser.rows[0];
      } else {
        user = userRes.rows[0];
        // Ensure google_id and profile updates are synced
        if (!user.google_id || (photo_url && user.photo_url !== photo_url)) {
          const updatedUser = await query(
            `UPDATE users 
             SET google_id = COALESCE(google_id, $1), 
                 photo_url = COALESCE(photo_url, $2),
                 name = COALESCE(name, $3),
                 updated_at = NOW()
             WHERE id = $4
             RETURNING id, email, name, photo_url, google_id, created_at`,
            [google_id, photo_url, name, user.id]
          );
          user = updatedUser.rows[0];
        }
      }

      const token = generateToken(user);
      return res.status(200).json({ token, user });
    }

    // 2. Handle standard Email/Password Login
    const userRes = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userRes.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    const user = userRes.rows[0];
    if (!user.password_hash) {
      return res.status(400).json({ error: 'This email is linked to a Google account. Please use Google Login.' });
    }

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    const token = generateToken(user);
    res.status(200).json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        photo_url: user.photo_url,
        google_id: user.google_id,
        created_at: user.created_at
      }
    });
  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Server error during login.' });
  }
});

// 3. Get Current User Profile (authenticated)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const userRes = await query(
      'SELECT id, email, name, photo_url, google_id, created_at FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    res.status(200).json(userRes.rows[0]);
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ error: 'Server error fetching profile.' });
  }
});

// 4. Update Profile Route
router.put('/profile', authenticateToken, async (req, res) => {
  const { name, photo_url } = req.body;

  try {
    const updated = await query(
      `UPDATE users 
       SET name = COALESCE($1, name), 
           photo_url = COALESCE($2, photo_url),
           updated_at = NOW() 
       WHERE id = $3 
       RETURNING id, email, name, photo_url, google_id, created_at`,
      [name, photo_url, req.user.userId]
    );

    if (updated.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    res.status(200).json({
      message: 'Profile updated successfully.',
      user: updated.rows[0]
    });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ error: 'Server error updating profile.' });
  }
});

export default router;
