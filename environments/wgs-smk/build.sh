#!/bin/bash

# # Test build
# docker build -t clarity001/wgs-smk:test -f Dockerfile --progress=plain . 2>&1 | tee build.log

# Build and push to dockerhub
docker build -t clarity001/wgs-smk:latest -f Dockerfile --progress=plain --push . 2>&1 | tee build.log
