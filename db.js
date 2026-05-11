require('dotenv').config();
const mysql = require('mysql2/promise');

// Aiven MySQL requires SSL For classroom/demo machines, rejectUnauthorized=false and avoids Windows self signed certificate chain errors while still using SSL encryption.
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'rideflow_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  dateStrings: true,
  ssl: { rejectUnauthorized: false }
});

module.exports = pool;
