{ pkgs, ... }:
{
  users.users.thekkid = {
    isNormalUser = true;
    description = "Alexander Bandukwala";
    extraGroups = [ "networkmanager" "wheel" "docker" ];

    packages = with pkgs; [
      firefox slack element-desktop thunderbird vesktop vscode.fhs
      google-chrome git unstable.opam gcc gnumake pkg-config zoom-us
      htop duf dust nmap anki activitywatch vlc zotero glamoroustoolkit
      openjdk21 gimp gmp unstable.awatcher signal-desktop obs-studio tmux
      texlive.combined.scheme-full code-cursor calibre kitty alacritty
      (agda.withPackages (p: [ p.standard-library ])) jetbrains.idea
      claude-code
    ];
  };
}
