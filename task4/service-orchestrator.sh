#!/bin/bash

# Complete this script to deploy external-service and counter-service in two separate containers
# You will be using the conductor tool that you completed in task 3.

# Creating link to the tool within this directory
ln -s ../task3/conductor.sh conductor.sh
ln -s ../task3/config.sh config.sh

# use the above scripts to accomplish the following actions -

# Logical actions to do:
# 1. Build image for the container
bash ./conductor.sh build mydebian

# 2. Run two containers say c1 and c2 which should run in background. Tip: to keep the container running
#    in background you should use a init program that will not interact with the terminal and will not
#    exit. e.g. sleep infinity, tail -f /dev/null

# run the two containers
sudo bash conductor.sh run mydebian c1 "tail -f /dev/null" &
sudo bash conductor.sh run mydebian c2 "tail -f /dev/null" &

sleep 5

# 3. Copy directory external-service to c1 and counter-service to c2 at appropriate location. You can
#    put these directories in the containers by copying them within ".containers/{c1,c2}/rootfs/" directory

# Copy external-service to c1
cp -a external-service ./.containers/c1/rootfs/

# Copy counter-service to c2
cp -a counter-service ./.containers/c2/rootfs/

chmod -R 755 counter-service
chmod -R 755 external-service

# 4. Configure network such that:
# 4.a: c1 is connected to the internet and c1 has its port 8080 forwarded to port 3000 of the host
# 4.b: c2 is connected to the internet and does not have any port exposed
# 4.c: peer network is setup between c1 and c2

bash conductor.sh -i -e 8080-3000 addnetwork c1
bash conductor.sh -i addnetwork c2
bash conductor.sh peer c1 c2

# 5. Get ip address of c2. You should use script to get the ip address. 
#    You can use ip interface configuration within the host to get ip address of c2 or you can 
#    exec any command within c2 to get it's ip address
# Run the command and store the output in a variable

output=$(sudo bash conductor.sh exec c2 "ip a")
c2_ip=$(echo "$output" | grep c2-inside | grep inet)
ip=$(echo "$c2_ip" | grep -oP 'inet \K[^/]+')
echo "IP Address of container c2: $ip"

# 6. Within c2 launch the counter service using exec [path to counter-service directory within c2]/run.sh

./conductor.sh exec c2 "apt update" 
./conductor.sh exec c2 "apt install net-tools" 
./conductor.sh exec c2 "counter-service/run.sh" &
while true; do
    temp=$(sudo ./conductor.sh exec c2 "netstat -tuln" | grep 8080)
    if [ -n "$temp" ]; then
        echo "Port 8080 opened successfully"
        break
    else
        echo "Waiting for port 8080 to open"
        sleep 1
    fi
done
# 7. Within c1 launch the external service using exec [path to external-service directory within c1]/run.sh

sudo bash conductor.sh exec c1 "apt update" 
sudo bash conductor.sh exec c1 "apt install net-tools" 
sudo bash conductor.sh exec c1 "external-service/run.sh http://$ip:8080/" &
while true; do
    temp=$(sudo ./conductor.sh exec c1 "netstat -tuln" | grep 8080)
    if [ -n "$temp" ]; then
        echo "Port 8080 opened successfully"
        break
    else
        echo "Waiting for port 8080 to open"
        sleep 1
    fi
done

# wait
# 8. Within your host system open/curl the url: http://localhost:3000 to verify output of the service
output=$(ip a | grep enp | grep inet)
ip_address=$(echo "$output" | grep -oP 'inet \K[^/]+')
echo $ip_address

curl http://$ip_address:3000

# for checking
wait
# 9. On any system which can ping the host system open/curl the url: `http://<host-ip>:3000` to verify
#   output of the service

# sudo bash conductor.sh stop c1
# sudo bash conductor.sh stop c2

# sudo bash conductor.sh ps
