import express from 'express';
import bcrypt from 'bcryptjs';
import nodemailer from 'nodemailer';
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
    // Check if user already exists in main users table
    const userExist = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userExist.rows.length > 0) {
      return res.status(400).json({ error: 'User with this email already exists.' });
    }

    // Google Sign-In registration: Direct insertion as verified user
    if (google_id) {
      const newUser = await query(
        `INSERT INTO users (email, name, photo_url, google_id, is_verified)
         VALUES ($1, $2, $3, $4, TRUE)
         RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
        [email, name || 'Google User', photo_url || null, google_id]
      );
      const user = newUser.rows[0];
      const token = generateToken(user);
      return res.status(201).json({
        message: 'User registered successfully via Google.',
        token,
        user
      });
    }

    // Manual Email/Password registration
    if (!password) {
      return res.status(400).json({ error: 'Password is required for standard registration.' });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Clean up any stale registration attempts in temp_users
    await query('DELETE FROM temp_users WHERE email = $1', [email]);

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

    // Save registration details to temp_users table
    await query(
      `INSERT INTO temp_users (email, password_hash, name, photo_url, otp, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [email, passwordHash, name || 'User', photo_url || null, otp, expiresAt]
    );

    // Send verification mail
    try {
      await sendEmail(
        email,
        'Grow Expense - Verify Your Email Address',
        `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
            <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
            <p>Hi ${name || 'User'},</p>
            <p>Welcome to Grow Expense! Please verify your email address using the following One-Time Password (OTP) verification code:</p>
            <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
              ${otp}
            </div>
            <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
              This OTP is valid for <strong>15 minutes</strong>.
            </p>
          </div>
        `
      );
    } catch (mailErr) {
      console.error('Mail dispatch error on signup:', mailErr);
      // Delete from temp_users since mail failed
      await query('DELETE FROM temp_users WHERE email = $1', [email]);
      return res.status(500).json({ error: `Verification mail failed to send: ${mailErr.message}. Registration aborted.` });
    }

    return res.status(201).json({
      message: 'Registration initiated. Email verification required.',
      needsVerification: true,
      email
    });
  } catch (error) {
    console.error('Registration Error:', error);
    res.status(500).json({ error: `Server error during registration: ${error.message}` });
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
        // If not in main users, check if they exist in temp_users (started manual registration but didn't verify, now using Google)
        const tempUserRes = await query('SELECT * FROM temp_users WHERE email = $1', [email]);
        if (tempUserRes.rows.length > 0) {
          // Delete from temp_users
          await query('DELETE FROM temp_users WHERE email = $1', [email]);
        }

        // Create verified user on-the-fly for Google sign-in
        const newUser = await query(
          `INSERT INTO users (email, name, photo_url, google_id, is_verified)
           VALUES ($1, $2, $3, $4, TRUE)
           RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
          [email, name || 'Google User', photo_url || null, google_id]
        );
        user = newUser.rows[0];
      } else {
        user = userRes.rows[0];
        
        // Secure Link: Ensure google_id, is_verified, and profile updates are synced
        const updatedUser = await query(
          `UPDATE users 
           SET google_id = COALESCE(google_id, $1), 
               photo_url = COALESCE(photo_url, $2),
               name = COALESCE(name, $3),
               is_verified = TRUE,
               updated_at = NOW()
           WHERE id = $4
           RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
          [google_id, photo_url, name, user.id]
        );
        user = updatedUser.rows[0];
      }

      const token = generateToken(user);
      return res.status(200).json({ token, user });
    }

    // 2. Handle standard Email/Password Login
    // A. Check verified users first
    const userRes = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userRes.rows.length > 0) {
      const user = userRes.rows[0];
      if (!user.password_hash) {
        return res.status(400).json({ error: 'This email is linked to a Google account. Please use Google Login.' });
      }

      const isMatch = await bcrypt.compare(password, user.password_hash);
      if (!isMatch) {
        return res.status(400).json({ error: 'Invalid email or password.' });
      }

      const token = generateToken(user);
      return res.status(200).json({
        token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          photo_url: user.photo_url,
          google_id: user.google_id,
          gemini_api_key: user.gemini_api_key,
          gemini_api_key_secondary: user.gemini_api_key_secondary,
          created_at: user.created_at
        }
      });
    }

    // B. Check temp_users (unverified signups)
    const tempUserRes = await query('SELECT * FROM temp_users WHERE email = $1', [email]);
    if (tempUserRes.rows.length > 0) {
      const tempUser = tempUserRes.rows[0];
      const isMatch = await bcrypt.compare(password, tempUser.password_hash);
      if (!isMatch) {
        return res.status(400).json({ error: 'Invalid email or password.' });
      }

      // Generate a fresh OTP code
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

      await query(
        `UPDATE temp_users 
         SET otp = $1, expires_at = $2, failed_attempts = 0 
         WHERE email = $3`,
        [otp, expiresAt, email]
      );

      try {
        // Mail the code
        await sendEmail(
          email,
          'Grow Expense - Verify Your Email Address',
          `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
              <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
              <p>Hi ${tempUser.name || 'User'},</p>
              <p>Please verify your email address to complete your registration. Use the following One-Time Password (OTP) verification code:</p>
              <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
                ${otp}
              </div>
              <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
                This OTP is valid for <strong>15 minutes</strong>.
              </p>
            </div>
          `
        );
      } catch (mailErr) {
        console.error('Login Verification Mail Error:', mailErr);
        return res.status(500).json({ error: `Verification mail failed to send: ${mailErr.message}` });
      }

      return res.status(403).json({
        error: 'email_unverified',
        needsVerification: true,
        email
      });
    }

    // C. Not found in either
    return res.status(400).json({ error: 'Invalid email or password.' });
  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Server error during login.' });
  }
});

