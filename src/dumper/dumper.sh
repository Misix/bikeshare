#!/usr/bin/env bash

# Dumper
#
# This script will download all the available known sites that use the
# General Bikeshare Feed Specification (GBFS).
# 
# Usage:
#   ./dumper.sh

# This master list will define all the avilable feeds
MASTER_LIST="https://raw.githubusercontent.com/NABSA/gbfs/master/systems.csv"

# These are the programs required for the script to run successfully.
REQUIREMENTS=("openssl" "curl" "jq" "csvcut")

# This is a timestamp of when the dump is occuring.
DATE="$(date "+%Y-%m-%d")"
TIMESTAMP="$(date "+%s")"

# This is where the resulting data will be stored.
DATA_DIR="./data/$DATE/$TIMESTAMP"
mkdir -p "$DATA_DIR"

# Check the requirements
for program in "${REQUIREMENTS[@]}"
do
  if ! hash $program 2>/dev/null
  then
    echo "$program not found. Aborting."
    exit 1
  fi
done

# Now we can start cooking. Get the list of available systems, and start
# dumping.
urls=($(curl --silent "$MASTER_LIST" | csvcut -c "Auto-Discovery URL" | tail -n +2 | sort | uniq))

for feed in "${urls[@]}"
do
  # If this feed is not a gbfs.json file, then we do not yet know how
  # to handle it.
  if [[ "gbfs.json" != "$(echo "$feed" | rev | cut -d '/' -f 1 | rev)" ]]
  then
    echo "Not GBFS file, feed not supported. ($feed)"
    continue
  fi
  
  feed_hash="$(echo -n "$feed" | openssl dgst -sha1 -binary | xxd -p)"
  feed_dir="$DATA_DIR/$feed_hash"
  
  # The data does not already exist, so create a directory.
  mkdir -p "$feed_dir"
  
  # Inside of that, create a directory with the current timestamp. By
  # doing this, we can ensure that there won't be too many directories
  # for the filesystem.
  scrape_dir="$feed_dir/$DATE/$TIMESTAMP"
  mkdir -p "$scrape_dir"
  
  # Dump the primary link file
  cd "$scrape_dir" && {
    curl --silent -O "$feed"
    
    # Get the other links found in this feed, ignoring the gbfs.json
    # file we have already downloaded.
    other_files=($(jq -r '.data.en.feeds | .[].url' gbfs.json | grep -v "$feed"))
    
    for file in "${other_files[@]}"
    do
      curl --silent -O "$file"
    done
    
    cd -
  } > /dev/null
done

# Tar and compress everything.
tar -C "$DATA_DIR" -jcf "$DATA_DIR.tar.bz2" ./
rm -r "$DATA_DIR"
