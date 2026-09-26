{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/desktop-gnome.nix
    ../../modules/audio-pipewire.nix
    ../../modules/users/thekkid.nix
  ];

  networking.hostName = "thekkid-desktop";
  networking.networkmanager.enable = true;

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.supportedFilesystems = [ "ntfs" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.keyboard.zsa.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    vim openconnect dotnetCorePackages.sdk_9_0 hplip
  ];

  # KNOWN FRAGILITY: this exact string is tied to the currently running
  # kernel (6.30.223.271-59-6.18.53) and will silently stop matching (build
  # failure citing a different version string) on the next kernel bump.
  # More robust alternative, to switch to now or on the next break:
  #   nixpkgs.config.allowInsecurePredicate = pkg:
  #     lib.hasPrefix "broadcom-sta-" (lib.getName pkg);
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.53"
  ];

  # Points auto-upgrade at this flake+host now that there's no channel to
  # implicitly upgrade from. NOTE: reapplies whatever is currently committed
  # on disk — does NOT `git pull` or bump flake.lock by itself. Nothing
  # actually changes on a nightly run until flake.lock is updated some other
  # way (manual `nix flake update` + commit, or a separate timer) — tracked
  # as a follow-up.
  system.autoUpgrade = {
    enable = true;
    flake = "/home/thekkid/Projects/nixos-config#thekkid-desktop";
    flags = [ "-L" ];
  };

  # Deliberately pinned at the original install-time value. Do not "fix".
  system.stateVersion = "22.11";
}
