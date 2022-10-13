## Create SH tablespace and user

```
create tablespace users datafile size 4G autoextend on next 1G;

CREATE USER sh IDENTIFIED BY <password>;

ALTER USER sh DEFAULT TABLESPACE users
QUOTA UNLIMITED ON users;
```

## Import table data

If you have the datapump export for the lab, use these steps. If not, skip down to the SH sample schema install.

Put the datapump file in a directory on the server, then create a database directory object with the same path and load with data pump.
```
create directory ocw_hol as '/home/oracle/ocw_exports';

impdp dumpfile=ocw_lab_tables.dmp directory=ocw_hol logfile=imp_ocw_lab_tables.log
```

## Install SH sample schema

Only do this if you were not able to load the tables with the datapump export in the previous section.

https://github.com/oracle-samples/db-sample-schemas/releases

> Note: Only the Sales History schema is used. This command installs just the SH schema.
```
@/home/oracle/db-sample-schemas-19c/sales_history/sh_main &&password_sh &&default_ts &&temp_ts &&password_sys /home/oracle/db-sample-schemas-19c/sales_history/ &&logfile_dir v3 &&connect_string
```

## Procedures

```
prep/flush_buffer_cache.sql -- execute as sys
prep/flush_shared_pool.sql -- execute as sys
```

## Grants

```
grant connect to sh;
grant create table to sh
grant select on v_$sysstat to sh;
grant select on v_$mystat to sh;
grant select on v_$statname to sh;
grant execute on flush_buffer_cache to sh;
grant execute on flush_shared_pool to sh;
```

## Tables

Run all of the following commands as SH.

If the HCC practice has been done before, these tables will need to be dropped.
```
DROP TABLE mycust_archive PURGE;
DROP TABLE mycust_query PURGE;
```

Rename the sales table. This does not need to be done if it has been done previously or the schema was loaded from the data pump dump file.
```
alter table sales rename to sales_org;
```

Grow the sales table to 2G.
```
create table sales as
select * from sales_org where 1=0;

BEGIN
FOR i IN 1 .. 64 LOOP
insert /*+ APPEND PARALLEL(4) */ into sales
select * from sales_org;
commit;
END LOOP;
END;
/
```

Rename the customers table. This does not need to be done if it has been done previously or the schema was loaded from the data pump dump file.
```
alter table customers rename to customers_org;
```

Grow the customers table to 2G.
```
create table customers as
select * from customers_org
where 1=0;

insert /*+ APPEND */ into customers
select * from customers_tmp
order by cust_income_level;
commit;
```

Create a customers_tmp table and grow it to 2G.
```
create table customers_tmp as
select * from customers_org where 1=0;

BEGIN
FOR i IN 1 .. 155 LOOP
insert /*+ APPEND PARALLEL(4) */ into customers_tmp
select * from customers_org;
commit;
END LOOP;
END;
/
```

Create the customers_fc table for the flash cache exercise.
```
create table customers_fc as
select * from customers_org
where 1=0;

insert /*+ APPEND PARALLEL(4) */ into customers_fc
select * from customers_org;
commit;
```

## Student Environment

Create a local tnsnames.ora file.
```
mkdir -p ~/tnsadmin

echo "
DB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <database scan name>)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = <database service name>)
    )
  )" > ~/tnsadmin/tnsnames.ora
```

Add environment variables to shell source file (i.e. .bashrc or .bash_profile).
```
export TNS_ADMIN=~/tnsadmin
export TWO_TASK=DB
export PATH=<oracle home path>/bin:$PATH
export ORACLE_HOME=<oracle home path>
cd ~/files
```

## Miscellaneous

Only do this if you want to create a dump file from a fresh install of the sample schema.
Export the sales_org and customers_org tables
```
mkdir /home/oracle/ocw_exports

create directory ocw_hol as '/home/oracle/ocw_exports';

expdp dumpfile=ocw_lab_tables.dmp directory=ocw_hol logfile=exp_ocw_lab_tables.log tables=sh.sales_org,sh.customers_org exclude=constraint,grant
```