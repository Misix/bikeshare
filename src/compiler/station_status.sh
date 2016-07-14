#!/usr/bin/env bash

# This script will find all the station statuses inside a directory,
# add the appropriate system ID, and spit out a resulting CSV file that
# is suitable for importing into a database.

# The first thing to do is find all the files named station_status.json
# inside the specified directory.

if [[ ! $1 ]] || [[ ! $2 ]]
then
  echo "Please specify a directory to search and an output file."
  exit 1
fi

search_dir="$1"
out_file="$2"

tmp_dir="/tmp/$(openssl rand -hex 16)"
mkdir -p "$tmp_dir"

# Dump the list of filenames, because it is easier to work with.
filenames="$tmp_dir/filenames.txt"
jsonlike_intermediate="$tmp_dir/json.like"
csv_intermediate="$tmp_dir/final.csv"

find "$search_dir" -name "station_status.json" > "$filenames"

header="$(cat station_status_header.txt)"
cat "station_status_header.txt" > "$out_file"

cat "$filenames" | parallel 'system_id="$(jq -r '.data.system_id' {//}/system_information.json)"; jq -r ".data.stations | .[].system_id=\"$system_id\" | .[]" "{}" | jq -rs "" | json2csv -f "system_id,station_id,num_bikes_available,num_bikes_disabled,num_docks_available,num_docks_disabled,is_installed,is_renting,is_returning,last_reported" | tail -n +2' >> "$out_file"

# It is faster not to include this part in the parallel process.
# header="$(cat station_status_header.txt)"
# jq -rs '' "$jsonlike_intermediate" | json2csv -f "$header" >> "$csv_intermediate"

# cp "$csv_intermediate" "$out_file"
rm -r "$tmp_dir"
