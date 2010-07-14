#!/usr/bin/python

from config import hostname, port

import webdavlib
import random
import time
import threading

base=1127
userscount=100
password=""
batchcount=10
sleeptime=3
durationHeader="sogorequestduration"
#durationHeader="sogo-request-duration"

class StressIteration(threading.Thread):
    def __init__(self, username):
        threading.Thread.__init__(self)
        self.username = username
        self.time = 0.0
        self.sogoTime = 0.0

    def run(self):
        client = webdavlib.WebDAVClient(hostname, port,
                                        self.username, password)
        resource = "/SOGo/dav/%s/Calendar/personal/" % self.username
        startTime = time.time()
        query = webdavlib.WebDAVSyncQuery(resource, None,
                                          [ "getetag", "calendar-data" ])
        client.execute(query)
        if query.response["status"] != 207:
            print "*** received unexpected code: %d (%s)" \
                  % (query.response["status"], resource)
        endTime = time.time()
        headers = query.response["headers"]
        if headers.has_key(durationHeader):
            self.sogoTime = float(headers[durationHeader])
        self.time = endTime - startTime
	# print "%f, %f" % (self.time, self.sogoTime)

class StressTest:
    def __init__(self):
        self.usernames = [ "invite%d" % (base + x)
                           for x in xrange(userscount) ]
        self.random = random.Random()

    def iteration(self):
        usernames = self.random.sample(self.usernames, batchcount)
        startTime = time.time()
        threads = []
        for username in usernames:
            iteration = StressIteration(username)
            iteration.start()
            threads.append(iteration)

        for thread in threads:
            thread.join()

        endTime = time.time()

        programTime = endTime - startTime
        requestsTime = 0.0
        sogoTime = 0.0
        for thread in threads:
            requestsTime = requestsTime + thread.time
            sogoTime = sogoTime + thread.sogoTime

        print "Iteration time: %f, Total Requests Time: %f, Total SOGo Time: %f" \
              % (programTime, requestsTime, sogoTime)

    def start(self):
        while True:
            self.iteration()
            time.sleep(sleeptime)

if __name__ == "__main__":
    test = StressTest()
    test.start()
