use rideflow_db;

set @constraint_exists = (
    select count(*)
    from information_schema.table_constraints
    where constraint_schema = database()
      and table_name = 'rides'
      and constraint_name = 'chk_rides_status'
);

set @drop_sql = if(
    @constraint_exists > 0,
    'alter table rides drop constraint chk_rides_status',
    'select 1'
);

prepare drop_stmt from @drop_sql;
execute drop_stmt;
deallocate prepare drop_stmt;

alter table rides
    add constraint chk_rides_status
    check (ride_status in ('requested', 'accepted', 'driver_en_route', 'in_progress', 'payment_pending', 'completed', 'cancelled'));

delimiter $$

drop procedure if exists FinalizeRide$$

create procedure FinalizeRide(
    in p_ride_id bigint unsigned,
    in p_distance_km decimal(8,2),
    in p_duration_min int
)
begin
    declare v_vehicle_type varchar(20);
    declare v_city varchar(100);
    declare v_base_fare decimal(10,2);
    declare v_discount decimal(10,2);
    declare v_final_fare decimal(10,2);

    select v.vehicle_type, l.city
    into v_vehicle_type, v_city
    from rides r
    join vehicles v on r.vehicle_id = v.vehicle_id
    join locations l on r.pickup_location_id = l.location_id
    where r.ride_id = p_ride_id;

    call CalculateFare(v_vehicle_type, v_city, p_distance_km, p_duration_min, null, v_base_fare, v_discount, v_final_fare);

    update rides
    set distance_km = p_distance_km,
        duration_min = p_duration_min,
        fare = v_final_fare,
        end_time = now(),
        ride_status = 'payment_pending'
    where ride_id = p_ride_id
      and ride_status in ('accepted', 'driver_en_route', 'in_progress');

    select v_final_fare as calculated_fare;
end$$

drop procedure if exists PayRide$$

create procedure PayRide(
    in p_ride_id bigint unsigned,
    in p_payment_method varchar(20),
    in p_promo_code varchar(30)
)
begin
    declare v_vehicle_type varchar(20);
    declare v_city varchar(100);
    declare v_rider_id bigint unsigned;
    declare v_distance_km decimal(8,2);
    declare v_duration_min int;
    declare v_base_fare decimal(10,2);
    declare v_discount decimal(10,2);
    declare v_final_fare decimal(10,2);
    declare v_promo_id bigint unsigned default null;
    declare v_wallet_balance decimal(12,2) default 0.00;

    select v.vehicle_type, l.city, r.rider_id, r.distance_km, r.duration_min
    into v_vehicle_type, v_city, v_rider_id, v_distance_km, v_duration_min
    from rides r
    join vehicles v on r.vehicle_id = v.vehicle_id
    join locations l on r.pickup_location_id = l.location_id
    where r.ride_id = p_ride_id;

    call CalculateFare(v_vehicle_type, v_city, v_distance_km, v_duration_min, p_promo_code, v_base_fare, v_discount, v_final_fare);

    if p_payment_method = 'wallet' then
        select coalesce((select balance from wallets where user_id = v_rider_id), 0.00)
        into v_wallet_balance;

        if v_wallet_balance < v_final_fare then
            signal sqlstate '45000'
                set message_text = 'insufficient wallet balance';
        end if;
    end if;

    set v_promo_id = (
        select promo_code_id
        from promo_codes
        where code = p_promo_code
          and status = 'active'
          and expiry_date >= curdate()
          and times_used < usage_limit
        limit 1
    );

    update rides
    set fare = v_base_fare
    where ride_id = p_ride_id;

    insert into payments (ride_id, promo_code_id, amount, payment_method, payment_status, promo_discount_applied)
    values (p_ride_id, v_promo_id, v_final_fare, p_payment_method, 'paid', v_discount)
    on duplicate key update
        promo_code_id = values(promo_code_id),
        amount = values(amount),
        payment_method = values(payment_method),
        payment_status = 'paid',
        promo_discount_applied = values(promo_discount_applied),
        transaction_date = now();

    select v_final_fare as paid_amount;
end$$

delimiter ;

show procedure status where db = 'rideflow_db' and name in ('FinalizeRide', 'PayRide');
