#! /bin/bash

# env copied from 
export OWNCLOUD_VERSION=10.12
export OWNCLOUD_DOMAIN=localhost:8080
export OWNCLOUD_TRUSTED_DOMAINS=localhost
export ADMIN_USERNAME=admin
export ADMIN_PASSWORD=admin
export HTTP_PORT=8080

if [ "$OWNCLOUD_TRUSTED_DOMAINS" == "localhost" ]; then
  if [ ! -f trusted_domains.txt ]; then
    echo "no hosts/ip/domain besides localhost"
    echo "Please enter other values allowed in Host: HTTP header:"
    read OTHER_TRUSTED_DOMAIN
    echo $OTHER_TRUSTED_DOMAIN > trusted_domains.txt
  else
    OTHER_TRUSTED_DOMAIN=$(<trusted_domains.txt)
  fi
  if [ "$OTHER_TRUSTED_DOMAIN" != "" ]; then
    OWNCLOUD_TRUSTED_DOMAIN="localhost,$OTHER_TRUSTED_DOMAIN"
  fi
fi



# customized local volume config
SVC_PREFIX="jmbc-owncloud"
NFS_SHARE="/srv"
OWNCLOUD_SUBDIR="$NFS_SHARE/jmbc_owncloud"
OWNCLOUD_FRONTEND="$OWNCLOUD_SUBDIR/files"
OWNCLOUD_REDIS="$OWNCLOUD_SUBDIR/redis"
OWNCLOUD_MYSQL="$OWNCLOUD_SUBDIR/mysql"

exportfs &> /dev/null
if [ $? -ne 0 ]; then
  echo "NFS server not installed!  Install now? (y/n) [n]"
  read DO_NFS_INSTALL
  if [ "$DO_NFS_INSTALL" == "y" ]; then
    echo "It might ask for sudo password"
    sudo apt install nfs-kernel-server
  else
    exit
  fi
fi

if [ ! -d $NFS_SHARE ]; then
  echo "No srv dir, creating... It might ask for sudo password"
  sudo mkdir $NFS_SHARE
  sudo chmod 777 $NFS_SHARE
fi

showmount -e localhost | cut -f1 -d' ' | grep $NFS_SHARE &> /dev/null
if [ $? -ne 0 ]; then
  echo "No NFS mount ($NFS_SHARE) defined.  Creating, but may need sudo password"
  ALLOWED_SUBNET=$(<allowed_nfs_subnet.txt &> /dev/null)
  if [ "$ALLOWED_SUBNET" == "" ]; then
    echo "Enter X.X.X.X/X for hosts allowed to access NFS share [*]"
    read ALLOWED_SUBNET
    if [ "$ALLOWED_SUBNET" == "" ]; then
      ALLOWED_SUBNET="*"
    fi
    echo $ALLOWED_SUBNET > allowed_nfs_subnet.txt
  fi
  EXPORT_LINE="$NFS_SHARE		$ALLOWED_SUBNET(rw,sync,no_subtree_check)"
  sudo echo $EXPORT_LINE >> /var/exports
  sudo exportfs -ra
fi

sudo mkdir $OWNCLOUD_SUBDIR
sudo chmod 777 $OWNCLOUD_SUBDIR
mkdir $OWNCLOUD_FRONTEND
mkdir $OWNCLOUD_REDIS
mkdir $OWNCLOUD_MYSQL
# chmod 777 $OWNCLOUD_FRONTEND
# sudo chown -R www-data:www-data $OWNCLOUD_SUBDIR

if [ ! -d "$OWNCLOUD_SUBDIR" ]; then
  echo "$OWNCLOUD_SUBDIR doesnt exist. creation failed above"
  exit 1
fi


# important docker steps

docker image pull owncloud/server:$OWNCLOUD_VERSION
docker image pull mariadb:10.6
docker image pull redis:6

docker stack deploy --compose-file=docker-compose.yml $SVC_PREFIX


#waiting until service creates the config folder, before changing permissions
echo waiting for local volume to create folders
while [ ! -d "$OWNCLOUD_FRONTEND/config" ]; do
  echo -n "."
  sleep 1
done
echo "."
sleep 1
sudo chmod -R 777 $OWNCLOUD_FRONTEND/*



#waiting until service is up, then update front end to 3 replicas
echo Waiting for frontend to finish, before stopping chown
docker service ls | grep ${SVC_PREFIX}'_owncloud.*1/1' &> /dev/null
while [ $? -ne 0 ]; do
  echo -n "."
  sleep 1
  docker service ls | grep ${SVC_PREFIX}'_owncloud.*1/1' &> /dev/null
done
docker service ls | grep ${SVC_PREFIX}_owncloud
docker service update --replicas 3 ${SVC_PREFIX}_owncloud
docker service ls | grep ${SVC_PREFIX}_owncloud



# now update containers, to have chown=false
echo Removing chown option
docker stack deploy --compose-file=docker-compose_no_chown.yml $SVC_PREFIX
# the problem is that the chown option sets the permission correctly
# and if you turn it off, you have to manually set the permissions



#waiting until service is up, then update front end to 3 replicas
echo Waiting for front end to finish, before updating replicas
docker service ls | grep ${SVC_PREFIX}'_owncloud.*1/1' &> /dev/null
while [ $? -ne 0 ]; do
  echo -n "."
  sleep 1
  docker service ls | grep ${SVC_PREFIX}'_owncloud.*1/1' &> /dev/null
done
docker service ls | grep ${SVC_PREFIX}_owncloud
docker service update --replicas 3 ${SVC_PREFIX}_owncloud
docker service ls | grep ${SVC_PREFIX}_owncloud



# show the nodes running the front end container
echo These are the containers that are clustered:
docker service ps jmbc-owncloud_owncloud
