#!/usr/bin/env bash
set -Eeuo pipefail

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

trap 'error "Status $? while: $BASH_COMMAND (line $LINENO/$BASH_LINENO)"' ERR

[ ! -f "/usr/local/bin/entrypoint.sh" ] && error "Script must run inside Docker container!" && exit 11
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 12

echo "❯ Starting CasaOS for Docker v$(</etc/version)..."
echo "❯ For support visit https://github.com/dockur/casa/issues"

checkEnvironment() {

  if [ ! -S /var/run/docker.sock ]; then
    error "Docker socket is missing? Please bind /var/run/docker.sock in your compose file." && exit 13
  fi

  return 0
}

checkDocker() {

  if ! docker info >/dev/null 2>&1; then
    error "Failed to connect to the Docker daemon through /var/run/docker.sock." && exit 22
  fi

  if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose is not available. Please install the Docker Compose plugin." && exit 23
  fi

  return 0
}

configureReferenceNetwork() {

  export REF_NET="$net"
  export REF_SEPARATOR="-"

  return 0
}

configureNetwork() {

  local current_subnet=""
  local network_json=""

  network_json="$(docker network inspect "$net" 2>/dev/null || true)"

  if [ -n "$network_json" ]; then
    current_subnet="$(jq -r '.[0].IPAM.Config[0].Subnet // ""' <<<"$network_json")"
  fi

  if [ -n "$current_subnet" ] && [ "$current_subnet" != "$subnet" ]; then
    info "Recreating bridge network '$net' because subnet changed from $current_subnet to $subnet..."

    if ! docker network rm "$net" >/dev/null 2>&1; then
      error "Failed to remove bridge network '$net'. Stop containers using it first." && exit 14
    fi
  fi

  if ! docker network inspect "$net" &>/dev/null; then
    if ! docker network create --driver=bridge "--subnet=$subnet" "$net" >/dev/null; then
      error "Failed to create bridge network '$net'!" && exit 14
    fi
  fi

  if ! docker network inspect "$net" &>/dev/null; then
    error "Bridge network '$net' does not exist?" && exit 15
  fi

  return 0
}

detectContainerId() {

  cid=$(grep -oE '[0-9a-f]{12,64}' /proc/self/cgroup | head -n1 || :)
  [ -z "$cid" ] && cid=$(grep -m1 "containers" /proc/self/mountinfo | sed -E 's#.*/containers/([^/]+)/.*#\1#') || :

  return 0
}

detectContainerNameFromId() {

  [ -z "$cid" ] && return 0

  name=$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's#^/##') || :
  [ -z "$name" ] && name="$cid"

  return 0
}

detectContainerNameFromHostname() {

  local matches=()

  [ -n "$name" ] && return 0

  mapfile -t matches < <(
    docker ps -q |
    xargs -r docker inspect --format '{{.Name}} {{.Config.Hostname}}' |
    awk -v target="$host" '$2 == target { print substr($1, 2) }'
  )

  if [ "${#matches[@]}" -eq 1 ]; then
    name="${matches[0]}"
  fi

  return 0
}

detectContainerName() {

  # Determine container name
  detectContainerId
  detectContainerNameFromId
  detectContainerNameFromHostname

  # Check if container name is valid
  if [ -z "$name" ] || ! docker inspect "$name" &>/dev/null; then
    error "Failed to identify the current container!" && exit 16
  fi

  return 0
}

inspectContainer() {

  # Inspect the container
  resp=$(docker inspect "$name") || {
    error "Failed to inspect container $name!" && exit 16
  }

  return 0
}

imageRepository() {

  local image="${1%%@*}"

  # Remove the tag from the final path component while preserving a registry port
  sed -E 's#:[^/:]+$##' <<<"$image"

  return 0
}

