{
  config,
  pkgs,
  myLib,
  ...
}:
let
  service = "Wi-Fi";
  adguard = "192.168.1.48";

  switchDns = pkgs.writeShellScript "home-dns" ''
    set -u
    device=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '$0 == "Hardware Port: ${service}" { getline; print $2 }')
    offered=$(/usr/sbin/ipconfig getpacket "$device" 2>/dev/null | /usr/bin/grep '^domain_name_server' | /usr/bin/tr -d '{},')

    if printf '%s\n' $offered | /usr/bin/grep -qx '${adguard}'; then
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
