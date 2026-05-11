const express = require('express');
const router = express.Router();
const db = require('../db');
const { requireRole } = require('./middleware');

router.use(requireRole('driver'));

router.get('/', async (req, res, next) => {
  try {
    const driverId = req.session.user.user_id;
    const [[driver]] = await db.query('SELECT * FROM drivers WHERE driver_id=?', [driverId]);
    const [vehicles] = await db.query("SELECT * FROM vehicles WHERE driver_id=? AND verification_status='verified'", [driverId]);
    // Only show available ride requests when driver is online
    const [requested] = driver.availability_status === 'online'
      ? await db.query(`
          SELECT r.*, CONCAT(u.first_name,' ',u.last_name) AS rider_name, p.label AS pickup_label, p.city AS pickup_city,
                 d.label AS dropoff_label, d.city AS dropoff_city
          FROM rides r
          JOIN users u ON r.rider_id=u.user_id
          JOIN locations p ON r.pickup_location_id=p.location_id
          JOIN locations d ON r.dropoff_location_id=d.location_id
          WHERE r.ride_status='requested'
          ORDER BY r.request_time ASC`)
      : [[]];
    const [myRides] = await db.query(`
      SELECT r.*, CONCAT(u.first_name,' ',u.last_name) AS rider_name, p.label AS pickup_label, p.city AS pickup_city,
             d.label AS dropoff_label, d.city AS dropoff_city, pay.payment_status, pay.amount
      FROM rides r
      JOIN users u ON r.rider_id=u.user_id
      JOIN locations p ON r.pickup_location_id=p.location_id
      JOIN locations d ON r.dropoff_location_id=d.location_id
      LEFT JOIN payments pay ON r.ride_id=pay.ride_id
      WHERE r.driver_id=?
      ORDER BY r.request_time DESC`, [driverId]);
    const [earnings] = await db.query(`
      SELECT COALESCE(SUM(net_earning),0) AS total_earnings, COUNT(*) AS earning_count
      FROM driver_earnings WHERE driver_id=?`, [driverId]);
    const [payouts] = await db.query(
      'SELECT * FROM driver_payouts WHERE driver_id=? ORDER BY requested_at DESC',
      [driverId]);
    res.render('driver', { driver, vehicles, requested, myRides, earningSummary: earnings[0], payouts });
  } catch (err) { next(err); }
});

router.post('/availability', async (req, res, next) => {
  try {
    await db.query("UPDATE drivers SET availability_status=? WHERE driver_id=?", [req.body.availability_status, req.session.user.user_id]);
    req.session.flash = { type: 'success', message: 'Availability updated.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

router.post('/accept/:rideId', async (req, res, next) => {
  try {
    const driverId = req.session.user.user_id;
    const [[driver]] = await db.query('SELECT availability_status FROM drivers WHERE driver_id=?', [driverId]);

    if (driver.availability_status === 'offline') {
      req.session.flash = { type: 'danger', message: 'You are offline. Go online first to accept rides.' };
      return res.redirect('/driver');
    }
    if (driver.availability_status === 'on_trip') {
      req.session.flash = { type: 'danger', message: 'You are already on a trip. Complete your current ride before accepting a new one.' };
      return res.redirect('/driver');
    }

    const vehicleId = req.body.vehicle_id;
    await db.query('CALL AcceptRide(?, ?, ?)', [req.params.rideId, driverId, vehicleId]);
    req.session.flash = { type: 'success', message: 'Ride accepted.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

router.post('/reject/:ride_id', async (req, res) => {
  try {
    const rideId = req.params.ride_id;

    await db.query(
      "update rides set ride_status = 'cancelled', driver_id = null, vehicle_id = null where ride_id = ?",
      [rideId]
    );

    res.redirect('/driver');
  } catch (err) {
    console.error(err);
    res.status(500).send('error rejecting ride');
  }
});

router.post('/start/:rideId', async (req, res, next) => {
  try {
    await db.query("UPDATE rides SET ride_status='in_progress', start_time=COALESCE(start_time,NOW()) WHERE ride_id=? AND driver_id=?", [req.params.rideId, req.session.user.user_id]);
    req.session.flash = { type: 'success', message: 'Ride marked in progress.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

router.post('/complete/:rideId', async (req, res, next) => {
  try {
    const { distance_km, duration_min } = req.body;
    await db.query('CALL FinalizeRide(?, ?, ?)', [req.params.rideId, distance_km, duration_min]);
    req.session.flash = { type: 'success', message: 'Ride finalized. Waiting for rider to complete payment.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

router.post('/payout', async (req, res, next) => {
  try {
    await db.query('INSERT INTO driver_payouts (driver_id, amount) VALUES (?, ?)', [req.session.user.user_id, req.body.amount]);
    req.session.flash = { type: 'success', message: 'Payout request submitted.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});


router.post('/rate', async (req, res, next) => {
  try {
    const { ride_id, rated_user_id, score, comment_text } = req.body;
    await db.query(`INSERT INTO ratings (ride_id, rated_by_user_id, rated_user_id, score, comment_text)
                    VALUES (?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE score=VALUES(score), comment_text=VALUES(comment_text), rating_timestamp=NOW()`,
                    [ride_id, req.session.user.user_id, rated_user_id, score, comment_text || null]);
    req.session.flash = { type: 'success', message: 'Rider rating submitted.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

router.post('/complaint', async (req, res, next) => {
  try {
    const { ride_id, reported_against_user_id, complaint_type, description } = req.body;
    await db.query(
      `INSERT INTO complaints (ride_id, filed_by_user_id, reported_against_user_id, complaint_type, description)
       VALUES (?, ?, ?, ?, ?)`,
      [ride_id || null, req.session.user.user_id, reported_against_user_id || null, complaint_type, description]
    );
    req.session.flash = { type: 'success', message: 'Complaint submitted to admin.' };
    res.redirect('/driver');
  } catch (err) { next(err); }
});

module.exports = router;

