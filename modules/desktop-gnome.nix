{ pkgs, ... }:
{
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
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
}
