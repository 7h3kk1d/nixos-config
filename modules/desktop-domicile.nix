# Domicile (a Wayland compositor whose renderer is a web engine) as a second
# login session beside GNOME, running the compositional-window-management
# shell. GDM still starts GNOME by default: pick "Domicile" from the gear menu
# on the login screen to try it, and log out to get GNOME back.
#
# The shell is whatever ~/.config/domicile/domicile.json names, e.g.
#   { "shell": "/home/thekkid/Projects/compositional-window-management/dist-shell/shell.js" }
# built with `npm run build:shell` in that repo.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.domicile.nixosModules.default ];

  programs.domicile = {
    enable = true;
    # Casting to Miracast TVs opens TCP 7236; not wanted on this machine.
    miracast = false;
  };

  # Lets the compositor and engine raise their frame threads without rtkit.
  users.users.thekkid.extraGroups = [ "domicile" ];

  # Wayland tools that work on Domicile (it serves screencopy, foreign-toplevel
  # list and data-control, but not layer-shell, so no waybar/mako/fuzzel).
  environment.systemPackages = with pkgs; [
    grim # screenshots: `grim -g "$(slurp)"`, or `grim -T <toplevel>` for a window
    slurp
    wl-clipboard
    wf-recorder
    cliphist # clipboard history over data-control
  ];
}