// 3. Get Current User Profile (authenticated)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const userRes = await query(
      'SELECT id, email, name, photo_url, google_id, gemini_api_key, gemini_api_key_secondary, created_at FROM users WHERE id = $1',
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
  const { name, photo_url, gemini_api_key, gemini_api_key_secondary } = req.body;

  try {
    const userExist = await query('SELECT * FROM users WHERE id = $1', [req.user.userId]);
    if (userExist.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }
    
    const userObj = userExist.rows[0];
    const newName = name !== undefined ? name : userObj.name;
    const newPhotoUrl = photo_url !== undefined ? photo_url : userObj.photo_url;
    const newGeminiKey = gemini_api_key !== undefined ? gemini_api_key : userObj.gemini_api_key;
    const newGeminiKeySecondary = gemini_api_key_secondary !== undefined ? gemini_api_key_secondary : userObj.gemini_api_key_secondary;

    const updated = await query(
      `UPDATE users 
       SET name = $1, 
           photo_url = $2,
           gemini_api_key = $3,
           gemini_api_key_secondary = $4,
           updated_at = NOW() 
       WHERE id = $5 
       RETURNING id, email, name, photo_url, google_id, gemini_api_key, gemini_api_key_secondary, created_at`,
      [newName, newPhotoUrl, newGeminiKey, newGeminiKeySecondary, req.user.userId]
    );

    res.status(200).json({
      message: 'Profile updated successfully.',
      user: updated.rows[0]
    });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ error: 'Server error updating profile.' });
  }
});

// Setup Mail Transporter for Gmail SMTP (optimized with connection pooling for speed)
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true, // Use SSL/TLS
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  pool: true, // Use connection pooling
  maxConnections: 3,
  maxMessages: 100,
});

