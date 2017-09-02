#!/bin/bash

# OS: Solaris
# Version: 11
# Severity: CAT-II
# Class: UNCLASSIFIED
# VulnID: V-48033
# Name: SV-60905r2


# Default minimum permissions for log file(s)
file_perms=00640

# Default file(s) user
file_owner="root"

# Default file(s) group
file_group="root"

# Default minimum permissions for log folder(s)
folder_perms=00750

# Default file(s) user
folder_owner="root"

# Default file(s) group
folder_group="sys"

# An array of log file(s) to examine permissions on
declare -a files
files+=(/var/adm/messages)

# An array of log folders(s) to examine permissions on
declare -a folders
folders+=(/var/adm)


# Global defaults for tool
author=
verbose=0
change=0
restore=0
interactive=0

# Working directory
cwd="$(dirname $0)"

# Tool name
prog="$(basename $0)"


# Copy ${prog} to DISA STIG ID this tool handles
stigid="$(echo "${prog}" | cut -d. -f1)"


# Ensure path is robust
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin


# Define the library include path
lib_path=${cwd}/../../../libs

# Define the tools include path
tools_path=${cwd}/../../../stigs

# Define the system backup path
backup_path=${cwd}/../../../backups/$(uname -n | awk '{print tolower($0)}')


# Robot, do work


# Error if the ${inc_path} doesn't exist
if [ ! -d ${lib_path} ] ; then
  echo "Defined library path doesn't exist (${lib_path})" && exit 1
fi