checkOtherInstance() {

  local container=""
  local container_image=""
  local container_name=""
  local container_repo=""
  local current_image=""
  local current_repo=""
  local other=""

  current_image=$(jq -r '.[0].Config.Image // ""' <<<"$resp")
  current_repo=$(imageRepository "$current_image")

  while read -r container; do
    [ -z "$container" ] && continue

    container_name=$(docker inspect -f '{{.Name}}' "$container" 2>/dev/null | sed 's#^/##') || continue
    [ "$container_name" = "$name" ] && continue

    container_image=$(docker inspect -f '{{.Config.Image}}' "$container" 2>/dev/null) || continue
    container_repo=$(imageRepository "$container_image")

    if [ -n "$current_repo" ] && [ "$container_repo" = "$current_repo" ]; then
      other="$container_name"
      break
    fi
  done < <(docker ps -q)

  if [ -n "$other" ]; then
    error "Another CasaOS container is already running: $other" && exit 24
  fi

  return 0
}

connectNetwork() {

  local network

  # Connect to bridge network
  network=$(jq -r ".[0].NetworkSettings.Networks[\"$net\"]" <<<"$resp")

  if [ -z "$network" ] || [[ "$network" == "null" ]]; then
    if ! docker network connect "$net" "$name"; then
      error "Failed to connect container to bridge network '$net'!" && exit 17
    fi
  fi

  return 0
}

detectDataMount() {

  mount=$(jq -r '.[0].Mounts[] | select(.Destination == "/DATA").Source' <<<"$resp")

  if [ -z "$mount" ] || [[ "$mount" == "null" ]] || [ ! -d "/DATA" ]; then
    error "You did not bind the /DATA folder!" && exit 18
  fi

  return 0
}

normalizeMountPath() {

  # Convert Windows paths to Linux path
  if [[ "$mount" == *":\\"* ]]; then
    mount="${mount,,}"
    mount="${mount//\\//}"
    mount="//${mount/:/}"
  fi

  if [[ "$mount" != "/"* ]]; then
    error "Please bind the /DATA folder to an absolute path!" && exit 19
  fi

  return 0
}

mirrorDataMount() {

  # Mirror external folder to local filesystem
  if [[ "$mount" == "/DATA" ]]; then
    return 0
  fi

  case "$mount" in
    ""|"/"|"/DATA"|"/data"|"/proc"|"/sys"|"/dev"|"/run"|"/tmp"|"/var"|"/etc"|"/usr"|"/opt"|"/home")
      error "Refusing to replace unsafe mount path: $mount" && exit 20
      ;;
  esac

  mkdir -p "$(dirname -- "$mount")"

  if [ -e "$mount" ] && [ ! -L "$mount" ]; then
    error "Mount path already exists and is not a symlink: $mount" && exit 21
  fi

  rm -f -- "$mount"
  ln -s /DATA "$mount"

  return 0
}

configureDataRoot() {

  export DATA_ROOT="$mount"

  return 0
}

configureIdentity() {

  # Get UID/GID from environment variables (default to 1000 if not set)
  PUID=${PUID:-1000}
  PGID=${PGID:-1000}

  # Get Docker group ID from the docker socket file
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "999")

  # Ensure group with PGID exists
  if ! getent group "$PGID" >/dev/null; then
    groupadd -g "$PGID" casaos
  fi

  # Ensure user with PUID exists
  if ! getent passwd "$PUID" >/dev/null; then
    useradd -u "$PUID" -g "$PGID" -M -s /sbin/nologin casaos
  fi

  return 0
}

prepareDirectories() {

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

  return 0
}

prepareLogs() {

  # Create log files with proper ownership
  touch /var/log/casaos-gateway.log
  touch /var/log/casaos-app-management.log
  touch /var/log/casaos-user-service.log
  touch /var/log/casaos-message-bus.log
  touch /var/log/casaos-local-storage.log
  touch /var/log/casaos-main.log

  chown "$PUID:$PGID" /var/log/casaos-*.log

  return 0
}

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

    # Skip systemd warnings
    if echo "$line" | grep -q "This process is not running as a systemd service."; then
      continue
    fi

    # Show everything else (actual errors, warnings, important info)
    echo "$line"
  done
}

