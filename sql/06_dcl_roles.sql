use rideflow_db;

create role if not exists 'rider_role';
create role if not exists 'driver_role';
create role if not exists 'admin_role';
create role if not exists 'support_role';


# rider role riders can request rides and make payments
grant select, insert on rideflow_db.rides to 'rider_role';
grant select, insert on rideflow_db.payments to 'rider_role';
grant select on rideflow_db.locations to 'rider_role';
grant select on rideflow_db.promo_codes to 'rider_role';
grant select, insert on rideflow_db.ratings to 'rider_role';
grant select, insert on rideflow_db.complaints to 'rider_role';


# driver role drivers can view assigned rides and update availability

grant select on rideflow_db.rides to 'driver_role';
grant select on rideflow_db.vehicles to 'driver_role';
grant select, update on rideflow_db.drivers to 'driver_role';
grant select, insert on rideflow_db.ratings to 'driver_role';
grant select, insert on rideflow_db.complaints to 'driver_role';

# admin role admin has full control over rideflow database

grant all privileges on rideflow_db.* to 'admin_role';

# support role support staff can view records but should not delete data
grant select on rideflow_db.* to 'support_role';

# demonstration ya test  first grant delete, then revoke it so the revoke command succeeds
grant delete on rideflow_db.complaints to 'support_role';
revoke delete on rideflow_db.complaints from 'support_role';

#comment out bhi karsakhti  dekhlo 
create user if not exists 'rider_test'@'%' identified by 'Rider@12345';
create user if not exists 'driver_test'@'%' identified by 'Driver@12345';
create user if not exists 'admin_test'@'%' identified by 'Admin@12345';
create user if not exists 'support_test'@'%' identified by 'Support@12345';

grant 'rider_role' to 'rider_test'@'%';
grant 'driver_role' to 'driver_test'@'%';
grant 'admin_role' to 'admin_test'@'%';
grant 'support_role' to 'support_test'@'%';

set default role 'rider_role' to 'rider_test'@'%';
set default role 'driver_role' to 'driver_test'@'%';
set default role 'admin_role' to 'admin_test'@'%';
set default role 'support_role' to 'support_test'@'%';

#apply changes
flush privileges;

#verification commands
show grants for 'rider_role';
show grants for 'driver_role';
show grants for 'admin_role';
show grants for 'support_role';