#!/usr/bin/python

import sogotests
import unittest
import webdavlib

from config import *

class HTTPContactCategoriesTest(unittest.TestCase):
    def _setCategories(self, user, categories = None):
        resource = '/SOGo/dav/%s/Contacts/' % user
        if categories is None:
            categories = []
        elements = [ { "{urn:inverse:params:xml:ns:inverse-dav}category": x }
                     for x in categories ]
        props = { "{urn:inverse:params:xml:ns:inverse-dav}contacts-categories": elements }
        proppatch = webdavlib.WebDAVPROPPATCH(resource, props)
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 207,
                          "failure (%s) setting '%s' categories on %s's contacts"
                          % (proppatch.response["status"],
                             "', '".join(categories), user))

    def _getCategories(self, user):
        resource = '/SOGo/dav/%s/Contacts/' % user
        props = [ "{urn:inverse:params:xml:ns:inverse-dav}contacts-categories" ]
        propfind = webdavlib.WebDAVPROPFIND(resource, props, "0")
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207,
                          "failure (%s) getting categories on %s's contacts"
                          % (propfind.response["status"], user))

        categories = []
        prop_nodes = propfind.response["document"].findall("{DAV:}response/{DAV:}propstat/{DAV:}prop/{urn:inverse:params:xml:ns:inverse-dav}contacts-categories")
        for prop_node in prop_nodes:
            cat_nodes = prop_node.findall("{urn:inverse:params:xml:ns:inverse-dav}category")
            if cat_nodes is not None:
                for cat_node in cat_nodes:
                    categories.append(cat_node.text)

        return categories


    def test(self):
        self._setCategories(username, [])
        cats = self._getCategories(username)
        self.assertTrue(cats is not None and len(cats) == 0)
        
        self._setCategories(username, [ "Coucou" ])
        cats = self._getCategories(username)
        self.assertTrue(cats is not None and len(cats) == 1)
        self.assertEquals(cats[0], "Coucou")
        
        self._setCategories(username, [ "Toto", "Cuicui" ])
        cats = self._getCategories(username)
        self.assertTrue(cats is not None and len(cats) == 2)
        self.assertEquals(cats[0], "Toto")
        self.assertEquals(cats[1], "Cuicui")
        
if __name__ == "__main__":
    sogotests.runTests()
