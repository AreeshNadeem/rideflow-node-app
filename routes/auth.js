const express = require('express');
const router = express.Router();
const db = require('../db');

// ── GET / (login page) ────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  if (req.session.user) return res.redirect(`/${req.session.user.role}`);
  res.render('login');
});

// ── POST /login ───────────────────────────────────────────────────────────────
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const [rows] = await db.query(
      "SELECT * FROM users WHERE email = ? AND account_status = 'active' LIMIT 1",
      [email]
    );
    if (!rows.length) {
      req.session.flash = { type: 'danger', message: 'Invalid email or inactive account.' };
      return res.redirect('/');
    }
    const user = rows[0];
    // Supports: plain password stored as-is (new registrations) OR legacy "password123hash" format
    const ok = password === user.password_hash || `${password}hash` === user.password_hash;
    if (!ok) {
      req.session.flash = { type: 'danger', message: 'Invalid password.' };
      return res.redirect('/');
    }
    req.session.user = {
      user_id: user.user_id,
      name: `${user.first_name} ${user.last_name}`,
      email: user.email,
      role: user.role
    };
    res.redirect(`/${user.role}`);
  } catch (err) { next(err); }
});

// ── GET /register ─────────────────────────────────────────────────────────────
router.get('/register', (req, res) => {
  if (req.session.user) return res.redirect(`/${req.session.user.role}`);
  res.render('register');
});

// ── POST /register ────────────────────────────────────────────────────────────
router.post('/register', async (req, res, next) => {
  try {
    const {
      role, first_name, last_name, email, phone, password, confirm_password,
      // driver-only fields
      license_no, national_id,
      // vehicle fields
      make, model, manufacture_year, color, vehicle_type, license_plate
    } = req.body;

    // ── Basic validation ────────────────────────────────────────────────────
    if (!['rider', 'driver'].includes(role)) {
      req.session.flash = { type: 'danger', message: 'Invalid role selected.' };
      return res.redirect('/register');
    }

    if (!first_name || !last_name || !email || !phone || !password) {
      req.session.flash = { type: 'danger', message: 'All fields are required.' };
      return res.redirect(`/register?role=${role}`);
    }

    if (password !== confirm_password) {
      req.session.flash = { type: 'danger', message: 'Passwords do not match.' };
      return res.redirect(`/register?role=${role}`);
    }

    if (password.length < 6) {
      req.session.flash = { type: 'danger', message: 'Password must be at least 6 characters.' };
      return res.redirect(`/register?role=${role}`);
    }

    // ── Check for duplicate email / phone ───────────────────────────────────
    const [existing] = await db.query(
      'SELECT user_id FROM users WHERE email = ? OR phone = ? LIMIT 1',
      [email, phone]
    );
    if (existing.length) {
      req.session.flash = { type: 'danger', message: 'An account with that email or phone already exists.' };
      return res.redirect(`/register?role=${role}`);
    }

    // ── Driver-specific field validation ────────────────────────────────────
    if (role === 'driver') {
      if (!license_no || !national_id || !make || !model || !manufacture_year || !color || !vehicle_type || !license_plate) {
        req.session.flash = { type: 'danger', message: 'All driver and vehicle fields are required.' };
        return res.redirect('/register?role=driver');
      }

      const [dupDriver] = await db.query(
        'SELECT driver_id FROM drivers WHERE license_no = ? OR national_id = ? LIMIT 1',
        [license_no, national_id]
      );
      if (dupDriver.length) {
        req.session.flash = { type: 'danger', message: 'A driver with that license number or CNIC already exists.' };
        return res.redirect('/register?role=driver');
      }

      const [dupPlate] = await db.query(
        'SELECT vehicle_id FROM vehicles WHERE license_plate = ? LIMIT 1',
        [license_plate]
      );
      if (dupPlate.length) {
        req.session.flash = { type: 'danger', message: 'That vehicle license plate is already registered.' };
        return res.redirect('/register?role=driver');
      }
    }

    // ── Insert user ─────────────────────────────────────────────────────────
    // Store password as plain text for demo (consistent with existing login check)
    const [userResult] = await db.query(
      `INSERT INTO users (first_name, last_name, email, phone, password_hash, role, account_status)
       VALUES (?, ?, ?, ?, ?, ?, 'active')`,
      [first_name.trim(), last_name.trim(), email.trim().toLowerCase(), phone.trim(), password, role]
    );
    const newUserId = userResult.insertId;

    // ── Create wallet for all users ─────────────────────────────────────────
    await db.query(
      'INSERT INTO wallets (user_id, balance) VALUES (?, 0.00)',
      [newUserId]
    );

    // ── Driver-specific inserts ─────────────────────────────────────────────
    if (role === 'driver') {
      await db.query(
        `INSERT INTO drivers (driver_id, license_no, national_id, verification_status, availability_status)
         VALUES (?, ?, ?, 'pending', 'offline')`,
        [newUserId, license_no.trim(), national_id.trim()]
      );

      await db.query(
        `INSERT INTO vehicles (driver_id, make, model, manufacture_year, color, license_plate, vehicle_type, verification_status)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')`,
        [newUserId, make.trim(), model.trim(), manufacture_year, color.trim(), license_plate.trim().toUpperCase(), vehicle_type]
      );

      req.session.flash = {
        type: 'success',
        message: 'Driver account created! Your profile is pending admin verification. You can log in and check your status.'
      };
    } else {
      req.session.flash = {
        type: 'success',
        message: 'Rider account created successfully! You can now log in.'
      };
    }

    res.redirect('/');
  } catch (err) { next(err); }
});

// ── POST /logout ──────────────────────────────────────────────────────────────
router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/'));
});

module.exports = router;
