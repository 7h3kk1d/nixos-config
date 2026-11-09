# Tailscale on the desktop: SSH into it from anywhere over the tailnet (tail8998f.ts.net).
#
# The desktop is always at home, so it does NOT accept the tailnet's subnet routes. With routes on,
# Linux sends traffic for the homelab VIPs (10.0.0.240/.241) through the tunnel even at home; with
# them off, *.home.abanduk.com (public DNS -> 10.0.0.241) goes straight over the LAN and keeps
# working if Tailscale or a k3s node is down. See the homelab repo, nix/README.md.
#
# --accept-dns=false: keep the desktop's DNS as it is (NetworkManager, no MagicDNS rewriting
# resolv.conf) while the Wi-Fi drop investigation runs. Other tailnet devices still reach this
# machine as `thekkid-desktop` through their own MagicDNS.
#
# Logging in is a one-time step by hand: `sudo tailscale up`, then open the printed URL.
{ ... }:
let
  flags = [
    "--accept-routes=false"
    "--accept-dns=false"
  ];
in
{
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP 41641, for direct connections instead of relays
    # `set` runs on every boot and switch, so the flags stay put after the first login.
    extraSetFlags = flags;
    extraUpFlags = flags;
  };
}