# Include all .sh files found in ${lib_path}
incs=($(ls ${lib_path}/*.sh))

# Exit if nothing is found
if [ ${#incs[@]} -eq 0 ]; then
  echo "'${#incs[@]}' libraries found in '${lib_path}'" && exit 1
fi


# Iterate ${incs[@]}
for src in ${incs[@]}; do

  # Make sure ${src} exists
  if [ ! -f ${src} ]; then
    echo "Skipping '$(basename ${src})'; not a real file (block device, symlink etc)"
    continue
  fi

  # Include $[src} making any defined functions available
  source ${src}

done


# Ensure we have permissions
if [ $UID -ne 0 ] ; then
  usage "Requires root privileges" && exit 1
fi


# Set variables
while getopts "ha:cvri" OPTION ; do
  case $OPTION in
    h) usage && exit 1 ;;
    a) author=$OPTARG ;;
    c) change=1 ;;
    v) verbose=1 ;;
    r) restore=1 ;;
    i) interactive=1 ;;
    ?) usage && exit 1 ;;
  esac
done


# Make sure we have an author if we are not restoring or validating
if [[ "${author}" == "" ]] && [[ ${restore} -ne 1 ]] && [[ ${change} -eq 1 ]]; then
  usage "Must specify an author name (use -a <initials>)" && exit 1
fi


# If ${restore} = 1 go to restoration mode
if [ ${restore} -eq 1 ]; then

  # If ${interactive} = 1 go to interactive restoration mode
  if [ ${interactive} -eq 1 ]; then
  
    # Print friendly message regarding restoration mode
    [ ${verbose} -eq 1 ] && print "Interactive restoration mode for '${file}'"

  fi

  # Print friendly message regarding restoration mode
  [ ${verbose} -eq 1 ] && print "Restored '${file}'"

  exit 0
fi


# If ${#files[@]}} = 0 or ${#folders[@]}
if [[ ${#files[@]} -eq 0 ]] || [[ ${#folders[@]} -eq 0 ]]; then
  
  # Print friendly message regarding restoration mode
  [ ${verbose} -eq 1 ] && usage "Must define at least one log file(s) and log folder(s)" && exit 1
  exit 1
fi


# If ${change} > 0
if [ ${change} -ne 0 ]; then

  # Create the backup env
  backup_setup_env "${backup_path}"

  # Create a snapshot of ${inodes[@]} current permissions
  bu_inode_perms "${backup_path}" "${author}" "${stigid}" "${files[@]} ${folders[@]}"
  if [ $? -ne 0 ]; then

    # Print friendly message
    [ ${verbose} -eq 1 ] && print "Snapshot of current permissions for '${stigid}' failed..."

    # Stop, we require a backup
    exit 1
  fi

  # Print friendly message
  [ ${verbose} -eq 1 ] && print "Created snapshot of current permissions"
fi


# Capture current IFS value
cIFS=$IFS

# Set IFS to something else temporarilty
IFS=+


# Create an empty array for errors
declare -a errs


# Iterate ${files[@]}
for inode in ${files[@]}; do

  # Handle symlinks
  inode="$(get_inode ${inode})"

  # Make sure we are operating on a file
  if [ -f ${inode} ]; then

    # If ${change} = 1
    if [ ${change} -eq 1 ]; then

      # Set {$file_perms} on ${inode}
      chmod ${file_perms} ${inode} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set permissions on '${inode}' to '${file_perms}'")
      
      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set permissions on '${inode}' to '${file_perms}'"


      # Change owner to ${file_owner} on ${inode}
      chown ${file_owner} ${inode} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set ownership on '${inode}' to '${file_owner}'")

      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set owner on '${inode}' to '${file_owner}'"


      # Change group to ${file_group} on ${inode}
      chgrp ${file_group} ${inode} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set group ownership on '${inode}' to '${file_group}'")

      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set group on '${inode}' to '${file_group}'"
    fi

    # Get current octal value of ${inode}
    cperms="$(get_octal ${inode})"
    [ ${cperms} != ${file_perms} ] && errs+=("Permissions on '${inode}' are set to '${cperms}' vs. '${file_perms}'")

    # Get current owner of ${inode}
    cuser="$(get_inode_user ${inode})"
    [ "${cuser}" != "${file_owner}" ] && errs+=("Ownership on '${inode}' is '${cuser}' vs. '${file_owner}'")

    # Get current group owner of ${inode}
    cgroup="$(get_inode_group ${inode})"
    [ "${cgroup}" != "${file_group}" ] && errs+=("Group ownership on '${inode}' is '${cgroup}' vs. '${file_group}'")
  fi
done


# Iterate ${folders[@]}
for folder in ${folders[@]}; do

  # Handle symlinks
  folder="$(get_inode ${folder})"

  # Make sure we are dealing with a directory
  if [ -d ${folder} ]; then

    # If ${change} = 1
    if [ ${change} -eq 1 ]; then

      # Set ${folder_perms} on ${folder}
      chmod ${folder_perms} ${folder} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set permissions on '${folder}' to '${folder_perms}'")

      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set permissions on '${folder}' to '${folder_perms}'"


      # Change owner to ${folder_owner} on ${folder}
      chown ${folder_owner} ${folder} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set ownership on '${folder}' to '${folder_owner}'")

      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set owner on '${folder}' to '${folder_owner}'"


      # Change group to ${folder_group} on ${folder}
      chgrp ${folder_group} ${folder} 2> /dev/null
      [ $? -ne 0 ] && errs+=("Couldn't set group ownership on '${folder}' to '${folder_group}'")

      # Print friendly message
      [ ${verbose} -eq 1 ] && print "Set group on '${folder}' to '${folder_group}'"
    fi

    # Get current octal value of ${folder}
    cdperms="$(get_octal ${folder})"
    [ ${cdperms} != ${folder_perms} ] && errs+=("Permissions on '${folder}' are set to '${cdperms}' vs. '${folder_perms}'")

    # Get current owner of ${folder}
    cduser="$(get_inode_user ${folder})"
    [ "${cduser}" != "${folder_owner}" ] && errs+=("Ownership on '${folder}' is '${cduser}' vs. '${folder_owner}'")

    # Get current group owner of ${folder}
    cdgroup="$(get_inode_group ${folder})"
    [ "${cdgroup}" != "${folder_group}" ] && errs+=("Group ownership on '${folder}' is '${cdgroup}' vs. '${folder_group}'")
  fi
done


# If ${#errs[@]} > 0
if [ ${#errs[@]} -gt 0 ]; then

  # Print friendly message
  [ ${verbose} -eq 1 ] && print "Errors were encountered regarding '${stigid}'" 1

  # Iterate ${errs[@]}
  for err in ${errs[@]}; do

    # Print friendly message
    [ ${verbose} -eq 1 ] && print "  - ${err}" 1
  done

  exit 1
fi


# Reset the IFS
IFS="${cIFS}"


# Print friendly success
[ ${verbose} -eq 1 ] && print "Success, conforms to '${stigid}'"

exit 0
