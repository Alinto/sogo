import PHPDeserializer
import webdavlib
import sys

commonMappings = { "owner_id": "owner",
                   "object_id": "filename",
                   "object_uid": "uid",
                   "object_name": "fn" }
cardMappings = { "object_alias": "nickname",
                 "object_email": "email",
                 "object_homeaddress": "homeaddress",
                 "object_homephone": "homephone",
                 "object_workaddress": "workaddress",
                 "object_workphone": "workphone",
                 "object_cellphone": "cellphone",
                 "object_fax": "fax",
                 "object_title": "title",
                 "object_company": "org",
                 "object_notes": "notes",
                 "object_freebusyurl": "fburl" }

prodid = "-//Inverse inc.//SOGo Turba Importer 1.0//EN"

# a managed type of template where each line is put only if at least one field
# has been filled
cardTemplate = u"""BEGIN:VCARD\r
VERSION:3.0\r
PRODID:%s\r
UID:${uid}\r
FN:${fn}\r
TITLE:${title}\r
ORG:${org};\r
NICKNAME:${nickname}\r
EMAIL:${email}\r
ADR;TYPE=work:;;${workaddress};;;;\r
ADR;TYPE=home:;;${homeaddress};;;;\r
TEL;TYPE=work:${workphone}\r
TEL;TYPE=home:${homephone}\r
TEL;TYPE=fax:${fax}\r
NOTE:${notes}\r
FBURL:${fburl}\r
END:VCARD""" % prodid