// Unified Email Sender supporting Google Apps Script HTTP API and local SMTP fallback
const sendEmail = async (to, subject, html) => {
  const emailApiUrl = process.env.EMAIL_API_URL;
  if (emailApiUrl) {
    console.log(`[Email] Sending email to ${to} via HTTP API...`);
    const response = await fetch(emailApiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ to, subject, html }),
    });
    const data = await response.json();
    if (!data.success) {
      throw new Error(data.error || 'Failed to send email via Apps Script API');
    }
    console.log(`[Email] Email successfully sent to ${to} via HTTP API.`);
  } else {
    console.log(`[Email] Sending email to ${to} via SMTP...`);
    const mailOptions = {
      from: `"Grow Expense" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      html,
    };
    await transporter.sendMail(mailOptions);
    console.log(`[Email] Email successfully sent to ${to} via SMTP.`);
  }
};

// A. Forgot Password - Generate & Mail OTP
router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    // 1. Verify if user exists
    const userExist = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userExist.rows.length === 0) {
      return res.status(404).json({ error: 'User with this email does not exist.' });
    }

    // 2. Generate a 6-digit random code
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes expiration

    // 3. Clear any existing OTPs and write the new one
    await query('DELETE FROM password_resets WHERE email = $1', [email]);
    await query(
      'INSERT INTO password_resets (email, otp, expires_at) VALUES ($1, $2, $3)',
      [email, otp, expiresAt]
    );

    // 4. Send Email
    await sendEmail(
      email,
      'Grow Expense - Password Reset OTP Verification Code',
      `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
          <p>Hi,</p>
          <p>We received a request to reset your password. Please use the following One-Time Password (OTP) verification code to proceed with the reset process:</p>
          <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
            ${otp}
          </div>
          <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
            This OTP is valid for <strong>15 minutes</strong>. If you did not request this password reset, you can safely ignore this email.
          </p>
        </div>
      `
    );
    res.status(200).json({ message: 'OTP sent to email successfully.' });
  } catch (error) {
    console.error('Forgot Password error:', error);
    res.status(500).json({ error: 'Server error processing forgot password request.' });
  }
});

// B. Verify OTP
router.post('/verify-otp', async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ error: 'Email and OTP are required.' });
  }

  try {
    const otpRes = await query(
      'SELECT * FROM password_resets WHERE email = $1 AND expires_at > CURRENT_TIMESTAMP',
      [email]
    );

    if (otpRes.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired OTP verification code.' });
    }

    const resetRecord = otpRes.rows[0];
    if (resetRecord.otp !== otp) {
      const attempts = (resetRecord.failed_attempts || 0) + 1;
      if (attempts >= 5) {
        await query('DELETE FROM password_resets WHERE email = $1', [email]);
        return res.status(400).json({ error: 'Too many incorrect OTP attempts. This code has been invalidated. Please request a new code.' });
      } else {
        await query('UPDATE password_resets SET failed_attempts = failed_attempts + 1 WHERE email = $1', [email]);
        return res.status(400).json({ error: `Invalid OTP code. You have ${5 - attempts} attempts remaining before it is invalidated.` });
      }
    }

    res.status(200).json({ message: 'OTP verified successfully.' });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ error: 'Server error verifying OTP code.' });
  }
});

// C. Reset Password
router.post('/reset-password', async (req, res) => {
  const { email, otp, new_password } = req.body;
  if (!email || !otp || !new_password) {
    return res.status(400).json({ error: 'Email, OTP, and new password are required.' });
  }

  try {
    // 1. Verify OTP remains valid
    const otpRes = await query(
      'SELECT * FROM password_resets WHERE email = $1 AND expires_at > CURRENT_TIMESTAMP',
      [email]
    );

    if (otpRes.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired OTP verification code.' });
    }

    const resetRecord = otpRes.rows[0];
    if (resetRecord.otp !== otp) {
      const attempts = (resetRecord.failed_attempts || 0) + 1;
      if (attempts >= 5) {
        await query('DELETE FROM password_resets WHERE email = $1', [email]);
        return res.status(400).json({ error: 'Too many incorrect OTP attempts. This code has been invalidated. Please request a new code.' });
      } else {
        await query('UPDATE password_resets SET failed_attempts = failed_attempts + 1 WHERE email = $1', [email]);
        return res.status(400).json({ error: `Invalid OTP code. You have ${5 - attempts} attempts remaining before it is invalidated.` });
      }
    }

    // 2. Hash new password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(new_password, salt);

    // 3. Update user database and clear OTP
    await query('UPDATE users SET password_hash = $1 WHERE email = $2', [passwordHash, email]);
    await query('DELETE FROM password_resets WHERE email = $1', [email]);

    res.status(200).json({ message: 'Password reset completed successfully.' });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(500).json({ error: 'Server error resetting password.' });
  }
});

// D. Verify Signup Email
router.post('/verify-signup', async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ error: 'Email and OTP are required.' });
  }

  try {
    const otpRes = await query(
      'SELECT * FROM temp_users WHERE email = $1 AND expires_at > CURRENT_TIMESTAMP',
      [email]
    );

    if (otpRes.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired OTP verification code.' });
    }

    const tempUser = otpRes.rows[0];
    if (tempUser.otp !== otp) {
      const attempts = (tempUser.failed_attempts || 0) + 1;
      if (attempts >= 5) {
        await query('DELETE FROM temp_users WHERE email = $1', [email]);
        return res.status(400).json({ error: 'Too many incorrect OTP attempts. Registration has been reset. Please sign up again.' });
      } else {
        await query('UPDATE temp_users SET failed_attempts = failed_attempts + 1 WHERE email = $1', [email]);
        return res.status(400).json({ error: `Invalid OTP code. You have ${5 - attempts} attempts remaining before registration is reset.` });
      }
    }

    // OTP matches! Create user in main users table
    const newUser = await query(
      `INSERT INTO users (email, password_hash, name, photo_url, is_verified)
       VALUES ($1, $2, $3, $4, TRUE)
       RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
      [tempUser.email, tempUser.password_hash, tempUser.name, tempUser.photo_url]
    );

    const user = newUser.rows[0];

    // Delete from temp_users since verification succeeded
    await query('DELETE FROM temp_users WHERE email = $1', [email]);

    const token = generateToken(user);

    res.status(200).json({
      message: 'Email verified successfully. Account activated.',
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        photo_url: user.photo_url,
        google_id: user.google_id,
        gemini_api_key: user.gemini_api_key,
        gemini_api_key_secondary: user.gemini_api_key_secondary,
        created_at: user.created_at
      }
    });
  } catch (error) {
    console.error('Verify signup error:', error);
    res.status(500).json({ error: 'Server error verifying email code.' });
  }
});

