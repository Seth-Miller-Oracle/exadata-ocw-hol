#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 [ -s sys_user_password | -c connect_string ] [ -d pdb_name ]"
  echo "          [ -p ] [ -h ]"
  echo
  echo "s     SYS user password."
  echo "c     EZ Connect connection string to the CDB in the form of scan_name/service_name."
  echo "d     PDB name."
  echo "p     Preview commands without executing them."
  echo "h     Print this Help."
  echo
}

exit_abnormal() {
  usage
  exit 1
}

# Parameters

while getopts s:c:d:ph flag
do
    case "${flag}" in
        s) sys_user_password=${OPTARG};;
        c) connect_string=${OPTARG};;
        d) pdb_name=${OPTARG};;
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


SQL_COMMAND="$SQL_SETUP
alter pluggable database ${pdb_name:?} open instances=all;
"
run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
