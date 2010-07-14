import time

def hours(nbr):
    return nbr * 3600

def days(nbr):
    return nbr *  hours(24)

class ev_generator:
    ev_templ = """
BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Inverse//Event Generator//EN\r
CALSCALE:GREGORIAN\r
BEGIN:VTIMEZONE\r
TZID:America/Montreal\r
BEGIN:DAYLIGHT\r
TZOFFSETFROM:-0500\r
TZOFFSETTO:-0400\r
DTSTART:20070311T020000\r
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\r
TZNAME:EDT\r
END:DAYLIGHT\r
BEGIN:STANDARD\r
TZOFFSETFROM:-0400\r
TZOFFSETTO:-0500\r
DTSTART:20071104T020000\r
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\r
TZNAME:EST\r
END:STANDARD\r
END:VTIMEZONE\r
BEGIN:VEVENT\r
SEQUENCE:4\r
TRANSP:OPAQUE\r
UID:%(uid)s\r
SUMMARY:%(summary)s\r
DTSTART;TZID=America/Montreal:%(start)s\r
DTEND;TZID=America/Montreal:%(end)s\r
CREATED:20080711T231608Z\r
DTSTAMP:20080711T231640Z\r
END:VEVENT\r
END:VCALENDAR\r
"""
    def __init__(self, maxDays):
        self.reset(maxDays)

    def reset(self, maxDays):
        self.maxDays = maxDays
        self.currentDay = 0
        self.currentStart = 0
        today = time.mktime(time.localtime())
        self.firstDay = today - days(maxDays + 30)

    def _calendarDate(self, eventTime):
        timeStruct = time.localtime(eventTime)
        return time.strftime("%Y%m%dT%H0000", timeStruct)

    def _iterValues(self):
        event = None

        if (self.currentDay < self.maxDays):
            eventStart = (self.firstDay
                          + days(self.currentDay)
                          + hours(self.currentStart + 8))
            eventEnd = eventStart + hours(1)

            thatDay = time.localtime(int(eventStart))
            uid = "Event%d%d" % (eventStart, eventEnd)
            summary = "%s - event %d" % (time.strftime("%Y-%m-%d", thatDay),
                                         self.currentStart)
            start = self._calendarDate(eventStart)
            end = self._calendarDate(eventEnd)
            event = {'uid': uid,
                     'summary': summary,
                     'start': start,
                     'end': end}

            self.currentStart = self.currentStart + 1
            if (self.currentStart > 7):
                self.currentStart = 0
                self.currentDay = self.currentDay + 1
        
        return event

    def iter(self):
        hasMore = False
        entryValues = self._iterValues()
        if (entryValues is not None):
            self.event = (self.ev_templ % entryValues).strip()
            hasMore = True

        return hasMore
