#!/usr/bin/env bash

echo "initializing..."

# echo "  -> dbus-daemon"
# /usr/bin/start-dbus-daemon.sh > /dev/null 2>&1

echo "  -> sshd"
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_dev_config
