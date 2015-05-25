#!/usr/bin/python


from config import hostname, port, username, password

import carddav
import sogotests
import unittest
import webdavlib


class JsonDavTests(unittest.TestCase):

    def setUp(self):
        self._connect_as_user()
        self.newphone = [{'type': 'home', 'value': '123.456.7890'}]
        self.newphones_difftype = [{'type': 'home', 'value': '123.456.7890'},
                                   {'type': 'work', 'value': '987.654.3210'},
                                   {'type': 'fax', 'value': '555.666.7777'}]
        self.newphones_sametype = [{'type': 'work', 'value': '123.456.7890'},
                                   {'type': 'work', 'value': '987.654.3210'}]
        # Easier to erase them all in tearDown
        self.allphones = list(self.newphone)
        self.allphones.extend(self.newphones_difftype)
        self.allphones.extend(self.newphones_sametype)

    def tearDown(self):
        self._connect_as_user()
        self._get_card()
        #- Remove the phones we just added
        for phone in self.allphones:
            try:
                self.card['phones'].pop(self.card['phones'].index(phone))
            except ValueError:
                #print "Can't find", phone
                pass
        self._save_card()
        

    def _connect_as_user(self, newuser=username, newpassword=password):
        self.dv = carddav.Carddav(newuser, newpassword)

    def _get_card(self, name="John Doe"):
        tmp_card = self.dv.get_cards(name)[0]
        self.card = self.dv.get_card(tmp_card['c_name'])

    def _save_card(self, card=None):
        if card:
            self.dv.save_card(card)
        else:
            self.dv.save_card(self.card)

    def _get_dav_data(self, filename, user=username, passwd=password):
        w = webdavlib.WebDAVClient(hostname, port, user, passwd)
        query = webdavlib.HTTPGET("http://localhost/SOGo/dav/%s/Contacts/personal/%s" % (username, filename))
        w.execute(query)
        self.assertEquals(query.response['status'], 200)
        return query.response['body'].split("\r\n")

    def _phone_to_dav_str(self, phonedict):
        return "TEL;TYPE=%s:%s" % (phonedict['type'], phonedict['value'])

    def _testMultiplePhones(self, phones):
        """ Add Multiple Phones to Contact JSON and verify with DAV """
        #- Use JSON to get CARD and add a phone and save it back
        self._get_card()
        oldphones = self.card['phones']
        oldphones.extend(phones)
        self._save_card()
        #- Make sure that the phone is there when using JSON
        self._connect_as_user()
        self._get_card()
        #print "C:::", self.card
        testphones = self.card['phones']
        #print "P1:", oldphones
        #print "P2:", testphones
        self.assertEquals(sorted(oldphones), sorted(testphones))
        #- Verify that DAV has the same values
        dav = self._get_dav_data(self.card['id'], username, password)
        for phone in phones:
            found = dav.index(self._phone_to_dav_str(phone))
        self.assertTrue(found > 0)

    def testSinglePhone(self):
        self._testMultiplePhones(self.newphone)
    
    def testMultipleDifferentPhones(self):
        self._testMultiplePhones(self.newphones_difftype)
    
    def testMultipleSameTypePhones(self):
        self._testMultiplePhones(self.newphones_sametype)
    
if __name__ == "__main__":
    sogotests.runTests()
