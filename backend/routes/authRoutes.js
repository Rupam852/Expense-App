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

    const isVerified = google_id ? true : false;

    // Insert user
    const newUser = await query(
      `INSERT INTO users (email, password_hash, name, photo_url, google_id, is_verified)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
      [email, passwordHash, name || 'User', photo_url || null, google_id || null, isVerified]
    );

    const user = newUser.rows[0];

    if (!isVerified) {
      try {
        // Generate a 6-digit OTP code
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

        await query('DELETE FROM password_resets WHERE email = $1', [email]);
        await query(
          'INSERT INTO password_resets (email, otp, expires_at) VALUES ($1, $2, $3)',
          [email, otp, expiresAt]
        );

        // Send verification mail
        const mailOptions = {
          from: `"Grow Expense" <${process.env.EMAIL_USER}>`,
          to: email,
          subject: 'Grow Expense - Verify Your Email Address',
          html: `
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
          `,
        };
        await transporter.sendMail(mailOptions);
      } catch (mailErr) {
        console.error('Registration Mail Error, rolling back user registration:', mailErr);
        // Rollback user creation to prevent orphaned unverified user
        await query('DELETE FROM users WHERE id = $1', [user.id]);
        await query('DELETE FROM password_resets WHERE email = $1', [email]);
        return res.status(500).json({ error: `Verification mail failed to send: ${mailErr.message}. Registration aborted.` });
      }

      return res.status(201).json({
        message: 'Registration successful. Email verification required.',
        needsVerification: true,
        email
      });
    }

    const token = generateToken(user);
    res.status(201).json({
      message: 'User registered successfully.',
      token,
      user
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
        // Create user on-the-fly for Google sign-in
        const newUser = await query(
          `INSERT INTO users (email, name, photo_url, google_id, is_verified)
           VALUES ($1, $2, $3, $4, TRUE)
           RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
          [email, name || 'Google User', photo_url || null, google_id]
        );
        user = newUser.rows[0];
      } else {
        user = userRes.rows[0];
        
        // SECURITY FIX: If the existing account has not been verified (created manually but never validated),
        // we must delete it to prevent "Unverified Email Account Takeover".
        if (!user.is_verified) {
          await query('DELETE FROM users WHERE id = $1', [user.id]);
          
          // Re-create the user fresh and verified via Google
          const newUser = await query(
            `INSERT INTO users (email, name, photo_url, google_id, is_verified)
             VALUES ($1, $2, $3, $4, TRUE)
             RETURNING id, email, name, photo_url, google_id, is_verified, gemini_api_key, gemini_api_key_secondary, created_at`,
            [email, name || 'Google User', photo_url || null, google_id]
          );
          user = newUser.rows[0];
        } else {
          // If the account was already verified, we link Google login securely.
          // Ensure google_id, is_verified, and profile updates are synced
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

    // Check if user is verified
    if (!user.is_verified) {
      try {
        // Generate a 6-digit verification code
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

        await query('DELETE FROM password_resets WHERE email = $1', [email]);
        await query(
          'INSERT INTO password_resets (email, otp, expires_at) VALUES ($1, $2, $3)',
          [email, otp, expiresAt]
        );

        // Mail the code
        const mailOptions = {
          from: `"Grow Expense" <${process.env.EMAIL_USER}>`,
          to: email,
          subject: 'Grow Expense - Verify Your Email Address',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
              <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
              <p>Hi ${user.name || 'User'},</p>
              <p>Please verify your email address to complete your login. Use the following One-Time Password (OTP) verification code:</p>
              <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
                ${otp}
              </div>
              <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
                This OTP is valid for <strong>15 minutes</strong>.
              </p>
            </div>
          `,
        };
        await transporter.sendMail(mailOptions);
      } catch (mailErr) {
        console.error('Login Verification Mail Error:', mailErr);
        return res.status(500).json({ error: `Failed to send verification email: ${mailErr.message}` });
      }

      return res.status(403).json({
        error: 'email_unverified',
        needsVerification: true,
        email
      });
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
        gemini_api_key: user.gemini_api_key,
        gemini_api_key_secondary: user.gemini_api_key_secondary,
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

// Setup Mail Transporter for Gmail SMTP
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

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
    const mailOptions = {
      from: `"Grow Expense" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: 'Grow Expense - Password Reset OTP Verification Code',
      html: `
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
      `,
    };

    await transporter.sendMail(mailOptions);
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

    // OTP matches! Update user status to verified
    await query('UPDATE users SET is_verified = TRUE WHERE email = $1', [email]);
    await query('DELETE FROM password_resets WHERE email = $1', [email]);

    // Fetch updated user to generate token
    const userRes = await query('SELECT * FROM users WHERE email = $1', [email]);
    const user = userRes.rows[0];
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
    const userRes = await query('SELECT * FROM users WHERE email = $1', [email]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const user = userRes.rows[0];
    if (user.is_verified) {
      return res.status(400).json({ error: 'Email is already verified.' });
    }

    // Generate a 6-digit verification code
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 mins expiry

    await query('DELETE FROM password_resets WHERE email = $1', [email]);
    await query(
      'INSERT INTO password_resets (email, otp, expires_at) VALUES ($1, $2, $3)',
      [email, otp, expiresAt]
    );

    // Send verification mail
    const mailOptions = {
      from: `"Grow Expense" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: 'Grow Expense - Verify Your Email Address',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #00D09C; text-align: center;">Grow Expense</h2>
          <p>Hi ${user.name || 'User'},</p>
          <p>Please verify your email address to complete your registration. Use the following One-Time Password (OTP) verification code:</p>
          <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 5px; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">
            ${otp}
          </div>
          <p style="color: #666; font-size: 13px; text-align: center; margin-top: 20px;">
            This OTP is valid for <strong>15 minutes</strong>.
          </p>
        </div>
      `,
    };
    await transporter.sendMail(mailOptions);

    res.status(200).json({ message: 'Verification OTP resent successfully.' });
  } catch (error) {
    console.error('Resend verification error:', error);
    res.status(500).json({ error: 'Server error resending verification code.' });
  }
});

export default router;
