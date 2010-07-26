#!/usr/bin/python

import sys
import MySQLdb
import webdavlib

import HordeSignatureConverter

from config import webdavConfig, dbConfig

xmlns_inversedav = "urn:inverse:params:xml:ns:inverse-dav"

def UploadSignature(client, user, signature):
    collection = '/SOGo/dav/%s/' % user
    proppatch \
        = webdavlib.WebDAVPROPPATCH(collection,
                                    { "{%s}signature" % xmlns_inversedav: \
                                          signature.encode("utf-8") })
    client.execute(proppatch)
    if (proppatch.response["status"] < 200
        or proppatch.response["status"] > 399):
        print "Failure uploading signature for user '%s': %d" \
            % (user, proppatch.response["status"])

if __name__ == "__main__":
    if len(sys.argv) > 1:
        user = sys.argv[1]
    else:
        raise Exception, "<user> argument must be specified" \
            " (use 'ALL' for everyone)"

    conn = MySQLdb.connect(host = dbConfig["hostname"],
                           user = dbConfig["username"],
                           passwd = dbConfig["password"],
                           db = dbConfig["database"],
                           use_unicode = True)

    cnv = HordeSignatureConverter.HordeSignatureConverter(user, "DOMAIN.COM")
    signatures = cnv.fetchSignatures(conn)
    conn.close()

    client = webdavlib.WebDAVClient(webdavConfig["hostname"],
                                    webdavConfig["port"],
                                    webdavConfig["username"],
                                    webdavConfig["password"])
    for user in signatures:
        signature = signatures[user]
        UploadSignature(client, user, signature)
