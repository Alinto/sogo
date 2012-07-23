#!/usr/bin/python
# cas-proxy-validate.py - this file is part of SOGo
#
#  Copyright (C) 2010 Inverse inc.
#
# Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# This script provides a CGI to avoid reentrancy issues when using SOGo in CAS
# mode

# debian dep: python-memcache

import cgi
import memcache
import os
import sys

config = { "cas-addr": "127.0.0.1",
           "memcached-addrs": ["127.0.0.1:11211"] }

class CASProxyValidator:
    def run(self):
        if os.environ.has_key("GATEWAY_INTERFACE"):
            self._runAsCGI()
        else:
            self._runAsCmd()

    def _runAsCGI(self):
        if self._cgiChecks():
            form = cgi.FieldStorage()
	    if form.list == []:
		message = "Empty parameters : assuming cert. validation"
		self._printCGIError(message, 200)
		return
            if form.has_key("pgtId") and form.has_key("pgtIou"):
                pgtIou = form.getfirst("pgtIou")
                pgtId = form.getfirst("pgtId")
                self._registerPGTIdAndIou(pgtIou, pgtId)
                message = "'%s' set to '%s'" \
                          % ("cas-pgtiou:%s" % pgtIou, pgtId)
                self._printCGIError(message, 200)
            else:
                self._printCGIError("Missing parameter.")

    def _cgiChecks(self):
        rc = False

        if os.environ["REQUEST_METHOD"] == "GET":
            if os.environ["REMOTE_ADDR"] == config["cas-addr"]:
                rc = True
            else:
                self._printCGIError("Who are you? (%s)" % os.environ["REMOTE_ADDR"])
        else:
            self._printCGIError("Only 'GET' is accepted.")

        return rc

    def _printCGIError(self, message, code = 403):
        print("Status: %d\n"
              "Content-Type: text/plain; charset=utf-8\n\n%s"
              % (code, message))

    def _runAsCmd(self):
        if len(sys.argv) == 3:
            self._registerPGTIdAndIou(sys.argv[1], sys.argv[2])
            print "set '%s' to '%s'" \
                  % ("cas-pgtiou:%s" % sys.argv[1], sys.argv[2])
        else:
            raise Exception, "Missing or too many parameters."

    def _registerPGTIdAndIou(self, pgtIou, pgtId):
        mc = memcache.Client(config["memcached-addrs"])
        mc.set("cas-pgtiou:%s" % pgtIou, pgtId)

if __name__ == "__main__":
    process = CASProxyValidator()
    process.run()
