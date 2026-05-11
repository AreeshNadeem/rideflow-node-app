use rideflow_db;

delimiter $$

#trigger 1: payment marked paid -> ride completed, archive ride, create driver earning
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
        set ride_status = 'completed', end_time = coalesce(end_time, now())
        where ride_id = new.ride_id;

        select driver_id, rider_id into v_driver_id, v_rider_id
        from rides where ride_id = new.ride_id;

        if v_driver_id is not null then
            set v_commission = round(new.amount * 0.20, 2);
            set v_net = new.amount - v_commission;

            insert ignore into driver_earnings
                (ride_id, driver_id, gross_fare, commission_percent, commission_amount, net_earning)
            values
                (new.ride_id, v_driver_id, new.amount, 20.00, v_commission, v_net);

            insert into wallets (user_id, balance)
            values (v_driver_id, v_net)
            on duplicate key update balance = balance + v_net;

            update drivers set availability_status = 'online'
            where driver_id = v_driver_id;
        end if;

        insert ignore into ride_history (ride_id, rider_id, driver_id, final_status, final_fare)
        select ride_id, rider_id, driver_id, 'completed', new.amount
        from rides where ride_id = new.ride_id;
    end if;

    if new.promo_code_id is not null then
        update promo_codes
        set times_used = times_used + 1
        where promo_code_id = new.promo_code_id;
    end if;
end$$

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
        set ride_status = 'completed', end_time = coalesce(end_time, now())
        where ride_id = new.ride_id;

        select driver_id, rider_id into v_driver_id, v_rider_id
        from rides where ride_id = new.ride_id;

        if v_driver_id is not null then
            set v_commission = round(new.amount * 0.20, 2);
            set v_net = new.amount - v_commission;

            insert ignore into driver_earnings
                (ride_id, driver_id, gross_fare, commission_percent, commission_amount, net_earning)
            values
                (new.ride_id, v_driver_id, new.amount, 20.00, v_commission, v_net);

            insert into wallets (user_id, balance)
            values (v_driver_id, v_net)
            on duplicate key update balance = balance + v_net;

            update drivers set availability_status = 'online'
            where driver_id = v_driver_id;
        end if;

        insert ignore into ride_history (ride_id, rider_id, driver_id, final_status, final_fare)
        select ride_id, rider_id, driver_id, 'completed', new.amount
        from rides where ride_id = new.ride_id;
    end if;

    if old.promo_code_id is null and new.promo_code_id is not null then
        update promo_codes
        set times_used = times_used + 1
        where promo_code_id = new.promo_code_id;
    end if;
end$$

# trigger 2: flag driver and notify admin when average rating drops below 3.5
create trigger trg_rating_after_insert_low_driver_rating
after insert on ratings
for each row
begin
    declare v_avg_rating decimal(3,2);
    declare v_is_driver int default 0;

    select count(*) into v_is_driver
    from drivers
    where driver_id = new.rated_user_id;

    if v_is_driver > 0 then
        select avg(score) into v_avg_rating
        from ratings
        where rated_user_id = new.rated_user_id;

        if v_avg_rating < 3.50 then
            update drivers
            set flagged_for_review = true,
                flag_reason = concat('Average rating dropped to ', round(v_avg_rating, 2))
            where driver_id = new.rated_user_id;

            insert into admin_notifications (user_id, title, message)
            values (
                new.rated_user_id,
                'Low Driver Rating Alert',
                concat('Driver ID ', new.rated_user_id, ' average rating is ', round(v_avg_rating, 2), '. Admin review required.')
            );
        end if;
    end if;
end$$

# trigger 3: archive cancelled rides
create trigger trg_ride_after_update_cancelled
after update on rides
for each row
begin
    if old.ride_status <> 'cancelled' and new.ride_status = 'cancelled' then
        insert ignore into ride_history (ride_id, rider_id, driver_id, final_status, final_fare)
        values (new.ride_id, new.rider_id, new.driver_id, 'cancelled', new.fare);
    end if;
end$$

delimiter ;

# event scheduler must be enabled by an admin user: set global event_scheduler = on;

drop event if exists evt_expire_promo_codes;

create event evt_expire_promo_codes
on schedule every 1 day
starts timestamp(current_date + interval 1 day)
do
    update promo_codes
    set status = 'expired'
    where expiry_date < curdate()
      and status = 'active';