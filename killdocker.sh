docker service rm $(docker service ls | grep jmbc-owncloud | cut -f1 -d' ' | xargs)
