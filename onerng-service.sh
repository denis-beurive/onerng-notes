#!/usr/bin/env sh

# The ONERNG device emulates a serial/modem device when you first plug the
# device into your machine. Therefore it is associated with a device file
# named /dev/ttyACM<n> (with <n>=0, 1...).

readonly DEVICE_MODEM="/dev/ttyACM0"

if [ ! -e "${DEVICE_MODEM}" ]; then
    printf "Device file \"%s\" does not exist! Please make sure that the OneRNG device is plugged." "${DEVICE_MODEM}"
else
    # Start the "rngd" daemon.
    #   -f Do not fork and become a daemon
    #   -r Kernel device used for random number input (default: /dev/hwrng)
    #
    # Interesting options:
    #   -o Kernel device used for random number output (default: /dev/random)
    #   -n 0|1 Do not use tpm as a source of random number input (default: 0)
    /usr/sbin/rngd -r "${DEVICE_MODEM}" -f
fi