#!/bin/sh

# Get UID/GID from environment variables (default to 1000 if not set)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Get Docker group ID from the docker socket file
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "999")
ls -al /var/run/docker.sock

# Ensure group with PGID exists
if ! getent group "$PGID" >/dev/null; then
  groupadd -g "$PGID" casaos
fi

# Ensure user with PUID exists
if ! getent passwd "$PUID" >/dev/null; then
  useradd -u "$PUID" -g "$PGID" -M -s /sbin/nologin casaos
fi

# Create necessary directories with proper ownership
mkdir -p /DATA/AppData/casaos/apps
mkdir -p /c/DATA/ # For compatibility with windows host
mkdir -p /var/log/casaos
mkdir -p /var/run/casaos

# Set ownership of directories that will be used by casaos processes
chown -R "$PUID:$PGID" /DATA/
chown -R "$PUID:$PGID" /c/DATA/
chown -R "$PUID:$PGID" /var/log/casaos
chown -R "$PUID:$PGID" /var/run/casaos
chown -R "$PUID:$PGID" /var/lib/casaos

# Create log files with proper ownership
touch /var/log/casaos-gateway.log
touch /var/log/casaos-app-management.log
touch /var/log/casaos-user-service.log
touch /var/log/casaos-message-bus.log
touch /var/log/casaos-local-storage.log
touch /var/log/casaos-main.log

chown "$PUID:$PGID" /var/log/casaos-*.log

# Define comprehensive log filter function
filter_logs() {
    local service_name="$1"

    while IFS= read -r line; do
        # Skip all HTTP 200 status requests (successful requests - usually not needed for debugging)
        if echo "$line" | grep -q '"status":200'; then
            continue
        fi

        # Skip HTTP 401 status requests (authentication failures - often just expired sessions)
        if echo "$line" | grep -q '"status":401'; then
            continue
        fi

        # Skip repetitive x-casaos errors (show only once at startup)
        if echo "$line" | grep -q "extension \`x-casaos\` not found"; then
            local error_marker="/tmp/xcasaos-error-${service_name}"
            if [ ! -f "$error_marker" ]; then
                echo "$line"
                touch "$error_marker"
            fi
            continue
        fi

        # Skip repetitive NVIDIA GPU errors (show only once at startup)
        if echo "$line" | grep -q "NvidiaGPUInfoList error.*nvidia-smi.*executable file not found"; then
            local gpu_marker="/tmp/nvidia-error-${service_name}"
            if [ ! -f "$gpu_marker" ]; then
                echo "$line"
                touch "$gpu_marker"
            fi
            continue
        fi

        # Skip Chinese ping messages
        if echo "$line" | grep -q "消息来了"; then
            continue
        fi

        # Skip any line that's just a user agent string (these are often incomplete log lines)
        if echo "$line" | grep -q "Mozilla/5.0.*Chrome.*Safari" && ! echo "$line" | grep -q '"time":'; then
            continue
        fi

        # Skip health check endpoints
        if echo "$line" | grep -q '"uri":".*health"'; then
            continue
        fi

        # Skip ping/heartbeat endpoints
        if echo "$line" | grep -q '"uri":".*ping"'; then
            continue
        fi

        # Skip WebSocket upgrade requests (unless they're errors)
        if echo "$line" | grep -q '"uri":".*websocket"' && echo "$line" | grep -q '"status":101'; then
            continue
        fi

        # Show everything else (actual errors, warnings, important info)
        echo "$line"
    done
}

echo "Starting CasaOS services as UID:GID $PUID:$PGID..."
echo "Docker group ID: $DOCKER_GID"

# Start the Gateway service with filtering
gosu "$PUID:$PGID" /usr/local/bin/casaos-gateway 2>&1 | filter_logs "gateway" > /var/log/casaos-gateway.log &

# Wait for the Gateway service to start
while [ ! -f /var/run/casaos/management.url ]; do
  echo "Waiting for the Gateway service to start..."
  sleep 1
done
while [ ! -f /var/run/casaos/static.url ]; do
  echo "Waiting for the Gateway service to start..."
  sleep 1
done

# Start the MessageBus service with filtering
gosu "$PUID:$PGID" /usr/local/bin/casaos-message-bus 2>&1 | filter_logs "message-bus" > /var/log/casaos-message-bus.log &

# Wait for the MessageBus service to start
while [ ! -f /var/run/casaos/message-bus.url ]; do
  echo "Waiting for the MessageBus service to start..."
  sleep 1
done

# Start the Main service with filtering
gosu "$PUID:$PGID" /usr/local/bin/casaos-main 2>&1 | filter_logs "main" > /var/log/casaos-main.log &

# Wait for the Main service to start
while [ ! -f /var/run/casaos/casaos.url ]; do
  echo "Waiting for the Main service to start..."
  sleep 1
done

# Start the LocalStorage service with filtering
gosu "$PUID:$PGID" /usr/local/bin/casaos-local-storage 2>&1 | filter_logs "local-storage" > /var/log/casaos-local-storage.log &

# Wait for /var/run/casaos/routes.json to be created and contains local_storage
while [ ! -f /var/run/casaos/routes.json ] || ! grep -q "local_storage" /var/run/casaos/routes.json; do
    echo "Waiting for /var/run/casaos/routes.json to be created and contains local_storage..."
    sleep 1
done

# Start the AppManagement service with dynamic Docker group ID and filtering
gosu "$PUID:$DOCKER_GID" /usr/local/bin/casaos-app-management 2>&1 | filter_logs "app-management" > /var/log/casaos-app-management.log &

# Start the UserService service with filtering
gosu "$PUID:$PGID" /usr/local/bin/casaos-user-service 2>&1 | filter_logs "user-service" > /var/log/casaos-user-service.log &

# Run the register UI events script
chown -R "$PUID:$PGID" /usr/local/bin/register-ui-events.sh
gosu "$PUID:$PGID" /usr/local/bin/register-ui-events.sh

echo "All CasaOS services started successfully!"

# Tail the log files to keep the container running and to display the logs in stdout
# Now the logs are already filtered at the file level
tail -f \
/var/log/casaos-gateway.log \
/var/log/casaos-app-management.log \
/var/log/casaos-user-service.log \
/var/log/casaos-message-bus.log \
/var/log/casaos-local-storage.log \
/var/log/casaos-main.log