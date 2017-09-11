from config import hostname, port, username, password
import webdavlib
import simplejson
import sogoLogin


DEBUG=True
DEBUG=False


class HTTPPreferencesPOST (webdavlib.HTTPPOST):
    cookie = None

    def prepare_headers (self):
        headers = webdavlib.HTTPPOST.prepare_headers(self)
        if self.cookie:
            headers["Cookie"] = self.cookie
        return headers

class HTTPPreferencesGET (webdavlib.HTTPGET):
    cookie = None
  
    def prepare_headers (self):
        headers = webdavlib.HTTPGET.prepare_headers(self)
        if self.cookie:
            headers["Cookie"] = self.cookie
        return headers

class Carddav:
    login = username
    passw = password

    def __init__(self, otherLogin = None, otherPassword = None):
        if otherLogin and otherPassword:
            self.login = otherLogin
            self.passw = otherPassword

        self.client = webdavlib.WebDAVClient(hostname, port)
        authCookie = sogoLogin.getAuthCookie(hostname, port, self.login, self.passw)
        self.cookie = authCookie
        self.cards = None
        self.calendars = None
        self.fields = None
        self.events = None

        #- If this is not set, we CAN'T save preferences
        self.preferences = None

    def _get(self, url):
        get = HTTPPreferencesGET(url)
        get.cookie = self.cookie
        self.client.execute(get)
        if DEBUG: print "(url):", url
        if DEBUG: print "(status):", get.response["status"]
        if DEBUG: print "(body):", get.response['body']
        content = simplejson.loads(get.response['body'])
        return content

    def _post(self, url, data, errormsg="failure POST"):
        if DEBUG: print "URL:", url
        post = HTTPPreferencesPOST(url, simplejson.dumps(data))
        post.content_type = "application/json"
        post.cookie = self.cookie
        self.client.execute(post)
        # Raise an exception if the pref wasn't properly set
        if post.response["status"] != 200:
            raise Exception ("%s, (code = %d)" % (errormsg, post.response["status"]))

    def load_cards(self):
        if not self.cards:
            url = "/SOGo/so/%s/Contacts/personal/view" % (self.login)
            content = self._get(url)
            #print "\nCONTENT:", content
            if 'headers' in content:
                self.cards = []
                fields = content['headers'][0]
                for h in content['headers'][1:]:
                    card = {}
                    for i, f in enumerate(fields):
                        card[f] = h[i]
                    self.cards.append(card)
            else:
                self.cards = []
        return self.cards

    def get_cards(self, pattern):
        self.load_cards()
        return [a for a in self.cards if pattern in a.values()]

    def get_card(self, idstr):
        url = "/SOGo/so/%s/Contacts/personal/%s/view" % (self.login, idstr)
        content = self._get(url)
        return content

    def save_card(self, card):
        url = "/SOGo/so/%s/Contacts/personal/%s/saveAsContact" % (self.login, card['id'])
        self._post(url, card, "failure saving card")

    def load_calendars(self):
        if not self.calendars:
            url = "/SOGo/so/%s/Calendar/calendarslist" % (self.login)
            content = self._get(url)
            self.calendars = content['calendars']
        return self.calendars

    def get_calendars(self, pattern):
        self.load_calendars()
        return [a for a in self.calendars if pattern in a.values()]

    def get_calendar(self, idstr):
        self.load_calendars()
        callist = [a for a in self.calendars if a['id'] == idstr]
        if len(callist):
            return callist[0]
        return None

    def save_calendar(self, calendar):
        url = "/SOGo/so/%s/Contacts/personal/%s/saveAsContact" % (self.login, calendar['id'])
        self._post(url, card, "failure saving calendar")

    def load_events(self):
        if not self.events:
            url = "/SOGo/so/%s/Calendar/eventslist" % (self.login)
            content = self._get(url)
            self.fields = content['fields']
            self.events = []
            for month in content['events']
                for day in content['events'][month]
                    tmp_events = content['events'][month][day]
                    self.events.extend(dict(zip(self.fields, event)) for event in tmp_events)
        return self.events

    def newguid(self, folderpath):
        url = "/SOGo/so/%s/%s/newguid" % (self.login, folderpath)
        content = self._get(url)
        return content['id']

    def save_event(self, event, folder, gid):
        #url = "/SOGo/so/%s/%s/%s/save" % (self.login, event['c_folder'], event['c_name'])
        url = "/SOGo/so/%s/%s/%s/saveAsAppointment" % (self.login, folder, gid)
        self._post(url, event, "failure saving event")

