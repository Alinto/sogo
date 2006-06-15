#!/usr/bin/python

import os, sys
from datetime import datetime

HOST="localhost"
USER="postgres"
DB="ogo"

today11=1088672400
LOGINPREFIX="Utilisateur-"

# parameters: useridx, aptid, aptid, startutime, endutime, title, parts
QUICK_TEMPLATE="""
INSERT INTO user_%i_quick
  ( c_name, uid, startdate, enddate, title, participants )
VALUES (
  '%s', '%s', %i, %i, '%s', '%s'
);
"""

# parameters: aptid, utcstarttime, title
#             'BD91C454-AA65-11D8-84CA-000D93C1A604'
#             '20040618T160000Z'
ICAL_TEMPLATE="""BEGIN:VEVENT
DURATION:PT1H
ATTENDEE;CN="Laurent Pierre":mailto:laurent@linagora.de
ATTENDEE;CN="Marcus Mueller":mailto:mm@skyrix.com
ATTENDEE;CN="Helge Hess":mailto:helge.hess@opengroupware.org
DTSTAMP:20040520T140002Z
UID:%s
SEQUENCE:1
STATUS:CONFIRMED
DTSTART:%sZ
SUMMARY:%s
END:VEVENT
"""

# parameters: useridx, aptid, creationutime, lastmodutime, icalcontent
BLOB_TEMPLATE="""
INSERT INTO user_%i_blob
  ( c_name, c_creationdate, c_lastmodified, c_version, c_content )
VALUES
  ( '%s', %i, %i, 1, '%s' );
"""

BASEDATE=1072963800
DAYFACTOR=60*60*24

def createAptsForUser(login, idx):
    print "-- User", idx, "login", login
    for dayofyear in range(1, 365):
        ICALID="%s-apt%i" % ( login, dayofyear )
        
        STARTDATE = BASEDATE + DAYFACTOR * dayofyear;
        start = datetime.utcfromtimestamp(STARTDATE)
        utcstarttime="%04i%02i%02iT%02i%02i00" % ( start.year, start.month,
                                               start.day, start.hour,
                                               start.minute )
        TITLE="Agenor %i (%s)" % ( dayofyear, login )
        ical=ICAL_TEMPLATE % ( ICALID, utcstarttime, TITLE )
        print BLOB_TEMPLATE % ( idx, ICALID, today11, today11,
                                ical )

        PARTS="Laurent Pierre, Marcus Mueller, Helge Hess"
        print QUICK_TEMPLATE % ( idx, ICALID, ICALID,
                                 STARTDATE, STARTDATE + 3600,
                                 TITLE, PARTS)
        print "-- end apt"
    print "-- end user", login
    print ""
    print ""

for i in range(2,200):
    createAptsForUser("%s%i" % (LOGINPREFIX, i), i)
