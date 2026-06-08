FROM grafana/alloy:v1.8.2

COPY config.alloy /etc/alloy/config.alloy

# Background worker: no inbound port required.
CMD ["run", "--storage.path=/tmp/alloy", "/etc/alloy/config.alloy"]
