#!/usr/bin/python

import sys
import samba.param

a = samba.param.LoadParm()
a.load_default()
print a.get(sys.argv[1])
