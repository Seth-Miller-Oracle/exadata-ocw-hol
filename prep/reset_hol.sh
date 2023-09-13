#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 [ -s sys_user_password | -c connect_string ] [ -n user_name ]"
  echo "          [ -p ] [ -h ]"
  echo
  echo "s     SYS user password."
  echo "c     EZ Connect connection string to the PDB in the form of scan_name/service_name."
  echo "n     Schema name."
  echo "p     Preview commands without executing them."
  echo "h     Print this Help."
  echo
}

exit_abnormal() {
  usage
  exit 1
}


# Parameters

while getopts s:c:n:ph flag
do
    case "${flag}" in
        s) sys_user_password=${OPTARG};;
        c) connect_string=${OPTARG};;
        n) user_name=${OPTARG};;
        p) preview=True;;
        h) usage; exit;;
	:) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


PREVIEW=${preview:=False}


# Variables

SQLPLUS_SYS="sqlplus -s sys/\"${sys_user_password:?}\"@${connect_string:?} AS SYSDBA"
SQL_SETUP='SET ECHO ON
SET TERMOUT OFF
SET FEEDBACK ON
SET LINESIZE 150
WHENEVER SQLERROR CONTINUE'


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
        select 'successful sqlplus execution' sqlplus_check from dual;
EOF

    if [[ $? -ne 0 ]]; then
        echo "sqlplus not working, check environment"
        exit
    fi
fi


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
