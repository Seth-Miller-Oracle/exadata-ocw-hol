#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 [ -f target_list_file | -t target_list ] [ -u database_name ] [ -e template_name ]"
  echo "          [ -o oracle_sid ] [ -n node_list ] [ -s sys_password ] [ -d data_disk_group ]"
  echo "          [ -r reco_disk_group ] [ -p ] [ -h ]"
  echo
  echo "f     A file containing the list of databases to create. The target names must be space delimited on a single line."
  echo "t     One or more database names to create. The target names must be space delimited in quotes."
  echo "u     Database name (DB_NAME). Defaults to the target name."
  echo "e     The name of the DBCA template. Defaults to General_Purpose.dbc."
  echo "o     Oracle SID (ORACLE_SID). Defaults to the target name."
  echo "n     List of RAC node names. The node names must be comma delimited in quotes."
  echo "s     SYS user password."
  echo "d     ASM data disk group."
  echo "r     ASM reco disk group."
  echo "p     Preview commands without executing them."
  echo "h     Print this Help."
  echo
}

exit_abnormal() {
  usage
  exit 1
}

# Parameters

while getopts f:t:u:e:o:n:s:d:r:ph flag
do
    case "${flag}" in
        f) for_list=${OPTARG};;
        t) target_list=${OPTARG};;
        u) database_name=${OPTARG};;
        e) template_name=${OPTARG};;
        o) oracle_sid=${OPTARG};;
        n) node_list=${OPTARG};;
        s) sys_password=${OPTARG};;
        d) data_dg=${OPTARG};;
        r) reco_dg=${OPTARG};;
        p) preview=True;;
        h) usage; exit;;
	:) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


PREVIEW=${preview:=False}

template_name=${template_name:-General_Purpose.dbc}


run_dbca () {
    expo="export CV_ASSUME_DISTID=OL7"
    conn=$(echo "dbca -silent \
        -ignorePrereqFailure \
        -createDatabase \
        -templateName ${template_name?} \
        -gdbName ${database_name?} \
        -sid ${oracle_sid?} \
        -nodeList ${node_list?} \
        -createAsContainerDatabase true \
        -numberOfPdbs 0 \
        -SysPassword ${sys_password?} \
        -SystemPassword ${sys_password?} \
        -emConfiguration NONE \
        -datafileDestination ${data_dg?} \
        -storageType ASM \
        -characterSet AL32UTF8 \
        -asmsnmpPassword ${sys_password?} \
        -diskGroupName ${data_dg?} \
        -recoveryGroupName ${reco_dg?} \
        -databaseConfType RAC \
        -automaticMemoryManagement FALSE \
        -initParams 'sga_target=5G,pga_aggregate_target=5G,processes=500'" | tr -s ' ')

    if [[ "$PREVIEW" = "True" ]]; then
        echo
        echo "$expo"
        echo "$conn"
        echo
    else
        echo
        echo "$expo"
        echo "$conn"
        echo
        $expo
        $conn
    fi
}

if [[ -n "$for_list" && -f "$for_list" ]]; then
    echo "Using for_list \"$for_list\""

    for i in $(cat ${for_list}); do
        database_name=${i?}
        oracle_sid=${i?}
        run_dbca
    done
    
elif [[ -n "$target_list" ]]; then
    echo "Using target_list \"$target_list\""

    for i in ${target_list}; do
        database_name=${i?}
        oracle_sid=${i?}
        run_dbca
    done

else
    echo "Must use -f or -t"

fi
