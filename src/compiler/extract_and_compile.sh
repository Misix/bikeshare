#!/usr/bin/env bash

# This script will find all the station statuses inside a directory,
# add the appropriate system ID, and spit out a resulting CSV file that
# is suitable for importing into a database.

# MODIFICATION NOTE:
# This version of the script does NOT look for an already-extracted
# dataset. Instead, this can work directly on any .tar.bz2 file that
# was created using the dumper.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! $1 ]]
then
  echo "Please specify an archive file. Results will be sent to stdout"
  exit 1
fi

archive_file="$1"
out_file="/mnt/ram/$(openssl rand -hex 8).csv"

tmp_dir="/tmp/$(openssl rand -hex 16)"
mkdir -p "$tmp_dir"

# Extract the archive to the temporary directory
tar xf "$archive_file" -C "$tmp_dir"

# Find all the valid files in this temporary place
data_dirs="$tmp_dir/data_dirs.txt"
find "$tmp_dir" -name "station_status.json" | sed 's|/[^/]*$||' > "$data_dirs"

# For each of those, grab the data
while read -r data_path
do
  system_id="$(jq -r '.data.system_id' $data_path/system_information.json 2>&1)" 2>&1
  
  # Some stations are broken, so we skip those.
  if [[ 0 != $? ]]
  then
    continue
  fi
  
  jq -r ".data.stations | .[].system_id=\"$system_id\" | .[]" "$data_path/station_status.json" 2>&1 | jq -rs "" 2>&1 | json2csv -f "system_id,station_id,num_bikes_available,num_bikes_disabled,num_docks_available,num_docks_disabled,is_installed,is_renting,is_returning,last_reported" 2>&1 | tail -n +2 2>&1
  
done < "$data_dirs"

rm -r "$tmp_dir"
