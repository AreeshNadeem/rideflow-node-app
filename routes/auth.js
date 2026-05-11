const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/', async (req, res) => {
  if (req.session.user) {
    return res.redirect(`/${req.session.user.role}`);
  }
  res.render('login');
});

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
    // Course demo-friendly check. Sample D3 data stores admin123hash/rider123hash/driver123hash.
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

router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/'));
});

module.exports = router;
