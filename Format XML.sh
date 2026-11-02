#!/usr/bin/env python3

import sys
import xml.dom.minidom

dom = xml.dom.minidom.parse(sys.stdin) # or xml.dom.minidom.parseString(xml_string)
print(dom.toprettyxml())
