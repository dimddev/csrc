#!/bin/sh

GROUP="admin"

FILE="/etc/ssh/sshd_config"
PF_CONF_D_TABLES="/etc/pf.conf.d/tables"
PF_SSH_IP_LIST="ssh_ip_list.table"

# must run as root
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' "Error: this script must be run as root." >&2
  exit 1
fi

[ -f "$FILE" ] && cp "$FILE" "${FILE}_"`date +%d%m%y%H%M%S`

[ ! -d "$PF_CONF_D_TABLES" ] && mkdir -p "$PF_CONF_D_TABLES"


case "$(uname -s)" in
  OpenBSD)
    IFCONFIG_OUT=$(ifconfig "$GROUP")
    ;;
  FreeBSD)
    IFCONFIG_OUT=$(ifconfig -a -g "$GROUP")
    ;;
  *)
    echo "Unsupported OS"
    exit 1
    ;;
esac

cat > "$FILE" << 'EOF'
Port 10022
SyslogFacility AUTH
LogLevel VERBOSE
LoginGraceTime 60
PermitRootLogin no
MaxAuthTries 3
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
AllowAgentForwarding no
AllowTcpForwarding no
TCPKeepAlive no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
PermitTunnel no
Banner none
MaxSessions 2
AllowGroups wheel
EOF

{
  for a in $(echo "$IFCONFIG_OUT" | grep inet | awk '{ print $2 }'); do

    if grep -q "$a" $FILE; then
      continue
    fi

    echo "ListenAddress $a"

    if [ ! $(ls -lo /etc/pf.conf.d/ | grep tables | awk '{ print $5 }') = "schg" ]; then
      echo "$a" >> "${PF_CONF_D_TABLES}/${PF_SSH_IP_LIST}"
    fi
  done
} | tee -a "$FILE"

{
  for u in $(cut -d: -f1 /etc/passwd); do
    [ "$u" = "root" ] && continue
    if id -nG "$u" | grep -qw -- wheel; then
      echo "AllowUsers $u"
    fi
  done
} | tee -a "$FILE"
