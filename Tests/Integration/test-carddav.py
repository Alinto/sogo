#!/usr/bin/python


from config import hostname, port, username, password

import carddav
import sogotests
import unittest
import webdavlib
import time


class JsonDavEventTests(unittest.TestCase):
    def setUp(self):
        self._connect_as_user()

    def _connect_as_user(self, newuser=username, newpassword=password):
        self.dv = carddav.Carddav(newuser, newpassword)

    def _create_new_event(self, path):
        gid = self.dv.newguid(path)
        event = {'startDate': "2015-12-25",
                 'startTime': "10:00",
                 'endDate':   "2015-12-25",
                 'endTime':   "23:00",
                 'isTransparent': 0,
                 'sendAppointmentNotifications': 0,
                 'summary':   "Big party",
                 'alarm': {'action': 'display',
                         'quantity': 10,
                         'unit': "MINUTES",
                         'reference': "BEFORE",
                         'relation': "START",
                         'email': "sogo1@example.com"},
                 'organizer': {'name': u"Balthazar C\xe9sar",
                             'email': "sogo2@example.com"},
                 'c_name': gid,
                 'c_folder': path
                }
        return (event, path, gid)

    def _get_dav_data(self, filename, user=username, passwd=password):
        w = webdavlib.WebDAVClient(hostname, port, user, passwd)
        query = webdavlib.HTTPGET("http://localhost/SOGo/dav/%s/Calendar/personal/%s" % (username, filename))
        w.execute(query)
        self.assertEquals(query.response['status'], 200)
        return query.response['body'].split("\r\n")

    def _get_dav_field(self, davdata, fieldname):
        try:
            data = [a.split(':')[1] for a in davdata if fieldname in a][0]
        except IndexError:
            data = ''
        return data

    def test_create_new_event(self):
        path = 'Calendar/personal'
        (event, folder, gid) = self._create_new_event(path)
        #print "Saving Event to:", folder, gid
        self.dv.save_event(event, folder, gid)
        #- Get the event back with JSON
        self._connect_as_user()
        self.dv.load_events()
        elist = [e for e in self.dv.events if e['c_name'] == gid]
        #- MUST have this event -- only once
        self.assertEquals(len(elist), 1)
        strdate = "%d-%.02d-%.02d" % time.gmtime(elist[0]['c_startdate'])[0:3]
        self.assertEquals(strdate, event['startDate'])
        #- Get the event back with DAV
        dav = self._get_dav_data(gid, username, password)
        self.assertEquals(self._get_dav_field(dav, 'SUMMARY:'), event['summary'])


class JsonDavPhoneTests(unittest.TestCase):

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
        #- In case there are no cards for this user
        try:
            self._get_card()
        except IndexError:
            path = 'Contacts/personal'
            (card, path, gid) = self._create_new_card(path)
            self._save_card(card)

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

    def _create_new_card(self, path):
        gid = self.dv.newguid(path)
        card = {'c_categories': None,
                'c_cn': 'John Doe',
                'c_component': 'vcard',
                'c_givenname': 'John Doe',
                'c_mail': 'johndoe@nothere.com',
                'c_name': gid,
                'c_o': '',
                'c_screenname': '',
                'c_sn': '',
                'c_telephonenumber': '123.456.7890',
                'emails': [{'type': 'pref', 'value': 'johndoe@nothere.com'}],
                'phones': [{'type': 'home', 'value': '111.222.3333'}],
                'id': gid}
        return (card, path, gid)

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
