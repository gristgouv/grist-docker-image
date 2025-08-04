#!/bin/env python3
import sys

main_version = sys.argv[1]
latest_tag = sys.argv[2]

if latest_tag.startswith(main_version):
    old_iteration = int(latest_tag.split("-")[1])
    new_iteration = old_iteration + 1
    print(f"{main_version}-{new_iteration}")
else:
    print(f"{main_version}-1")
