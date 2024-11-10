#!/usr/bin/env bash
set -Eeuo pipefail

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

[ ! -f "/root/entrypoint.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

echo "❯ Starting CasaOS for Docker v$(</run/version)..."
echo "❯ For support visit https://github.com/dockur/casa/issues"

if [ ! -S /var/run/docker.sock ]; then
  error "Docker socket is missing? Please bind /var/run/docker.sock in your compose file." && exit 13
fi

target=$(hostname)

if ! docker inspect "$target" &>/dev/null; then
  error "Failed to find a container with name '$target'!" && exit 16
fi

resp=$(docker inspect "$target")
mount=$(echo "$resp" | jq -r '.[0].Mounts[] | select(.Destination == "/DATA").Source')

if [ -z "$mount" ] || [[ "$mount" == "null" ]] || [ ! -d "/DATA" ]; then
  error "You did not bind the /DATA folder!" && exit 18
fi

# Convert Windows paths to Linux path
if [[ "$mount" == *":\\"* ]]; then
  mount="${mount,,}"
  mount="${mount//\\//}"
  mount="//${mount/:/}"
fi

if [[ "$mount" != "/"* ]]; then
  error "Please bind the /DATA folder to an absolute path!" && exit 19
fi

# Mirror external folder to local filesystem
if [[ "$mount" != "/DATA" ]]; then
  mkdir -p "$mount"
  rm -rf "$mount"
  ln -s /DATA "$mount"
fi

export DATA_ROOT="$mount"

# Create directories
mkdir -p /DATA/AppData/casaos

mkdir -p /var/log
touch /var/log/casaos-gateway.log
touch /var/log/casaos-app-management.log
touch /var/log/casaos-user-service.log
touch /var/log/casaos-mesage-bus.log
touch /var/log/casaos-local-storage.log
touch /var/log/casaos-main.log

# Start the Gateway service and redirect stdout and stderr to the log files
./casaos-gateway > /var/log/casaos-gateway.log 2>&1 &

# Wait for the Gateway service to start
while [ ! -f /var/run/casaos/management.url ]; do
  info "Waiting for the Management service to start..."
  sleep 1
done

while [ ! -f /var/run/casaos/static.url ]; do
  info "Waiting for the Gateway service to start..."
  sleep 1
done

# Start the MessageBus service and redirect stdout and stderr to the log files
./casaos-message-bus > /var/log/casaos-message-bus.log 2>&1 &

# Wait for the Gateway service to start
while [ ! -f /var/run/casaos/message-bus.url ]; do
  info "Waiting for the Message service to start..."
  sleep 1
done

# Start the Main service and redirect stdout and stderr to the log files
./casaos-main > /var/log/casaos-main.log 2>&1 &
# Wait for the Main service to start
while [ ! -f /var/run/casaos/casaos.url ]; do
  info "Waiting for the Main service to start..."
  sleep 1
done

# Start the LocalStorage service and redirect stdout and stderr to the log files
./casaos-local-storage > /var/log/casaos-local-storage.log 2>&1 &

# wait for /var/run/casaos/routes.json to be created and contains local_storage
# Wait for /var/run/casaos/routes.json to be created and contains local_storage
while [ ! -f /var/run/casaos/routes.json ] || ! grep -q "local_storage" /var/run/casaos/routes.json; do
    info "Waiting for /var/run/casaos/routes.json to be created and contains local_storage..."
    sleep 1
done

# Start the AppManagement service and redirect stdout and stderr to the log files
./casaos-app-management > /var/log/casaos-app-management.log 2>&1 &

# Start the UserService service and redirect stdout and stderr to the log files
./casaos-user-service > /var/log/casaos-user-service.log 2>&1 &

./register-ui-events.sh

# Tail the log files to keep the container running and to display the logs in stdout
tail -f \
/var/log/casaos-gateway.log \
/var/log/casaos-app-management.log \
/var/log/casaos-user-service.log \
/var/log/casaos-message-bus.log \
/var/log/casaos-local-storage.log \
/var/log/casaos-main.log
