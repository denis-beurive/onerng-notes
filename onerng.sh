#!/usr/bin/env sh
#
#	Version 3.6
#       UDEV doesn't allow us to start daemon's directly
#       so we queue some thing to start the daemon a few secs
#       after
#
set -eu 
if [ "$1" = "daemon" ]; then
	if [ ! -c /dev/"${2}" ]
	then
		exit 1
	fi
	ONERNG_URANDOM_RESEED="0"
	if [ -x /etc/onerng.conf ] 	
	then
		. /etc/onerng.conf
	else
		ONERNG_START_RNGD="1"
		ONERNG_MODE_COMMAND="cmd0"
		ONERNG_VERIFY_FIRMWARE="1"
		ONERNG_AES_WHITEN="1"
	fi
	
	#
	# a user can override this default entropy value
	#    in /etc/onerng.conf
	#
	if [ -z "$ONERNG_ENTROPY" ] 
	then
		ONERNG_ENTROPY=".93750"		# our default entropy value from onerng
	fi

	umask 0177
	# wait for udev to finish

        sleep 1		
        stty -F /dev/"${2}" raw -echo clocal -crtscts
		# make a temp file
	t=`mktemp`
	echo  $$ >/var/lock/LCK.."${2}"
	trap "rm -f -- '${t}' '/var/lock/LCK..${2}'" EXIT


	i=0
        while [ $i -lt 200 ]	# loop waiting for things to come up
        do
		truncate --size=0 "${t}"
		# off, produce nothing, flush
                echo "cmd0" >/dev/"${2}"		# standard noise
                echo "cmdO" >/dev/"${2}"		# turn it on
                dd if=/dev/"${2}" iflag=fullblock of=${t} bs=1 &
                pid=$!
        	stty -F /dev/"${2}" raw -echo clocal -crtscts
                sleep 0.05

		echo "cmdo" >/dev/"${2}"		# turn it off
		echo "cmd4" >/dev/"${2}"		# turn off noise gathering
		echo "cmdw" >/dev/"${2}"		# flush entropy pool
                kill $pid
                if [ -s "${t}" ]			# if we got some data exit the loop
                then 
                       	break
                fi
                i=$((i + 1))
        done

	if [ "$ONERNG_VERIFY_FIRMWARE" = "1" ]
	then
		sleep 0.1
		# read data into temp file
		truncate --size=0 "${t}"
		dd if=/dev/"${2}" iflag=fullblock of=${t} bs=4 &
		pid=$!
		sleep 0.02

		echo "cmdO" >/dev/"${2}"		# start it
		echo "cmdX" >/dev/"${2}"		# extract image
		# wait a while, should be done, kill it
		sleep 3.5
		kill $pid

		echo "cmdo" >/dev/"${2}"		# turn it off
		echo "cmdw" >/dev/"${2}"		# flush entropy pool

		# process the data, verify its signature, log any errors
		/home/denis/Documents/github/onerng/venv/bin/python /sbin/onerng_verify.py ${t}
		# python /sbin/onerng_verify.py $t 

		# res 1 err, 0 OK
		res=$?

		# clean up temp file
		rm -f -- "${t}"
		rm /var/lock/LCK.."${2}"
		trap - EXIT

		# if we failed quit - it's a bad or compromised board
		if [ "${res}" = "1" ]
		then
			exit 1
		fi
	else
		# clean up temp file
		rm -f -- "${t}"
		rm /var/lock/LCK.."${2}"
		trap - EXIT
	fi
	if [ "$ONERNG_START_RNGD" = "1" ]
	then
        	# waste some entropy
        	nohup dd if=/dev/"${2}" of=/dev/null bs=10k count=1 >/dev/null&

		# start the device
        	echo "$ONERNG_MODE_COMMAND" >/dev/"${2}"
        	echo "cmdO" >/dev/"${2}"
        	sleep .5

		# after dd is done start rngd
		PATH=/sbin:/usr/sbin:$PATH
		export  PATH

		#
		# there are multiple versions of RNGD in the field with incompatible flags
		#
		#	-n 1 -d 1  turn OFF default rngs if present 
		#
		#	--rng-entropy allows us to qualify the quality of our entropy source
		#
		RNGD_FLAGS=""
		v=$(rngd --help| grep no-tpm | wc -l)
		if [ "${v}" != "0" ]
		then
			RNGD_FLAGS="$RNGD_FLAGS -n 1"
		fi
		v=$(rngd --help| grep no-drng | wc -l)
		if [ "$v" != "0" ]
		then
			RNGD_FLAGS="$RNGD_FLAGS -d 1"
		fi
		v=$(rngd --help| grep rng-entropy | wc -l)
		if [ "$v" != "0" ]
		then
			# set the entropy to 7.5 bits/byte
			RNGD_FLAGS="$RNGD_FLAGS --rng-entropy=$ONERNG_ENTROPY"
		fi

		#
		#       if the system has a default RNG running shut it down
		#
		v=$(systemctl list-units 2>/dev/null | grep rng-tools | grep running | wc -l)
		if [ "$v" = "1" ]
		then
			systemctl stop rng-tools
		fi

		#
		#	RNGD seems to do its random testing in a way that doesn't always tolerate
		#	randomness in the way that failures occur (in random strings false negatives happen - ie ranmdom
		#	data that looks like it might not be random occur in the real world), the tests RNGD does work
		#	on relatively small blocks so it finds them  - failure rates of 1 in 1000 are acceptable,
		#	rngd gets worried if a bunch of these happen close to each other in time and shuts down, of
		#	course when these blocks occur in time is random too and eventually if we're running lots
		#	of data through rngd we seem to trigger this
		#
		#	If ONERNG_AES_WHITEN is enabled (the default) we use openssl AES to 'whiten' the input stream
		#	by encrypting it with a random key obtained from the OneRNG
		#
		if [ "$ONERNG_AES_WHITEN" = "1" ]
		then
        		 nohup openssl enc -aes128 -nosalt -in /dev/"${2}" -pass file:/dev/"${2}" -out /dev/stdout 2>/dev/null | rngd -f  $RNGD_FLAGS -r /dev/stdin >/dev/null  2>/dev/null &
			echo $! > /var/lock/LCK.."${2}"
		else
        		rngd $RNGD_FLAGS -p /var/lock/LCK.."${2}" -r /dev/"${2}"
		fi
	
		#
		#	if the urandom_min_reseed_secs parameter exists then allow
		#	us to override it - it's there to stop /dev/urandom from sucking
		#	up all the system entropy, but with onerng we have lots, so usually
		#	we set this to "0" which allows /dev/urandom to suck as much entropy
		#	as it wants (many systems have this set to 60 [secs])
		#
		if [ -e /proc/sys/kernel/random/urandom_min_reseed_secs ]
		then
			if [ -n "$ONERNG_URANDOM_RESEED"  ]
			then
				echo "$ONERNG_URANDOM_RESEED" >/proc/sys/kernel/random/urandom_min_reseed_secs
			fi
		fi
	else
        	echo "cmdo" >/dev/"${2}"
	fi
        exit 0
