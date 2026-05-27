const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireRole } = require('./middleware');

router.use(requireRole('admin'));

// ── GET / ─────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    // Stat cards
    const [[usersCount]]      = await db.query('SELECT COUNT(*) AS count FROM users');
    const [[ridesCount]]      = await db.query('SELECT COUNT(*) AS count FROM rides');
    const [[revenue]]         = await db.query("SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE payment_status='paid'");
    const [[driversCount]]    = await db.query('SELECT COUNT(*) AS count FROM drivers');
    const [[openComplaints]]  = await db.query("SELECT COUNT(*) AS count FROM complaints WHERE status IN ('open','in_review')");
    const [[pendingDrivers]]  = await db.query("SELECT COUNT(*) AS count FROM drivers WHERE verification_status='pending'");
    const [[refundTotal]]     = await db.query("SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE payment_status='refunded'");

    // Financial reports
    const [revenueByCity]     = await db.query('SELECT city, SUM(total_revenue) AS total_revenue FROM RevenueByCityView GROUP BY city ORDER BY total_revenue DESC');
    const [paymentBreakdown]  = await db.query("SELECT payment_method, COUNT(*) AS total_payments, COALESCE(SUM(amount),0) AS total_amount FROM payments GROUP BY payment_method ORDER BY total_amount DESC");
    const [rideStatusBreakdown] = await db.query('SELECT ride_status, COUNT(*) AS total FROM rides GROUP BY ride_status ORDER BY total DESC');

    // Driver earnings & commissions
    const [driverEarnings]    = await db.query(`
      SELECT de.driver_id, CONCAT(u.first_name,' ',u.last_name) AS driver_name,
             COUNT(de.earning_id) AS total_rides,
             COALESCE(SUM(de.gross_fare),0) AS total_gross,
             COALESCE(SUM(de.commission_amount),0) AS total_commission,
             COALESCE(SUM(de.net_earning),0) AS total_net
      FROM driver_earnings de
      JOIN users u ON de.driver_id = u.user_id
      GROUP BY de.driver_id, driver_name
      ORDER BY total_gross DESC`);

    const [[commissionTotal]] = await db.query('SELECT COALESCE(SUM(commission_amount),0) AS total FROM driver_earnings');

    // Refund & dispute details
    const [refundList]        = await db.query(`
      SELECT p.payment_id, p.ride_id, p.amount, p.payment_method, p.transaction_date,
             CONCAT(u.first_name,' ',u.last_name) AS rider_name
      FROM payments p
      JOIN rides r ON p.ride_id = r.ride_id
      JOIN users u ON r.rider_id = u.user_id
      WHERE p.payment_status = 'refunded'
      ORDER BY p.transaction_date DESC LIMIT 20`);

    // Pending drivers needing verification
    const [pendingDriverList] = await db.query(`
      SELECT d.driver_id, d.license_no, d.national_id, d.verification_status,
             d.flagged_for_review, d.flag_reason,
             CONCAT(u.first_name,' ',u.last_name) AS driver_name,
             u.email, u.phone, u.registration_date
      FROM drivers d
      JOIN users u ON d.driver_id = u.user_id
      WHERE d.verification_status = 'pending'
      ORDER BY u.registration_date DESC`);

    // Pending vehicles
    const [pendingVehicles]   = await db.query(`
      SELECT v.*, CONCAT(u.first_name,' ',u.last_name) AS driver_name
      FROM vehicles v
      JOIN users u ON v.driver_id = u.user_id
      WHERE v.verification_status = 'pending'
      ORDER BY v.vehicle_id DESC`);

    // All drivers (for manage section)
    const [allDrivers]        = await db.query(`
      SELECT d.driver_id, d.license_no, d.national_id, d.verification_status, d.availability_status,
             d.flagged_for_review, d.flag_reason,
             CONCAT(u.first_name,' ',u.last_name) AS driver_name,
             u.email, u.phone, u.account_status
      FROM drivers d
      JOIN users u ON d.driver_id = u.user_id
      ORDER BY u.registration_date DESC`);

    // Views data
    const [topDrivers]        = await db.query('SELECT * FROM DriverLeaderboardView LIMIT 10');
    const [activeRides]       = await db.query('SELECT * FROM ActiveRidesView ORDER BY request_time DESC');
    const [notifications]     = await db.query('SELECT * FROM admin_notifications ORDER BY created_at DESC LIMIT 15');

    // Management data
    const [users]             = await db.query('SELECT user_id, first_name, last_name, email, role, account_status, registration_date FROM users ORDER BY registration_date DESC');
    const [vehicles]          = await db.query(`SELECT v.*, CONCAT(u.first_name,' ',u.last_name) AS driver_name FROM vehicles v JOIN users u ON v.driver_id=u.user_id ORDER BY v.verification_status ASC, v.vehicle_id DESC`);
    const [pricing]           = await db.query('SELECT * FROM pricing_rules ORDER BY city, vehicle_type');
    const [complaints]        = await db.query(`
      SELECT c.*, CONCAT(f.first_name,' ',f.last_name) AS filed_by_name,
             CONCAT(r.first_name,' ',r.last_name) AS reported_name
      FROM complaints c
      JOIN users f ON c.filed_by_user_id=f.user_id
      LEFT JOIN users r ON c.reported_against_user_id=r.user_id
      ORDER BY c.created_at DESC LIMIT 30`);
    const [payouts]           = await db.query(`
      SELECT dp.*, CONCAT(u.first_name,' ',u.last_name) AS driver_name
      FROM driver_payouts dp
      JOIN users u ON dp.driver_id = u.user_id
      ORDER BY dp.requested_at DESC LIMIT 30`);
    const [ratings]           = await db.query(`
      SELECT rt.*, CONCAT(rb.first_name,' ',rb.last_name) AS rated_by_name,
             CONCAT(ru.first_name,' ',ru.last_name) AS rated_user_name
      FROM ratings rt
      JOIN users rb ON rt.rated_by_user_id = rb.user_id
      JOIN users ru ON rt.rated_user_id    = ru.user_id
      ORDER BY rt.rating_timestamp DESC LIMIT 30`);

    res.render('admin', {
      stats: { usersCount, ridesCount, revenue, driversCount, openComplaints, pendingDrivers, refundTotal, commissionTotal },
      revenueByCity, paymentBreakdown, rideStatusBreakdown,
      driverEarnings, refundList,
      pendingDriverList, pendingVehicles, allDrivers,
      topDrivers, activeRides, notifications,
      users, vehicles, pricing, complaints, payouts, ratings
    });
  } catch (err) { next(err); }
});

