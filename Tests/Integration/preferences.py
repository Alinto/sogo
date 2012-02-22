from config import hostname, port, username, password
import webdavlib
import urllib
import base64
import simplejson

import sogoLogin



# must be kept in sync with SoObjects/SOGo/SOGoDefaults.plist
# this should probably be fetched magically...
SOGoSupportedLanguages = [ "Catalan", "Czech", "Dutch", "Danish", "Welsh", "English",
                           "SpanishSpain", "SpanishArgentina", "French", "German",
                           "Icelandic", "Italian", "Hungarian", "BrazilianPortuguese",
                           "NorwegianBokmal", "NorwegianNynorsk", "Polish", "Russian",
                           "Ukrainian", "Swedish" ];
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

    authCookie = sogoLogin.getAuthCookie(hostname, port, username, password)
    self.cookie = authCookie

    # map between preferences/jsonDefaults and the webUI names
    # should probably be unified...
    self.preferencesMap = {
        "SOGoLanguage": "language",
        "SOGoTimeZone": "timezone",
        "SOGoSieveFilters": "sieveFilters",

			   # Vacation stuff
			   "Vacation": "enableVacation", # to disable, don't specify it
			   "autoReplyText": "autoReplyText", # string
			   "autoReplyEmailAddresses":  "autoReplyEmailAddresses", # LIST
			   "daysBetweenResponse":  "daysBetweenResponsesList", 
			   "ignoreLists":  "ignoreLists", #bool

			   # forward stuff
         "Forward": "enableForward", # to disable, don't specify it
         "forwardAddress": "forwardAddress",
         "keepCopy": "forwardKeepCopy",
    }

  def set(self, preference, value=None):
    # if preference is a dict, set all prefs found in the dict
    content=""
    if isinstance(preference, dict):
      for k,v in preference.items():
        content+="%s=%s&" % (self.preferencesMap[k], v)
    else:
      # assume it is a str
      formKey = self.preferencesMap[preference]
      content = "%s=%s&hasChanged=1" % (formKey, value)


    url = "/SOGo/so/%s/preferences" % self.login

    post = HTTPPreferencesPOST (url, content)
    post.content_type = "application/x-www-form-urlencoded"
    post.cookie = self.cookie

    self.client.execute (post)

    # Raise an exception if the pref wasn't properly set
    if post.response["status"] != 200:
      raise Exception ("failure setting prefs, (code = %d)" \
                       % post.response["status"])

  def get(self, preference):
    url = "/SOGo/so/%s/preferences/jsonDefaults" % self.login
    get = HTTPPreferencesGET (url)
    get.cookie = self.cookie
    self.client.execute (get)
    content = simplejson.loads(get.response['body'])
    result = None
    try:
      result = content[preference]
    except:
      pass
    return result

# Simple main to test this class
if __name__ == "__main__":
  p = preferences ()
  print p.get ("SOGoLanguage")
  p.set ("SOGoLanguage", SOGoSupportedLanguages.index("French"))
  print p.get ("SOGoLanguage")
