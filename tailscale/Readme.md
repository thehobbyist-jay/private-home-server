# Expose Hermes and n8n via Tailscale Funnel
# Publish Hermes gateway (8642) and dashboard (9119) through the ts-hermes sidecar
# Adjust ports and host as needed

docker exec ts-hermes tailscale funnel --https=443 --bg 8642
# To expose the Hermes dashboard (if you want public access):
# docker exec ts-hermes tailscale funnel --https=443 --bg 9119

docker exec ts-n8n tailscale funnel --https=443 --bg 5678
