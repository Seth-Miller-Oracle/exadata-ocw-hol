# dbca -silent -deleteDatabase -sourceDB studenta -sysDBAUserName sys -sysDBAPassword Oracle_4U

nohup dbca -silent \
-createDatabase \
-templateName General_Purpose.dbc \
-gdbName studenta \
-sid studenta \
-nodeList 'exa10db01,exa10db02' \
-createAsContainerDatabase true \
-numberOfPdbs 0 \
-pdbadminUsername pdbadmin \
-pdbadminPassword Oracle_4U \
-SysPassword Oracle_4U \
-SystemPassword Oracle_4U \
-emConfiguration NONE \
-datafileDestination '+DATAC1' \
-storageType ASM \
-characterSet AL32UTF8 \
-asmsnmpPassword Oracle_4U \
-diskGroupName '+DATAC1' \
-recoveryGroupName '+RECOC1' \
-databaseConfType RAC \
-automaticMemoryManagement FALSE \
-initParams 'sga_target=10G,pga_aggregate_target=5G' &