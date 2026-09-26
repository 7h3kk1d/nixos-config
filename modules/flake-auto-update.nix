# Keeps flake.lock from going stale. system.autoUpgrade rebuilds from
# whatever is committed on disk but never advances the lock itself, so
# without this, autoUpgrade just re-applies the same pinned nixpkgs
# revision forever. This runs `nix flake update` + commits weekly, so
# autoUpgrade actually has something new to pick up.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.flakeAutoUpdate;
in
{
  options.services.flakeAutoUpdate = {
    enable = lib.mkEnableOption "weekly automatic nix flake update + commit";

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/thekkid/Projects/nixos-config";
      description = "Path to the flake repo to update.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "thekkid";
      description = "User to run the update as (needs write access to the repo and a configured git identity).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.flake-auto-update = {
      description = "Update flake.lock and commit";
      path = [ pkgs.git pkgs.nix ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        WorkingDirectory = cfg.repoPath;
      };
      script = ''
        set -euo pipefail
        nix flake update
        if ! git diff --quiet -- flake.lock; then
          git add flake.lock
          git commit -m "Automated: nix flake update ($(date -u +%Y-%m-%d))"
        fi
      '';
    };

    systemd.timers.flake-auto-update = {
      description = "Weekly flake.lock update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
