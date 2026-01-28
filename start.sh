#!/bin/sh

# Start Tailscale daemon in background
/usr/sbin/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --state=/var/lib/tailscale/tailscaled.state &

# Wait a few seconds for daemon to start
sleep 5

# Authenticate Tailscale
# Authenticate Tailscale
/usr/bin/tailscale up --authkey="${TS_AUTHKEY}" --hostname=clawdbot-railway --advertise-exit-node

# Expose port 443 via Tailscale with HTTPS
/usr/bin/tailscale serve --bg https:443 tcp://localhost:8080

# Start the main application

exec node src/server.js
