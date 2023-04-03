#!/bin/sh -e
printf 'Welcome to the Iglunix guided installer\n'

prompt() {
	# usage:
	# prompt <prompt> <default> <var> [options ...]
	q="$1"
	default="$2"
	d_prompt="$default"
	if [ -z "$d_prompt" ]
	then
		d_prompt=none
	fi

	var="$3"
	shift; shift; shift;
	answer=''
	while [ -z "$answer" ]
	do
		printf '%s: ' "$q"
		[ ! -z "$1" ] && printf '%s ' "$@"
		printf '[%s]: ' "$d_prompt"
		read answer
		if [ -z "$answer" ]
		then
			answer=$default
		fi
	done
	read "$var" << EOF
$answer
EOF
}

prompt 'Select Disk' '' disk /dev/sd? /dev/nvme?n?
prompt 'Enter Hostname' 'iglunix' hostname
