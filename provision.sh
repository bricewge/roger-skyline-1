#!/usr/bin/env sh
#
# Force the creation the VM

set -e

vm=roger-skyline-1
bridge_interface=wlp3s0

if VBoxManage list  vms | grep -q "$vm"; then
    VBoxManage controlvm "$vm" poweroff 1>/dev/null 2>/dev/null || true
    VBoxManage unregistervm --delete "$vm"
fi

nix-build

VBoxManage import result/nixos*.ova \
    --vsys 0 --vmname "$vm"
VBoxManage modifyvm "$vm" \
    --nic1 bridged --bridgeadapter1 "$bridge_interface"
VBoxManage startvm "$vm" --type headless
