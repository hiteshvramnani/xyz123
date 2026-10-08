#!/bin/bash
# Deploy script — run on the Ubuntu server
# Usage: ./deploy.sh YOUR_DOMAIN
# Example: ./deploy.sh myapp.example.com

set -e

DOMAIN="${1:?Usage: ./deploy.sh YOUR_DOMAIN}"

echo "=== Deploying to ${DOMAIN} ==="

# 1. Create deploy directory
mkdir -p /opt/portal
cd /opt/portal

# 2. Copy files (you'll scp these from your Mac first — see instructions)
echo "Checking for required files..."
for f in docker-compose.prod.yml Dockerfile package.json package-lock.json tsconfig.json tsconfig.build.json; do
  if [ ! -f "$f" ]; then
    echo "Missing: $f"
    exit 1
  fi
done

# Copy src and prisma directories
for d in src prisma; do
  if [ ! -d "$d" ]; then
    echo "Missing directory: $d"
    exit 1
  fi
done

# 3. Write Caddyfile with the domain
cat > Caddyfile <<EOF
${DOMAIN} {
    reverse_proxy backend:3000
}
EOF

# 4. Update docker-compose with the domain (for JWT secret, etc.)
echo "Starting services..."
docker compose -f docker-compose.prod.yml down || true
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d

echo ""
echo "=== Deploy complete ==="
echo "API available at: https://${DOMAIN}/api/v1"
echo ""
echo "Run health check:"
echo "  curl https://${DOMAIN}/api/v1"
