#!/usr/bin/sh


# Parameters

while getopts s:p:c:d: flag
do
    case "${flag}" in
        s) sys_user=${OPTARG};;
        p) sys_user_password=${OPTARG};;
        c) connect_string=${OPTARG};;
        d) pdb_name=${OPTARG};;
    esac
done


# Variables

sys_user=${sys_user:-sys}


SQLPLUS_SYS="sqlplus -s ${sys_user:?}/\"${sys_user_password:?}\"@${connect_string:?} AS SYSDBA"
SQL_SETUP='SET ECHO ON
SET TERMOUT OFF
SET FEEDBACK ON
SET LINESIZE 150
WHENEVER SQLERROR EXIT SQL.SQLCODE'


# Functions

run_sqlplus () {
    local conn=$1
    local comm=$2

    $conn << EOF
    $comm
EOF
}


SQL_COMMAND="$SQL_SETUP
create pluggable database ${pdb_name:?} admin user pdbadmin identified by ${sys_user_password:?};
alter pluggable database ${pdb_name:?} open instances=all;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"