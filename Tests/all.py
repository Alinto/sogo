#!/usr/bin/python

import os, unittest

if __name__ == "__main__":
    loader = unittest.TestLoader()
    modules = []
    for mod in os.listdir("."):
        if mod.startswith("test-") and mod.endswith(".py"):
            modules.append(mod[:-3])
            __import__(mod[:-3])

    if len(modules) > 0:
        print "Test modules: '%s'" % "', '".join(modules)
        suite = loader.loadTestsFromNames(modules)
        runner = unittest.TextTestRunner()
        runner.run(suite)
    else:
        print "No test available."
