#!/bin/bash

# Always chown webroot for better mounting
chown -Rf nginx:nginx /var/www

# Remote logging to Papertrail
rsyslogd -f /etc/rsyslog.conf && \
/remote_syslog/remote_syslog -d ${PAPERTRAIL_DOMAIN} -p ${PAPERTRAIL_PORT} --pid-file=/var/run/remote_syslog.pid --poll \
--hostname=${LOG_HOSTNAME} ${LOG_FILES}

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf