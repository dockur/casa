#!/usr/bin/env bash
set -Eeuo pipefail

if [ ! -S /var/run/docker.sock ]; then
  echo "ERROR: Docker socket is missing? Please bind /var/run/docker.sock in your compose file." && exit 13
fi

: "${REF_NET:="meta"}"

if ! docker network inspect "$REF_NET" &>/dev/null; then
  if ! docker network create --driver=bridge --subnet="10.21.0.0/16" "$REF_NET" >/dev/null; then
    echo "ERROR: Failed to create network '$REF_NET'!" && exit 14
  fi
  if ! docker network inspect "$REF_NET" &>/dev/null; then
    echo "ERROR: Network '$REF_NET' does not exist?" && exit 15
  fi
fi

target=$(hostname)

if ! docker inspect "$target" &>/dev/null; then
  echo "ERROR: Failed to find a container with name '$target'!" && exit 16
fi

resp=$(docker inspect "$target")
network=$(echo "$resp" | jq -r '.[0].NetworkSettings.Networks["$REF_NET"]')

if [ -z "$network" ] || [[ "$network" == "null" ]]; then
  if ! docker network connect "$REF_NET" "$target"; then
    echo "ERROR: Failed to connect container to network '$REF_NET'!" && exit 17
  fi
fi

mount=$(echo "$resp" | jq -r '.[0].Mounts[] | select(.Destination == "/DATA").Source')

if [ -z "$mount" ] || [[ "$mount" == "null" ]] || [ ! -d "/DATA" ]; then
  echo "ERROR: You did not bind the /DATA folder!" && exit 18
fi

# Convert Windows paths to Linux path
if [[ "$mount" == *":\\"* ]]; then
  mount="${mount,,}"
  mount="${mount//\\//}"
  mount="//${mount/:/}"
fi

if [[ "$mount" != "/"* ]]; then
  echo "ERROR: Please bind the /DATA folder to an absolute path!" && exit 19
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
  echo "Waiting for the Gateway service to start..."
  sleep 1
done
while [ ! -f /var/run/casaos/static.url ]; do
  echo "Waiting for the Gateway service to start..."
  sleep 1
done

# Start the MessageBus service and redirect stdout and stderr to the log files
./casaos-message-bus > /var/log/casaos-message-bus.log 2>&1 &

# Wait for the Gateway service to start
while [ ! -f /var/run/casaos/message-bus.url ]; do
  echo "Waiting for the Gateway service to start..."
  sleep 1
done

# Start the Main service and redirect stdout and stderr to the log files
./casaos-main > /var/log/casaos-main.log 2>&1 &
# Wait for the Main service to start
while [ ! -f /var/run/casaos/casaos.url ]; do
  echo "Waiting for the Main service to start..."
  sleep 1
done

# Start the LocalStorage service and redirect stdout and stderr to the log files
./casaos-local-storage > /var/log/casaos-local-storage.log 2>&1 &

# wait for /var/run/casaos/routes.json to be created and contains local_storage
# Wait for /var/run/casaos/routes.json to be created and contains local_storage
while [ ! -f /var/run/casaos/routes.json ] || ! grep -q "local_storage" /var/run/casaos/routes.json; do
    echo "Waiting for /var/run/casaos/routes.json to be created and contains local_storage..."
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
