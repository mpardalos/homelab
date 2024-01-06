#!/usr/bin/env bash

hosts=$(ansible-inventory --list all | jq -r '._meta.hostvars[].ansible_host')

for host in $hosts; do
    echo "--- $host ---"
    ssh -t $host sudo dnf update
    echo
done

echo
echo ---
echo All done!