fi

#
#	when something is removed kill the daemon
#
if [ "${1}" = "kill" ]; then
	if [ -e /var/lock/LCK.."${2}" ]
	then
        	kill -9 "$(cat /var/lock/LCK.."${2}")"
	else
		if [ -z "${DEVPATH}" ]
		then
			echo "Missing DEVPATH variable, are you running from udev?"
			exit 1
		fi 

		#
		#	some systems have a broken udev, udevd remove
		#		is seldom used and obviously not well tested
		#		%k in the udev rules doesn't give the same
		#		name you were given when the add occured
		#		the solution is to see if the current dev name 
		#		matches one of the /sys/class/tty/ttyACM* files
		#		if so use that name's lock file to kill rngd
		#
		t1="$(echo "${DEVPATH}" | grep ttyACM | wc -l)"
		if [ "${v}" = "1" ]
		then
			t1="$DEVPATH"
		else
			t1="$(ls -lt /sys/class/tty/ttyACM* | grep "${DEVPATH}")"
		fi
		t2=$(basename "${t1}")
		if [ -e /var/lock/LCK.."${t2}" ]
		then
        		kill -9 "$(cat /var/lock/LCK.."${t2}")"
        		rm /var/lock/LCK.."${t2}"
		fi
	fi

	#
	#       if there's a default rng-tools we can restart it
	#
	v=$(which systemctl | grep "not found" | wc -l)
	if [ "${v}" != "1" ]
	then
		v=$(systemctl list-units | grep rng-tools | grep running | wc -l)
		if [ "${v}" = "0" ]
		then
			systemctl start rng-tools >/dev/null 2>&1
		fi
	fi
        exit 0
fi
#
#	normal case - start the daemon using at
#
if [ ! -c /dev/"${1}" ]
then
	exit 1
fi
echo "/sbin/onerng.sh daemon ${1}" | at -M NOW
exit 0
