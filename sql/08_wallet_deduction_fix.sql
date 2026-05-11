use rideflow_db;

delimiter $$

drop procedure if exists CompleteRideAndCreatePayment$$

create procedure CompleteRideAndCreatePayment(
    in p_ride_id bigint unsigned,
    in p_distance_km decimal(8,2),
    in p_duration_min int,
    in p_payment_method varchar(20),
    in p_promo_code varchar(30)
)
begin
    declare v_vehicle_type varchar(20);
    declare v_city varchar(100);
    declare v_rider_id bigint unsigned;
    declare v_base_fare decimal(10,2);
    declare v_discount decimal(10,2);
    declare v_final_fare decimal(10,2);
    declare v_promo_id bigint unsigned default null;
    declare v_wallet_balance decimal(12,2) default 0.00;

    select v.vehicle_type, l.city, r.rider_id
    into v_vehicle_type, v_city, v_rider_id
    from rides r
    join vehicles v on r.vehicle_id = v.vehicle_id
    join locations l on r.pickup_location_id = l.location_id
    where r.ride_id = p_ride_id;

    call CalculateFare(v_vehicle_type, v_city, p_distance_km, p_duration_min, p_promo_code, v_base_fare, v_discount, v_final_fare);

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
    set distance_km = p_distance_km,
        duration_min = p_duration_min,
        fare = v_base_fare,
        end_time = now()
    where ride_id = p_ride_id;

    insert into payments (ride_id, promo_code_id, amount, payment_method, payment_status, promo_discount_applied)
    values (p_ride_id, v_promo_id, v_final_fare, p_payment_method, 'paid', v_discount)
    on duplicate key update
        amount = values(amount),
        payment_method = values(payment_method),
        payment_status = 'paid',
        promo_discount_applied = values(promo_discount_applied),
        promo_code_id = values(promo_code_id),
        transaction_date = now();
end$$

drop trigger if exists trg_payment_after_insert_paid$$

create trigger trg_payment_after_insert_paid
after insert on payments
for each row
begin
    declare v_driver_id bigint unsigned;
    declare v_rider_id bigint unsigned;
    declare v_commission decimal(10,2);
    declare v_net decimal(10,2);

    if new.payment_status = 'paid' then
        update rides
        set ride_status = 'completed',
            end_time = coalesce(end_time, now())
        where ride_id = new.ride_id;

        select driver_id, rider_id
        into v_driver_id, v_rider_id
        from rides
        where ride_id = new.ride_id;

        if new.payment_method = 'wallet' then
            update wallets
            set balance = balance - new.amount
            where user_id = v_rider_id;
        end if;

        if v_driver_id is not null then
            set v_commission = round(new.amount * 0.20, 2);
            set v_net = new.amount - v_commission;

            insert ignore into driver_earnings (ride_id, driver_id, gross_fare, commission_percent, commission_amount, net_earning)
            values (new.ride_id, v_driver_id, new.amount, 20.00, v_commission, v_net);

            insert into wallets (user_id, balance)
            values (v_driver_id, v_net)
            on duplicate key update balance = balance + v_net;

            update drivers
            set availability_status = 'online'
            where driver_id = v_driver_id;
        end if;

        insert ignore into ride_history (ride_id, rider_id, driver_id, final_status, final_fare)
        select ride_id, rider_id, driver_id, 'completed', new.amount
        from rides
        where ride_id = new.ride_id;
    end if;

    if new.promo_code_id is not null then
        update promo_codes
        set times_used = times_used + 1
        where promo_code_id = new.promo_code_id;
    end if;
end$$

drop trigger if exists trg_payment_after_update_paid$$

create trigger trg_payment_after_update_paid
after update on payments
for each row
begin
    declare v_driver_id bigint unsigned;
    declare v_rider_id bigint unsigned;
    declare v_commission decimal(10,2);
    declare v_net decimal(10,2);

    if old.payment_status <> 'paid' and new.payment_status = 'paid' then
        update rides
        set ride_status = 'completed',
            end_time = coalesce(end_time, now())
        where ride_id = new.ride_id;

        select driver_id, rider_id
        into v_driver_id, v_rider_id
        from rides
        where ride_id = new.ride_id;

        if new.payment_method = 'wallet' then
            update wallets
            set balance = balance - new.amount
            where user_id = v_rider_id;
        end if;

        if v_driver_id is not null then
            set v_commission = round(new.amount * 0.20, 2);
            set v_net = new.amount - v_commission;

            insert ignore into driver_earnings (ride_id, driver_id, gross_fare, commission_percent, commission_amount, net_earning)
            values (new.ride_id, v_driver_id, new.amount, 20.00, v_commission, v_net);

            insert into wallets (user_id, balance)
            values (v_driver_id, v_net)
            on duplicate key update balance = balance + v_net;

            update drivers
            set availability_status = 'online'
            where driver_id = v_driver_id;
        end if;

        insert ignore into ride_history (ride_id, rider_id, driver_id, final_status, final_fare)
        select ride_id, rider_id, driver_id, 'completed', new.amount
        from rides
        where ride_id = new.ride_id;
    end if;

    if old.promo_code_id is null and new.promo_code_id is not null then
        update promo_codes
        set times_used = times_used + 1
        where promo_code_id = new.promo_code_id;
    end if;
end$$

delimiter ;

show triggers like 'payments';