startService() {

  local service_name="$1"
  local command="$2"
  local group="${3:-$PGID}"
  local log_file="/var/log/casaos-${service_name}.log"

  gosu "$PUID:$group" "$command" 2>&1 | filter_logs "$service_name" > "$log_file" &
}

waitForFile() {

  local file="$1"
  local service_name="$2"

  while [ ! -f "$file" ]; do
    info "Waiting for the $service_name service to start..."
    sleep 1
  done
}

waitForRoutes() {

  # Wait for /var/run/casaos/routes.json to be created and contains local_storage
  while [ ! -f /var/run/casaos/routes.json ] || ! grep -q "local_storage" /var/run/casaos/routes.json; do
    info "Waiting for routes to be created..."
    sleep 1
  done
}

startCasaServices() {

  # Start the Gateway service with filtering
  startService "gateway" "/usr/local/bin/casaos-gateway"

  # Wait for the Management service to start
  waitForFile "/var/run/casaos/management.url" "Management"

  # Wait for the Gateway service to start
  waitForFile "/var/run/casaos/static.url" "Gateway"

  # Start the MessageBus service with filtering
  startService "message-bus" "/usr/local/bin/casaos-message-bus"

  # Wait for the MessageBus service to start
  waitForFile "/var/run/casaos/message-bus.url" "MessageBus"

  # Start the Main service with filtering
  startService "main" "/usr/local/bin/casaos-main"

  # Wait for the Main service to start
  waitForFile "/var/run/casaos/casaos.url" "Main"

  # Start the LocalStorage service with filtering
  startService "local-storage" "/usr/local/bin/casaos-local-storage"

  waitForRoutes

  # Start the AppManagement service with dynamic Docker group ID and filtering
  startService "app-management" "/usr/local/bin/casaos-app-management" "$DOCKER_GID"

  # Start the UserService service with filtering
  startService "user-service" "/usr/local/bin/casaos-user-service"
}

runRegisterUiEvents() {

  # Run the register UI events script
  chown -R "$PUID:$PGID" /usr/local/bin/register-ui-events.sh
  gosu "$PUID:$PGID" /usr/local/bin/register-ui-events.sh

  return 0
}

configureRclone() {

  # Configure rclone
  mkdir -p /var/run/rclone
  touch /var/run/rclone/rclone.sock

  # Ensure rclone socket has correct permissions
  chown "$PUID:$PGID" /var/run/rclone/rclone.sock

  return 0
}

startSamba() {

  : "${SAMBA:="Y"}"

  if [[ "$SAMBA" != [Nn]* ]]; then
    if ! smbd; then
      error "Samba daemon failed to start!"
      smbd -i --debug-stdout || true
    fi
  fi

  return 0
}

tailLogs() {

  trap - ERR

  # Tail the log files to keep the container running and to display the logs in stdout
  # Now the logs are already filtered at the file level
  tail -f \
  /var/log/casaos-gateway.log \
  /var/log/casaos-app-management.log \
  /var/log/casaos-user-service.log \
  /var/log/casaos-message-bus.log \
  /var/log/casaos-local-storage.log \
  /var/log/casaos-main.log
}

checkEnvironment
checkDocker

cid=""
name=""
net="casa-net"
host=$(hostname -s)
subnet="${SUBNET:-10.22.0.0/16}"

configureReferenceNetwork
detectContainerName
inspectContainer
checkOtherInstance
configureNetwork
connectNetwork
detectDataMount
normalizeMountPath
mirrorDataMount
configureDataRoot
configureIdentity
prepareDirectories
prepareLogs
startCasaServices
runRegisterUiEvents
configureRclone
startSamba
tailLogs
