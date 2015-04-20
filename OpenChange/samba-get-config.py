#!/usr/bin/python

import sys
import samba.param

a = samba.param.LoadParm()
a.set('debug level', '0')
a.load_default()
print a.get(sys.argv[1])
