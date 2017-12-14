# How to shutdown libvirt guests instead of suspending

	Author: Evert Mouw <post@evert.net>
	Date  : 2017-12-11

## Problem

Libvirt suspends virtual machines (guests) but I want them to shutdown.

Reasons to shutdown VMs on reboot or poweroff include:

- clean umount so filesystems are accessible
- activating new kernels or updates
- avoiding long writes by not saving state

## Solution in short

You have to tell the `libvirtd-guests' what to do.

You want to set the *parallel shutdown* to 4 or so, because the default setting (0) means only one VM can be in the shutdown state at any time...

```
ON_SHUTDOWN=shutdown
PARALLEL_SHUTDOWN=4
```

The settings can be changed in:

	Arch Linux (2017-12) | /etc/conf.d/libvirt-guests
	Ubuntu 16.04 LTS     | /etc/default/libvirt-guests
	????                 | /etc/sysconf/libvirt-guests

To also *use* these settings, do:

```
systemctl enable libvirtd-guests
systemctl restart libvirtd-guests
```

## Overriding libvirt-guests

The stuff below is *NOT TESTED* and just a suggestion.

```
systemctl disable libvirt-guests
cp /usr/lib/systemd/system/libvirt-guests.service /etc/systemd/system/
cp /usr/lib/libvirt/libvirt-guests.sh /etc/libvirt/
sed -i 's/\/usr\/lib/\/etc\/libvirt/g' /etc/systemd/system/libvirt-guests.service
systemctl enable libvirt-guests
vim /etc/libvirt/libvirt-guests.sh
```

## Windows guests

Sometimes Windows guests need multiple shutdown signals. You can override (edit) the `libvirt-guests.sh` script as suggested by [Sebastian Marsching](https://sebastian.marsching.com/wiki/Linux/KVM).

Another solution is to change the `libvirt-guests.service` by moving the `ExecStop` to `ExecStopPost` and giving a custom `ExecStopPost`.

```
ExecStop=/root/kvm-winguests-shutdown.sh
ExecStopPost=/usr/lib/libvirt/libvirt-guests.sh stop
```

```
systemctl disable libvirt-guests
cp /usr/lib/systemd/system/libvirt-guests.service /etc/systemd/system/
vim /etc/systemd/system/libvirt-guests.service
systemctl enable libvirt-guests
```

The file `/root/kvm-winguests-shutdown.sh` will contain:

```
#!/bin/sh
# this script is run by a  modified libvirt-guests.service
WINDOWSGUESTS="win10 anotherwinbox"
for W in $WINDOWSGUESTS; do
	virsh qemu-agent-command $W '{"execute":"guest-ping"}' > /dev/null
	sleep 1
	virsh shutdown --mode acpi $W
	sleep 1
	virsh shutdown --mode agent $W
done
```

Don't forget to make it executable: `chmod +x /root/kvm-winguests-shutdown.sh`

Furthermore Windows needs a few settings so it can be brought down gracefully. It needs at least the two registry settings below, and some Server editions also need the *shutdown event tracker* to be disabled. More info: see the folder "Shutdown Windows Guests".

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system]
"shutdownwithoutlogon"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows]
"ShutdownWarningDialogTimeout"=dword:00000001
```

## More details

The `SHUTDOWN_TIMEOUT` is in seconds. It seems it's also an environment variable, I saw mentioned `env libvirtd_shutdown_timeout` a few times. I advise 300 seconds, it is the default.

Code snippets from `/usr/lib/libvirt/libvirt-guests.sh`

```
sysconfdir="/etc"

URIS=default
ON_BOOT=start
ON_SHUTDOWN=suspend
SHUTDOWN_TIMEOUT=300
PARALLEL_SHUTDOWN=0
START_DELAY=0
BYPASS_CACHE=0
CONNECT_RETRIES=10
RETRIES_SLEEP=1
SYNC_TIME=0

test -f "$sysconfdir"/conf.d/libvirt-guests &&
    . "$sysconfdir"/conf.d/libvirt-guests
```

The `CONNECT_RETRIES` and `RETRIES_SLEEP` settings control how often `libvirt-guests.sh` (the `libvirt-guests.service`) tries to connect to the *libvirtd* (`libvirtd.service`). Sometimes libvirtd is not yet ready, even after the service has started it still needs to initialize a few things so it cannot accept connections from the guests service. Source: [Michal Privoznik (2014)](https://www.redhat.com/archives/libvir-list/2014-February/msg01359.html)

For even more information, see the source code of [libvirt-guests.sysconf](https://github.com/libvirt/libvirt/blob/master/tools/libvirt-guests.sysconf)
