set search_path to test;

-- Table: "employee_main"
drop table if exists employee_main cascade;
create table employee_main
(
  id bigserial not NULL,
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

create or replace function employee_view_dml()
returns trigger
language plpgsql
as $function$
   declare
      new_id int;
   begin
      if TG_OP = 'INSERT' then
         insert into employee_main(name) values(new.name) returning id into new_id;
         insert into employee_secondary(batch, id, varchar_col1) values(1, new_id, new.address);
         insert into employee_secondary(batch, id, varchar_col1) values(2, new_id, new.position);
         return new;
      elsif TG_OP = 'UPDATE' then
         update employee_main set name = new.name where id = old.id;
         update employee_secondary set varchar_col1 = new.address where id = old.id and batch = 1;
         update employee_secondary set varchar_col1 = new.position where id = old.id and batch = 2;
         return new;
      elsif TG_OP = 'DELETE' then
         delete from employee_secondary where id = old.id;
         delete from employee_main where id = old.id;
         return null;
      end if;
      return new;
    end;
$function$;

create trigger employee_view_dml_trig
   instead of insert or update or delete on
      employee for each row execute procedure employee_view_dml();

insert into employee(name, address, position) 
      values('Victor', 'Moscow', 'Developer');
insert into employee(name, address, position) 
      values('Vadim', 'Moscow', 'Project Manager');
      
update employee set 
   position = 'Senior Developer',
   address = 'California'
where name = 'Victor';

delete from employee where name = 'Vadim';