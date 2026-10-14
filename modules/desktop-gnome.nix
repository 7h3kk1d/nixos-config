{ pkgs, ... }:
{
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];

  # Without this, Electron apps (Vesktop, VSCode, Slack, ...) run under
  # XWayland instead of natively on Wayland. That breaks the portal's
  # screen-share window picker: it opens and lets you pick a window, but
  # xdg-desktop-portal-gnome can't associate the picker with the app's
  # (XWayland) window ("Failed to associate portal window with parent
  # window" in its logs), so the share silently never starts.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