// E. Resend Signup Verification OTP
router.post('/resend-verification', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    // Check if email already verified in users
    const userRes = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userRes.rows.length > 0) {
      return res.status(400).json({ error: 'Email is already verified.' });
    }

    const tempUserRes = await query('SELECT * FROM temp_users WHERE email = $1', [email]);
    if (tempUserRes.rows.length === 0) {
      return res.status(404).json({ error: 'No active signup found for this email. Please sign up first.' });
    }

    const tempUser = tempUserRes.rows[0];

    // Generate a new 6-digit verification code
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

    await query(
      `UPDATE temp_users 
       SET otp = $1, expires_at = $2, failed_attempts = 0 
       WHERE email = $3`,
      [otp, expiresAt, email]
    );

    // Send verification mail
    await sendEmail(
      email,
      'Grow Expense - Verify Your Email Address',
      `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
          <p>Hi ${tempUser.name || 'User'},</p>
          <p>Please verify your email address to complete your registration. Use the following One-Time Password (OTP) verification code:</p>
          <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
            ${otp}
          </div>
          <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
            This OTP is valid for <strong>15 minutes</strong>.
          </p>
        </div>
      `
    );

    res.status(200).json({ message: 'Verification OTP resent successfully.' });
  } catch (error) {
    console.error('Resend verification error:', error);
    res.status(500).json({ error: 'Server error resending verification code.' });
  }
});

export default router;
