# OneRNG notes

This repository contains notes about the [OneRNG random number generator](https://onerng.info/).

These notes apply to Ubuntu `21.10` ("impish").

```bash
$ uname -a
Linux labo 5.13.0-20-generic #20-Ubuntu SMP Fri Oct 15 14:21:35 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
$  lsb_release -a
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 21.10
Release:    21.10
Codename:   impish
```

# Quick install

**Note**: I install "`python-gnupg`" using "`pip`", within a virtual environment.

```bash
$ sudo apt-get install rng-tools at openssl
$ wget -O onerng_3.6.orig.tar.gz https://github.com/OneRNG/onerng.github.io/blob/master/sw/onerng_3.6.orig.tar.gz?raw=true
$ md5sum onerng_3.6.orig.tar.gz
$ tar zxvf onerng_3.6.orig.tar.gz
$ cd onerng_3.6.orig
$ sudo make install
$ sudo udevadm control --reload-rules; echo $?
```

Install the python package "`python-gnupg`" within a virtual environment:

```bash
$ mkdir onerng && cd onerng
$ virtualenv --python=python3.9.7 venv
$ source venv/bin/activate
(venv) $ python --version
Python 3.9.7
(venv) $ pip install python-gnupg
...
```

Now you can run the script `/sbin/onerng.sh` (not mandatory):

```bash
(venv) $ sudo /sbin/onerng.sh daemon ttyACM0 ; echo $?
nohup: redirection de la sortie d'erreur standard vers la sortie standard
0
```

> [This version](onerng.sh) of the script `/sbin/onerng.sh` has been reviewed (to enforce shell safety).

# Check that the device is recognized

```bash
$ sudo dmesg
[42895.959680] usb 2-1.5: new full-speed USB device number 4 using ehci-pci
[42896.072325] usb 2-1.5: New USB device found, idVendor=1d50, idProduct=6086, bcdDevice= 0.09
[42896.072344] usb 2-1.5: New USB device strings: Mfr=1, Product=3, SerialNumber=3
[42896.072351] usb 2-1.5: Product: 00
[42896.072355] usb 2-1.5: Manufacturer: Moonbase Otago http://www.moonbaseotago.com/random
[42896.072360] usb 2-1.5: SerialNumber: 00
[42896.110325] cdc_acm 2-1.5:1.0: ttyACM0: USB ACM device
[42896.110637] usbcore: registered new interface driver cdc_acm
[42896.110641] cdc_acm: USB Abstract Control Model driver for USB modems and ISDN adapters
```
 
You can see that the hardware is recognized as being a USB ACM device.
It is accessible through [/dev/ttyACM0](https://rfc1149.net/blog/2013/03/05/what-is-the-difference-between-devttyusbx-and-devttyacmx/).

```bash
$ sudo dmesg | grep "USB ACM device" | perl -ne 'if ($_ =~ m/:[^:]+:\s*(ttyACM\d+)\s*:/) { print "/dev/${1}\n"; }'
/dev/ttyACM0
```

# Configure the device

See [this document](http://moonbaseotago.com/onerng/#Generic):

```bash
sudo su -
device=$(dmesg | grep "USB ACM device" | perl -ne 'if ($_ =~ m/:[^:]+:\s*(ttyACM\d+)\s*:/) { print "/dev/${1}\n"; }')
chown root "${device}"  
chgrp root "${device}" 
chmod 600 "${device}"
stty raw -echo < "${device}" # (1)
echo  cmd0 > "${device}"     # (2)
echo  cmdO > "${device}"     # (3)
```

> * (1) put the tty device into raw mode (no echo, treat special like any other characters)
> * (2) put the device into the avalanche/whitening mode
> * (3) turn on the feed to the USB

# Get random data from the device

You can read data from it by running the following command: 

```bash
sudo cat /dev/ttyACM0
```

However, this is not very convenient. This _quick and dirty_ [Perl script](reader.pl) gives better result:

```Perl
use strict;

open(my $fd, '<', '/dev/ttyACM0') or die "Cannot open /dev/ttyACM0: $!";
binmode $fd;
my $n=0;
while($n++ < $ARGV[0]) {
    my $data;
    my $s;
    read($fd, $data, 4) == 4 or die "Error while reading /dev/ttyACM0: $!";
    printf("%x", $data);
    print(unpack("H$s", $data));
}
close($fd);
```

Example:

```bash
$ sudo perl reader.pl 32
0201050a0813070e030f0e130703060b07062230a01040d0b0e0202050c0f0523
```

> You get random data.

# Testing the RNG

Install [dieharder](https://www.systutorials.com/docs/linux/man/1-dieharder/):

```bash
sudo apt install dieharder
```

Collect random data from the device:

```bash
sudo su -
head -c $((1024 * 1024)) /dev/ttyACM0 > data.bin
```

```bash
$ dieharder -a -f data.bin
#=============================================================================#
#            dieharder version 3.31.1 Copyright 2003 Robert G. Brown          #
#=============================================================================#
   rng_name    |           filename             |rands/second|
        mt19937|                        data.bin|  8.24e+07  |
#=============================================================================#
        test_name   |ntup| tsamples |psamples|  p-value |Assessment
#=============================================================================#
   diehard_birthdays|   0|       100|     100|0.28119427|  PASSED  
      diehard_operm5|   0|   1000000|     100|0.72859729|  PASSED  
  diehard_rank_32x32|   0|     40000|     100|0.36826938|  PASSED  
    diehard_rank_6x8|   0|    100000|     100|0.11765513|  PASSED  
   diehard_bitstream|   0|   2097152|     100|0.07057076|  PASSED  
        diehard_opso|   0|   2097152|     100|0.78313562|  PASSED  
        diehard_oqso|   0|   2097152|     100|0.93090267|  PASSED  
         diehard_dna|   0|   2097152|     100|0.06381576|  PASSED  
diehard_count_1s_str|   0|    256000|     100|0.50218933|  PASSED  
diehard_count_1s_byt|   0|    256000|     100|0.08184496|  PASSED  
 diehard_parking_lot|   0|     12000|     100|0.51744758|  PASSED  
    diehard_2dsphere|   2|      8000|     100|0.95713557|  PASSED  
    diehard_3dsphere|   3|      4000|     100|0.39968818|  PASSED  
     diehard_squeeze|   0|    100000|     100|0.96849682|  PASSED  
        diehard_sums|   0|       100|     100|0.00201768|   WEAK   
        diehard_runs|   0|    100000|     100|0.53251554|  PASSED  
        diehard_runs|   0|    100000|     100|0.14528869|  PASSED  
       diehard_craps|   0|    200000|     100|0.76439758|  PASSED  
       diehard_craps|   0|    200000|     100|0.97937725|  PASSED  
 marsaglia_tsang_gcd|   0|  10000000|     100|0.82442915|  PASSED  
 marsaglia_tsang_gcd|   0|  10000000|     100|0.99688665|   WEAK   
         sts_monobit|   1|    100000|     100|0.71439323|  PASSED  
            sts_runs|   2|    100000|     100|0.22796351|  PASSED  
```

# Problem

There is a problem with `rng-tools`. The OS entropy pool is not stocked up with random data.

```bash
(venv) $ systemctl restart rng-tools
(venv) $ systemctl status rng-tools
● rng-tools.service - Add entropy to /dev/random 's pool a hardware RNG
     Loaded: loaded (/lib/systemd/system/rng-tools.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2021-11-02 22:16:25 CET; 2s ago
   Main PID: 19595 (rngd)
      Tasks: 1 (limit: 18478)
     Memory: 276.0K
        CPU: 10ms
     CGroup: /system.slice/rng-tools.service
             └─19595 /usr/sbin/rngd -r /dev/hwrng -f

nov. 02 22:16:25 labo systemd[1]: Started Add entropy to /dev/random 's pool a hardware RNG.
nov. 02 22:16:25 labo rngd[19595]: read error
nov. 02 22:16:25 labo rngd[19595]: read error
```

You can see that the command executed is `/usr/sbin/rngd -r /dev/hwrng -f`.

A quick look at the man page for `rngd` tells us that:

> rngd - Check and feed random data from hardware device to kernel random device
> 
> * `-f` Do not fork and become a daemon
> * `-r` Kernel device used for random number input (default: `/dev/hwrng`)
> * `-o` Kernel device used for random number output (default: `/dev/random`)

Thus, let's try this:

```bash
$ sudo rngd -f -r /dev/ttyACM0 -o /dev/random
```

It works!

However, the command below does **NOT** work:

```bash
$ sudo rngd -f -r /dev/hwrng -o /dev/random 
read error

read error
```

**Conclusion**: it seems that we should specify the value `/dev/ttyACM0` for the command line optin `-r` (instead of the value `/dev/hwrng`).

The configuration file for `rng-tools` is supposed to be `/etc/default/rng-tools`. Please note that we add the line "`HRNGDEVICE=/dev/ttyACM0`" to the configuration file.

```
$ cat /etc/default/rng-tools 
# Configuration for the rng-tools initscript
# $Id: rng-tools.default,v 1.1.2.5 2008-06-10 19:51:37 hmh Exp $

# This is a POSIX shell fragment

# Set to the input source for random data, leave undefined
# for the initscript to attempt auto-detection.  Set to /dev/null
# for the viapadlock and tpm drivers.
#HRNGDEVICE=/dev/hwrng
#HRNGDEVICE=/dev/null
HRNGDEVICE=/dev/ttyACM0

# Additional options to send to rngd. See the rngd(8) manpage for
# more information.  Do not specify -r/--rng-device here, use
# HRNGDEVICE for that instead.
#RNGDOPTIONS="--hrng=intelfwh --fill-watermark=90% --feed-interval=1"
#RNGDOPTIONS="--hrng=viakernel --fill-watermark=90% --feed-interval=1"
#RNGDOPTIONS="--hrng=viapadlock --fill-watermark=90% --feed-interval=1"
#RNGDOPTIONS="--hrng=tpm --fill-watermark=90% --feed-interval=1"
```

And then: 

```bash
$ if [ -c /dev/ttyACM0 ]; then echo "OK"; fi
OK
$ sudo /etc/init.d/rng-tools stop && sudo /etc/init.d/rng-tools start && echo "OK" && tail /var/log/syslog
Stopping rng-tools (via systemctl): rng-tools.service.
Starting rng-tools (via systemctl): rng-tools.service.
OK
...
Dec  7 22:08:24 labo systemd[1]: Stopping Add entropy to /dev/random 's pool a hardware RNG...
Dec  7 22:08:24 labo systemd[1]: rng-tools.service: Deactivated successfully.
Dec  7 22:08:24 labo systemd[1]: Stopped Add entropy to /dev/random 's pool a hardware RNG.
Dec  7 22:08:24 labo systemd[1]: Started Add entropy to /dev/random 's pool a hardware RNG.
Dec  7 22:08:24 labo rngd[10153]: read error
Dec  7 22:08:24 labo rngd[10153]: read error
```

But even if we set the value of `HRNGDEVICE` to `/dev/ttyACM0`, the value used for executing `rngd` is still the default value `/dev/hwrng`.

**Conclusion**: it seems that the configuration file `/etc/default/rng-tools` is just ignored.

> The script `/etc/init.d/rng-tools` loads the configuration file `/etc/default/rng-tools` (checked: no doubt about that). However, for some unknown reason the configuration is not used (although it should be).

