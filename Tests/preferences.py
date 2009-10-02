from config import hostname, port, username, password
import webdavlib
import urllib
import base64


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

  def __init__ (self, otherLogin = None, otherPassword = None):
    if otherLogin and otherPassword:
      self.login = otherLogin
      self.passw = otherPassword

    self.client = webdavlib.WebDAVClient(hostname, port,
                                         self.login, self.passw)

    authString = \
        base64.urlsafe_b64encode (username+":"+password).replace("=", "%3D")
    self.cookie = \
        "0xHIGHFLYxSOGo=basic%%20%s;%%20SOGo=6C0F6C0F014AC60ED5" % authString

    self.preferencesMap = {"language": "2.1.0.3.0.1.3.1.1.3.1.2"}

  def set (self, preference, value):
    formKey = self.preferencesMap[preference]
    content = "%s=%s" % (formKey, value)
    url = "/SOGo/so/%s/preferences" % self.login

    post = HTTPPreferencesPOST (url, content)
    post.content_type = "application/x-www-form-urlencoded"
    post.cookie = self.cookie

    self.client.execute (post)

    # Raise an exception if the language wasn't properly set
    if post.response["status"] != 200:
      raise Exception ("failure setting language, (code = %d)" \
                       % post.response["status"])

  def get (self, preference):
    url = "/SOGo/so/%s/preferences/jsonDefaults" % self.login
    get = HTTPPreferencesGET (url)
    get.cookie = self.cookie
    self.client.execute (get)
    content = eval (get.response['body'])
    result = None
    try:
      result = content[preference]
    except:
      pass
    return result


# Simple main to test this class
if __name__ == "__main__":
  p = preferences ()
  p.set ("language", 6)
