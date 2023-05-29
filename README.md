# OwnCloud-on-DockerSwarm
Shell scripts to deploy OwnCloud File sharing to Docker Swarm Cluster

docker-compose.yml originally copied from ...

To get started...

Just add execute permission "chmod 700 install.sh" 
and run "./install.sh"

For docker containers that need local volume
Creates "/srv"
Creates "/srv/jmbc-owncloud"

Assumes 192.168.0.11,192.168.0.12,192.168.0.13 are the hostnames assigned to owncloud
-Erase or change "trusted_domains.txt"

username/password is admin/admin

published port is 8080

