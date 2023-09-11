#!/usr/bin/sh


# Parameters

while getopts f:t:u:e:o:n:s:d:r:p: flag
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
        p) preview=${OPTARG};;
    esac
done


if [[ "${preview:0:1}" = "T" || "${preview:0:1}" = "t" ]]
    then PREVIEW='True'
    else PREVIEW='False'
fi

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
        -initParams 'sga_target=5G,pga_aggregate_target=5G'" | tr -s ' ')

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
