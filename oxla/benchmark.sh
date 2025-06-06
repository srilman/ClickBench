#!/bin/bash -e

# docker
sudo apt install docker.io

# base
sudo apt-get install -y postgresql-client curl wget apt-transport-https ca-certificates software-properties-common gnupg2 parallel
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential

# download dataset
echo "Download dataset."
wget --continue 'https://datasets.clickhouse.com/hits_compatible/hits.csv.gz'
echo "Unpack dataset."
gzip -d -f hits.csv.gz
mkdir data
mv hits.csv data

# get and configure Oxla image
echo "Install and run Oxla."

sudo docker run --rm -p 5432:5432 -v data:/data --name oxlacontainer public.ecr.aws/oxla/release:1.53.0-beta > /dev/null 2>&1 &
sleep 30 # waiting for container start and db initialisation (leader election, etc.)

# create table and ingest data
export PGCLIENTENCODING=UTF8

PGPASSWORD=oxla psql -h localhost -U oxla -t < create.sql
echo "Insert data."
PGPASSWORD=oxla psql -h localhost -U oxla -t -c '\timing' -c "COPY hits FROM '/data/hits.csv';"

# get ingested data size
echo "data size after ingest:"
PGPASSWORD=oxla psql -h localhost -U oxla -t -c '\timing' -c "SELECT pg_total_relation_size('hits');"

# Note from the ClickBench maintainers: The original submission had below sleep statement. The benchmark rules are sceptical of such calls:
#     "You should not wait for cool down after data loading or running OPTIMIZE / VACUUM before the main benchmark queries unless it is strictly required for the system."
# I (rschu1ze) therefore re-ran the benchmark without sleep and it did not change the result. Therefore commenting sleep out.
#
# wait for merges to finish
# sleep 60

# run benchmark
echo "running benchmark..."
./run.sh
