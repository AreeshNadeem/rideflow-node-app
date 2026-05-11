require('dotenv').config();
const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use('/public', express.static(path.join(__dirname, 'public')));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(session({
  secret: process.env.SESSION_SECRET || 'rideflow_secret',
  resave: false,
  saveUninitialized: false
}));

app.use((req, res, next) => {
  res.locals.user = req.session.user || null;
  res.locals.flash = req.session.flash || null;
  delete req.session.flash;
  next();
});

app.use('/', require('./routes/auth'));
app.use('/rider', require('./routes/rider'));
app.use('/driver', require('./routes/driver'));
app.use('/admin', require('./routes/admin'));

app.use((req, res) => res.status(404).render('error', { message: 'Page not found' }));
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).render('error', { message: err.message || 'Server error' });
});

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => console.log(`RideFlow running at http://localhost:${PORT}`));
