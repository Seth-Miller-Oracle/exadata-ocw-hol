#!/usr/bin/sh


usage() {
  
  echo "Usage: $0 <-f|-t target_list> <-b database_version> [-u database_name] [-e template_name]"
  echo "          [-o oracle_sid] <-n node_list> <-p sys_user_password> <-g|-v> <-d datafile_dest>"
  echo "          [-c recofile_dest] [-l] [-r] [-h]"
  echo
  echo "  -f target_list          a file containing the list of databases to create;"
  echo "                            the target names must be space delimited on a single line"
  echo "  -t target_list          one or more database names to create; the target names"
  echo "                            must be space delimited in quotes; e.g. 'target1 target2'"
  echo "  -b database_version     database version; must be '19' or '23'"
  echo "  -u database_name        database name (DB_NAME); defaults to the target name"
  echo "  -e template_name        the name of the DBCA template; defaults to 'General_Purpose.dbc'"
  echo "  -o oracle_sid           database service ID (ORACLE_SID); defaults to the target name"
  echo "  -n node_list            list of RAC node names; the node names must be comma delimited"
  echo "                            in quotes; e.g. 'node1,node2'"
  echo "  -p sys_user_password    SYS user password"
  echo "  -g                      use ASM as the database storage type"
  echo "  -v                      use Exascale as the database storage type"
  echo "  -d datafile_dest        datafile destination; if the storage type is ASM, this will be"
  echo "                            the data disk group and the datafile destination; if the storage"
  echo "                            type is Exascale this will be the datafile destination suffix;"
  echo "                            e.g. the datafile destination will be @<target_name>_<datafile_dest>"
  echo "  -c recofile_dest        recofile destination; if the storage type is ASM, this will be"
  echo "                            the reco disk group and the recofile destination; if the storage"
  echo "                            type is Exascale this will not be used"
  echo "  -l                      exports the parameter 'CV_ASSUME_DISTID=OL7' before running dbca"
  echo "  -r                      preview commands without executing them"
  echo "  -h                      print this help"
  echo
}

exit_abnormal() {
  usage
  exit 1
}

# Parameters

while getopts f:t:b:u:e:o:n:p:gvd:c:i:j:lrh flag
do
    case "${flag}" in
        f) file_list=${OPTARG};;
        t) line_list=${OPTARG};;
        b) db_version=${OPTARG};;
        u) database_name=${OPTARG};;
        e) template_name=${OPTARG};;
        o) oracle_sid=${OPTARG};;
        n) node_list=${OPTARG};;
        p) sys_user_password=${OPTARG};;
        g) storage_type_asm=True;;
        v) storage_type_exascale=True;;
        d) datafile_dest=${OPTARG};;
        c) recofile_dest=${OPTARG};;
        l) assume_ol7=True;;
        r) preview=True;;
        h) usage; exit;;
	:) echo "Error: -${OPTARG} requires an argument."
           exit_abnormal;;
        *) exit_abnormal;;
    esac
done


if [[ "$storage_type_asm" = "True" && "$storage_type_exascale" = "True" ]]; then
    echo "Invalid option. Choose either -g or -v, not both."
    exit_abnormal
elif [[ "$storage_type_asm" = "True" && (-z "$datafile_dest" || -z "$recofile_dest") ]]; then
    echo "Invalid option. If storage type is ASM, datafile_dest and recofile_dest must both be defined."
    exit_abnormal
elif [[ "$storage_type_asm" = "True" ]]; then
    storage_type=ASM
elif [[ "$storage_type_exascale" = "True" && -z "$datafile_dest" ]]; then
    echo "Invalid option. If storage type is EXASCALE, datafile_dest must be defined."
    exit_abnormal
elif [[ "$storage_type_exascale" = "True" ]]; then
    storage_type=EXASCALE
else
    echo "Invalid option. Choose either -g or -v."
    exit_abnormal
fi


if [[ -n "$file_list" && -n "$line_list" ]]; then
    echo "Invalid option. Choose either -f or -t, not both."
    exit_abnormal
elif [[ -n "$file_list" && ! -f "$file_list" ]]; then
    echo "Invalid option. The target_list must be a file."
    exit_abnormal
elif [[ -n "$file_list" ]]; then
    target_list=$(cat $file_list)
elif [[ -n "$line_list" ]]; then
    target_list=$line_list
else
    echo "Invalid option. Choose either -f or -t."
    exit_abnormal
fi


PREVIEW=${preview:=False}
OL7=${assume_ol7:=False}
template_name=${template_name:=General_Purpose.dbc}


# Functions

convert_file_dest () {
    local file_dest=$1
    local target=$2

    if [[ "$storage_type" = "ASM" && "$file_dest" = "data" ]]; then
        echo "+${datafile_dest}"
    elif [[ "$storage_type" = "ASM" && "$file_dest" = "reco" ]]; then
        echo "+${recofile_dest}"
    elif [[ "$storage_type" = "EXASCALE" ]]; then
        echo "@${target}_${datafile_dest}"
    fi
}


run_dbca () {
    local l_database_name=$1
    local l_oracle_sid=$2
    local l_datafile_dest=$3
    local l_recofile_dest=$4

    if [[ "${OL7}" = "True" ]]
        then expo="export CV_ASSUME_DISTID=OL7"
        else expo=""
    fi

    if [[ "${db_version}" = "23" ]]; then
        conn=$(echo "dbca -silent \
            -ignorePrereqFailure \
            -createDatabase \
            -templateName ${template_name?} \
            -gdbName ${l_database_name?} \
            -sid ${l_oracle_sid?} \
            -nodeList ${node_list?} \
            -createAsContainerDatabase true \
            -numberOfPdbs 0 \
            -SysPassword ${sys_user_password?} \
            -SystemPassword ${sys_user_password?} \
            -emConfiguration NONE \
            -storageType ${storage_type?} \
            -datafileDestination ${l_datafile_dest?} \
            -recoveryAreaDestination ${l_recofile_dest?} \
            -characterSet AL32UTF8 \
            -databaseConfType RAC \
            -automaticMemoryManagement FALSE" | tr -s ' ')

    elif [[ "${db_version}" = "19" ]]; then
        conn=$(echo "dbca -silent \
            -ignorePrereqFailure \
            -createDatabase \
            -templateName ${template_name?} \
            -gdbName ${database_name?} \
            -sid ${l_oracle_sid?} \
            -nodeList ${node_list?} \
            -createAsContainerDatabase true \
            -numberOfPdbs 0 \
            -SysPassword ${sys_user_password?} \
            -SystemPassword ${sys_user_password?} \
            -emConfiguration NONE \
            -datafileDestination ${l_datafile_dest?} \
            -storageType ${storage_type?} \
            -characterSet AL32UTF8 \
            -asmsnmpPassword ${sys_user_password?} \
            -diskGroupName ${datafile_dest?} \
            -recoveryGroupName ${l_recofile_dest?} \
            -databaseConfType RAC \
            -automaticMemoryManagement FALSE" | tr -s ' ')

    else exit_abnormal

    fi

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

for i in ${target_list}; do
    run_dbca "$i" "$i" $(convert_file_dest "data" "$i") $(convert_file_dest "reco" "$i")
done
