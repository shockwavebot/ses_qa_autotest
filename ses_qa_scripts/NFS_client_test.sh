#!/bin/bash
# This script is testing mount of NFS export with different mount options 
# USAGE:
# ./NFS_client_test.sh NFS_IP_ADDRESS

[[ -n $1 ]] && NFS_HA_IP=$1 || (echo ERROR: Missing NFS IP. ; exit 1)

timeout_limit=5   
# LOG_FILE=/tmp/NFS_HA_QA_test_$(date +%H_%M_%S).log
LOG_FILE=/tmp/NFS_HA_QA_test.log
> $LOG_FILE
MOUNT_OPTIONS_FILE=/tmp/mount_options_input_file
##### mount options input file #####
echo "\
mount.nfs4 -o rw,hard,intr,noatime
mount.nfs4 -o rw,soft,timeo=20,noatime 
mount -t nfs 
mount -t nfs -o rw,sync 
mount.nfs4 " > $MOUNT_OPTIONS_FILE
####################################
date >> $LOG_FILE
mount_target="${NFS_HA_IP}:/ /mnt"
# base64 /dev/urandom | head --bytes=10MB > /tmp/random.txt
openssl rand -base64 10000000 -out > /tmp/random.txt

function test_command_for_timeout {
  timeout $timeout_limit $command_to_test
  timeout_rc=$?
  if [[ $timeout_rc == 0 ]]
    then
    echo "INFO: command: [ $command_to_test ] finished OK" >> $LOG_FILE
    else
      echo "ERROR: command: [ $command_to_test ] timed out after $timeout_limit seconds" >> $LOG_FILE; exit 1 
    fi
}

# check if nothing mounted to /mnt, and if yes, force umount
mount|grep mnt && umount /mnt -f 

# test ping on a HA IP
ping -q -c 3 $NFS_HA_IP|grep " 0% packet loss" || ( echo "PING status: *** KO ***" >> $LOG_FILE;exit 1 )
echo "PING status: OK " >> $LOG_FILE

# TESTING
while read mount_options
do
# test mount 
command_to_test="$mount_options $mount_target"
test_command_for_timeout
# test ls
command_to_test="ls /mnt/cephfs"
test_command_for_timeout
# test write 
command_to_test="cp /tmp/random.txt /mnt/cephfs/nfs-ganesha_test_file_$(date +%H_%M_%S)"
test_command_for_timeout
# test read 
command_to_test="tail -n 1 /mnt/cephfs/nfs-ganesha_test_file_*"
test_command_for_timeout
# test umount 
command_to_test='umount /mnt'
test_command_for_timeout

done < $MOUNT_OPTIONS_FILE

date >> $LOG_FILE
exit 0