const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireRole } = require('./middleware');

router.use(requireRole('rider'));

router.get('/', async (req, res, next) => {
  try {
    const riderId = req.session.user.user_id;
    const [[wallet]] = await db.query('SELECT balance FROM wallets WHERE user_id = ?', [riderId]);
    const [locations] = await db.query('SELECT * FROM locations ORDER BY city, label');
    const [rides] = await db.query(`
      SELECT r.*, p.label AS pickup_label, p.city AS pickup_city, d.label AS dropoff_label, d.city AS dropoff_city,
             CONCAT(du.first_name, ' ', du.last_name) AS driver_name,
             pay.payment_status, pay.amount AS paid_amount
      FROM rides r
      JOIN locations p ON r.pickup_location_id = p.location_id
      JOIN locations d ON r.dropoff_location_id = d.location_id
      LEFT JOIN users du ON r.driver_id = du.user_id
      LEFT JOIN payments pay ON r.ride_id = pay.ride_id
      WHERE r.rider_id = ?
      ORDER BY r.request_time DESC`, [riderId]);
    const [promos] = await db.query("SELECT code, discount_type, discount_value FROM promo_codes WHERE status='active' AND expiry_date >= CURDATE() AND times_used < usage_limit ORDER BY code");
    res.render('rider', { wallet, locations, rides, promos });
  } catch (err) { next(err); }
});

router.post('/book', async (req, res, next) => {
  try {
    const { pickup_location_id, dropoff_location_id, scheduled_time } = req.body;
    if (pickup_location_id === dropoff_location_id) {
      req.session.flash = { type: 'danger', message: 'Pickup and dropoff cannot be the same.' };
      return res.redirect('/rider');
    }
    const schedule = scheduled_time ? scheduled_time.replace('T', ' ') + ':00' : null;
    await db.query('CALL RequestRide(?, ?, ?, ?)', [req.session.user.user_id, pickup_location_id, dropoff_location_id, schedule]);
    req.session.flash = { type: 'success', message: 'Ride requested successfully.' };
    res.redirect('/rider');
  } catch (err) { next(err); }
});

router.post('/cancel/:rideId', async (req, res, next) => {
  try {
    await db.query("UPDATE rides SET ride_status='cancelled' WHERE ride_id=? AND rider_id=? AND ride_status IN ('requested','accepted')", [req.params.rideId, req.session.user.user_id]);
    req.session.flash = { type: 'success', message: 'Ride cancelled if it was eligible.' };
    res.redirect('/rider');
  } catch (err) { next(err); }
});

router.post('/rate', async (req, res, next) => {
  try {
    const { ride_id, rated_user_id, score, comment_text } = req.body;
    await db.query(`INSERT INTO ratings (ride_id, rated_by_user_id, rated_user_id, score, comment_text)
                    VALUES (?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE score=VALUES(score), comment_text=VALUES(comment_text), rating_timestamp=NOW()`,
                    [ride_id, req.session.user.user_id, rated_user_id, score, comment_text || null]);
    req.session.flash = { type: 'success', message: 'Rating submitted.' };
    res.redirect('/rider');
  } catch (err) { next(err); }
});


router.post('/wallet-topup', async (req, res, next) => {
  try {
    const amount = Number(req.body.amount || 0);
    if (amount <= 0) {
      req.session.flash = { type: 'danger', message: 'Enter a valid wallet top-up amount.' };
      return res.redirect('/rider');
    }
    await db.query('INSERT INTO wallets (user_id, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)', [req.session.user.user_id, amount]);
    req.session.flash = { type: 'success', message: 'Wallet balance updated.' };
    res.redirect('/rider');
  } catch (err) { next(err); }
});

router.post('/pay', async (req, res, next) => {
  try {
    const { ride_id, payment_method, promo_code } = req.body;
    const riderId = req.session.user.user_id;

    // Verify this ride belongs to this rider and is awaiting payment
    const [[ride]] = await db.query(
      "SELECT * FROM rides WHERE ride_id = ? AND rider_id = ? AND ride_status = 'payment_pending'",
      [ride_id, riderId]
    );
    if (!ride) {
      req.session.flash = { type: 'danger', message: 'Ride not found or not eligible for payment.' };
      return res.redirect('/rider');
    }

    let finalAmount = Number(ride.fare);
    let promoId = null;
    let promoDiscount = 0.00;

    // Apply promo code discount if provided
    if (promo_code && promo_code.trim()) {
      const [[promo]] = await db.query(
        "SELECT * FROM promo_codes WHERE code = ? AND status = 'active' AND expiry_date >= CURDATE() AND times_used < usage_limit",
        [promo_code.trim()]
      );
      if (promo) {
        promoId = promo.promo_code_id;
        if (promo.discount_type === 'percentage') {
          promoDiscount = Math.round(finalAmount * promo.discount_value / 100 * 100) / 100;
        } else {
          promoDiscount = Number(promo.discount_value);
        }
        promoDiscount = Math.min(promoDiscount, finalAmount);
        finalAmount = Math.round((finalAmount - promoDiscount) * 100) / 100;
      } else {
        req.session.flash = { type: 'warning', message: 'Promo code is invalid or expired. Payment processed without discount.' };
      }
    }

    // Wallet balance check — friendly error on rider's own page
    if (payment_method === 'wallet') {
      const [[wallet]] = await db.query(
        'SELECT COALESCE(balance, 0.00) AS balance FROM wallets WHERE user_id = ?', [riderId]
      );
      const balance = wallet ? Number(wallet.balance) : 0;
      if (balance < finalAmount) {
        req.session.flash = {
          type: 'danger',
          message: `Insufficient wallet balance. Fare: PKR ${finalAmount.toFixed(2)}, Your balance: PKR ${balance.toFixed(2)}. Please top up or choose another method.`
        };
        return res.redirect('/rider');
      }
    }

    // Insert payment as 'paid' — the after-insert trigger handles:
    //   ride → completed, rider wallet deduction, driver earnings & wallet, ride_history
    await db.query(
      `INSERT INTO payments (ride_id, promo_code_id, amount, payment_method, payment_status, promo_discount_applied)
       VALUES (?, ?, ?, ?, 'paid', ?)`,
      [ride_id, promoId, finalAmount, payment_method, promoDiscount]
    );

    req.session.flash = { type: 'success', message: `Payment of PKR ${finalAmount.toFixed(2)} confirmed. Ride completed!` };
    res.redirect('/rider');
  } catch (err) { next(err); }
});

router.post('/complaint', async (req, res, next) => {
  try {
    const { ride_id, reported_against_user_id, complaint_type, description } = req.body;
    await db.query(`INSERT INTO complaints (ride_id, filed_by_user_id, reported_against_user_id, complaint_type, description)
                    VALUES (?, ?, ?, ?, ?)`, [ride_id || null, req.session.user.user_id, reported_against_user_id || null, complaint_type, description]);
    req.session.flash = { type: 'success', message: 'Complaint submitted to admin.' };
    res.redirect('/rider');
  } catch (err) { next(err); }
});

module.exports = router;

