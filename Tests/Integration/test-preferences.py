#!/usr/bin/python
from config import hostname, port, username, password

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

if __name__ == "__main__":
    sogotests.runTests()
