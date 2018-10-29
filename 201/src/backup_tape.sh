#!/bin/bash
# A UNIX / Linux shell script to backup dirs to tape device like /dev/st0 (linux)
# This script make both full and incremental backups.
# You need at two sets of five  tapes. Label each tape as Mon, Tue, Wed, Thu and Fri.
# You can run script at midnight or early morning each day using cronjons.
# The operator or sys admin can replace the tape every day after the script has done.
# Script must run as root or configure permission via sudo.
# -------------------------------------------------------------------------
# Copyright (c) 1999 Vivek Gite <vivek@nixcraft.com>
# This script is licensed under GNU GPL version 2.0 or above
# -------------------------------------------------------------------------
# This script is part of nixCraft shell script collection (NSSC)
# Visit http://bash.cyberciti.biz/ for more information.
# -------------------------------------------------------------------------
# Last updated on : March-2003 - Added log file support.
# Last updated on : Feb-2007 - Added support for excluding files / dirs.
# -------------------------------------------------------------------------
LOGBASE=/root/backup/log
 
# Backup dirs; do not prefix /
BACKUP_ROOT_DIR="home sales"
 
# Get todays day like Mon, Tue and so on
NOW=$(date +"%a")
 
# Tape devie name
TAPE="/dev/st0"
 
# Exclude file
TAR_ARGS=""
EXCLUDE_CONF=/root/.backup.exclude.conf
 
# Backup Log file
LOGFIILE=$LOGBASE/$NOW.backup.log
 
# Path to binaries
TAR=/bin/tar
MT=/bin/mt
MKDIR=/bin/mkdir
 
# ------------------------------------------------------------------------
# Excluding files when using tar
# Create a file called $EXCLUDE_CONF using a text editor
# Add files matching patterns such as follows (regex allowed):
# home/vivek/iso
# home/vivek/*.cpp~
# ------------------------------------------------------------------------
[ -f $EXCLUDE_CONF ] && TAR_ARGS="-X $EXCLUDE_CONF"
 
#### Custom functions #####
# Make a full backup
full_backup(){
	local old=$(pwd)
	cd /
	$TAR $TAR_ARGS -cvpf $TAPE $BACKUP_ROOT_DIR
	$MT -f $TAPE rewind
	$MT -f $TAPE offline
	cd $old
}
 
# Make a  partial backup
partial_backup(){
	local old=$(pwd)
	cd /
	$TAR $TAR_ARGS -cvpf $TAPE -N "$(date -d '1 day ago')" $BACKUP_ROOT_DIR
	$MT -f $TAPE rewind
	$MT -f $TAPE offline
	cd $old
}
 
# Make sure all dirs exits
verify_backup_dirs(){
	local s=0
	for d in $BACKUP_ROOT_DIR
	do
		if [ ! -d /$d ];
		then
			echo "Error : /$d directory does not exits!"
			s=1
		fi
	done
	# if not; just die
	[ $s -eq 1 ] && exit 1
}
 
#### Main logic ####
 
# Make sure log dir exits
[ ! -d $LOGBASE ] && $MKDIR -p $LOGBASE
 
# Verify dirs
verify_backup_dirs
 
# Okay let us start backup procedure
# If it is monday make a full backup;
# For Tue to Fri make a partial backup
# Weekend no backups
case $NOW in
	Mon)	full_backup;;
	Tue|Wed|Thu|Fri) 	partial_backup;;
	*) ;;
esac > $LOGFIILE 2>&1
