#Areesh Nadeem 24i-2571
#Fizza Hussain 24i-2621

drop database if exists rideflow_db;
create database rideflow_db;
use rideflow_db;


drop table if exists complaints;
drop table if exists ratings;
drop table if exists payments;
drop table if exists rides;
drop table if exists promo_codes;
drop table if exists locations;
drop table if exists vehicles;
drop table if exists drivers;
drop table if exists users;


# users table
create table users (
    user_id bigint unsigned auto_increment primary key,
    first_name varchar(50) not null,
    last_name varchar(50) not null,
    email varchar(100) not null,
    phone varchar(20) not null,
    password_hash varchar(255) not null,
    role varchar(20) not null,
    account_status varchar(20) not null default 'active',
    registration_date datetime not null default current_timestamp,

    constraint uq_users_email unique (email),
    constraint uq_users_phone unique (phone),

    constraint chk_users_role
        check (role in ('admin', 'rider', 'driver')),

    constraint chk_users_account_status
        check (account_status in ('active', 'suspended', 'banned'))
) ;

# drivers table (1:1 with users)
create table drivers (
    driver_id bigint unsigned primary key,
    license_no varchar(30) not null,
    national_id varchar(25) not null,
    profile_photo varchar(255) null,
    verification_status varchar(20) not null default 'pending',
    availability_status varchar(20) not null default 'offline',

    constraint uq_drivers_license_no unique (license_no),
    constraint uq_drivers_national_id unique (national_id),

    constraint chk_drivers_verification_status  check (verification_status in ('pending', 'verified', 'rejected')),

    constraint chk_drivers_availability_status  check (availability_status in ('online', 'offline', 'on_trip')),

    constraint fk_drivers_user foreign key (driver_id)  references users(user_id)  on delete cascade on update cascade
) ;

# vehicles table (many vehicles per driver)

create table vehicles (
    vehicle_id bigint unsigned auto_increment primary key,
    driver_id bigint unsigned not null,
    make varchar(50) not null,
    model varchar(50) not null,
    manufacture_year year not null,
    color varchar(30) not null,
    license_plate varchar(20) not null,
    vehicle_type varchar(20) not null,
    verification_status varchar(20) not null default 'pending',

    constraint uq_vehicles_license_plate unique (license_plate),

    constraint chk_vehicles_vehicle_type
        check (vehicle_type in ('economy', 'premium', 'bike')),

    constraint chk_vehicles_verification_status
        check (verification_status in ('pending', 'verified', 'rejected')),

    constraint fk_vehicles_driver  foreign key (driver_id)  references drivers(driver_id)   on delete cascade   on update cascade
) ;

# locations table
create table locations (
    location_id bigint unsigned auto_increment primary key,
    label varchar(100) null,
    street varchar(100) not null,
    area varchar(100) not null,
    city varchar(100) not null,
    latitude decimal(10,8) not null,
    longitude decimal(11,8) not null,

    constraint chk_locations_latitude
        check (latitude between -90.00000000 and 90.00000000),

    constraint chk_locations_longitude
        check (longitude between -180.00000000 and 180.00000000)
);

# promo codes table
create table promo_codes (
    promo_code_id bigint unsigned auto_increment primary key,
    code varchar(30) not null,
    discount_type varchar(20) not null,
    discount_value decimal(10,2) not null,
    expiry_date date not null,
    status varchar(20) not null default 'active',
    usage_limit int unsigned not null default 1,
    times_used int unsigned not null default 0,

    constraint uq_promo_codes_code unique (code),

    constraint chk_promo_discount_type
        check (discount_type in ('percentage', 'fixed')),

    constraint chk_promo_discount_value
        check (discount_value > 0),

    constraint chk_promo_status
        check (status in ('active', 'expired', 'disabled')),

    constraint chk_promo_usage_limit
        check (usage_limit > 0),

    constraint chk_promo_times_used
        check (times_used >= 0)
) ;

