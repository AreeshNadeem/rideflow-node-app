# RideFlow D3 Node.js UI

A Node.js + Express + EJS web app for the RideFlow DBMS final deliverable. It connects directly to the live Aiven MySQL database and demonstrates role-based login, rider dashboard, driver dashboard, admin analytics, reports, and CRUD-style actions.

## Run

```bash
npm install
copy .env.example .env
npm start
```

Edit `.env` with your real Aiven MySQL password before starting.

Open: http://localhost:3000

## Demo logins

- Admin: `admin@rideflow.com` / `admin123`
- Rider: `ali.rider@rideflow.com` / `rider123`
- Driver: `hamza.driver@rideflow.com` / `driver123`

## Main features

- Role-based login for Rider, Driver, Admin
- Rider: book rides, view history, wallet top-up, rating, complaint
- Driver: toggle availability, accept/reject ride, start/complete ride, payout request, rate rider
- Admin: charts, reports, users, vehicles, fare rules, complaints
- Uses MySQL views, procedures, triggers, events, and reporting tables

See `TESTING_GUIDE.md` for step-by-step testing and screenshot checklist.


