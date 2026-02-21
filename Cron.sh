# backup

tar -czf cron-state.tar.gz \
  /etc/crontab \
  /etc/cron.* \
  /var/spool/cron

# restore

tar -xzf cron-state.tar.gz -C /
