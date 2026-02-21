# backup

tar -czf systemd-timers.tar.gz /var/lib/systemd/timers

# restore

tar -xzf systemd-timers.tar.gz -C /
systemctl daemon-reexec