// ── POST /user-status ─────────────────────────────────────────────────────────
router.post('/user-status', async (req, res, next) => {
  try {
    await db.query('UPDATE users SET account_status=? WHERE user_id=?', [req.body.account_status, req.body.user_id]);
    req.session.flash = { type: 'success', message: 'User status updated.' };
    res.redirect('/admin#users');
  } catch (err) { next(err); }
});

// ── POST /driver-verify ───────────────────────────────────────────────────────
router.post('/driver-verify', async (req, res, next) => {
  try {
    const { driver_id, verification_status } = req.body;
    await db.query('UPDATE drivers SET verification_status=? WHERE driver_id=?', [verification_status, driver_id]);
    if (verification_status === 'verified') {
      await db.query(
        `INSERT INTO admin_notifications (user_id, title, message) VALUES (?, 'Account Verified', 'Your driver account has been verified. You can now go online and accept rides.')`,
        [driver_id]
      );
    }
    req.session.flash = { type: 'success', message: `Driver verification updated to "${verification_status}".` };
    res.redirect('/admin#pending-drivers');
  } catch (err) { next(err); }
});

// ── POST /vehicle-status ──────────────────────────────────────────────────────
router.post('/vehicle-status', async (req, res, next) => {
  try {
    await db.query('UPDATE vehicles SET verification_status=? WHERE vehicle_id=?', [req.body.verification_status, req.body.vehicle_id]);
    req.session.flash = { type: 'success', message: 'Vehicle verification updated.' };
    res.redirect('/admin#pending-drivers');
  } catch (err) { next(err); }
});

// ── POST /pricing ─────────────────────────────────────────────────────────────
router.post('/pricing', async (req, res, next) => {
  try {
    const { pricing_rule_id, base_rate, per_km_rate, per_minute_rate, surge_multiplier } = req.body;
    await db.query(`UPDATE pricing_rules SET base_rate=?, per_km_rate=?, per_minute_rate=?, surge_multiplier=? WHERE pricing_rule_id=?`,
      [base_rate, per_km_rate, per_minute_rate, surge_multiplier, pricing_rule_id]);
    req.session.flash = { type: 'success', message: 'Pricing rule updated.' };
    res.redirect('/admin#pricing');
  } catch (err) { next(err); }
});

// ── POST /complaint-status ────────────────────────────────────────────────────
router.post('/complaint-status', async (req, res, next) => {
  try {
    const resolvedAt = req.body.status === 'resolved' ? new Date() : null;
    await db.query('UPDATE complaints SET status=?, admin_action=?, resolved_at=? WHERE complaint_id=?',
      [req.body.status, req.body.admin_action || null, resolvedAt, req.body.complaint_id]);
    req.session.flash = { type: 'success', message: 'Complaint updated.' };
    res.redirect('/admin#complaints');
  } catch (err) { next(err); }
});

// ── POST /payout-status ───────────────────────────────────────────────────────
router.post('/payout-status', async (req, res, next) => {
  try {
    const { payout_id, payout_status } = req.body;
    const processedAt = payout_status === 'paid' ? new Date() : null;
    await db.query('UPDATE driver_payouts SET payout_status=?, processed_at=? WHERE payout_id=?',
      [payout_status, processedAt, payout_id]);
    req.session.flash = { type: 'success', message: `Payout marked as "${payout_status}".` };
    res.redirect('/admin#payouts');
  } catch (err) { next(err); }
});

module.exports = router;