# rides table (core table)
create table rides (
    ride_id bigint unsigned auto_increment primary key,
    rider_id bigint unsigned not null,
    driver_id bigint unsigned null,
    vehicle_id bigint unsigned null,
    pickup_location_id bigint unsigned not null,
    dropoff_location_id bigint unsigned not null,
    ride_status varchar(20) not null default 'requested',
    request_time datetime not null default current_timestamp,
    scheduled_time datetime null,
    accepted_time datetime null,
    start_time datetime null,
    end_time datetime null,
    distance_km decimal(8,2) not null default 0.00,
    duration_min int unsigned not null default 0,
    fare decimal(10,2) not null default 0.00,

    constraint chk_rides_status
        check (ride_status in ( 'requested', 'accepted', 'driver_en_route', 'in_progress', 'completed', 'cancelled'
        )),
        
    constraint chk_rides_distance
        check (distance_km >= 0),

    constraint chk_rides_duration
        check (duration_min >= 0),

    constraint chk_rides_fare
        check (fare >= 0),

    constraint fk_rides_rider foreign key (rider_id)  references users(user_id)
        on delete restrict
        on update cascade,

    constraint fk_rides_driver foreign key (driver_id) references drivers(driver_id)
        on delete set null on update cascade,

    constraint fk_rides_vehicle foreign key (vehicle_id)  references vehicles(vehicle_id) on delete set null on update cascade,

    constraint fk_rides_pickup_location  foreign key (pickup_location_id) references locations(location_id) on delete restrict on update cascade,

    constraint fk_rides_dropoff_location foreign key (dropoff_location_id) references locations(location_id) on delete restrict on update cascade
) ;

# payments table (1:1 with rides)
create table payments (
    payment_id bigint unsigned auto_increment primary key,
    ride_id bigint unsigned not null,
    promo_code_id bigint unsigned null,
    amount decimal(10,2) not null,
    payment_method varchar(20) not null,
    payment_status varchar(20) not null default 'pending',
    transaction_date datetime not null default current_timestamp,
    promo_discount_applied decimal(10,2) not null default 0.00,

    constraint uq_payments_ride_id unique (ride_id),

    constraint chk_payments_amount
        check (amount >= 0),

    constraint chk_payments_discount
        check (promo_discount_applied >= 0),

    constraint chk_payments_method 
		check (payment_method in ('cash', 'wallet', 'card')),

    constraint chk_payments_status 
		check (payment_status in ('pending', 'paid', 'failed', 'refunded')),

    constraint fk_payments_ride foreign key (ride_id) references rides(ride_id) on delete cascade on update cascade,

    constraint fk_payments_promo_code foreign key (promo_code_id) references promo_codes(promo_code_id) on delete set null on update cascade
) ;

# ratings table (rider rates driver and driver rates rider per ride)
create table ratings (
    rating_id bigint unsigned auto_increment primary key,
    ride_id bigint unsigned not null,
    rated_by_user_id bigint unsigned not null,
    rated_user_id bigint unsigned not null,
    score tinyint unsigned not null,
    comment_text varchar(500) null,
    rating_timestamp datetime not null default current_timestamp,

    constraint uq_ratings_per_pair unique (ride_id, rated_by_user_id, rated_user_id),

    constraint chk_ratings_score check (score between 1 and 5),

    constraint fk_ratings_ride foreign key (ride_id)  references rides(ride_id) on delete cascade on update cascade,

    constraint fk_ratings_rated_by_user foreign key (rated_by_user_id) references users(user_id)  on delete restrict  on update cascade,

    constraint fk_ratings_rated_user foreign key (rated_user_id) references users(user_id) on delete restrict on update cascade
);

# complaints table
create table complaints (
    complaint_id bigint unsigned auto_increment primary key,
    ride_id bigint unsigned null,
    filed_by_user_id bigint unsigned not null,
    reported_against_user_id bigint unsigned null,
    complaint_type varchar(50) not null,
    description varchar(1000) not null,
    status varchar(20) not null default 'open',
    created_at datetime not null default current_timestamp,
    resolved_at datetime null,
    admin_action varchar(500) null,

    constraint chk_complaints_status
        check (status in ('open', 'in_review', 'resolved', 'rejected')),

    constraint fk_complaints_ride
        foreign key (ride_id)  references rides(ride_id) on delete set null on update cascade,

    constraint fk_complaints_filed_by
        foreign key (filed_by_user_id) references users(user_id) on delete restrict on update cascade,

    constraint fk_complaints_reported_against
        foreign key (reported_against_user_id) references users(user_id)  on delete set null on update cascade
);