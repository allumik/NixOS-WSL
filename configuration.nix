{ lib, pkgs, config, modulesPath, ... }:

with lib;
let
  defaultUser = "nixos";
  automountPath = "/mnt";
  syschdemd = import ./syschdemd.nix { inherit lib pkgs config defaultUser; };
in
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  # WSL is closer to a container than anything else
  boot.isContainer = true;
  networking.dhcpcd.enable = false;

  users = {
    users.${defaultUser} = {
      # fix UID as is expected needed in wslg
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    users.root = {
      shell = "${syschdemd}/bin/syschdemd";
      # Otherwise WSL fails to login as root with "initgroups failed 5"
      extraGroups = [ "root" ];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  # Disable systemd units that don't make sense on WSL
  systemd = {
    # Don't allow emergency mode, because we don't have a console.
    enableEmergencyMode = false;

    services = {
      "serial-getty@ttyS0".enable = false;
      "serial-getty@hvc0".enable = false;
      "getty@tty1".enable = false;
      "autovt@".enable = false;

      firewall.enable = false;
      systemd-resolved.enable = false;
      systemd-udevd.enable = false;
    };
  };

  environment = {
    # WSLg support
    etc = {
      "wsl.conf".text = ''
        [automount]
        enabled=true
        mountFsTab=true
        root=${automountPath}/
        options=metadata,uid=1000,gid=100
      '';
      hosts.enable = false;
      "resolv.conf".enable = false;
    };

    variables = {
      DISPLAY = ":0";
      WAYLAND_DISPLAY = "wayland-0";

      PULSE_SERVER = "${automountPath}/wslg/PulseServer";
      XDG_RUNTIME_DIR = "${automountPath}/wslg/runtime-dir";
      WSL_INTEROP = "/run/WSL/1_interop";
    };
  };

  system.activationScripts.copy-launchers.text = ''
    for x in applications icons; do
      echo "Copying /usr/share/$x"
      mkdir /usr/share/
      rm -rf /usr/share/$x
      cp -r $systemConfig/sw/share/$x/. /usr/share/$x
    done
  '';
}
