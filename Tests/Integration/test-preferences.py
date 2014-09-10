#!/usr/bin/python
from config import hostname, port, username, password, white_listed_attendee

import preferences
import simplejson
import sogotests
import unittest
import utilities

class preferencesTest(unittest.TestCase):

    def _setTextPref(self, prefText = None ):
      """ set a text preference to a known value """
      self.prefs.set("autoReplyText", prefText)

      # make sure it was set correctly
      prefData = self.prefs.get("Vacation")
        
      self.assertEqual(prefData["autoReplyText"], prefText,
                  "%s != %s" % (prefData["autoReplyText"], prefText))

    def setUp(self):
      self.prefs = preferences.preferences()

    def tearDown(self):
      self.prefs.set("autoReplyText", "")

    def testSetTextPreferences(self):
      """ Set/get a text preference - normal characters"""
      
      self._setTextPref("defaultText")

    def testSetTextPreferencesWeirdChars(self):
      """ Set/get a text preference - weird characters - used to crash on 1.3.12"""
      prefText = "weird data   \ ' \"; ^"
      self._setTextPref(prefText)

    def testSetPreventInvitation(self):
      """ Set/get the PreventInvitation pref"""
      self.prefs.set('PreventInvitations', '0')
      notset = self.prefs.get_settings('')['Calendar']['PreventInvitations']
      self.assertEqual(notset, 0)
      self.prefs.set('enablePreventInvitations', '0')
      isset = self.prefs.get_settings('')['Calendar']['PreventInvitations']
      self.assertEqual(isset, 1)

    def testPreventInvitationsWhiteList(self):
      """Add to the PreventInvitations Whitelist"""
      self.prefs.set("whiteList", white_listed_attendee)
      whitelist = self.prefs.get_settings('Calendar')['PreventInvitationsWhitelist']
      self.assertEqual(whitelist, white_listed_attendee)



if __name__ == "__main__":
    sogotests.runTests()
