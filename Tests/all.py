#!/usr/bin/python

import os, sys, unittest, getopt, traceback
import preferences

if __name__ == "__main__":
    loader = unittest.TestLoader()
    modules = []
    # Duplicated from UIxPreferences.m
    languages = ["Czech", "Dutch", "English", "French", 
                 "German", "Hungarian", "Italian", "BrazilianPortuguese", 
                 "Russian", "Spanish", "Welsh"]

    # We can disable testing all languages
    testLanguages = True
    opts, args = getopt.getopt (sys.argv[1:], [], ["disable-languages"])
    for o, a in opts:
        if o == "--disable-languages":
            testLanguages = False


    for mod in os.listdir("."):
        if mod.startswith("test-") and mod.endswith(".py"):
            modules.append(mod[:-3])
            __import__(mod[:-3])

    if len(modules) > 0:
        suite = loader.loadTestsFromNames(modules)
        print "%d tests in modules: '%s'" % (suite.countTestCases(),
                                             "', '".join(modules))
        runner = unittest.TextTestRunner()

        if testLanguages:
            prefs = preferences.preferences()
            # Get the current language
            userLanguageString = prefs.get ("Language")
            if userLanguageString:
                userLanguage = languages.index (userLanguageString)
            else:
                userLanguage = 2

            for i in range (0, len (languages)):
                try:
                    prefs.set ("language", i)
                except Exception, inst:
                    print '-' * 60
                    traceback.print_exc ()
                    print '-' * 60
                
                print "Running test in %s (%d/%d)" % \
                    (languages[i], i + 1, len (languages))
                runner.run(suite)
            # Revert to the original language
            prefs.set ("language", userLanguage)
        else:
            runner.run(suite)

    else:
        print "No test available."
