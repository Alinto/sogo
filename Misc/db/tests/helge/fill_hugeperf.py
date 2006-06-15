#!/usr/bin/python

import pg, time, sys

USER="agenor"
HOST="localhost"
DB="agenor_testhugeperf"
QUICKTABLE="SOGo_huge_quick"
BLOBTABLE="SOGo_huge_ical"

db = pg.DB(DB, HOST, 5432, "", "", USER);
print "connection:", db

# index, index, start, end, index, 
QUICKTEMPLATE="""INSERT INTO %s (
  c_pkey, c_sourceid, c_startdate, c_enddate, c_title, c_attendees,
  c_isallday, c_sequenceid, c_generation
) VALUES (
  %i, 'longsource%iid', %i, %i, 'long title %i',
  'hh@skyrix.com,mm@skyrix,je@skyrix.com,fr@skyrix.com,jm@skyrix.com,hh@skyrix.com,mm@skyrix,je@skyrix.com,fr@skyrix.com,jm@skyrix.com,hh@skyrix.com,mm@skyrix,je@skyrix.com,fr@skyrix.com,jm@skyrix.com',
  0, 0, 1
);"""

# index, ical
ICALTEMPLATE="INSERT INTO %s ( c_pkey, c_data ) VALUES ( %i, '%s' );"

ICALFILE="""BEGIN:VEVENT
DURATION:PT1H
ATTENDEE;CN="Elke Bethke";DIR="addressbook://B156F3F0-9CFD-11D8-8561-000
 D93C1A604:ABPerson":mailto:E.Bethke@Sachsen-Anhalt-Lotto.de
ATTENDEE;CN="Erik Doernenburg";DIR="addressbook://B15FCB0F-9CFD-11D8-8561
 -000D93C1A604:ABPerson":mailto:erik@x101.net
ATTENDEE;CN="Christian Schnelle";DIR="addressbook://B1418D4E-9CFD-11D8-8
 561-000D93C1A604:ABPerson":mailto:cs@enervation.de
ATTENDEE;CN="Chris Herrenberger";DIR="addressbook://B14A390C-9CFD-11D8-8
 561-000D93C1A604:ABPerson":invalid:nomail
ATTENDEE;CN="Horst Parplies";DIR="addressbook://B19B47E5-9CFD-11D8-8561-
 000D93C1A604:ABPerson":mailto:horst.parplies@freenet.de
ATTENDEE;CN="Imdat Solak";DIR="addressbook://B19EDB62-9CFD-11D8-8561-000
 D93C1A604:ABPerson":mailto:imdat@solak.de
ATTENDEE;CN="Jens Enders";DIR="addressbook://B1B6819F-9CFD-11D8-8561-000
 D93C1A604:ABPerson":mailto:jens.enders@skyrix.com
ATTENDEE;CN="Jens Muenster";DIR="addressbook://B1BBA42E-9CFD-11D8-8561-00
 0D93C1A604:ABPerson":mailto:jens.muenster@skyrix.com
ATTENDEE;CN="Laurent Pierre";DIR="addressbook://9337C270-A825-11D8-B930-
 000D93C1A604:ABPerson":mailto:laurent.pierre@linagora.com
ATTENDEE;CN="Marcel Weiher";DIR="addressbook://B1F9BB12-9CFD-11D8-8561-0
 00D93C1A604:ABPerson":mailto:marcel@metaobject.co
DTSTAMP:20040520T140002Z
UID:BD91C454-AA65-11D8-84CA-000D93C1A604
SEQUENCE:3
STATUS:CONFIRMED
DTSTART;TZID=Europe/Berlin:20040618T160000
SUMMARY:SIZE EVENT
X-WR-ITIPSTATUSML:UNCLEAN
END:VEVENT
"""


# ******************** INSERT ********************

FROM=int(sys.argv[1])
TO=FROM+1000000
#FROM=1
#TO=1000000

timingstart=time.time()

for i in range(FROM, TO):
    start=time.time()
    end=start+(60 * 30)
    
    QSQL = QUICKTEMPLATE % ( QUICKTABLE, i, i, start, end, i, )
    BSQL = ICALTEMPLATE  % ( BLOBTABLE, i, ICALFILE )
    
    if i % 10000 == 0:
        print "%i (%.2fs): quick %s" % ( i, time.time()-timingstart, QSQL )
        #print "%i: blob  %s" % ( i, BSQL )
    db.query(QSQL + BSQL)

