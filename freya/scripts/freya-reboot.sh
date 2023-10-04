#!/usr/bin/bash

ssh-freya() {
    echo "[mpardalos@freya] $@" >&2
    ssh -t mpardalos@freya.home.mpardalos.com $@
}

ssh-freya "sudo systemctl reboot"
ssh-keygen -R freya.home.mpardalos.com
