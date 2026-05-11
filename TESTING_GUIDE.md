# RideFlow Node.js UI Testing Guide

## 1. Start the app

```bash
cd rideflow_node_app
copy .env.example .env   # Windows only, if .env does not exist yet
npm install
npm start
```

Open: http://localhost:3000

Make sure `.env` contains your Aiven settings:

```env
DB_HOST=mysql-1cbc98b4-labtask12.c.aivencloud.com
DB_PORT=15960
DB_USER=avnadmin
DB_PASSWORD=YOUR_AIVEN_PASSWORD
DB_NAME=rideflow_db
PORT=3000
SESSION_SECRET=rideflow_secret
```

## 2. Login accounts

Use the sample accounts inserted by `02_sample_data.sql`:

| Role | Email | Password |
|---|---|---|
| Admin | admin@rideflow.com | admin123 |
| Rider | ali.rider@rideflow.com | rider123 |
| Driver | hamza.driver@rideflow.com | driver123 |

## 3. Rider dashboard tests

Login as `ali.rider@rideflow.com`.

Test these features:

1. Wallet top-up
   - Enter amount such as `500`.
   - Click Add.
   - Wallet balance should increase.

2. Book ride
   - Select pickup and dropoff locations.
   - Make sure pickup and dropoff are different.
   - Click Request Ride.
   - New ride should appear in My Ride History with status `requested`.

3. Cancel ride
   - For a requested/accepted ride, click Cancel.
   - Status should become `cancelled`.

4. Rating
   - If a ride is completed and has a driver, submit a rating.
   - This inserts/updates a row in `ratings`.

5. Complaint
   - Enter Ride ID, optional reported user ID, type, and description.
   - Submit complaint.
   - Admin dashboard should show it under Complaints / Disputes.

Screenshots to capture:
- Rider dashboard
- Book ride form
- Ride history table
- Wallet top-up result
- Complaint form/result

## 4. Driver dashboard tests

Login as `hamza.driver@rideflow.com`.

Test these features:

1. Toggle availability
   - Change status to online/offline/on_trip.
   - Click Update.
   - Status badge should change.

2. Accept requested ride
   - A requested ride should appear in Available Ride Requests.
   - Select a verified vehicle.
   - Click Accept.
   - Ride should move to My Trips with status `accepted`.

3. Start ride
   - Click Start Ride.
   - Status should become `in_progress`.

4. Complete ride and create payment
   - Enter distance, duration, payment method, and optional promo code.
   - Click Complete + Pay.
   - Procedure should calculate fare and create payment.
   - Triggers should update payment/ride related data.

5. Payout request
   - Enter amount and click Payout.
   - New payout row should be inserted.

6. Rate rider
   - For a completed ride, submit rider rating.

Screenshots to capture:
- Driver dashboard
- Available ride requests
- Accepted ride in My Trips
- Complete + Pay form
- Earnings card

## 5. Admin dashboard tests

Login as `admin@rideflow.com`.

Test these features:

1. Analytics cards
   - Users, rides, revenue, drivers, complaints should load from MySQL.

2. Charts
   - Revenue by city chart
   - Payment method breakdown chart
   - Ride status breakdown chart

3. Top drivers view
   - Table should show drivers from `DriverLeaderboardView`.

4. Active rides view
   - Table should show ongoing rides from `ActiveRidesView`.

5. Manage users
   - Change user status to active/suspended/banned.
   - Save and check it updates.

6. Manage vehicles
   - Change vehicle verification status.
   - Save and check it updates.

7. Fare rules
   - Change base rate / per km / per minute / surge.
   - Save and verify values update.

8. Complaints
   - Update complaint status and admin action.

Screenshots to capture:
- Admin dashboard full page
- Revenue and payment charts
- Top drivers table
- Manage users table
- Manage vehicles table
- Fare rules table
- Complaints table

## 6. Role-based access test

1. Login as Rider.
2. Try opening: http://localhost:3000/admin
3. You should be redirected or shown access denied.
4. Login as Driver.
5. Try opening: http://localhost:3000/rider
6. You should be redirected or shown access denied.

This proves role-based login is enforced.

## 7. Backend SQL proof screenshots

From MySQL Workbench, capture:

```sql
SHOW TABLES;
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW PROCEDURE STATUS WHERE Db = 'rideflow_db';
SHOW TRIGGERS;
SHOW EVENTS;
SELECT * FROM ActiveRidesView;
SELECT * FROM TopDriversView;
```

Also run and screenshot the queries in `03_required_queries.sql`.
