#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 <-p sys_user_password> <-s scan_name> <-n database_name> <-d pdb_name> <-g|-v> <-f file_dest>"
  echo "          [-u db_user_name] [-w db_user_password] [-r] [-h]"
  echo
  echo "  -p sys_user_password   SYS user password"
  echo "  -s scan_name           SCAN name"
  echo "  -n database_name       database name"
  echo "  -d pdb_name            PDB name suffix; PDB name will be <database_name>_<pdb_name>"
  echo "  -g                     use a disk group (ASM) for database file storage; file_dest prefix will be '+'"
  echo "  -v                     use a vault (Exascale> for database file storage; file_dest prefix will be '@'"
  echo "  -f file_dest           database file destination path suffix;"
  echo "                           file destination path will be <+|@><database_name>_<file_dest>"
  echo "  -u db_user_name        database user name; must start with 'C##'; defaults to 'C##SH'"
  echo "  -w db_user_password    database user password; defaults to sys_user_password"
  echo "  -r                     preview commands without executing them"
  echo "  -h                     print this help"
  echo
}

exit_abnormal() {
  usage
  exit 1
}


# Parameters

while getopts p:s:n:d:gvf:u:w:rh flag
do
    case "${flag}" in
        p) sys_user_password=${OPTARG};;
        s) scan_name=${OPTARG};;
        n) database_name=${OPTARG};;
        d) pdb_name=${OPTARG};;
        g) file_dest_asm=True;;
        v) file_dest_exascale=True;;
        f) file_dest_suffix=${OPTARG};;
        u) db_user_name=${OPTARG};;
        w) db_user_password=${OPTARG};;
        r) preview=True;;
        h) usage; exit;;
	    :) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


if [[ "$file_dest_asm" = "True" && "$file_dest_exascale" = "True" ]]; then
    echo "Invalid option. Choose either -g or -v, not both."
    exit_abnormal
elif [[ "$file_dest_asm" = "True" ]]; then
    file_dest="+${database_name?}_${file_dest_suffix?}"
elif [[ "$file_dest_exascale" = "True" ]]; then
    file_dest="@${database_name?}_${file_dest_suffix?}"
else
    echo "Invalid option. Choose either -g or -v."
    exit_abnormal
fi

PREVIEW=${preview:=False}
db_user_name=${db_user_name:=C##SH}
db_user_password=${db_user_password:=${sys_user_password?}}


# Variables

SQLPLUS_SYS="sqlplus -s sys/\"${sys_user_password?}\"@${scan_name?}/${database_name?} AS SYSDBA"
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


SQL_COMMAND="$SQL_SETUP
create user ${db_user_name?} identified by ${db_user_password?};
grant sysdba to ${db_user_name?} container=all;

create pluggable database ${database_name?}_${pdb_name?} admin user pdbadmin identified by ${sys_user_password?};
alter pluggable database ${database_name?}_${pdb_name?} open restricted;
alter session set container=${database_name?}_${pdb_name?};

create temporary tablespace temp_pdb tempfile '${file_dest?}' size 100m autoextend on next 100m maxsize unlimited;
alter database default temporary tablespace temp_pdb;
drop tablespace temp including contents and datafiles;
create temporary tablespace temp tempfile '${file_dest?}' size 100m autoextend on next 100m maxsize unlimited;
alter database default temporary tablespace temp;
drop tablespace temp_pdb including contents and datafiles;

alter session set container=CDB\$ROOT;
alter pluggable database ${database_name?}_${pdb_name?} close immediate instances=all;
alter pluggable database ${database_name?}_${pdb_name?} open instances=all;
"

run_sqlplus "$SQLPLUS_SYS" "$SQL_COMMAND"
