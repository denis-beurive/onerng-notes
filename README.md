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


