#!/usr/bin/python

# XXX this script has to be run as root because it su to sogo_user
# in order to use its .GNUstepDefaults prefs
# Would be much better to have another way to specify which Defaults to use

from config import sogo_user, sogo_tool_path

import os
import pwd
import shutil
import sogotests
import tempfile
import unittest

class sogoToolTest(unittest.TestCase):

    def setUp(self):
      self.backupdir = tempfile.mkdtemp()

    def tearDown(self):
      os.chdir("/")
      shutil.rmtree(self.backupdir)

    def testBackupAll(self):
      """ sogo-tool backup ALL """

      (uid, gid) = pwd.getpwnam(sogo_user)[2:4]

      # We need to run as root since there's no way
      # of using another user's GNUstepDefaults
      self.assertEqual(os.getuid(), 0, "this test must run as root...")

      os.chown(self.backupdir, uid, gid)
      cmd = "sudo -u %s bash -c \"(cd %s && %s backup . ALL >/dev/null 2>&1)\"" % (sogo_user, self.backupdir, sogo_tool_path)
      print "sogo-tool cmd to execute %s" % cmd
      status = os.system(cmd)
      print "Exit status of os.system(): %d" % status
      rc = os.WEXITSTATUS(status)
      self.assertEqual(rc, 0, "sogo-tool failed RC=%d" % rc)


if __name__ == "__main__":
    sogotests.runTests()
