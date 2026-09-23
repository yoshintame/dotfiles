{
  config,
  pkgs,
  myLib,
  ...
}:
let
  service = "Wi-Fi";
  adguard = "192.168.1.48";
  homeRouterMac = "64:20:e3:6e:af:12";

  switchDns = pkgs.writeShellScript "home-dns" ''
    set -u
    device=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '$0 == "Hardware Port: ${service}" { getline; print $2 }')
    packet=$(/usr/sbin/ipconfig getpacket "$device" 2>/dev/null)
    offered=$(printf '%s\n' "$packet" | /usr/bin/grep '^domain_name_server' | /usr/bin/tr -d '{},')
    gateway=$(printf '%s\n' "$packet" | /usr/bin/awk -F'[{},]' '/^router/ { print $2 }')

    gatewayMac=""
    if [ -n "$gateway" ]; then
      /sbin/ping -c 1 -t 1 "$gateway" >/dev/null 2>&1
      gatewayMac=$(/usr/sbin/arp -n "$gateway" | /usr/bin/awk '{ print $4 }')
    fi

    if [ "$gatewayMac" = '${homeRouterMac}' ] && printf '%s\n' $offered | /usr/bin/grep -qx '${adguard}'; then
      want='${adguard}'
    else
      want='Empty'
    fi

    current=$(/usr/sbin/networksetup -getdnsservers '${service}')
    case "$current" in
      *"aren't any"*) current='Empty' ;;
    esac

    if [ "$current" != "$want" ]; then
      /usr/sbin/networksetup -setdnsservers '${service}' "$want"
      echo "$(/bin/date '+%F %T') ${service} DNS: $current -> $want"
    fi
  '';
in
myLib.mkModule config "home-dns" {
  launchd.daemons.home-dns.serviceConfig = {
    Label = "com.yoshintame.home-dns";
    ProgramArguments = [ "${switchDns}" ];
    WatchPaths = [ "/var/run/resolv.conf" ];
    StartInterval = 300;
    RunAtLoad = true;
    StandardOutPath = "/tmp/home-dns.log";
    StandardErrorPath = "/tmp/home-dns.log";
  };
}
