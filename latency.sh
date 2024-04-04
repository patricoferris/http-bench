#! /usr/bin/env bash
set -xe

rm -rf output/*
mkdir -p output

for backend in "miou" "posix" "linux" "linux-big-queue"; do
  ./_build/default/main.exe -b $backend &
  running_pid=$!
  echo "Measuring latency of $backend"
  sleep 2;
  wrk2 \
    -t2 -c1000 -d30s \
    --timeout 2000 \
    -R 200000 --latency \
    -H 'Connection: keep-alive' \
    "http://localhost:9091" > output/run-$backend.txt;
  kill ${running_pid};
  sleep 1;
done
echo "The results are available in $PWD/output"
