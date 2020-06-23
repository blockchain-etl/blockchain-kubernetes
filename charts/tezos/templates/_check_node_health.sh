#!/usr/bin/env sh
set -ex # -e exits on error

usage() { echo "Usage: $0 <datadir> <max_lag_in_seconds> <last_synced_block_file>]" 1>&2; exit 1; }

datadir="$1"
max_lag_in_seconds="$2"
last_synced_block_file="$3"

if [ -z "${datadir}" ] || [ -z "${max_lag_in_seconds}" ] || [ -z "${last_synced_block_file}" ]; then
    usage
fi

set +e

block_timestamp=$(tezos-client --chain {{ .Values.tezos.chain_id }} --block head get timestamp -s)

set -e
# https://unix.stackexchange.com/a/367406/255685
if [ -z "${block_timestamp}" ] || [ ${block_timestamp} -le 0 ]; then
    echo "Block number returned by the node is empty or not a number"
    exit 1
fi

if [ ! -f ${last_synced_block_file} ]; then
    old_block_timestamp="";
else
    old_block_timestamp=$(cat ${last_synced_block_file});
fi;

if [ "${block_timestamp}" != "${old_block_timestamp}" ]; then
  mkdir -p $(dirname "${last_synced_block_file}")
  echo ${block_timestamp} > ${last_synced_block_file}
fi

file_age=$(($(date +%s) - $(date -r ${last_synced_block_file} +%s)));
max_age=${max_lag_in_seconds};
echo "${last_synced_block_file} age is $file_age seconds. Max healthy age is $max_age seconds";
if [ ${file_age} -lt ${max_age} ]; then exit 0; else exit 1; fi
