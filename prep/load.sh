#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 <-p sys_user_password> [-u db_user_name] [-w db_user_password] [-t db_user_tablespace]"
  echo "          <-o data_pump_os_dir> <-d data_pump_db_dir> <-f data_pump_prefix> <-c connect_string>"
  echo "          [-r] [-h]"
  echo
  echo "  -p sys_user_password    SYS user password"
  echo "  -u db_user_name         database user name; defaults to 'SH'"
  echo "  -w db_user_password     database user password; defaults to sys_user_password"
  echo "  -t db_user_tablespace   database user tablespace; defaults to 'USERS'"
  echo "  -o data_pump_os_dir     operating system directory containing Data Pump dump file"
  echo "  -d data_pump_db_dir     Data Pump database directory name"
  echo "  -f data_pump_prefix     file prefix for Data Pump dump and log files"
  echo "  -c connect_string       EZ Connect connect string"
  echo "  -r                      preview commands without executing them"
  echo "  -h                      print this help"
  echo
}

exit_abnormal() {
  usage
  exit 1
}

# Parameters

while getopts p:u:w:t:o:d:f:c:rh flag
do
    case "${flag}" in
        p) sys_user_password=${OPTARG};;
        u) db_user_name=${OPTARG};;
        w) db_user_password=${OPTARG};;
        t) db_user_tablespace=${OPTARG};;
        o) data_pump_os_dir=${OPTARG};;
        d) data_pump_db_dir=${OPTARG};;
        f) data_pump_prefix=${OPTARG};;
        c) connect_string=${OPTARG};;
        r) preview=True;;
        h) usage; exit;;
    	:) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


PREVIEW=${preview:=False}
db_user_name=${db_user_name:=SH}
db_user_password=${db_user_password:=${sys_user_password?}}
db_user_tablespace=${db_user_tablespace:=USERS}


SQLPLUS_SYS="sqlplus -s sys/\"${sys_user_password?}\"@${connect_string?} AS SYSDBA"
SQL_SETUP='SET ECHO ON
SET TERMOUT OFF
SET FEEDBACK ON
SET LINESIZE 150
WHENEVER SQLERROR EXIT SQL.SQLCODE'


# Functions

run_sqlplus () {
    local conn=$1
    local comm=$2

    if [[ "$PREVIEW" = "True" ]]; then
        echo
        echo "$conn << EOF"
        echo "$comm"
        echo "EOF"
    else
        $conn << EOF
        $comm
EOF
    fi
}


# Make sure sqlplus works

if [[ "$PREVIEW" = "False" ]]; then
    $SQLPLUS_SYS << EOF
        select 'successful sqlplus execution' sqlplus_check from dual;
EOF

    if [[ $? -ne 0 ]]; then
        echo "sqlplus not working, check environment"
        exit
    fi
fi


# Create SH tablespace and user

SQL_COMMAND="$SQL_SETUP
CREATE TABLESPACE ${user_tablespace?} DATAFILE SIZE 4G AUTOEXTEND ON NEXT 1G;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE USER ${user_name?} IDENTIFIED BY ${user_password?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
ALTER USER ${user_name?} DEFAULT TABLESPACE ${user_tablespace?}
    QUOTA UNLIMITED ON ${user_tablespace?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


# Import table data

SQL_COMMAND="$SQL_SETUP
CREATE DIRECTORY ${data_pump_db_dir?} AS '${data_pump_os_dir?}';
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

OS_COMMAND=("impdp \"'sys/${sys_user_password?}@${connect_string?} AS SYSDBA'\" dumpfile=${data_pump_prefix?}.dmp directory=${data_pump_db_dir} logfile=imp_${data_pump_prefix?}.log")
if [[ "$PREVIEW" = "True" ]]; then
 echo
 echo "${OS_COMMAND[@]}"
else
 eval "${OS_COMMAND[@]}"
fi


# Create database procedures

SQL_COMMAND="$SQL_SETUP
@flush_buffer_cache.sql
@flush_shared_pool.sql
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


# Grant user additional privileges

SQL_COMMAND="$SQL_SETUP
GRANT CONNECT TO ${user_name?};
GRANT CREATE TABLE TO ${user_name?};
GRANT SELECT ON v_\$sysstat TO ${user_name?};
GRANT SELECT ON v_\$mystat TO ${user_name?};
GRANT SELECT ON v_\$statname TO ${user_name?};
GRANT EXECUTE ON flush_buffer_cache TO ${user_name?};
GRANT EXECUTE ON flush_shared_pool TO ${user_name?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


# Create user tables

SQL_COMMAND="$SQL_SETUP
WHENEVER SQLERROR CONTINUE
DROP TABLE ${user_name?}.mycust_archive PURGE;
DROP TABLE ${user_name?}.mycust_query PURGE;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${user_name?}.sales AS
SELECT * FROM ${user_name?}.sales_org WHERE 1=0;

BEGIN
FOR i IN 1 .. 64 LOOP
INSERT /*+ APPEND PARALLEL(4) */ INTO ${user_name?}.sales
SELECT * FROM ${user_name?}.sales_org;
COMMIT;
END LOOP;
END;
/
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${user_name?}.customers_tmp AS
SELECT * FROM ${user_name?}.customers_org WHERE 1=0;

BEGIN
FOR i IN 1 .. 155 LOOP
INSERT /*+ APPEND PARALLEL(4) */ INTO ${user_name?}.customers_tmp
SELECT * FROM ${user_name?}.customers_org;
COMMIT;
END LOOP;
END;
/
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${user_name?}.customers AS
SELECT * FROM ${user_name?}.customers_org
WHERE 1=0;

INSERT /*+ APPEND */ INTO ${user_name?}.customers
SELECT * FROM ${user_name?}.customers_tmp
ORDER BY cust_income_level;

COMMIT;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${user_name?}.customers_fc AS
SELECT * FROM ${user_name?}.customers_org
WHERE 1=0;

INSERT /*+ APPEND PARALLEL(4) */ INTO ${user_name?}.customers_fc
SELECT * FROM ${user_name?}.customers_org;
COMMIT;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
SHUTDOWN IMMEDIATE
STARTUP
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
COLUMN tempfile NEW_VALUE tempfile
SELECT name tempfile FROM v\$tempfile;
ALTER DATABASE TEMPFILE '&tempfile' RESIZE 100M;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
COLUMN tempfile NEW_VALUE tempfile
SELECT name tempfile FROM v\$tempfile;
ALTER DATABASE TEMPFILE '&tempfile' RESIZE 100M;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
COLUMN tempfile NEW_VALUE tempfile
SELECT name tempfile FROM v\$tempfile;
ALTER DATABASE TEMPFILE '&tempfile' RESIZE 100M;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

