
#!/usr/bin/sh


# Parameters

while getopts s:p:c:n: flag
do
    case "${flag}" in
        s) sys_user=${OPTARG};;
        p) sys_user_password=${OPTARG};;
        c) connect_string=${OPTARG};;
        n) user_name=${OPTARG};;
    esac
done


# Variables

sys_user=${sys_user:-sys}


SQLPLUS_SYS="sqlplus -s ${sys_user:?}/\"${sys_user_password:?}\"@${connect_string:?} AS SYSDBA"
SQL_SETUP='SET ECHO ON
SET TERMOUT OFF
SET FEEDBACK ON
SET LINESIZE 150
WHENEVER SQLERROR CONTINUE'


# Functions

run_sqlplus () {
    local conn=$1
    local comm=$2

    $conn << EOF
    $comm
EOF
}


echo
echo "----------------------------------------------------"
echo
echo ${connect_string:?}
echo


SQL_COMMAND="$SQL_SETUP
DROP TABLE ${user_name:?}.mycust_archive PURGE;
DROP TABLE ${user_name:?}.mycust_query PURGE;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


SQL_COMMAND="$SQL_SETUP
drop table ${user_name:?}.customers_fc purge;

create table ${user_name:?}.customers_fc as
select * from ${user_name:?}.customers_org
where 1=0;

INSERT /*+ APPEND PARALLEL(4) */ INTO ${user_name:?}.customers_fc
SELECT * FROM ${user_name:?}.customers_org;

commit;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


SQL_COMMAND="$SQL_SETUP
select cust_gender, count(*) from ${user_name:?}.customers
where cust_income_level = 'C: 50,000 - 69,999'
group by cust_gender;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


echo
echo "===================================================="
echo
