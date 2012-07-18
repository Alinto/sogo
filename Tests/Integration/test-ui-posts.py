#!/usr/bin/python


from config import hostname, port, username, password, \
                   webCalendarURL

import simplejson
import sogoLogin
import sogotests
import unittest
import utilities
import webdavlib
import httplib


class UIPostsTests(unittest.TestCase):

  def setUp(self):
    self.client = webdavlib.WebDAVClient(hostname, port)
    self.gcClient = webdavlib.WebDAVClient(hostname, port)
    self.cookie = sogoLogin.getAuthCookie(hostname, port, username, password)

  def _urlPostData(self, client, url, data, exp_status=200):
    post = webdavlib.HTTPPOST(url, data)
    post.content_type = "application/x-www-form-urlencoded"
    post.cookie = self.cookie

    client.execute(post)
    if (exp_status is not None):
      self.assertEquals(post.response["status"], exp_status)
    return post.response

  def _urlGet(self, client, url, exp_status=200):
    get = webdavlib.HTTPGET(url)
    get.cookie = self.cookie

    client.execute(get)
    if (exp_status is not None):
      self.assertEquals(get.response["status"], exp_status)
    return get.response

  def testAddWebCalendar(self):
    """ Add Web Calendar """

    ret=True
    data = "url=%s" % webCalendarURL
    calendarBaseURL="/SOGo/so/%s/Calendar" % username
    addWebCalendarURL = "%s/addWebCalendar" % calendarBaseURL
    response = self._urlPostData(self.client, addWebCalendarURL, data)

    respJSON = simplejson.loads(response['body'])
    folderID = respJSON['folderID']

    #sogo1:Calendar/C07-5006F300-1-370E2480
    (_, calID) = folderID.split('/', 1)
    self.assertNotEqual(calID, None)

    # reload the cal
    calURL = "%s/%s" % (calendarBaseURL, calID)
    try:
      response = self._urlGet(self.client, "%s/reload" % calURL, exp_status=None)
    except httplib.BadStatusLine:
      # that's bad, the server probably reset the connection. fake a 502
      response['status'] = 502

    # cleanup our trash
    self._urlPostData(self.gcClient, "%s/delete" % calURL, "", exp_status=None)

    # delayed assert to allow cal deletion on failure
    self.assertEqual(response['status'], 200)

    
    
if __name__ == "__main__":
    sogotests.runTests()
