use rideflow_db;

# sample data for testing dashboard, reports, triggers, and queries  .....passwords are demo hashes only.

-- ============================================================
-- USERS  
-- ============================================================
insert ignore into users (first_name, last_name, email, phone, password_hash, role, account_status) values
-- admin
('Admin',   'User',     'admin@rideflow.com',         '03000000001', 'admin123hash',  'admin',  'active'),
-- riders
('Ali',     'Khan',     'ali.rider@rideflow.com',     '03000000002', 'rider123hash',  'rider',  'active'),
('Sara',    'Ahmed',    'sara.rider@rideflow.com',     '03000000003', 'rider123hash',  'rider',  'active'),
('Bilal',   'Rider',   'bilal.rider@rideflow.com',    '03000000006', 'rider123hash',  'rider',  'active'),
('Zainab',  'Mirza',   'zainab.rider@rideflow.com',   '03000000010', 'rider123hash',  'rider',  'active'),
('Usman',   'Tariq',   'usman.rider@rideflow.com',    '03000000011', 'rider123hash',  'rider',  'active'),
('Hira',    'Baig',    'hira.rider@rideflow.com',     '03000000012', 'rider123hash',  'rider',  'active'),
('Faisal',  'Siddiqui','faisal.rider@rideflow.com',   '03000000013', 'rider123hash',  'rider',  'active'),
('Maryam',  'Aslam',   'maryam.rider@rideflow.com',   '03000000014', 'rider123hash',  'rider',  'active'),
-- drivers
('Hamza',   'Malik',   'hamza.driver@rideflow.com',   '03000000004', 'driver123hash', 'driver', 'active'),
('Ayesha',  'Noor',    'ayesha.driver@rideflow.com',  '03000000005', 'driver123hash', 'driver', 'active'),
('Kamran',  'Sheikh',  'kamran.driver@rideflow.com',  '03000000007', 'driver123hash', 'driver', 'active'),
('Tariq',   'Butt',    'tariq.driver@rideflow.com',   '03000000008', 'driver123hash', 'driver', 'active'),
('Sana',    'Iqbal',   'sana.driver@rideflow.com',    '03000000009', 'driver123hash', 'driver', 'active'),
('Rehan',   'Chaudhry','rehan.driver@rideflow.com',   '03000000015', 'driver123hash', 'driver', 'active');

-- ============================================================
-- DRIVERS 
-- ============================================================
insert ignore into drivers (driver_id, license_no, national_id, profile_photo, verification_status, availability_status) values
(10, 'LIC-1001', '35202-1111111-1', 'hamza.jpg',  'verified', 'online'),
(11, 'LIC-1002', '35202-2222222-2', 'ayesha.jpg', 'verified', 'online'),
(12, 'LIC-1003', '35202-3333333-3', 'kamran.jpg', 'verified', 'online'),
(13, 'LIC-1004', '35202-4444444-4', 'tariq.jpg',  'verified', 'offline'),
(14, 'LIC-1005', '35202-5555555-5', 'sana.jpg',   'verified', 'online'),
(15, 'LIC-1006', '35202-6666666-6', 'rehan.jpg',  'verified', 'online');

-- ============================================================
-- VEHICLES  
-- ============================================================
insert ignore into vehicles (driver_id, make, model, manufacture_year, color, license_plate, vehicle_type, verification_status) values
-- economy cars
(10, 'Toyota',  'Corolla',  2020, 'White',  'LEA-1234', 'economy', 'verified'),
(12, 'Suzuki',  'Cultus',   2021, 'Silver', 'ISD-4321', 'economy', 'verified'),
(13, 'Honda',   'City',     2019, 'Grey',   'LEB-9876', 'economy', 'verified'),
-- premium cars
(11, 'Honda',   'Civic',    2022, 'Black',  'LEB-5678', 'premium', 'verified'),
(14, 'Toyota',  'Camry',    2023, 'Pearl',  'ISD-7777', 'premium', 'verified'),
-- bikes
(12, 'Yamaha',  'YBR 125',  2022, 'Red',    'LEA-B001', 'bike',    'verified'),
(15, 'Honda',   'CG 125',   2021, 'Blue',   'ISD-B002', 'bike',    'verified'),
(15, 'United',  'US 100',   2023, 'Green',  'LEB-B003', 'bike',    'verified');

