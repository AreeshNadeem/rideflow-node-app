
use rideflow_db;

# backend object verification

show tables;

show full tables
where Table_type = 'VIEW';

show procedure status
where Db = 'rideflow_db';

show triggers;

show events;

# view testing

select * from ActiveRidesView;
select * from TopDriversView;
select * from DriverLeaderboardView;
select * from RevenueByCityView;

# fix and test CalculateFare procedure

set @base = 0;
set @discount = 0;
set @final = 0;

call CalculateFare(
    'economy',
    'Islamabad',
    10.00,
    25,
    'WELCOME20',
    @base,
    @discount,
    @final
);

select @base as base_fare, @discount as discount, @final as final_fare;

# payment trigger test payment marked paid should update ride to completed
select ride_id, ride_status
from rides
where ride_id = 1;

update payments
set payment_status = 'paid'
where payment_id = 1;

select ride_id, ride_status
from rides
where ride_id = 1;

# promo code event test event expires promo codes past expiry date
select promo_code_id, code, expiry_date, status
from promo_codes;

# promo usage trigger test insert payment with promo code, then check times_used
select promo_code_id, code, times_used
from promo_codes;

delete from payments
where ride_id = 2;

insert into payments (
    ride_id,
    promo_code_id,
    amount,
    payment_method,
    payment_status,
    promo_discount_applied
)
values (
    2,
    1,
    500.00,
    'card',
    'paid',
    50.00
);

select promo_code_id, code, times_used
from promo_codes;

# final checks

select ride_id, ride_status, fare
from rides
order by ride_id;

select payment_id, ride_id, promo_code_id, amount, payment_method, payment_status
from payments
order by payment_id;

select *
from admin_notifications;