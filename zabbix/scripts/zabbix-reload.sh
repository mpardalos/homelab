#!/usr/bin/bash

ssh-zabbix() {
    echo "[mpardalos@zabbix] $@" >&2
    ssh -t mpardalos@zabbix.home.mpardalos.com $@
}

ssh-valhalla() {
    echo "[root@valhalla] $@" >&2
    ssh -t root@valhalla.home.mpardalos.com $@
}

vm_id=$(ssh-valhalla qm list | grep Zabbix | awk '{ print $1 }')
ssh-valhalla qm stop $vm_id
ssh-valhalla qm rollback $vm_id pre-install
ssh-valhalla qm start $vm_id

ssh-keygen -R zabbix.home.mpardalos.com
