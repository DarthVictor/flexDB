-- Table: "employee_main"
use test 
go
if exists (select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'employee_secondary')
    drop table employee_secondary
go
if exists (select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'employee_main')
    drop table employee_main
go
create table employee_main
(
  id bigint not NULL,
  name varchar(128),
  constraint employee_main_pkey primary key (id)
)
go
-- Table: "employee_secondary"
if exists (select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'employee_secondary')
    drop table employee_secondary;
go
create table employee_secondary
(
  pk bigint identity(1,1) not null,
  batch integer not null,
  id bigint not null references employee_main(id),
  varchar_col1 varchar(128),
  
  constraint employee_secondary_pkey primary key (pk),
  unique (batch, id)
)

go
if exists (select * from INFORMATION_SCHEMA.VIEWS where TABLE_NAME = 'employee')
    drop view employee
go
create view employee as
select e.id as id, e.name as name, b1.varchar_col1 as address, b2.varchar_col1 as position
from employee_main e
inner join employee_secondary b1
	on e.id = b1.id and b1.batch = 1
inner join employee_secondary b2
	on e.id = b2.id and b2.batch = 2	
go

create trigger employee_view_insert on employee
instead of insert
as
   begin
      insert into employee_main(id, name) select id, name from inserted
      insert into employee_secondary(batch, id, varchar_col1) select 1, id, address from inserted
      insert into employee_secondary(batch, id, varchar_col1) select 2, id, position from inserted      
   end
go

create trigger employee_view_update on employee
instead of update
as
   begin
      update employee_main set 
         name = inserted.name 
      from employee_main
         inner join inserted 
            on employee_main.id = inserted.id
      
      update employee_secondary set 
         varchar_col1 = inserted.address 
      from employee_secondary
         inner join inserted 
            on employee_secondary.id = inserted.id
            and employee_secondary.batch = 1
      
      update employee_secondary set 
         varchar_col1 = inserted.position 
      from employee_secondary
         inner join inserted 
            on employee_secondary.id = inserted.id
            and employee_secondary.batch = 2   
   end
go

create trigger employee_view_delete on employee
instead of delete
as
   begin
      delete from employee_secondary where id in (select id from deleted)
      delete from employee_main where id in (select id from deleted)		
   end
go

insert into employee(id, name, address, position) 
      values(1, 'Victor', 'Moscow', 'Developer')
insert into employee(id, name, address, position) 
      values(2, 'Vadim', 'Moscow', 'Project Manager')
      
update employee set 
   position = 'Senior Developer',
   address = 'California'
where name = 'Victor'

delete employee where name = 'Vadim'
go