#!/bin/bash
sleep 5

INITIAL_CONFIG_FILE=/data/gpinitsystem_singlenode
MACHINE_LIST_FILE=/data/hostlist_singlenode

if [ -f /home/gpadmin/.profile ]; then
  source /home/gpadmin/.profile
else
  echo ">> Generating .profile ..."
  echo "source /opt/greenplum-db-6.8.1/greenplum_path.sh" > /home/gpadmin/.profile
fi

if [ ! -f /home/gpadmin/.ssh/id_rsa ]; then
  echo ">> Generating ssh keys ..."
  ssh-keygen -f /home/gpadmin/.ssh/id_rsa -t rsa -N ""
fi


if [ ! -f $INITIAL_CONFIG_FILE ]; then
  
  echo ">> creating /data ..."
  sudo mkdir -p /data
  sudo chown gpadmin -R /data
  

  echo ">> Generating $MACHINE_LIST_FILE ..."
  echo `hostname` > $MACHINE_LIST_FILE

  echo ">> creating /data/master ..."
  mkdir -p /data/master

  SEGMENT_DIRS=()
  for i in $(seq 1 $SEGMENTS)
  do 
    echo ">> Creating /data/segment$i ..."
    mkdir -p /data/segment$i
    SEGMENT_DIRS+=(/data/segment$i)
  done
  
  echo ">> Validating via gpssh-exkeys ..."
  gpssh-exkeys -f /data/hostlist_singlenode

  ### Generate the `gpinitsystem_singlenode`
  echo ">> Generting $INITIAL_CONFIG_FILE ..."
  echo "# FILENAME: $INITIAL_CONFIG_FILE" > $INITIAL_CONFIG_FILE
  echo "" >> $INITIAL_CONFIG_FILE
  echo "ARRAY_NAME='$ARRAY_NAME'" >> $INITIAL_CONFIG_FILE
  echo "MACHINE_LIST_FILE='$MACHINE_LIST_FILE'" >> $INITIAL_CONFIG_FILE
  echo "SEG_PREFIX=$SEG_PREFIX" >> $INITIAL_CONFIG_FILE
  echo "PORT_BASE=$PORT_BASE" >> $INITIAL_CONFIG_FILE
  echo "declare -a DATA_DIRECTORY=($(IFS=' ' ; echo "${SEGMENT_DIRS[*]}"))" >> $INITIAL_CONFIG_FILE
  echo "MASTER_HOSTNAME=`hostname`" >> $INITIAL_CONFIG_FILE
  echo "MASTER_DIRECTORY=/data/master" >> $INITIAL_CONFIG_FILE
  echo "MASTER_PORT=5432" >> $INITIAL_CONFIG_FILE
  echo "TRUSTED_SHELL=ssh" >> $INITIAL_CONFIG_FILE
  echo "CHECK_POINT_SEGMENTS=8" >> $INITIAL_CONFIG_FILE
  echo "ENCODING=UNICODE" >> $INITIAL_CONFIG_FILE
  if [ -n "$DATABASE_NAME" ]; then
    echo "DATABASE_NAME=$DATABASE_NAME" >> $INITIAL_CONFIG_FILE
  fi
  
  

  pushd /data
    echo ">> gpinitsystem ..."
    gpinitsystem -ac gpinitsystem_singlenode

    echo "host all  all 0.0.0.0/0 trust" >> /data/master/$SEG_PREFIX-1/pg_hba.conf

    echo ">> Restart ..."
    MASTER_DATA_DIRECTORY=/data/master/$SEG_PREFIX-1/ gpstop -a
    MASTER_DATA_DIRECTORY=/data/master/$SEG_PREFIX-1/ gpstart -a
  popd

  if [ ! -z $GP_USER ]; then
    echo "GP_USER: $GP_USER"
  else
    GP_USER=greenplum
    echo "GP_USER: $GP_USER"
  fi

  if [ ! -z $GP_PASSWORD ]; then
    echo "GP_PASSWORD: $GP_PASSWORD"
  else
    GP_PASSWORD=pivotal
    echo "GP_PASSWORD: $GP_PASSWORD"
  fi

  /opt/greenplum-db-6.8.1/bin/psql -v ON_ERROR_STOP=1 --username gpadmin --dbname postgres <<-EOSQL
CREATE USER $GP_USER WITH PASSWORD '$GP_PASSWORD' SUPERUSER;
CREATE USER guest WITH PASSWORD 'guest';
CREATE DATABASE guest WITH OWNER guest;
EOSQL

  cat << EOF
+------------------------------------------------------------------------------------
|  CREATE USER $GP_USER WITH PASSWORD '$GP_PASSWORD' SUPERUSER;
|  CREATE USER guest WITH PASSWORD 'guest';
|  CREATE DATABASE guest WITH OWNER guest;
+------------------------------------------------------------------------------------
EOF


  echo ">> DONE!"

else

  @echo ">> Starting greanplum ..."
  MASTER_DATA_DIRECTORY=/data/master/$SEG_PREFIX-1/ gpstart -a

fi
