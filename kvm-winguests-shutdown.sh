#!/bin/sh
# this script is run by a  modified libvirt-guests.service
# more info: "shutdown libvirt guests instead of suspending.md"
WINDOWSGUESTS="win10"
for W in $WINDOWSGUESTS; do
	virsh qemu-agent-command $W '{"execute":"guest-ping"}' > /dev/null
	sleep 1
	virsh shutdown --mode acpi $W
	sleep 1
	virsh shutdown --mode agent $W
done
