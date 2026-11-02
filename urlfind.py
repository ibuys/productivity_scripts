#!/usr/bin/env python3
"""Extract URLs from standard input, one per line."""

import re
import sys

URL_PATTERN = re.compile(
    r"""(?i)\b((?:[a-z][\w-]+:(?:/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))"""
)

for line in sys.stdin:
    for match in URL_PATTERN.finditer(line):
        print(match.group(0))
