use rideflow_db;

#1. basic sql: list all completed rides for a specific rider ordered by date
select
    r.ride_id,
    concat(u.first_name, ' ', u.last_name) as rider_name,
    r.ride_status,
    r.fare,
    r.end_time
from rides r
join users u on r.rider_id = u.user_id
where r.rider_id = 2
  and r.ride_status = 'completed'
order by r.end_time desc;

# 2. basic sql: list all drivers in a city ordered by rating
select
    d.driver_id,
    concat(u.first_name, ' ', u.last_name) as driver_name,
    l.city,
    round(avg(rt.score), 2) as average_rating
from drivers d
join users u on d.driver_id = u.user_id
join vehicles v on d.driver_id = v.driver_id
left join rides r on d.driver_id = r.driver_id
left join locations l on r.pickup_location_id = l.location_id
left join ratings rt on rt.rated_user_id = d.driver_id
where l.city = 'Islamabad' or l.city is null
group by d.driver_id, driver_name, l.city
order by average_rating desc;

#3. aggregate: total revenue per city
select
    l.city,
    sum(p.amount) as total_revenue
from payments p
join rides r on p.ride_id = r.ride_id
join locations l on r.pickup_location_id = l.location_id
where p.payment_status = 'paid'
group by l.city
order by total_revenue desc;

# 4. aggregate + having: average driver ratings below 3.5
select
    d.driver_id,
    concat(u.first_name, ' ', u.last_name) as driver_name,
    round(avg(rt.score), 2) as average_rating
from drivers d
join users u on d.driver_id = u.user_id
join ratings rt on rt.rated_user_id = d.driver_id
group by d.driver_id, driver_name
having avg(rt.score) < 3.5;

# 5. aggregate: number of completed trips per driver
select  d.driver_id,
    concat(u.first_name, ' ', u.last_name) as driver_name,
    count(r.ride_id) as completed_trips
from drivers d
join users u on d.driver_id = u.user_id
left join rides r on d.driver_id = r.driver_id and r.ride_status = 'completed'
group by d.driver_id, driver_name
order by completed_trips desc;

# 6. inner join report: full trip report linking riders, rides, drivers, and vehicles
select
    r.ride_id,
    concat(ru.first_name, ' ', ru.last_name) as rider_name,
    concat(du.first_name, ' ', du.last_name) as driver_name,
    concat(v.make, ' ', v.model) as vehicle,
    v.license_plate,
    pickup.city as pickup_city,
    dropoff.city as dropoff_city,
    r.ride_status,
    r.fare,
    r.request_time
from rides r
inner join users ru on r.rider_id = ru.user_id
inner join drivers d on r.driver_id = d.driver_id
inner join users du on d.driver_id = du.user_id
inner join vehicles v on r.vehicle_id = v.vehicle_id
inner join locations pickup on r.pickup_location_id = pickup.location_id
inner join locations dropoff on r.dropoff_location_id = dropoff.location_id
order by r.request_time desc;

# 7. left join: all riders including those who have never completed a ride
select
    u.user_id as rider_id,
    concat(u.first_name, ' ', u.last_name) as rider_name,
    count(r.ride_id) as completed_rides
from users u
left join rides r on u.user_id = r.rider_id and r.ride_status = 'completed'
where u.role = 'rider'
group by u.user_id, rider_name
order by completed_rides desc;

# 8. join payments and promocodes: discount usage per ride
select
    r.ride_id,
    p.payment_id,
    p.amount,
    p.payment_method,
    p.payment_status,
    pc.code as promo_code,
    p.promo_discount_applied
from rides r
join payments p on r.ride_id = p.ride_id
left join promo_codes pc on p.promo_code_id = pc.promo_code_id
order by p.transaction_date desc;