#!/Users/jonathan.buys/Unix/env/json2yaml/bin/python

import sys
import yaml
import json

yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)

