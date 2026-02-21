# backup

systemctl stop bluetooth
tar -czf bluetooth-state.tar.gz /var/lib/bluetooth
systemctl start bluetooth

# restore

systemctl stop bluetooth
tar -xzf bluetooth-state.tar.gz -C /
systemctl start bluetooth
