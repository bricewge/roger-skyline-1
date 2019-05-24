#!/usr/bin/env sh
#
# Deploy a new version of roger-skyline-1
# TODO Use ssh to achieve this

set -e

user=bricewge
host=192.168.10.2
port=21229
target=$user@$host:$port

scp ./configuration.nix "scp://$target/~"
ssh -t "ssh://$target" 'sudo cp $HOME/configuration.nix /etc/nixos && sudo nixos-rebuild switch --upgrade'
