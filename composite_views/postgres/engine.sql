set search_path to flex;
drop table if exists entities cascade;
create table entities
(
  id bigserial not null,
  name varchar(128) not null,
  display_name varchar(128) not null,  
  constraint entities_pkey primary key (id)
);

drop table if exists fields cascade;
create table fields
(
  id bigserial not null,
  entities_id bigint not null  REFERENCES entities (id),
  name varchar(128) not null,
  display_name varchar(128) not null,  
  data_type_id bigint not null  REFERENCES data_types (id),
  is_flex boolean not null,
  batch_no int null,
  field_in_batch_no int null,
  constraint fields_pkey primary key (id)
);

drop table if exists data_types cascade;
create table data_types
(
  id bigserial not null,
  name varchar(128) not null,
  display_name varchar(128) not null,  
  sql_name varchar(128) unique not null,
  constraint data_types_pkey primary key (id)
);

drop table if exists entities_attr cascade;
create table entities_attr
(
  id bigserial not null,
  entities_id bigint not null  REFERENCES entities (id),
  data_type_id bigint not null  REFERENCES data_types (id),
  num_of_fields int null
  constraint entities_attr_pkey primary key (id)
);




create or replace function create_entity(
  IN entity_name varchar(128),
  IN entity_display_name varchar(128),
  IN base_entity_name varchar(128),
)
returns text -- NULL, if new entity created without error, otherwise error string
language plpgsql
as $function$
   declare
    entity_id bigint,
    base_entity_id bigint
   begin
      start transaction serializable 

        if exists (select 1 from entities where name = entity_name) then
          rollback;
          return 'Table with name = ' + entity_name + ' already exists';
        end if;
        if not exists (select 1 from entities where name = base_entity_name) then
          rollback;
          return 'Base table with name = ' + base_entity_name + ' doesn`t exist';
        end if;
        
        -- Main table creation
        create_table_like(entity_name + '_main', base_entity_name)
        create_table_like(entity_name + '_attrs', base_entity_name + '_attrs')
        insert into entities(name, display_name) values(entity_name, entity_display_name)
        select entity_id = id from entities where name = entity_name
        select base_entity_id = id from entities where name = base_entity_name
       
        insert into fields(name, display_name, is_flex, data_type_id, batch_no, field_in_batch_no) 
                    select name, display_name, is_flex, data_type_id, batch_no, field_in_batch_no
        from fields where entities_id = base_entity_id
        
        insert into entities_attr(entities_id, data_type_id, num_of_fields)
                          select  entities_id, data_type_id, num_of_fields
        from entities_attr where entities_id = base_entity_id
        
        generate_view(entity_id)
        generate_trigger(entity_id)
      
      commit;
    end;
$function$;

create or replace function generate_view ( -- creates view
  entity_id bigint
)
returns text -- NULL, if new entity created without error, otherwise error string
language plpgsql
as $function$  
  begin;
    
  end;
$function$;

create or replace view employee as
select e.id as id, e.name as name, b1.varchar_col1 as address, b2.varchar_col1 as position
from employee_main e
inner join employee_secondary b1
	on e.id = b1.id and b1.batch = 1
inner join employee_secondary b2
	on e.id = b2.id and b2.batch = 2	

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


/* For Postgres 9.2 or less, TODO: check foreign constrains on Postgres 9.4 */
create or replace function create_table_like(source text, newtable text)
returns void language plpgsql
as $$
declare
    _query text;
begin
    execute
        format(
            'create table %s (like %s including all)',
            newtable, source);
    for _query in
        select
            format (
                'alter table %s add constraint %s %s',
                newtable,
                replace(conname, source, newtable),
                pg_get_constraintdef(oid))
        from pg_constraint
        where contype = 'f' and conrelid = source::regclass
    loop
        execute _query;
    end loop;
end $$;
