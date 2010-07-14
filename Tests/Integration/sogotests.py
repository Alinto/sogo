import sys
import unittest
import time

def UnitTestTextTestResultNewStartTest(self, test):
    self.xstartTime = time.time()
    self.oldStartTest(test)

def UnitTestTextTestResultNewStopTest(self, test):
    unittest.TestResult.stopTest(self, test)
    endTime = time.time()
    delta = endTime - self.xstartTime
    print "  %f ms" % delta

def runTests():
    unittest._TextTestResult.oldStartTest = unittest._TextTestResult.startTest
    unittest._TextTestResult.startTest = UnitTestTextTestResultNewStartTest
    unittest._TextTestResult.stopTest = UnitTestTextTestResultNewStopTest

    argv = []
    argv.extend(sys.argv)
    argv.append("-v")
    unittest.main(argv=argv)
