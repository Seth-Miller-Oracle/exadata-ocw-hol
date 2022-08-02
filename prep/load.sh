#!/bin/bash


# Parameters

while getopts s:p:c:r: flag
do
    case "${flag}" in
        s) sys_user=${OPTARG};;
        p) sys_user_password=${OPTARG};;
        c) connect_string=${OPTARG};;
        r) preview=${OPTARG};;
    esac
done


# Variables

SYS_USER=${sys_user:-sys}
SYS_USER_PASSWORD=${sys_user_password:-Oracle_4U}
CONNECT_STRING=${connect_string}
USER_NAME='sh'
USER_PASSWORD='Oracle_4U'
USER_TABLESPACE='users'
DATA_PUMP_OS_DIR='/home/oracle/ocw_exports'
DATA_PUMP_DB_DIR='ocw_exports'
DATA_PUMP_PREFIX='ocw_lab_tables'  # dump file will be ${DATA_PUMP_PREFIX}.dmp


if [[ "${preview:0:1}" = "T" || "${preview:0:1}" = "t" ]]
then PREVIEW='True'
else PREVIEW='False'
fi

SQLPLUS_SYS="sqlplus -s ${SYS_USER:?}/\"${SYS_USER_PASSWORD:?}\"@${CONNECT_STRING:?} AS SYSDBA"
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
        #echo "exit code: $?"
    fi
}


# Make sure sqlplus works

if [[ "$PREVIEW" = "False" ]]; then
    $SQLPLUS_SYS << EOF
        select 'successful sqlplus execution' from dual;
EOF

    if [[ $? -ne 0 ]]; then
        echo "sqlplus not working, check environment"
        exit
    fi
fi


# Create SH tablespace and user

SQL_COMMAND="$SQL_SETUP
CREATE TABLESPACE ${USER_TABLESPACE?} DATAFILE SIZE 4G AUTOEXTEND ON NEXT 1G;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE USER ${USER_NAME?} IDENTIFIED BY ${USER_PASSWORD?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
ALTER USER ${USER_NAME?} DEFAULT TABLESPACE ${USER_TABLESPACE?}
    QUOTA UNLIMITED ON ${USER_TABLESPACE?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


# Import table data

SQL_COMMAND="$SQL_SETUP
CREATE DIRECTORY ${DATA_PUMP_DB_DIR?} AS '${DATA_PUMP_OS_DIR?}';
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

OS_COMMAND=("impdp \"'${SYS_USER:?}/${SYS_USER_PASSWORD:?}@${CONNECT_STRING:?} AS SYSDBA'\" dumpfile=${DATA_PUMP_PREFIX?}.dmp directory=${DATA_PUMP_DB_DIR} logfile=imp_${DATA_PUMP_PREFIX?}.log")
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
GRANT SELECT ON v_\$mystat TO ${USER_NAME?};
GRANT SELECT ON v_\$statname TO ${USER_NAME?};
GRANT EXECUTE ON flush_buffer_cache TO ${USER_NAME?};
GRANT EXECUTE ON flush_shared_pool TO ${USER_NAME?};
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


# Create user tables

SQL_COMMAND="$SQL_SETUP
WHENEVER SQLERROR CONTINUE
DROP TABLE ${USER_NAME?}.mycust_archive PURGE;
DROP TABLE ${USER_NAME?}.mycust_query PURGE;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${USER_NAME?}.sales AS
SELECT * FROM ${USER_NAME?}.sales_org WHERE 1=0;

BEGIN
FOR i IN 1 .. 64 LOOP
INSERT /*+ APPEND PARALLEL(4) */ INTO ${USER_NAME?}.sales
SELECT * FROM ${USER_NAME?}.sales_org;
COMMIT;
END LOOP;
END;
/
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${USER_NAME?}.customers_tmp AS
SELECT * FROM ${USER_NAME?}.customers_org WHERE 1=0;

BEGIN
FOR i IN 1 .. 155 LOOP
INSERT /*+ APPEND PARALLEL(4) */ INTO ${USER_NAME?}.customers_tmp
SELECT * FROM ${USER_NAME?}.customers_org;
COMMIT;
END LOOP;
END;
/
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${USER_NAME?}.customers AS
SELECT * FROM ${USER_NAME?}.customers_org
WHERE 1=0;

INSERT /*+ APPEND */ INTO ${USER_NAME?}.customers
SELECT * FROM ${USER_NAME?}.customers_tmp
ORDER BY cust_income_level;

COMMIT;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

SQL_COMMAND="$SQL_SETUP
CREATE TABLE ${USER_NAME?}.customers_fc AS
SELECT * FROM ${USER_NAME?}.customers_org
WHERE 1=0;

BEGIN
FOR i IN 1 .. 10 LOOP
INSERT /*+ APPEND PARALLEL(4) */ INTO ${USER_NAME?}.customers_fc
SELECT * FROM ${USER_NAME?}.customers_org;
COMMIT;
END LOOP;
END;
/
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
