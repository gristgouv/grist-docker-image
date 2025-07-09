#!/bin/env python3

# validates that the docker tag matches the grist version configured in the dockerfile
# inputs :
# - first arg: docker tag
# - second arg: dockerfile to extract version from

import sys

tag = sys.argv[1]
dockerfile = sys.argv[2]
ARG_LINE_PREFIX = "ARG GRIST_VERSION="

with open(dockerfile, "r") as f:
    # handle ARG line possibly being moved in the future
    # by selecting the first line matching the prefix
    grist_version = [
        line for line in f.readlines() if line.startswith(ARG_LINE_PREFIX)
    ][0].removeprefix(ARG_LINE_PREFIX).removeprefix('v').strip()

print(f"GRIST_VERSION in Dockerfile is {grist_version}")

if not tag.startswith(grist_version):
    # startswith because we append an iteration number to our tags e.g. 1.6.1-1
    print("Please update the version in the Dockerfile to match the tag")
    exit(1)
