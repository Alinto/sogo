#!/usr/bin/python


from config import hostname, port, username, password

import json
import sogotests
import unittest
import webdavlib


class JSONFormsTests(unittest.TestCase):
  def setUp(self):
    self.client = webdavlib.WebDAVClient(hostname, port)

  def testJsonContactCreation(self):
    # json connect
    form_data = {"userName": username,
                 "password": password}
    data = json.dumps(form_data)
    post = webdavlib.HTTPPOST("/SOGo/connect", data,
                              content_type = "application/json")
    self.client.execute(post)
    self.assertEquals(post.response["status"], 200)

    # retrieve auth cookie for further ops
    cookie = post.response["headers"]["set-cookie"]
    parts = cookie.split(";")
    login_value = parts[0].strip()
    event_uid = "json-contact"
    base_url = "/SOGo/so/%s/Contacts/personal/%s.vcf" % (username, event_uid)

    # delete old version of future card if exists
    post = webdavlib.HTTPPOST("%s/delete" % base_url, "")
    post.cookie = login_value
    self.client.execute(post)

    # create card
    card_data = {"givenname": "Json",
                 "sn": "Card",
                 "displayname": "Json Card",
                 "mail": "nouvelle@carte.com"}
    data = json.dumps(card_data)
    post = webdavlib.HTTPPOST("%s/saveAsContact" % base_url,
                              data, content_type = "application/json")
    post.cookie = login_value
    self.client.execute(post)
    self.assertEquals(post.response["status"], 200)

if __name__ == "__main__":
    sogotests.runTests()
