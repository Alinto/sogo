#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username, attendee1, attendee1_delegate

import unittest

class CalDAVITIPDelegationTest(unittest.TestCase):
    def testConfigPY(self):
        """ config.py validation """
        try:
            test = hostname
        except:
            self.fail("'hostname' is not defined")

        try:
            test = username
        except:
            self.fail("'username' is not defined")

        try:
            test = subscriber_username
        except:
            self.fail("'subscriber_username' is not defined")

        try:
            test = attendee1
        except:
            self.fail("'attendee1' is not defined")

        try:
            test = attendee1_delegate
        except:
            self.fail("'attendee1_delegate' is not defined")

        self.assertEquals(subscriber_username, attendee1,
                          "'subscriber_username' and 'attendee1'"
                          + " must be the same user")

        userHash = {}
        userList = [ username, subscriber_username, attendee1_delegate ]
        for user in userList:
            self.assertFalse(userHash.has_key(user),
                             "username, attendee1, attendee1_delegate must"
                             + " all be different users ('%s')"
                             % user)
            userHash[user] = True

if __name__ == "__main__":
    unittest.main()
