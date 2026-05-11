const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireRole } = require('./middleware');

router.use(requireRole('admin'));

router.get('/', async (req, res, next) => {
  try {
    const [[usersCount]] = await db.query('SELECT COUNT(*) AS count FROM users');
    const [[ridesCount]] = await db.query('SELECT COUNT(*) AS count FROM rides');
    const [[revenue]] = await db.query("SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE payment_status='paid'");
    const [[driversCount]] = await db.query('SELECT COUNT(*) AS count FROM drivers');
    const [[openComplaints]] = await db.query("SELECT COUNT(*) AS count FROM complaints WHERE status IN ('open','in_review')");

    const [revenueByCity] = await db.query('SELECT city, SUM(total_revenue) AS total_revenue FROM RevenueByCityView GROUP BY city ORDER BY total_revenue DESC');
    const [topDrivers] = await db.query('SELECT * FROM DriverLeaderboardView LIMIT 10');
    const [activeRides] = await db.query('SELECT * FROM ActiveRidesView ORDER BY request_time DESC');
    const [notifications] = await db.query('SELECT * FROM admin_notifications ORDER BY created_at DESC LIMIT 10');
    const [users] = await db.query('SELECT user_id, first_name, last_name, email, role, account_status FROM users ORDER BY user_id');
    const [vehicles] = await db.query(`SELECT v.*, CONCAT(u.first_name,' ',u.last_name) AS driver_name FROM vehicles v JOIN users u ON v.driver_id=u.user_id ORDER BY v.vehicle_id`);
    const [pricing] = await db.query('SELECT * FROM pricing_rules ORDER BY city, vehicle_type');
    const [paymentBreakdown] = await db.query("SELECT payment_method, COUNT(*) AS total_payments, COALESCE(SUM(amount),0) AS total_amount FROM payments GROUP BY payment_method ORDER BY total_amount DESC");
    const [rideStatusBreakdown] = await db.query('SELECT ride_status, COUNT(*) AS total FROM rides GROUP BY ride_status ORDER BY total DESC');
    const [complaints] = await db.query(`SELECT c.*, CONCAT(f.first_name,' ',f.last_name) AS filed_by_name, CONCAT(r.first_name,' ',r.last_name) AS reported_name
                                        FROM complaints c
                                        JOIN users f ON c.filed_by_user_id=f.user_id
                                        LEFT JOIN users r ON c.reported_against_user_id=r.user_id
                                        ORDER BY c.created_at DESC LIMIT 20`);

    const [payouts] = await db.query(`
      SELECT dp.*, CONCAT(u.first_name,' ',u.last_name) AS driver_name
      FROM driver_payouts dp
      JOIN users u ON dp.driver_id = u.user_id
      ORDER BY dp.requested_at DESC LIMIT 20`);
    const [ratings] = await db.query(`
      SELECT rt.*, 
             CONCAT(rb.first_name,' ',rb.last_name) AS rated_by_name,
             CONCAT(ru.first_name,' ',ru.last_name) AS rated_user_name
      FROM ratings rt
      JOIN users rb ON rt.rated_by_user_id = rb.user_id
      JOIN users ru ON rt.rated_user_id    = ru.user_id
      ORDER BY rt.rating_timestamp DESC LIMIT 30`);

    res.render('admin', {
      stats: { usersCount, ridesCount, revenue, driversCount, openComplaints },
      revenueByCity, topDrivers, activeRides, notifications, users, vehicles, pricing,
      paymentBreakdown, rideStatusBreakdown, complaints, payouts, ratings
    });
  } catch (err) { next(err); }
});

router.post('/user-status', async (req, res, next) => {
  try {
    await db.query('UPDATE users SET account_status=? WHERE user_id=?', [req.body.account_status, req.body.user_id]);
    req.session.flash = { type: 'success', message: 'User status updated.' };
    res.redirect('/admin');
  } catch (err) { next(err); }
});

router.post('/vehicle-status', async (req, res, next) => {
  try {
    await db.query('UPDATE vehicles SET verification_status=? WHERE vehicle_id=?', [req.body.verification_status, req.body.vehicle_id]);
    req.session.flash = { type: 'success', message: 'Vehicle verification updated.' };
    res.redirect('/admin');
  } catch (err) { next(err); }
});

router.post('/pricing', async (req, res, next) => {
  try {
    const { pricing_rule_id, base_rate, per_km_rate, per_minute_rate, surge_multiplier } = req.body;
    await db.query(`UPDATE pricing_rules SET base_rate=?, per_km_rate=?, per_minute_rate=?, surge_multiplier=? WHERE pricing_rule_id=?`,
      [base_rate, per_km_rate, per_minute_rate, surge_multiplier, pricing_rule_id]);
    req.session.flash = { type: 'success', message: 'Pricing rule updated.' };
    res.redirect('/admin');
  } catch (err) { next(err); }
});

router.post('/complaint-status', async (req, res, next) => {
  try {
    const resolvedAt = req.body.status === 'resolved' ? new Date() : null;
    await db.query('UPDATE complaints SET status=?, admin_action=?, resolved_at=? WHERE complaint_id=?',
      [req.body.status, req.body.admin_action || null, resolvedAt, req.body.complaint_id]);
    req.session.flash = { type: 'success', message: 'Complaint updated.' };
    res.redirect('/admin');
  } catch (err) { next(err); }
});

module.exports = router;
