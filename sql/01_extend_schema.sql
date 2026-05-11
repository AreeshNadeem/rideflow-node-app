use rideflow_db;

alter table drivers
    add column flagged_for_review boolean not null default false,
    add column flag_reason varchar(255) null;

create table if not exists pricing_rules (
    pricing_rule_id bigint unsigned auto_increment primary key,
    vehicle_type varchar(20) not null,
    city varchar(100) not null,
    base_rate decimal(10,2) not null,
    per_km_rate decimal(10,2) not null,
    per_minute_rate decimal(10,2) not null,
    surge_multiplier decimal(4,2) not null default 1.00,
    peak_start_time time null,
    peak_end_time time null,
    status varchar(20) not null default 'active',
    created_at datetime not null default current_timestamp,

    constraint uq_pricing_vehicle_city unique (vehicle_type, city),
    constraint chk_pricing_vehicle_type check (vehicle_type in ('economy', 'premium', 'bike')),
    constraint chk_pricing_rates check (base_rate >= 0 and per_km_rate >= 0 and per_minute_rate >= 0),
    constraint chk_pricing_surge check (surge_multiplier >= 1.00),
    constraint chk_pricing_status check (status in ('active', 'disabled'))
);

create table if not exists wallets (
    wallet_id bigint unsigned auto_increment primary key,
    user_id bigint unsigned not null,
    balance decimal(12,2) not null default 0.00,
    last_updated datetime not null default current_timestamp on update current_timestamp,

    constraint uq_wallet_user unique (user_id),
    constraint chk_wallet_balance check (balance >= 0),
    constraint fk_wallet_user foreign key (user_id) references users(user_id)
        on delete cascade on update cascade
);

create table if not exists driver_earnings (
    earning_id bigint unsigned auto_increment primary key,
    ride_id bigint unsigned not null,
    driver_id bigint unsigned not null,
    gross_fare decimal(10,2) not null,
    commission_percent decimal(5,2) not null default 20.00,
    commission_amount decimal(10,2) not null,
    net_earning decimal(10,2) not null,
    earning_status varchar(20) not null default 'credited',
    created_at datetime not null default current_timestamp,

    constraint uq_earning_ride unique (ride_id),
    constraint chk_earning_amounts check (gross_fare >= 0 and commission_amount >= 0 and net_earning >= 0),
    constraint chk_earning_status check (earning_status in ('credited', 'paid_out')),
    constraint fk_earning_ride foreign key (ride_id) references rides(ride_id)
        on delete cascade on update cascade,
    constraint fk_earning_driver foreign key (driver_id) references drivers(driver_id)
        on delete restrict on update cascade
);

create table if not exists driver_payouts (
    payout_id bigint unsigned auto_increment primary key,
    driver_id bigint unsigned not null,
    amount decimal(10,2) not null,
    payout_status varchar(20) not null default 'requested',
    requested_at datetime not null default current_timestamp,
    processed_at datetime null,

    constraint chk_payout_amount check (amount > 0),
    constraint chk_payout_status check (payout_status in ('requested', 'approved', 'paid', 'rejected')),
    constraint fk_payout_driver foreign key (driver_id) references drivers(driver_id)
        on delete restrict on update cascade
);

create table if not exists admin_notifications (
    notification_id bigint unsigned auto_increment primary key,
    user_id bigint unsigned null,
    title varchar(150) not null,
    message varchar(1000) not null,
    is_read boolean not null default false,
    created_at datetime not null default current_timestamp,

    constraint fk_notification_user foreign key (user_id) references users(user_id)
        on delete set null on update cascade
);

create table if not exists ride_history (
    history_id bigint unsigned auto_increment primary key,
    ride_id bigint unsigned not null,
    rider_id bigint unsigned not null,
    driver_id bigint unsigned null,
    final_status varchar(20) not null,
    final_fare decimal(10,2) not null,
    archived_at datetime not null default current_timestamp,

    constraint uq_history_ride unique (ride_id),
    constraint chk_history_status check (final_status in ('completed', 'cancelled')),
    constraint fk_history_ride foreign key (ride_id) references rides(ride_id)
        on delete cascade on update cascade,
    constraint fk_history_rider foreign key (rider_id) references users(user_id)
        on delete restrict on update cascade,
    constraint fk_history_driver foreign key (driver_id) references drivers(driver_id)
        on delete set null on update cascade
);

describe drivers;