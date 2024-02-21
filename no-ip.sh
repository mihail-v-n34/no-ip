#!/bin/bash

hostname="your-hostname"
login="your-login"
password="your-password"

# Resolve hostname to it's current IP address
resolvedIp="$(ping -q -c 1 -t 1 $hostname 2> /dev/null | grep -m 1 PING | cut -d '(' -f2 | cut -d ')' -f1)"
if [ -z "$resolvedIp" ]; then
	echo "no-ip: Can't resolve hostname $hostname"
	exit 1
else
	echo "no-ip: Hostname $hostname resolved to $resolvedIp"
fi

# Get current external IP address
currentIp=$(curl -s -w "\n" "ipinfo.io/ip")
[ -z "$currentIp" ] && currentIp="$(curl -s -w "\n" "http://ip1.dynupdate.no-ip.com/")" # retry 1
[ -z "$currentIp" ] && currentIp="$(curl -s -w "\n" "https://api.ipify.org")" # retry 2
if [[ $currentIp =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "no-ip: Current IP is $currentIp"
else
	echo "no-ip: Can't get current IP"
	exit 1
fi

# Check if existing DNS record is still valid
if [ "$currentIp" = "$resolvedIp" ]; then
	echo "no-ip: DNS record is still valid, no need to update it"
	exit 0
else
	echo "no-ip: Updating DNS record..."
fi

# Update DNS record
serverResponse="$(curl --silent --connect-timeout 10 --max-time 15 "https://$login:$password@dynupdate.no-ip.com/nic/update?hostname=$hostname&myip=$currentIp" | { read body; read code; echo $body; })"
# Remove leading and trailing whitespace characters (unneeded precaution)
serverResponse="${serverResponse#"${serverResponse%%[![:space:]]*}"}"
serverResponse="${serverResponse%"${serverResponse##*[![:space:]]}"}"

# Divide server response into two parts
if [ ! -z "$(echo "$serverResponse" | grep " ")" ]; then
	part1="$(echo $serverResponse | cut -d " " -f 1)"
	part2="$(echo $serverResponse | cut -d " " -f 2-999)"
else
	part1="$serverResponse"
fi

# Process server response
if [ ! -z "$part2" ]; then
	if [ "$part1" = "good" ]; then
		echo "no-ip: DNS record successfully updated to $part2"
	else
		if [ "$part1" = "nochg" ]; then
			# We don't really expect to get this response, because we already checked
			# that we are not going to update DNS record if it is still valid
			echo "no-ip: DNS record redundantly updated to $part2"
		else
			# Unexpected server response?
			# See https://noip.com/integrate/response for details
			echo "no-ip: Operation failed, unexpected server response: \"$part1 $part2\""
			exit 1
		fi
	fi
else
	# Different types of errors
	case "$part1" in	
		"nohost")	echo "no-ip: Hostname supplied does not exist under specified account" && exit 1;;
		"badauth")	echo "no-ip: Invalid username password combination" && exit 1;;
		"badagent")	echo "no-ip: Client disabled. Client should exit and not perform any more updates without user intervention" && exit 1;;
		"!donator")	echo "no-ip: An update request was sent, including a feature that is not available to that particular user such as offline options" && exit 1;;
		"abuse")	echo "no-ip: Username is blocked due to abuse. Client should stop sending updates." && exit 1;;
		"911")		echo "no-ip: A fatal error on our side such as a database outage. Retry the update no sooner than 30 minutes" && exit 1;;
		"")		echo "no-ip: Operation failed, empty response received" && exit 1;;
		*)		echo "no-ip: Operation failed, unexpected server reponse: \"$part1\"" && exit 1;;
	esac
fi

exit 0