-- ============================================================
-- LOCATIONS  
-- ============================================================
insert ignore into locations (label, street, area, city, latitude, longitude) values
-- Islamabad
('FAST NUCES',           'A.K. Brohi Road',        'H-11',          'Islamabad', 33.65190000, 73.01540000),
('Centaurus Mall',       'Jinnah Avenue',           'F-8',           'Islamabad', 33.70770000, 73.04980000),
('Blue Area',            'Jinnah Avenue',           'Blue Area',     'Islamabad', 33.72450000, 73.09340000),
('F-10 Markaz',          'Islamabad Expressway',    'F-10',          'Islamabad', 33.69850000, 73.02360000),
('Islamabad Airport',    'Islamabad Expressway',    'New Islamabad', 'Islamabad', 33.61670000, 72.84160000),
('Pakistan Monument',    'Shakarparian Road',       'Shakarparian',  'Islamabad', 33.69310000, 73.06850000),
('Faisal Mosque',        'Shah Faisal Avenue',      'F-8',           'Islamabad', 33.72950000, 73.03870000),
('Pindi Railway Station','Railway Road',            'Saddar',        'Rawalpindi',33.59970000, 73.04420000),
-- Lahore
('Liberty Market',       'Main Boulevard',          'Gulberg',       'Lahore',    31.50990000, 74.34410000),
('Emporium Mall',        'Abdul Haque Road',        'Johar Town',    'Lahore',    31.46780000, 74.26620000),
('DHA Phase 6',          'Khayaban-e-Iqbal',        'DHA',           'Lahore',    31.47230000, 74.39870000),
('Lahore Airport',       'Walton Road',             'Walton',        'Lahore',    31.52160000, 74.40360000),
('Packages Mall',        'Walton Road',             'Walton',        'Lahore',    31.52060000, 74.40490000),
('Anarkali Bazaar',      'Lohari Gate Road',        'Old City',      'Lahore',    31.57470000, 74.31240000),
('Gulberg Galleria',     'Main Boulevard Gulberg',  'Gulberg III',   'Lahore',    31.50780000, 74.34220000),
('Model Town Park',      'Model Town Link Road',    'Model Town',    'Lahore',    31.48540000, 74.32990000);

-- ============================================================
-- PRICING RULES 
-- ============================================================
insert ignore into pricing_rules (vehicle_type, city, base_rate, per_km_rate, per_minute_rate, surge_multiplier, peak_start_time, peak_end_time) values
('economy', 'Islamabad', 150.00, 45.00, 8.00,  1.50, '17:00:00', '21:00:00'),
('premium', 'Islamabad', 250.00, 70.00, 12.00, 1.70, '17:00:00', '21:00:00'),
('bike',    'Islamabad',  80.00, 25.00,  4.00, 1.30, '17:00:00', '21:00:00'),
('economy', 'Lahore',    140.00, 40.00,  7.00, 1.40, '17:00:00', '21:00:00'),
('premium', 'Lahore',    240.00, 65.00, 11.00, 1.60, '17:00:00', '21:00:00'),
('bike',    'Lahore',     70.00, 22.00,  3.50, 1.20, '17:00:00', '21:00:00');

-- ============================================================
-- PROMO CODES  
-- ============================================================

insert ignore into promo_codes (code, discount_type, discount_value, expiry_date, status, usage_limit, times_used) values

('WELCOME20',   'percentage', 20.00, date_add(curdate(), interval 30 day),  'active',  100, 0),
('FLAT100',     'fixed',     100.00, date_add(curdate(), interval 10 day),  'active',   50, 0),
('OLD50',       'fixed',      50.00, date_sub(curdate(), interval 5 day),   'active',   20, 0),
('BIKE10',      'percentage', 10.00, date_add(curdate(), interval 60 day),  'active',  200, 0),
('NEWUSER30',   'percentage', 30.00, date_add(curdate(), interval 14 day),  'active',   75, 0),
('MOTHERSDAY',  'percentage', 25.00, date_add(curdate(), interval 7 day),   'active',  300, 0);

-- ============================================================
-- WALLETS
-- ============================================================
insert ignore into wallets (user_id, balance) values
(2,  2000.00),
(3,  1500.00),
(4,   800.00),
(5,  1200.00),
(6,   500.00),
(7,  3000.00),
(8,   750.00),
(9,   400.00),
(10,    0.00),
(11,    0.00),
(12,    0.00),
(13,    0.00),
(14,    0.00),
(15,    0.00);

