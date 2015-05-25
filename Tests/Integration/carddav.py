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

        #- If this is not set, we CAN'T save preferences
        self.preferences = None

    def load_cards(self):
        if not self.cards:
            url = "/SOGo/%s/Contacts/personal/view" % (self.login)
            get = HTTPPreferencesGET(url)
            get.cookie = self.cookie
            self.client.execute(get)
            if DEBUG: print "(url):", url
            if DEBUG: print "(status):", get.response["status"]
            if DEBUG: print "(body):", get.response['body']
            content = simplejson.loads(get.response['body'])
            self.cards = content['cards']
        return self.cards

    def get_cards(self, pattern):
        self.load_cards()
        return [a for a in self.cards if pattern in a.values()]

    def get_card(self, idstr):
        url = "/SOGo/%s/Contacts/personal/%s/view" % (self.login, idstr)
        get = HTTPPreferencesGET(url)
        get.cookie = self.cookie
        self.client.execute(get)
        if DEBUG: print "(url):", url
        if DEBUG: print "(status):", get.response["status"]
        if DEBUG: print "(body):", get.response['body']
        content = simplejson.loads(get.response['body'])
        return content

    def save_card(self, card):
        url = "/SOGo/%s/Contacts/personal/%s/saveAsContact" % (self.login, card['id'])
        if DEBUG: print "URL:", url

        post = HTTPPreferencesPOST(url, simplejson.dumps(card))
        post.content_type = "application/json"
        post.cookie = self.cookie
        self.client.execute(post)

        # Raise an exception if the pref wasn't properly set
        if post.response["status"] != 200:
            raise Exception ("failure setting prefs, (code = %d)" \
                       % post.response["status"])

