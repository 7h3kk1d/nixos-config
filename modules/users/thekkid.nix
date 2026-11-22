{ pkgs, ... }:
{
  users.users.thekkid = {
    isNormalUser = true;
    # Keep the systemd user manager running with no one logged in, so a logout
    # (or switching between GNOME and Domicile) doesn't kill tmux and what runs
    # in it: apps live in scopes under user@1000.service, which otherwise stops
    # when the last session ends.
    linger = true;
    description = "Alexander Bandukwala";
    extraGroups = [ "networkmanager" "wheel" "docker" ];

    packages = with pkgs; [
      firefox slack element-desktop thunderbird vesktop
      # Temporary (2026-11-09): 26.05's vscode 1.144.0 fails in patchPhase (missing ripgrep
      # bin); unstable's builds. Back to plain vscode.fhs once 26.05 has the fix.
      unstable.vscode.fhs
      google-chrome git unstable.opam gcc gnumake pkg-config zoom-us
      htop duf dust nmap anki activitywatch vlc zotero glamoroustoolkit
      openjdk21 gimp gmp unstable.awatcher signal-desktop obs-studio tmux
      texlive.combined.scheme-full code-cursor calibre kitty alacritty
      (agda.withPackages (p: [ p.standard-library ])) jetbrains.idea
      unstable.claude-code
    ];
  };
}
