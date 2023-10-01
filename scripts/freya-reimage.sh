#!/usr/bin/bash

ssh-valhalla() {
    echo "[root@valhalla] $@" >&2
    ssh -o LogLevel=QUIET -t root@valhalla.home.mpardalos.com $@
}

vm_id=$(ssh-valhalla qm list | grep Freya | awk '{ print $1 }')
ssh-valhalla qm stop $vm_id
ssh-valhalla qm rollback $vm_id pre-install
ssh-valhalla qm start $vm_id
