#!/usr/bin/bash

ssh-zabbix() {
    echo "[mpardalos@zabbix] $@" >&2
    ssh -t mpardalos@zabbix.home.mpardalos.com $@
}

ssh-zabbix "sudo systemctl reboot"
ssh-keygen -R zabbix.home.mpardalos.com
