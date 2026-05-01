#!/bin/sh
set -e
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}
changed=0
if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi
if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi
if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi

# Start server in background, wait for it to be ready, then bootstrap
gosu node "$@" &
SERVER_PID=$!

echo "Waiting for server to be ready..."
until gosu node node -e "require('http').get('http://localhost:3100/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))" 2>/dev/null; do
    sleep 2
done

echo "Server ready. Running bootstrap..."
gosu node pnpm paperclipai auth bootstrap-ceo 2>&1 || true

wait $SERVER_PID
