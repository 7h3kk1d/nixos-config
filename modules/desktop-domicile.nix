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
    # X11 apps (Steam, its games): Domicile has no Xwayland; the CWM shell starts
    # this bridge on DISPLAY=:11 and puts that DISPLAY on what it launches.
    xwayland-satellite

    # "CWM in a window": Domicile nested in GNOME, for trying it without switching
    # sessions. Unsets DISPLAY so X11 apps open inside it (through the shell's
    # xwayland-satellite) rather than on GNOME, and GNOME's LD_LIBRARY_PATH so
    # its libraries stay out of Domicile's engine.
    #
    # DevTools on localhost:9341 (trial only, not the login session): lets the
    # shell's page be inspected while CWM is being tried out. Any program
    # running as this user can drive that page through it.
    (writeShellScriptBin "cwm-nested" ''
      export DOMICILE_ENGINE_ARGS="--remote-debugging-port=9341 ''${DOMICILE_ENGINE_ARGS:-}"
      # Watchdog: if GPU-borrowed RAM (amdgpu GTT, normally under 100 MB) passes
      # 4 GB, stop the nested desktop before the system runs out of memory.
      env -u DISPLAY -u LD_LIBRARY_PATH domicile "$@" & pid=$!
      gtt() { local t=0 f; for f in /sys/class/drm/card*/device/mem_info_gtt_used; do [ -r "$f" ] && t=$(( t + $(<"$f") )); done; echo $t; }
      while kill -0 $pid 2>/dev/null; do
        if [ "$(gtt)" -gt $(( 4096 * 1048576 )) ]; then
          /bin/notify-send -u critical "CWM stopped" "GPU memory ran away; closed the nested desktop to protect the session."
          kill -TERM $pid; sleep 5; kill -KILL $pid 2>/dev/null; break
        fi
        sleep 2
      done
      wait $pid
    '')
    (makeDesktopItem {
      name = "cwm-nested";
      desktopName = "CWM in a window";
      comment = "Compositional window management (Domicile) inside this desktop";
      exec = "cwm-nested";
      icon = "preferences-system-windows";
      categories = [ "System" ];
    })
  ];
}
