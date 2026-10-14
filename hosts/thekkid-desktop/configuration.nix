{ config, pkgs, lib, ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/desktop-gnome.nix
    ../../modules/audio-pipewire.nix
    ../../modules/users/thekkid.nix
    ../../modules/flake-auto-update.nix
  ];

  services.flakeAutoUpdate.enable = true;

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

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    vim openconnect dotnetCorePackages.sdk_9_0 hplip mangohud gh
  ];

  # Broadcom wifi driver is flagged insecure by nixpkgs. `lib.getName`
  # strips the version suffix entirely (e.g. "broadcom-sta-6.30.223.271-59-
  # 6.18.53" -> "broadcom-sta"), so match against that stripped name rather
  # than an exact version string — survives kernel bumps (the exact-match
  # form breaks every time the kernel version embedded in the derivation
  # name changes).
  nixpkgs.config.allowInsecurePredicate = pkg:
    (lib.getName pkg) == "broadcom-sta";

  # Points auto-upgrade at this flake+host now that there's no channel to
  # implicitly upgrade from. flake-auto-update.nix (enabled above) keeps
  # flake.lock from going stale, so this actually has new revisions to
  # pick up over time.
  system.autoUpgrade = {
    enable = true;
    flake = "/home/thekkid/Projects/nixos-config#thekkid-desktop";
    flags = [ "-L" ];
  };

  # Deliberately pinned at the original install-time value. Do not "fix".
  system.stateVersion = "22.11";
}
