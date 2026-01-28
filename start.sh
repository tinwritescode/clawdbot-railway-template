#!/bin/sh

# Start Tailscale daemon in background
/usr/sbin/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 --state=/var/lib/tailscale/tailscaled.state &

# Wait a few seconds for daemon to start
sleep 5

# Authenticate Tailscale
# Authenticate Tailscale
/usr/bin/tailscale up --authkey="${TS_AUTHKEY}" --hostname=clawdbot-railway --advertise-exit-node

# Expose port 443 via Tailscale with HTTPS
/usr/bin/tailscale serve --bg --https=443 http://localhost:8080

# Wait for serve to initialize and print the URL
sleep 2
echo "Tailscale Serve URL:"
/usr/bin/tailscale serve status

# Start the main application

# Unset TS_AUTHKEY so the app doesn't try to auto-configure Tailscale
unset TS_AUTHKEY

exec node src/server.js
