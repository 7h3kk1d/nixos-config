# Weekly push of this machine's Firefox history to the homelab collectors
# (7h3kk1d/collectors, sources/firefox; homelab cluster/README.md, Collectors).
#
# Sync can't stand in for this: it keeps only part of a desktop's visits, so each desktop sends
# its own places.sqlite, the whole history every time. A user service, as it reads the profile.
# The token is made by hand (the homelab README has how) and never enters the Nix store.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.firefoxHistoryPush;

  push = pkgs.writeShellApplication {
    name = "firefox-history-push";
    runtimeInputs = with pkgs; [ coreutils gzip sqlite curl hostname ];
    text = builtins.readFile ./firefox-history-push.sh;
  };
in
{
  options.services.firefoxHistoryPush = {
    enable = lib.mkEnableOption "weekly push of Firefox history to the homelab collectors";

    profile = lib.mkOption {
      type = lib.types.str;
      example = "/home/thekkid/.mozilla/firefox/l8alrqtq.default";
      description = "Firefox profile directory whose places.sqlite is pushed.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://firefox.home.abanduk.com/ingest";
      description = "The receiver's ingest URL.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "%h/.config/firefox-history-push/token";
      description = "File holding this machine's bearer token (systemd specifiers allowed).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ push ];

    systemd.user.services.firefox-history-push = {
      description = "Push Firefox history to the homelab collectors";
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${push}/bin/firefox-history-push ${cfg.profile} ${cfg.url} ${cfg.tokenFile}";
      };
    };

    systemd.user.timers.firefox-history-push = {
      description = "Weekly Firefox history push";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
