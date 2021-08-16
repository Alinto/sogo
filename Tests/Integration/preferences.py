from config import hostname, port, username, password
import webdavlib
import urllib
import base64
import simplejson

import sogoLogin


DEBUG=False
#DEBUG=True


# must be kept in sync with SoObjects/SOGo/SOGoDefaults.plist
# this should probably be fetched magically...
SOGoSupportedLanguages = [ "Arabic", "Basque", "Bulgarian", "Catalan", "ChineseChina", "ChineseTaiwan", "Croatian",
                           "Czech", "Dutch", "Danish", "Welsh", "English", "Finnish",
                           "SpanishSpain", "SpanishArgentina", "French", "German", "Hebrew",
                           "Hungarian", "Indonesian", "Icelandic", "Italian", "Japanese",
                           "Latvian", "Lithuanian", "Macedonian", "Montenegrin", "Portuguese", "BrazilianPortuguese",
                           "NorwegianBokmal", "NorwegianNynorsk", "Polish", "Romanian", "Russian",
                           "Serbian", "SerbianLatin", "Slovak", "Slovenian", "Swedish", "TurkishTurkey", "Ukrainian" ];
daysBetweenResponseList=[1,2,3,5,7,14,21,30]

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

class preferences:
    login = username
    passw = password

    def __init__(self, otherLogin = None, otherPassword = None):
        if otherLogin and otherPassword:
            self.login = otherLogin
            self.passw = otherPassword

        self.client = webdavlib.WebDAVClient(hostname, port)

        authCookie = sogoLogin.getAuthCookie(hostname, port, self.login, self.passw)
        self.cookie = authCookie

        #- If this is not set, we CAN'T save preferences
        self.preferences = None

    def find_key(self, d, key):
        if key in d:
            return d
        subdicts = [a[1] for a in d.iteritems() if type(a[1]) == dict]
        for subd in subdicts:
            ret = self.find_key(subd, key)
            if ret:
                return ret
        return None

    def load_preferences(self):
        defaults = self.get_defaults()
        settings = self.get_settings()
        self.preferences = {'defaults': defaults, 'settings': settings}
        #print "LOAD PREFS:", self.preferences

    def get(self, preference=None):
        if not self.preferences:
            self.load_preferences()
        #- Want the whole thing
        if not preference:
            return self.preferences
        else:
            tmpdict = self.find_key(self.preferences, preference)
            if tmpdict:
                return tmpdict[preference]
            else:
                return None
        
    def _get(self, subtype='jsonDefault', preference=None):
        url = "/SOGo/so/%s/%s" % (self.login, subtype)
        get = HTTPPreferencesGET(url)
        get.cookie = self.cookie
        self.client.execute(get)
        if DEBUG: print "DEBUG (url):", url
        if DEBUG: print "DEBUG (status):", get.response["status"]
        if DEBUG: print "DEBUG (body):", get.response['body']
        content = simplejson.loads(get.response['body'])
        result = None
        try:
            if preference:
                result = content[preference]
            else:
                result = content
        except:
            pass
        return result

    def get_defaults(self, preference=None):
        return self._get('jsonDefaults', preference)

    def get_settings(self, preference=None):
        return self._get('jsonSettings', preference)

    def set_nosave(self, preference, value=None):
        # First check if we did a get, if not, must get first
        if not self.preferences:
            self.load_preferences()

        # Get the right sub-dict and change the key/value
        subdict = self.find_key(self.preferences, preference)
        if not subdict:
            raise AttributeError("ERROR(nosubdict): looking for %s in: %s" %(preference, str(self.preferences)))
        subdict[preference] = value

    def set(self, preference, value=None):
        self.set_nosave(preference, value)
        self.save()

    def set_multiple(self, preferences={}):
        for key, value in preferences.iteritems():
            self.set_nosave(key, value)
        self.save()

    def set_or_create(self, preference, value, paths=['defaults']):
        if not self.preferences:
            self.load_preferences()
        subdict = self.find_key(self.preferences, preference)
        #- Pref is not set
        if not subdict:
            subdict = self.preferences
            for path in paths:
                subdict = subdict.setdefault(path, {})
        subdict[preference] = value

    def save(self):
        url = "/SOGo/so/%s/Preferences/save" % self.login

        post = HTTPPreferencesPOST(url, simplejson.dumps(self.preferences))
        post.content_type = "application/json"
        post.cookie = self.cookie
        self.client.execute(post)

        # Raise an exception if the pref wasn't properly set
        if post.response["status"] != 200:
            raise Exception ("failure setting prefs, (code = %d)" \
                       % post.response["status"])


# Simple main to test this class
if __name__ == "__main__":
    p = preferences ()
    print p.get ("SOGoLanguage")
    p.set ("SOGoLanguage", SOGoSupportedLanguages.index("French"))
    print p.get ("SOGoLanguage")
