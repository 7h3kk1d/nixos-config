# Follows the internet ping log. Once replies stop (3 misses in a row), records what
# still works, every 60s for as long as the drop lasts, so a drop can be pinned to a hop:
# the gateway, a wired LAN peer, other internet hosts, IPv6, TCP, and an ICMP traceroute.
#
# Usage: wifi-drop-trace <log dir> <interface> <gateway> <lan peer> <log name> <host>
# Writes <log dir>/trace.log: TRACE-START, CHECK <what>: <result>, HOP <traceroute line>,
# RECOVERED. Lines are prefixed with [unix-epoch] like the other logs.

log_dir=$1 iface=$2 gw=$3 lan_peer=$4 name=$5 host=$6
out="$log_dir/trace.log"

say() {
  printf '[%s] %s\n' "$(date +%s.%N)" "$*" >> "$out"
}

ping_check() { # label host [extra ping args]
  local label=$1 target=$2 got
  shift 2
  got=$(ping -n -q -c 3 -i 0.3 -W 1 "$@" "$target" 2>&1 | grep -o '[0-9]* received' | cut -d' ' -f1)
  say "CHECK ping $label $target: ${got:-error}/3"
}

snapshot() {
  say "TRACE-START after $1 missed"
  say "CHECK addr $iface: $(ip -4 -o addr show dev "$iface" | awk '{print $4}' | paste -sd' ')"
  say "CHECK route $host: $(ip route get "$host" 2>&1 | head -1)"
  say "CHECK neigh $gw: $(ip neigh show "$gw" | head -1)"
  ping_check gw "$gw"
  ping_check lan "$lan_peer"
  ping_check inet "$host"
  ping_check alt 8.8.8.8
  ping_check inet6 2606:4700:4700::1111 -6
  # TCP instead of ICMP: tells an ICMP-only problem apart from a real outage. 000 = no connection.
  say "CHECK tcp https://$host: $(curl -sk -o /dev/null -m 4 -w '%{http_code}' "https://$host/")"
  traceroute -I -n -q 1 -w 1 -m 8 "$host" 2>&1 | tail -n +2 | while IFS= read -r hop; do
    say "HOP $hop"
  done
}

misses=0
last_snapshot=0
tail -F -n 0 "$log_dir/$name.log" 2>/dev/null | while IFS= read -r line; do
  case $line in
    *"bytes from"*)
      if (( misses >= 3 )); then
        say "RECOVERED after $misses missed"
      fi
      misses=0
      continue
      ;;
    *"no answer yet"*)
      misses=$((misses + 1))
      ;;
    *)
      continue
      ;;
  esac
  now=$(date +%s)
  if (( misses >= 3 && now - last_snapshot >= 60 )); then
    last_snapshot=$now
    # In the background so RECOVERED is logged on time even while a snapshot runs.
    snapshot "$misses" &
  fi
done
