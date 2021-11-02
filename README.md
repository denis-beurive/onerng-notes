

I installed the required software on Ubuntu 21.10 ("impish").


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

The complete installation procedure is given below. Please note that the official procedure does not work for the version of Ubuntu I use.

The command to reaload the rules is "`sudo udevadm control --reload-rules`".

**Note**: I install "`python-gnupg`" using "`pip`", within a virtual environment.

```bash
sudo apt-get install rng-tools at openssl
wget -O onerng_3.6.orig.tar.gz https://github.com/OneRNG/onerng.github.io/blob/master/sw/onerng_3.6.orig.tar.gz?raw=true
md5sum onerng_3.6.orig.tar.gz
tar zxvf onerng_3.6.orig.tar.gz
cd onerng_3.6.orig
sudo make install
sudo udevadm control --reload-rules; echo $?
```

I have read threads on this forum, so I made some tests:

```bash
$ mkdir onerng && cd onerng
$ virtualenv --python=python3.9.7 venv
$ source venv/bin/activate
(venv) $ python --version
Python 3.9.7
(venv) $ pip install python-gnupg
Requirement already satisfied: python-gnupg in ./venv/lib/python3.9/site-packages (0.4.7)
(venv) $ sudo /sbin/onerng.sh daemon ttyACM0 ; echo $?
nohup: redirection de la sortie d'erreur standard vers la sortie standard
0
```

OK, it seems that everything is fine:


```bash
(venv) $ sudo dmesg
[15003.792514] perf: interrupt took too long (4995 > 4968), lowering kernel.perf_event_max_sample_rate to 40000
[15319.701445] audit: type=1400 audit(1635883955.014:66): apparmor="STATUS" operation="profile_load" profile="unconfined" name="/usr/sbin/haveged" pid=11589 comm="apparmor_parser"
[15532.082788] usb 2-1.6: USB disconnect, device number 4
[15534.823818] usb 2-1.5: new full-speed USB device number 5 using ehci-pci
[15534.937052] usb 2-1.5: New USB device found, idVendor=1d50, idProduct=6086, bcdDevice= 0.09
[15534.937072] usb 2-1.5: New USB device strings: Mfr=1, Product=3, SerialNumber=3
[15534.937079] usb 2-1.5: Product: 00
[15534.937083] usb 2-1.5: Manufacturer: Moonbase Otago http://www.moonbaseotago.com/random
[15534.937088] usb 2-1.5: SerialNumber: 00
[15534.939180] cdc_acm 2-1.5:1.0: ttyACM0: USB ACM device
[15797.400014] userif-3: sent link down event.
[15797.400034] userif-3: sent link up event.
[15798.006996] userif-3: sent link down event.
[15798.007014] userif-3: sent link up event.
```

However:

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

And, when I run the command "`cat /dev/random >/dev/null`", the intensity of the orange LED does not change.


