#!/bin/bash

echo "Entering entrypoint.sh, BUILDUSER: ${BUILDUSER}, KVM_GID: ${KVM_GID}, id: $(id)" 2>&1 | tee --append /tmp/entrypoint.log

if ! [ -z "${BUILDUSER}" ];then
	echo "Preparing container home directory for user ${BUILDUSER}" 2>&1 | tee --append /tmp/entrypoint.log
	adduser builder --disabled-password --uid "${BUILDUSER}" --gecos "" 2>&1 | tee --append /tmp/entrypoint.log
	mkdir /home/builder/.ssh 2>&1 | tee --append /tmp/entrypoint.log
	chown builder:builder /home/builder/.ssh 2>&1 | tee --append /tmp/entrypoint.log
	chmod 700 /home/builder/.ssh 2>&1 | tee --append /tmp/entrypoint.log
else
	echo "BUILDUSER not specified, leaving unconfigured..." 2>&1 | tee --append /tmp/entrypoint.log
fi

if ! [ -z "${KVM_GID}" ];then
	echo "Adding group KVM with GID ${KVM_GID}" 2>&1 | tee --append /tmp/entrypoint.log
	groupadd --gid ${KVM_GID} kvm 2>&1 | tee --append /tmp/entrypoint.log

	echo "Adding user 'builder' to group KVM"  2>&1 | tee --append /tmp/entrypoint.log
	usermod -a -G kvm builder 2>&1 | tee --append /tmp/entrypoint.log

	echo "Groups of user 'builder' are now: $(groups builder)"  2>&1 | tee --append /tmp/entrypoint.log
else
	echo "KVM_GID not supplied"  2>&1 | tee --append /tmp/entrypoint.log
fi

#echo "/etc/group" 2>&1 | tee --append /tmp/entrypoint.log
#cat /etc/group 2>&1 | tee --append /tmp/entrypoint.log
#
#echo "/etc/passwd" 2>&1 | tee --append /tmp/entrypoint.log
#cat /etc/passwd 2>&1 | tee --append /tmp/entrypoint.log

echo "Executing Jenkins-supplied command '$@'" 2>&1 | tee --append /tmp/entrypoint.log
exec "$@"
