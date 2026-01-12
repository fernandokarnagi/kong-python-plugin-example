#!/usr/bin/env python3

import sys

sys.path.append('/usr/local/lib/python3.12/dist-packages')

from kong_pdk import cli

cli.start_server()