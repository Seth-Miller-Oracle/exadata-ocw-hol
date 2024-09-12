#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 [ -p sys_user_password ] [ -s scan_name ] [ -n database_name ] [ -u user_name ] [ -d pdb_name ]"
  echo "          [ -p ] [ -h ]"
  echo
  echo "p     SYS user password."
  echo "s     SCAN name."
  echo "n     Database name."
  echo "u     User name."
  echo "d     PDB name suffix."
  echo "p     Preview commands without executing them."
  echo "h     Print this Help."
  echo
}

exit_abnormal() {
  usage
  exit 1
}


# Parameters

while getopts p:s:n:u:d:rh flag
do
    case "${flag}" in
        p) sys_user_password=${OPTARG};;
        s) scan_name=${OPTARG};;
        n) database_name=${OPTARG};;
        u) user_name=${OPTARG};;
        d) pdb_name=${OPTARG};;
        r) preview=True;;
        h) usage; exit;;
	:) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


PREVIEW=${preview:=False}


# Variables

SQLPLUS_SYS="sqlplus -s sys/\"${sys_user_password?}\"@${scan_name?}/${database_name?} AS SYSDBA"

SQL_SETUP='SET ECHO ON
SET TERMOUT OFF
SET FEEDBACK ON
SET LINESIZE 150
WHENEVER SQLERROR CONTINUE'

SQL_SETUP2='SET HEADING OFF
SET FEEDBACK OFF
SET NEWPAGE NONE
SET MARKUP CSV ON'

SQL_PDB="alter session set container = ${database_name?}_${pdb_name?};"

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

query_db () {
    local conn=$1
    local comm=$2

    if [[ "$PREVIEW" = "True" ]]; then
        echo >&2
        echo "$conn << EOF" >&2
        echo "$comm" >&2
        echo "EOF" >&2
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


echo
echo "----------------------------------------------------"
echo
echo ${database_name?}
echo


SQL_COMMAND="$SQL_SETUP2
$SQL_PDB
SELECT COUNT(*) FROM dba_tables
WHERE owner = '${user_name^^?}'
AND table_name = 'MYCUST_ARCHIVE';
"
mycust_archive_var=$(query_db "$SQLPLUS_SYS" "$SQL_COMMAND")

SQL_COMMAND="$SQL_SETUP2
$SQL_PDB
SELECT COUNT(*) FROM dba_tables
WHERE owner = '${user_name^^?}'
AND table_name = 'MYCUST_QUERY';
"
mycust_query_var=$(query_db "$SQLPLUS_SYS" "$SQL_COMMAND")

SQL_COMMAND="$SQL_SETUP2
$SQL_PDB
SELECT COUNT(*) FROM dba_tables
WHERE owner = '${user_name^^?}'
AND table_name = 'CUSTOMERS_FC';
"
customers_fc_var=$(query_db "$SQLPLUS_SYS" "$SQL_COMMAND")

SQL_COMMAND="$SQL_SETUP2
SELECT COUNT(*) FROM cdb_pdbs
WHERE pdb_name = '${database_name^^?}_FULL_CLONE';
"
full_clone_var=$(query_db "$SQLPLUS_SYS" "$SQL_COMMAND")

SQL_COMMAND="$SQL_SETUP2
SELECT COUNT(*) FROM cdb_pdbs
WHERE pdb_name = '${database_name^^?}_THIN_CLONE';
"
thin_clone_var=$(query_db "$SQLPLUS_SYS" "$SQL_COMMAND")


if [[ ${mycust_archive_var?} != "0" ]]; then
    SQL_COMMAND="$SQL_SETUP
    $SQL_PDB
    DROP TABLE ${user_name?}.mycust_archive PURGE;
    "
    run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
fi

if [[ ${mycust_query_var?} != "0" ]]; then
    SQL_COMMAND="$SQL_SETUP
    $SQL_PDB
    DROP TABLE ${user_name?}.mycust_query PURGE;
    "
    run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
fi

if [[ ${customers_fc_var?} != "0" ]]; then
    SQL_COMMAND="$SQL_SETUP
    $SQL_PDB
    DROP TABLE ${user_name?}.customers_fc PURGE;
    "
    run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
fi

if [[ ${full_clone_var?} != "0" ]]; then
    SQL_COMMAND="$SQL_SETUP
    DROP PLUGGABLE DATABASE ${database_name?}_full_clone INCLUDING DATAFILES;
    "
    run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
fi

if [[ ${thin_clone_var?} != "0" ]]; then
    SQL_COMMAND="$SQL_SETUP
    DROP PLUGGABLE DATABASE ${database_name?}_thin_clone INCLUDING DATAFILES;
    "
    run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
fi



SQL_COMMAND="$SQL_SETUP
$SQL_PDB
create table ${user_name?}.customers_fc as
select * from ${user_name?}.customers_org
where 1=0;

INSERT /*+ APPEND PARALLEL(4) */ INTO ${user_name?}.customers_fc
SELECT * FROM ${user_name?}.customers_org;

commit;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


SQL_COMMAND="$SQL_SETUP
$SQL_PDB
select cust_gender, count(*) from ${user_name?}.customers
where cust_income_level = 'C: 50,000 - 69,999'
group by cust_gender;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"


SQL_COMMAND="$SQL_SETUP
$SQL_PDB
truncate table ${user_name?}.fc_lab;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"

echo
echo "===================================================="
echo
