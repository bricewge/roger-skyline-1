{ config, pkgs, lib, ... }:

{
  # # * system
  nix.nixPath = [
    # "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixpkgs=https://nixos.org/channels/nixos-19.03/nixexprs.tar.xz"
    "nixos-config=/etc/nixos/configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  virtualisation.virtualbox.guest.enable = true;

  environment.systemPackages = with pkgs; [
    mailutils
  ];

  # * filesystem
  # from <nixpkgs/nixos/modules/virtualisation/virtualbox-image.nix>
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    # autoResize = true;
    fsType = "ext4";
  };

  boot.growPartition = true;
  boot.loader.grub.device = lib.mkDefault "/dev/sda";

  swapDevices = [{
    device = "/var/swap";
    size = 2048;
  }];

  # * users
  security.sudo.extraConfig = ''
    Defaults !tty_tickets
    Defaults timestamp_timeout=15
  '';

  users.users.bricewge = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "bricewge"; # NOTE Unsafe password
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCETarqjb35rOv+UpUpJTn2sP/WvwulfBOeRkjWzmanCP/aVyGe0YmG1r9jLegIUs5uq7fnA5LTiqaE6BWeySjJQnIG4WFmskXU+QHSCK4/xD40uj+U4BzkmaKAs43vJPqo7IQfu0+OMxzHikU0lsvKFhOQBlsKYhAJoWLTCdgFYreH/tSW+d29sQyAlOeNdB3/rfk9rw3tK/kjzxuKgk25HpN7mewO8jV2HY4S0jMKKWwRWbiDLy2H6kLIb5nQ7nIgwjrjEnBgwTv2hOtjrcSfL5uL7BLr1UpUmVzZ9YYdaRLEvTOyC/27xOR5QRNtOnHYa5WCDD8TKXY8s95WsNw9GY7DbT/W1BvhAb+YgQtvxcH0eUD92F2XBy9wse2g13tIyJT/l4ZIf64Sk/B+7qeRn9vZ5Kd7+RANWe3hX1x2/K1eCpEeDsuDyciaI9TbIG6HjaME7RJEW6/6cu9zzQlbcKk3B0J1kL6EdONsSFkzbyZklX4ksH9pvjRU4cqXBw248orExL2MsXeKz8BqRINezvk75DK47xQNci8chP2BEyLJoJ7r0L18TL9skvCHPKaQrSp4Opnodo+DCcUyCbtmyPkX+nLfIL5HRhmh46O4DacZ7ICMopnZEpqxB6f0Ac6pnyCzjAvGrXtVeUoSTJg2rDScPpXV8Sn40/z0LyZGw== cardno:000609852866" ];
  };

  # * network
  networking = {
    hostName = "roger-skyline-1";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = false;
    # TODO Adapt to the correction network
    # NOTE It should wlso be changed in ./deploy.sh
    interfaces.eth0.ipv4 = {
      addresses = [ { address = "192.168.10.2"; prefixLength = 30; } ];
    };
    defaultGateway = "192.168.10.1";
    nameservers = [ "8.8.8.8" "1.1.1.1" ];
    firewall.allowedTCPPorts = [ 80 443 ];
  };

  # * services
  # ** misc
  services.postfix.enable = true; # Mail Transfert Agent

  # ** ssh
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    challengeResponseAuthentication = false;
    permitRootLogin = "no";
    ports = [ 21229 ];
  };

  # ** web server
  services.httpd.enable = true;
  services.httpd.adminAddr = "alice@example.org";
  services.httpd.documentRoot = "${pkgs.valgrind.doc}/share/doc/valgrind/html";

  # ** auto upgrade
  system.autoUpgrade = {
    enable = true;
    dates = "Mon *-*-* 04:00";
  };
  systemd.timers.nixos-upgrade.timerConfig = {
    OnBootSec = "1min";
  };
  systemd.services.nixos-upgrade = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # WAITING for systemd >= 240 to support "append"
    # serviceConfig = {
    #   StandardOutput = "append:/var/log/update_script.log";
    #   StandardError = "append:/var/log/update_script.log";
    # };
    script = lib.mkForce ''
      (
        date --iso-8601=seconds
        ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch --upgrade
      ) 1>>/var/log/update_script.log 2>&1
    '';
  };

  # ** monitor crontab
  systemd.services.monitor-crontab = {
    enable = true;
    startAt = "00:00";
    serviceConfig = {
      StateDirectory = "monitor-crontab";
    };
    script = ''
      set -x
      monitored_path=/etc/crontab
      checksum_path=''${STATE_DIRECTORY:-/var/lib/monitor-crontab}/checksum
      checksum=$(sha256sum "$monitored_path")
      prev_checksum=$(${pkgs.coreutils}/bin/cat "$checksum_path" || true)

      if [ ! -e "$checksum_path" ]; then
        echo "$checksum" > "$checksum_path"
        exit
      fi

      if [ "$checksum" = "$prev_checksum" ]; then exit; fi

      echo "$checksum" > "$checksum_path"
      ${pkgs.system-sendmail}/bin/sendmail root <<MAIL
      /etc/crontab has been modified
      MAIL
    '';
  };
}
