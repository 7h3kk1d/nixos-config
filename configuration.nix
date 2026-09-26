# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";

  networking.hostName = "thekkid-desktop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Detroit";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # nvidia stuff
  # hardware.graphics.enable=true;
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   powerManagement.enable = false;
  #   open = false;
  #   nvidiaSettings = true;
  # };
  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.videoDrivers = [ "nvidia" ];


  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;



  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  # sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.thekkid = {
      isNormalUser = true;
      description = "Alexander Bandukwala";
      extraGroups = [ "networkmanager" "wheel" "docker" ];

      packages = with pkgs; [
        firefox slack element-desktop thunderbird vesktop vscode.fhs google-chrome git unstable.opam gcc gnumake pkg-config zoom-us htop duf dust nmap anki activitywatch vlc zotero glamoroustoolkit openjdk21 gimp gmp unstable.awatcher signal-desktop obs-studio tmux texlive.combined.scheme-full code-cursor calibre kitty alacritty (agda.withPackages (p: [p.standard-library])) jetbrains.idea claude-code
      ];
  };

  # systemd.services.activitywatch = {
  #   description = "Activity Watch";
  #   script = ''
  #     #!/bin/sh
  #     ${pkgs.activitywatch}/bin/aw-server & ${pkgs.activitywatch}/bin/aw-watcher-afk & ${pkgs.activitywatch}/bin/aw-watcher-window
  #   '';
  #   wantedBy= ["multi-user.target"];
  #   restartIfChanged = true;
  # };
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
   vim openconnect dotnetCorePackages.sdk_9_0 hplip # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

  # boot.blacklistedKernelModules = ["nouveau"];
  boot.supportedFilesystems = [ "ntfs" ];
  system.autoUpgrade.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];
  nix.settings.experimental-features = ["nix-command" "flakes" ];
  virtualisation.docker.enable = true;
  hardware.keyboard.zsa.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

xdg.portal.enable = true;

xdg.portal.extraPortals = [
  pkgs.xdg-desktop-portal-gnome
];
nixpkgs.config.permittedInsecurePackages = [
  "broadcom-sta-6.30.223.271-59-6.18.53"
];

}
