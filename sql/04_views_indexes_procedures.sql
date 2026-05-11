use rideflow_db;

create index idx_rides_rider_id on rides(rider_id);
create index idx_rides_driver_id on rides(driver_id);
create index idx_rides_status on rides(ride_status);
create index idx_locations_city on locations(city);
create index idx_payments_status on payments(payment_status);
create index idx_ratings_rated_user on ratings(rated_user_id);


create or replace view ActiveRidesView as
select
    r.ride_id,
    r.ride_status,
    concat(ru.first_name, ' ', ru.last_name) as rider_name,
    ru.phone as rider_phone,
    concat(du.first_name, ' ', du.last_name) as driver_name,
    du.phone as driver_phone,
    v.license_plate,
    pickup.city as pickup_city,
    dropoff.city as dropoff_city,
    r.request_time,
    r.start_time
from rides r
join users ru on r.rider_id = ru.user_id
left join drivers d on r.driver_id = d.driver_id
left join users du on d.driver_id = du.user_id
left join vehicles v on r.vehicle_id = v.vehicle_id
join locations pickup on r.pickup_location_id = pickup.location_id
join locations dropoff on r.dropoff_location_id = dropoff.location_id
where r.ride_status in ('accepted', 'driver_en_route', 'in_progress');

create or replace view TopDriversView as
select
    d.driver_id,
    concat(u.first_name, ' ', u.last_name) as driver_name,
    round(avg(rt.score), 2) as average_rating,
    count(rt.rating_id) as rating_count
from drivers d
join users u on d.driver_id = u.user_id
join ratings rt on rt.rated_user_id = d.driver_id
group by d.driver_id, driver_name
having avg(rt.score) > 4.5;

create or replace view RevenueByCityView as
select
    l.city,
    date(p.transaction_date) as revenue_date,
    sum(p.amount) as total_revenue,
    count(p.payment_id) as total_payments
from payments p
join rides r on p.ride_id = r.ride_id
join locations l on r.pickup_location_id = l.location_id
where p.payment_status = 'paid'
group by l.city, date(p.transaction_date);

create or replace view DriverLeaderboardView as
select
    d.driver_id,
    concat(u.first_name, ' ', u.last_name) as driver_name,
    pickup.city,
    round(avg(rt.score), 2) as average_rating,
    count(distinct r.ride_id) as completed_trips
from drivers d
join users u on d.driver_id = u.user_id
left join rides r on d.driver_id = r.driver_id and r.ride_status = 'completed'
left join locations pickup on r.pickup_location_id = pickup.location_id
left join ratings rt on rt.rated_user_id = d.driver_id
group by d.driver_id, driver_name, pickup.city
order by average_rating desc, completed_trips desc;

# stored procedures

delimiter $$

create procedure CalculateFare(
    in p_vehicle_type varchar(20),
    in p_city varchar(100),
    in p_distance_km decimal(8,2),
    in p_duration_min int,
    in p_promo_code varchar(30),
    out p_base_fare decimal(10,2),
    out p_discount decimal(10,2),
    out p_final_fare decimal(10,2)
)
begin
    declare v_base_rate decimal(10,2);
    declare v_per_km_rate decimal(10,2);
    declare v_per_minute_rate decimal(10,2);
    declare v_surge decimal(4,2);
    declare v_discount_type varchar(20);
    declare v_discount_value decimal(10,2);

    select base_rate, per_km_rate, per_minute_rate,
           case
              when peak_start_time is not null
               and peak_end_time is not null
               and curtime() between peak_start_time and peak_end_time
              then surge_multiplier
              else 1.00
           end
    into v_base_rate, v_per_km_rate, v_per_minute_rate, v_surge
    from pricing_rules
    where vehicle_type = p_vehicle_type
      and city = p_city
      and status = 'active'
    limit 1;

    set p_base_fare = round((v_base_rate + (v_per_km_rate * p_distance_km) + (v_per_minute_rate * p_duration_min)) * v_surge, 2);
    set p_discount = 0.00;

    if p_promo_code is not null and p_promo_code <> '' then
        select discount_type, discount_value
        into v_discount_type, v_discount_value
        from promo_codes
        where code = p_promo_code
          and status = 'active'
          and expiry_date >= curdate()
          and times_used < usage_limit
        limit 1;

        if v_discount_type = 'percentage' then
            set p_discount = round(p_base_fare * (v_discount_value / 100), 2);
        elseif v_discount_type = 'fixed' then
            set p_discount = v_discount_value;
        end if;
    end if;

    if p_discount > p_base_fare then
        set p_discount = p_base_fare;
    end if;

    set p_final_fare = p_base_fare - p_discount;
end$$

create procedure RequestRide(
    in p_rider_id bigint unsigned,
    in p_pickup_location_id bigint unsigned,
    in p_dropoff_location_id bigint unsigned,
    in p_scheduled_time datetime
)
begin
    insert into rides (rider_id, pickup_location_id, dropoff_location_id, scheduled_time, ride_status)
    values (p_rider_id, p_pickup_location_id, p_dropoff_location_id, p_scheduled_time, 'requested');

    select last_insert_id() as new_ride_id;
end$$

create procedure AcceptRide(
    in p_ride_id bigint unsigned,
    in p_driver_id bigint unsigned,
    in p_vehicle_id bigint unsigned
)
begin
    update rides
    set driver_id = p_driver_id,
        vehicle_id = p_vehicle_id,
        ride_status = 'accepted',
        accepted_time = now()
    where ride_id = p_ride_id
      and ride_status = 'requested';

    update drivers
    set availability_status = 'on_trip'
    where driver_id = p_driver_id;
end$$

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
    declare v_base_fare decimal(10,2);
    declare v_discount decimal(10,2);
    declare v_final_fare decimal(10,2);
    declare v_promo_id bigint unsigned;

    select v.vehicle_type, l.city
    into v_vehicle_type, v_city
    from rides r
    join vehicles v on r.vehicle_id = v.vehicle_id
    join locations l on r.pickup_location_id = l.location_id
    where r.ride_id = p_ride_id;

    call CalculateFare(v_vehicle_type, v_city, p_distance_km, p_duration_min, p_promo_code, v_base_fare, v_discount, v_final_fare);

    select promo_code_id into v_promo_id
    from promo_codes
    where code = p_promo_code and status = 'active'
    limit 1;

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

delimiter ;

show index from rides;
show index from locations;
show index from payments;
show index from ratings;