#!/bin/bash


# Get our working directory
cwd="$(pwd)"

# Define our bootstrapper location
bootstrap="${cwd}/tools/bootstrap.sh"

# Bail if it cannot be found
if [ ! -f ${bootstrap} ]; then
  echo "Unable to locate bootstrap; ${bootstrap}" && exit 1
fi

# Load our bootstrap
source ${bootstrap}


# Make sure we are operating on global zones
if [ "$(zonename)" != "global" ]; then
  usage "${stigid} only applies to global zones" && exit 1
fi


# Get EPOCH
s_epoch="$(gen_epoch)"

# Create a timestamp
timestamp="$(gen_date)"


# Whos is calling?
caller=$(ps $PPID | grep -c stigadm)


# Set ${status} to false
status=0

# Get a blob of the current status
blob="$(auditconfig -getcond)"

# Get boolean of current status
status=$(echo "${blob}" | nawk '$1 ~ /^audit/ && $4 ~ /^auditing/{print 1}')


# If ${restore} = 1 go to restoration mode
if [[ ${restore} -eq 1 ]] && [[ ${status} -eq 1 ]]; then

  # Do work
  audit -t
  [ $? -ne 0 ] && exit 1

  exit 0
fi


# If ${change} == 1 & ${status} = 0
if [[ ${change} -eq 1 ]] && [[ ${status} -eq 0 ]]; then

  # Do work
  audit -s

  # Get a blob of the current status
  blob="$(auditconfig -getcond)"

  # Get boolean of current status
  status=$(echo "${blob}" | nawk '$1 ~ /^audit/ && $4 ~ /^auditing/{print 1}')
fi


# Get EPOCH
e_epoch="$(gen_epoch)"

seconds=$(subtract ${s_epoch} ${e_epoch})

# Generate a run time
[ ${seconds} -gt 60 ] && run_time="$(divide ${seconds} 60) Min." || run_time="${seconds} Sec."


# If ${status} != 1
if [ ${status:=0} -ne 1 ]; then

  # Set ${results} error message
  results="Failed validation"

  # Populate a value in ${errors[@]} if ${caller} is > 0
  [ ${caller} -gt 0 ] && errors=("${stigid}")
fi

# Set ${results} passed message
[ ${status} -eq 1 ] && results="Passed validation"


# Print friendly success (This could be easier to discern)
if [ ${verbose} -eq 1 ]; then
  results="${results}\", Details: \"${blob}\","
fi


# If ${caller} = 0
if [ ${caller} -eq 0 ]; then

  # Apply some values expected for general report
  stigs=("${stigid}")
  total_stigs=${#stigs[@]}

  # Generate report ourselves
  report="$(report "${report}")"

  echo "${report}" > ${log}
fi


# Capture module report to ${log}
stig_module_report "${results}" >> ${log}


if [ ${caller} -eq 0 ]; then
  # Finish up the report
  echo "}" >> ${log}

  # Print ${log}
  cat ${log}
fi


# Return an error/success code
[ ${status} -eq 1 ] && exit 0 || exit 1


# Date: 2017-06-21
#
# Severity: CAT-II
# Classification: UNCLASSIFIED
# STIG_ID: V0047781
# STIG_Version: SOL-11.1-010040
# Rule_ID: SV-60657r1
#
# OS: Solaris
# Version: 11
# Architecture: Sparc X86
#
# Title: The audit system must produce records containing sufficient information to establish the identity of any user/subject associated with the event.
# Description: Enabling the audit system will produce records with accurate time stamps, source, user, and activity information. Without this information malicious activity cannot be accurately tracked.
