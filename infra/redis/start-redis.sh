#!/bin/sh
set -eu

case "${REDIS_USERNAME:-}" in
  ""|*[!A-Za-z0-9_.-]*)
    echo "REDIS_USERNAME must use only letters, digits, dot, underscore, or hyphen" >&2
    exit 64
    ;;
esac

if [ "${#REDIS_PASSWORD}" -lt 16 ]; then
  echo "REDIS_PASSWORD must be at least 16 characters" >&2
  exit 64
fi

umask 077
cat > /tmp/interstellar-redis.conf <<EOF
bind 0.0.0.0 ::
protected-mode yes
port 6379
timeout 0
tcp-keepalive 300
dir /data
appendonly yes
appendfsync everysec
save 3600 1 300 100 60 10000
user default off
user ${REDIS_USERNAME} on >${REDIS_PASSWORD} ~* &* +@all -@dangerous
EOF

exec redis-server /tmp/interstellar-redis.conf
