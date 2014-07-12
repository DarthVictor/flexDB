set search_path to test;

-- Table: "employee_main"
drop table if exists employee_main cascade;
create table employee_main
(
  id bigint not NULL,
  name varchar(128),
  constraint employee_main_pkey primary key (id)
);

-- Table: "employee_secondary"
drop table if exists employee_secondary cascade;
create table employee_secondary
(
  pk bigserial not null,
  batch integer not null,
  id bigint not null references employee_main(id),
  varchar_col1 varchar(128),
  
  constraint employee_secondary_pkey primary key (pk),
  unique (batch, id)
);

create or replace view employee as
select e.id as id, e.name as name, b1.varchar_col1 as address, b2.varchar_col1 as position
from employee_main e
inner join employee_secondary b1
	on e.id = b1.id and b1.batch = 1
inner join employee_secondary b2
	on e.id = b2.id and b2.batch = 2	
;

create or replace rule employee_rule_insert as on insert to employee do instead (
		insert into employee_main(id, name) values(new.id, new.name);
		insert into employee_secondary(batch, id, varchar_col1) values(1, new.id, new.address);
		insert into employee_secondary(batch, id, varchar_col1) values(2, new.id, new.position);
);

create or replace rule employee_rule_update as on update to employee do instead (
		update employee_main set name = new.name where id = old.id;
		update employee_secondary set varchar_col1 = new.address where id = old.id and batch = 1;
		update employee_secondary set varchar_col1 = new.position where id = old.id and batch = 2;
);

create or replace rule employee_rule_delete as on delete to employee do instead (
		delete from employee_secondary where id = old.id;
		delete from employee_main where id = old.id;
);

/*
drop rule if exists employee_rule_insert on employee cascade; 
drop rule if exists employee_rule_update on employee cascade; 
drop rule if exists employee_rule_delete on employee cascade; 
*/


insert into employee(id, name, address, position) 
      values(1, 'Victor', 'Moscow', 'Developer');
insert into employee(id, name, address, position) 
      values(2, 'Vadim', 'Moscow', 'Project Manager');
      
update employee set 
   position = 'Senior Developer',
   address = 'California'
where name = 'Victor';

delete from employee where name = 'Vadim';
