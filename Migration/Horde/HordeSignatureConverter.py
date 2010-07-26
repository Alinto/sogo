import PHPDeserializer
import sys

class HordeSignatureConverter:
    def __init__(self, user, domain):
        self.user = user
        self.domain = domain
        self.domainLen = len(domain)

    def fetchSignatures(self, conn):
        self.signatures = None
        self.conn = conn
        self.fetchIdentities()

        return self.signatures

    def fetchIdentities(self):
        self.users = {}

        cursor = self.conn.cursor()
        if self.user == "ALL":
            userClause = ""
        else:
            userClause = "AND pref_uid = '%s'" % self.user
        query = "SELECT pref_uid, pref_value" \
            "      FROM horde_prefs" \
            "     WHERE pref_scope = 'horde'" \
            "       AND pref_name = 'identities'" \
            "        %s" % userClause
        cursor.execute(query)

        self.signatures = {}
        records = cursor.fetchall()
        max = len(records)
        if max > 0:
            for record in records:
                user = record[0]
                signature = self.decodeSignature(record[1], user)
                if signature is None or len(signature.strip()) == 0:
                    print "No useful signature found for %s" % user
                else:
                    self.signatures[user] = signature

            print "%d useful signature(s) found in %d record(s)" % (len(self.signatures), max)
        else:
            print "No record found"

        cursor.close()

    def decodeSignature(self, prefs, user):
        des = PHPDeserializer.PHPDeserializer(prefs)
        identities = des.deserialize()
        nbrEntries = len(identities)
        signatures = []
        for identity in identities:
            fromAddr = identity["from_addr"]
            if (len(fromAddr) > self.domainLen
                and fromAddr[-self.domainLen:] == self.domain):
                if identity.has_key("signature"):
                    signatures.append(identity["signature"])

        if len(signatures) > 0:
            signature = self.chooseSignature(signatures)
        else:
            signature = None

        return signature

    def chooseSignature(self, signatures):
        biggest = -1
        length = -1
        count = 0
        for signature in signatures:
            thisLength = len(signature)
            if thisLength > 0 and thisLength > length:
                biggest = count
            count = count + 1

        if biggest == -1:
            signature = None
        else:
            signature = signatures[biggest]

        return signature