class TurbaConverter:
    def __init__(self, user, webdavConfig):
        self.user = user
        self.webdavConfig = webdavConfig

    def start(self, conn):
        self.conn = conn
        self.readUsers()
        self.missing = []
        for user in self.users.keys():
            self.hasCards = False
            self.hasLists = False
            self.currentUser = user
            self.readUserRecords()
            if self.hasCards or self.hasLists:
                print "Converting addressbook of '%s'" % user
                self.prepareCards()
                self.uploadCards()
                self.prepareLists()
                self.uploadLists()
            else:
                self.missing.append(user)

        if len(self.missing) > 0:
            print "No information extracted for: %s" % ", ".join(self.missing)

        print "Done"

    def readUsers(self):
        self.users = {}

        cursor = self.conn.cursor()
        query = "SELECT user_uid, datatree_name FROM horde_datatree"
        if self.user != "ALL":
            query = query + " WHERE user_uid = '%s'" % self.user
        cursor.execute(query)

        records = cursor.fetchall()
        count = 0
        max = len(records)
        for record in records:
            record_user = record[0].lower()
            if not self.users.has_key(record_user):
                self.users[record_user] = []
            self.users[record_user].append(record[1])
            count = count + 1
        cursor.close()

    def readUserRecords(self):
        self.cards = {}
        self.lists = {}

        cursor = self.conn.cursor()
        owner_ids = self.users[self.currentUser]
        whereClause = "owner_id = '%s'" % "' or owner_id = '".join(owner_ids)
        query = "SELECT * FROM turba_objects WHERE %s" % whereClause
        cursor.execute(query)
        self.prepareColumns(cursor)

        records = cursor.fetchall()
        count = 0
        max = len(records)
        while count < max:
            self.parseRecord(records[count])
            count = count + 1

        cursor.close()

    def prepareColumns(self, cursor):
        self.columns = {}
        count = 0
        for dbColumn in cursor.description:
            columnId = dbColumn[0]
            self.columns[columnId] = count
            count = count + 1

    def parseRecord(self, record):
        typeCol = self.columns["object_type"]
        meta = {}
        self.applyRecordMappings(meta, record, commonMappings)

        if record[typeCol] == "Object":
            meta["type"] = "card"
            self.hasCards = True
            self.applyRecordMappings(meta, record, cardMappings)
        elif record[typeCol] == "Group":
            meta["type"] = "list"
            self.hasLists = True
            self.fillListMembers(meta, record)
        else:
            raise Exception, "UNKNOWN TYPE: %s" % record[type]

        self.dispatchMeta(meta)

    def applyRecordMappings(self, meta, record, mappings):
        for k in mappings.keys():
            metaKey = mappings[k]
            meta[metaKey] = self.recordColumn(record, k)

    def recordColumn(self, record, columnName):
        columnIndex = self.columns[columnName]
        value = record[columnIndex]
        if value is None:
            value = u""
        else:
            value = self.deUTF8Ize(value)

        return value

    def deUTF8Ize(self, value):
        # unicode -> repeat(utf-8 str -> iso-8859-1 str) -> unicode
        oldValue = value

        done = False
        while not done:
            try:
                utf8Value = value.encode("iso-8859-1")
                value = utf8Value.decode("utf-8")
            except:
                done = True
            if value == oldValue:
                done = True

        return value

    def fillListMembers(self, meta, record):
        members = self.recordColumn(record, "object_members")
        if members is not None and len(members) > 0:
            deserializer = PHPDeserializer.PHPDeserializer(members)
            dMembers = deserializer.deserialize()
        else:
            dMembers = []
        meta["members"] = dMembers

    def dispatchMeta(self, meta):
        owner = meta["owner"]
        if meta["type"] == "card":
            repository = self.cards
        else:
            repository = self.lists
        filename = meta["filename"]
        repository[filename] = meta

    def prepareCards(self):
        count = 0
        for filename in self.cards.keys():
            card = self.cards[filename]
            card["data"] = self.buildVCard(card).encode("utf-8")
            count = count + 1
        if count > 0:
            print "  prepared %d cards" % count

    def buildVCard(self, card):
        vcardArray = []
        tmplArray = cardTemplate.split("\r\n")
        for line in tmplArray:
            keyPos = line.find("${")
            if keyPos > -1:
                keyEndPos = line.find("}")
                key = line[keyPos+2:keyEndPos]
                if card.has_key(key):
                    value = card[key]
                    if len(value) > 0:
                        newLine = "%s%s%s" % (line[0:keyPos],
                                              value.replace(";", "\;"),
                                              line[keyEndPos + 1:])
                        vcardArray.append(self.foldLineIfNeeded(newLine))
            else:
                vcardArray.append(self.foldLineIfNeeded(line))

        return "\r\n".join(vcardArray)

    def foldLineIfNeeded(self, line):
        wasFolded = False
        newLine = line\
            .replace("\\", "\\\\") \
            .replace("\r", "\\r") \
            .replace("\n", "\\n")
        lines = []
        while len(newLine) > 73:
            wasFolded = True
            lines.append(newLine[0:73])
            newLine = newLine[73:]
        lines.append(newLine)

        newLine = "\r\n ".join(lines)
        if wasFolded:
            print "line was folded: '%s' ->\n\n%s\n\n" % (line, newLine)

        return newLine

    def uploadCards(self):
        self.uploadEntries(self.cards,
                           "vcf", "text/x-vcard; charset=utf-8");

    def prepareLists(self):
        count = 0
        skipped = 0
        for filename in self.lists.keys():
            list = self.lists[filename]
            vlist = self.buildVList(list)
            if vlist is None:
                skipped = skipped + 1
            else:
                list["data"] = vlist.encode("utf-8")
                count = count + 1

        if (count + skipped) > 0:
            print "  prepared %d lists. %d were skipped." % (count, skipped)

    def buildVList(self, list):
        vlist = None

        members = list["members"]
        if len(members) > 0:
            cardMembers = []
            for member in members:
                card = self.getListCard(member)
                if card is not None:
                    cardMembers.append(card)
            if len(cardMembers) > 0:
                vlist = self.assembleVList(list, cardMembers)
            else:
                print "  list '%s' skipped because of lack of usable" \
                    " members" % list["filename"]

        return vlist

    def getListCard(self, cardRef):
        card = None
        if len(cardRef) != 0 and not cardRef.startswith("localldap:"):
            if cardRef.startswith("localsql:"):
                cardRef = cardRef[9:]
            if self.cards.has_key(cardRef):
                card = self.cards[cardRef]
            else:
                print "card reference does not exist: '%s'" % cardRef

        return card

    def assembleVList(self, list, cardMembers):
        entries = []
        for cardMember in cardMembers:
            if cardMember.has_key("fn") and len(cardMember["fn"]) > 0:
                fn = ";FN=%s" % cardMember["fn"]
            else:
                fn = ""
            if cardMember.has_key("email") and len(cardMember["email"]) > 0:
                email = ";EMAIL=%s" % cardMember["email"]
            else:
                email = ""
            entries.append("CARD%s%s:%s.vcf"
                           % (fn, email, cardMember["filename"]))
        if list.has_key("fn") and len(list["fn"]) > 0:
            listfn = "FN:%s\r\n" % list["fn"]
        else:
            listfn = ""
        vlist = """BEGIN:VLIST\r
PRODID:%s\r
VERSION:1.0\r
UID:%s\r
%s%s\r
END:VLIST""" % (prodid, list["uid"], listfn, "\r\n".join(entries))

        return vlist

    def uploadLists(self):
        self.uploadEntries(self.lists,
                           "vlf", "text/x-vcard; charset=utf-8");

    def uploadEntries(self, entries, extension, mimeType):
        isatty = sys.stdout.isatty() # enable progressive display of summary
        success = 0
        failure = 0
        client = webdavlib.WebDAVClient(self.webdavConfig["hostname"],
                                        self.webdavConfig["port"],
                                        self.webdavConfig["username"],
                                        self.webdavConfig["password"])
        collection = '/SOGo/dav/%s/Contacts/personal' % self.currentUser

        mkcol = webdavlib.WebDAVMKCOL(collection)
        client.execute(mkcol)
        
        for entryName in entries.keys():
            entry = entries[entryName]
            if entry.has_key("data"):
                fullFilename = "%s.%s" % (entry["filename"], extension)
                url = "%s/%s" % (collection, fullFilename)
                put = webdavlib.HTTPPUT(url, entry["data"])
                put.content_type = mimeType
                client.execute(put)
                if (put.response["status"] < 200
                    or put.response["status"] > 399):
                    failure = failure + 1
                    print "  error uploading '%s': %d" \
                        % (fullFilename, put.response["status"])
                else:
                    success = success + 1
                if isatty:
                    print "\r  successes: %d; failures: %d" % (success, failure),
                    if (success + failure) % 5 == 0:
                        sys.stdout.flush()
        if isatty:
            print ""
        else:
            if (success + failure) > 0:
                print "  successes: %d; failures: %d\n" % (success, failure)
                sys.stdout.flush()
