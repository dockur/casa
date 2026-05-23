#!/bin/sh

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
