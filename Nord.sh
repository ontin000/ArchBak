# backup

systemctl stop nordvpnd
tar -czf nordvpn-state.tar.gz /var/lib/nordvpn
systemctl start nordvpnd

# restore

systemctl stop nordvpnd
tar -xzf nordvpn-state.tar.gz -C /
systemctl start nordvpnd
