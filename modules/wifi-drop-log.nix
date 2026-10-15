# Always-on Wi-Fi drop logger for the homelab drop investigation
# (https://github.com/7h3kk1d/homelab, Notion: "Set up monitoring for Wi-Fi/internet drops").
#
# Pings each target once a second from boot, and records sleep/resume, NetworkManager
# link events, and the access point/signal every 30s. That way a missed ping can be told
# apart from the machine being asleep or still reconnecting after resume.
# When the internet target stops answering, wifi-drop-trace records what still works
# (gateway, LAN peer, other hosts, IPv6, TCP, traceroute) to pin the drop to a hop.
# Run `wifi-drop-report` to list drops.
#
# Logs, all lines prefixed with [unix-epoch]:
#   <logDir>/<target>.log  ping -D -O output ("no answer yet" = missed reply)
#   <logDir>/events.log    START/STOP, SLEEP/RESUME, NM <action>, LINK <signal> <chan> <rate> <bssid>
#   <logDir>/trace.log     TRACE-START, CHECK <what>: <result>, HOP <traceroute line>, RECOVERED
{ config, lib, pkgs, ... }:
let
  cfg = config.services.wifiDropLog;

  # Timestamps any line that ping didn't (errors on stderr, our own markers).
  stamp = ''
    while IFS= read -r line; do
      case "$line" in
        \[*) printf '%s\n' "$line" ;;
        *) printf '[%s] %s\n' "$(date +%s.%N)" "$line" ;;
      esac
    done
  '';

  logEvent = pkgs.writeShellScript "wifi-drop-event" ''
    printf '[%s] %s\n' "$(${pkgs.coreutils}/bin/date +%s.%N)" "$*" >> ${cfg.logDir}/events.log
  '';

  pingService = name: host: lib.nameValuePair "wifi-drop-ping-${name}" {
    description = "Wi-Fi drop logger: ping ${host}";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = [ pkgs.iputils pkgs.coreutils ];
    serviceConfig = {
      LogsDirectory = "wifi-drop";
      LogsDirectoryMode = "0755";
      StandardOutput = "append:${cfg.logDir}/${name}.log";
      Restart = "always";
      RestartSec = 2;
    };
    # ping exits when there is no route (e.g. Wi-Fi down); log that and keep going.
    script = ''
      while true; do
        { stdbuf -oL ping -D -O -n ${host} 2>&1; echo "PING-EXIT $?"; } | ${stamp}
        sleep 1
      done
    '';
  };

  trace = pkgs.writeShellApplication {
    name = "wifi-drop-trace";
    runtimeInputs = with pkgs; [ coreutils gawk gnugrep iproute2 iputils curl traceroute ];
    text = builtins.readFile ./wifi-drop-trace.sh;
  };

  report = pkgs.writers.writePython3Bin "wifi-drop-report" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./wifi-drop-report.py);
in
{
  options.services.wifiDropLog = {
    enable = lib.mkEnableOption "always-on Wi-Fi drop logger";

    interface = lib.mkOption {
      type = lib.types.str;
      description = "Wi-Fi interface to record link state for.";
    };

    targets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        gw = "10.0.0.1"; # Xfinity XB7
        inet = "1.1.1.1";
      };
      description = "Log name -> host to ping once a second.";
    };

    traceTarget = lib.mkOption {
      type = lib.types.str;
      default = "inet";
      description = "Name in `targets` whose missed pings start a trace. `targets.gw` is the gateway.";
    };

    lanPeer = lib.mkOption {
      type = lib.types.str;
      default = "10.0.0.4"; # picloud
      description = "Another LAN host to ping during a drop, to tell the gateway apart from the LAN.";
    };

    logDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/wifi-drop";
      readOnly = true;
      description = "Where logs are written (fixed by LogsDirectory).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mapAttrs' pingService cfg.targets // {
      wifi-drop-events = {
        description = "Wi-Fi drop logger: link state and start/stop markers";
        wantedBy = [ "multi-user.target" ];
        after = [ "NetworkManager.service" ];
        path = [ pkgs.networkmanager pkgs.gnugrep pkgs.coreutils ];
        serviceConfig = {
          LogsDirectory = "wifi-drop";
          LogsDirectoryMode = "0755";
          ExecStartPre = "${logEvent} START";
          ExecStopPost = "${logEvent} STOP";
          Restart = "always";
          RestartSec = 5;
        };
        script = ''
          while true; do
            # SIGNAL CHAN RATE BSSID of the connected AP (BSSID colons arrive escaped as \:)
            link=$(nmcli -t -f IN-USE,SIGNAL,CHAN,RATE,BSSID dev wifi list ifname ${cfg.interface} --rescan no 2>/dev/null \
              | grep '^\*' | head -1 | cut -d: -f2- | sed 's/\\:/-/g; s/:/ /g; s/ Mbit\/s/Mbps/')
            ${logEvent} "LINK ''${link:-none}"
            sleep 30
          done
        '';
      };

      wifi-drop-trace = {
        description = "Wi-Fi drop logger: trace the path when ${cfg.targets.${cfg.traceTarget}} stops answering";
        wantedBy = [ "multi-user.target" ];
        after = [ "wifi-drop-ping-${cfg.traceTarget}.service" ];
        serviceConfig = {
          LogsDirectory = "wifi-drop";
          LogsDirectoryMode = "0755";
          ExecStart = lib.escapeShellArgs [
            (lib.getExe trace)
            cfg.logDir
            cfg.interface
            cfg.targets.gw
            cfg.lanPeer
            cfg.traceTarget
            cfg.targets.${cfg.traceTarget}
          ];
          Restart = "always";
          RestartSec = 5;
        };
      };

      # Active while the system is asleep: ExecStart runs on the way down, ExecStop on resume.
      wifi-drop-sleep = {
        description = "Wi-Fi drop logger: sleep/resume markers";
        wantedBy = [ "sleep.target" ];
        before = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LogsDirectory = "wifi-drop";
          LogsDirectoryMode = "0755";
          ExecStart = "${logEvent} SLEEP";
          ExecStop = "${logEvent} RESUME";
        };
      };
    };

    networking.networkmanager.dispatcherScripts = [{
      type = "basic";
      source = pkgs.writeShellScript "wifi-drop-nm" ''
        # $1 = interface, $2 = action (up, down, connectivity-change, ...)
        if [ "$1" = "${cfg.interface}" ] || [ "$2" = "connectivity-change" ]; then
          ${logEvent} "NM $2 $1 ''${CONNECTIVITY_STATE:-}"
        fi
      '';
    }];

    services.logrotate.settings.wifi-drop = {
      files = "${cfg.logDir}/*.log";
      frequency = "daily";
      rotate = 60;
      compress = true;
      delaycompress = true;
      copytruncate = true;
      missingok = true;
      notifempty = true;
    };

    environment.systemPackages = [ report ];
  };
}