-- ============================================================
-- RIDES  
-- ============================================================
insert ignore into rides (rider_id, driver_id, vehicle_id, pickup_location_id, dropoff_location_id, ride_status, request_time, accepted_time, start_time, end_time, distance_km, duration_min, fare) values
-- completed rides
(2,  10, 1, 1,  2,  'completed', date_sub(now(), interval 3  day), date_sub(now(), interval 3  day), date_sub(now(), interval 3  day), date_sub(now(), interval 3  day), 12.50, 28, 936.50),
(3,  11, 4, 9,  10, 'completed', date_sub(now(), interval 2  day), date_sub(now(), interval 2  day), date_sub(now(), interval 2  day), date_sub(now(), interval 2  day),  8.00, 22, 950.00),
(4,  12, 2, 3,  4,  'completed', date_sub(now(), interval 5  day), date_sub(now(), interval 5  day), date_sub(now(), interval 5  day), date_sub(now(), interval 5  day),  6.00, 15, 490.00),
(5,  13, 3, 11, 12, 'completed', date_sub(now(), interval 4  day), date_sub(now(), interval 4  day), date_sub(now(), interval 4  day), date_sub(now(), interval 4  day), 14.00, 32, 780.00),
(6,  14, 5, 13, 14, 'completed', date_sub(now(), interval 1  day), date_sub(now(), interval 1  day), date_sub(now(), interval 1  day), date_sub(now(), interval 1  day),  9.50, 20, 1100.00),
(7,  15, 6, 1,  3,  'completed', date_sub(now(), interval 6  day), date_sub(now(), interval 6  day), date_sub(now(), interval 6  day), date_sub(now(), interval 6  day),  4.00, 12, 205.00),
(8,  12, 6, 9,  15, 'completed', date_sub(now(), interval 7  day), date_sub(now(), interval 7  day), date_sub(now(), interval 7  day), date_sub(now(), interval 7  day),  7.50, 18, 365.00),
(9,  15, 7, 5,  6,  'completed', date_sub(now(), interval 8  day), date_sub(now(), interval 8  day), date_sub(now(), interval 8  day), date_sub(now(), interval 8  day),  3.00, 10, 155.00),
-- in_progress ride
(2,  11, 4, 1,  2,  'in_progress', now(), now(), now(), null, 5.00, 10, 0.00),
-- requested (no driver yet)
(3,  null, null, 3, 4, 'requested', now(), null, null, null, 0.00, 0, 0.00);

-- ============================================================
-- PAYMENTS 
-- ============================================================
insert ignore into payments (ride_id, promo_code_id, amount, payment_method, payment_status, transaction_date, promo_discount_applied) values
(1, 1, 749.20, 'wallet', 'paid',    date_sub(now(), interval 3 day), 187.30),
(2, null, 950.00, 'cash', 'paid',   date_sub(now(), interval 2 day),   0.00),
(3, null, 490.00, 'cash', 'paid',   date_sub(now(), interval 5 day),   0.00),
(4, 2,    680.00, 'wallet', 'paid', date_sub(now(), interval 4 day), 100.00),
(5, null, 1100.00,'card', 'paid',   date_sub(now(), interval 1 day),   0.00),
(6, 4,    184.50, 'wallet', 'paid', date_sub(now(), interval 6 day),  20.50),
(7, null, 365.00, 'cash', 'paid',   date_sub(now(), interval 7 day),   0.00),
(8, null, 155.00, 'cash', 'paid',   date_sub(now(), interval 8 day),   0.00);

-- ============================================================
-- RATINGS
-- ============================================================
insert ignore into ratings (ride_id, rated_by_user_id, rated_user_id, score, comment_text) values
(1, 2,  10, 5, 'Excellent driver, very polite'),
(1, 10, 2,  5, 'Polite and on-time rider'),
(2, 3,  11, 4, 'Good ride, comfortable car'),
(2, 11, 3,  4, 'Good rider'),
(3, 4,  12, 5, 'Very professional'),
(3, 12, 4,  5, 'Great rider'),
(4, 5,  13, 3, 'A bit late but okay'),
(4, 13, 5,  4, 'Decent rider'),
(5, 6,  14, 5, 'Premium experience, loved it'),
(5, 14, 6,  5, 'Very courteous'),
(6, 7,  15, 4, 'Fast bike delivery, smooth ride'),
(6, 15, 7,  4, 'Cooperative rider'),
(7, 8,  12, 5, 'Great bike ride'),
(7, 12, 8,  5, 'Excellent'),
(8, 9,  15, 5, 'Super quick'),
(8, 15, 9,  5, 'Nice rider');

select user_id, first_name, email, role from users;

