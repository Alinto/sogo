#!/usr/bin/env python

import sys
import os
import re

DEBUG=False

dir_mappings = {
    # .wox
    "../UI/Templates":"../UI/Common",
    "../UI/Templates/AdministrationUI":"../UI/AdministrationUI",
    "../UI/Templates/Appointments":"../SoObjects/Appointments",
    "../UI/Templates/ContactsUI":"../UI/Contacts",
    "../UI/Templates/MailerUI":"../UI/MailerUI",
    "../UI/Templates/MailPartViewers":"../UI/MailPartViewers",
    "../UI/Templates/MainUI":"../UI/MainUI",
    "../UI/Templates/PreferencesUI":"../UI/PreferencesUI",
    "../UI/Templates/SchedulerUI":"../UI/Scheduler",
    # .toolbars
    "../UI/AdministrationUI/Toolbars":"../UI/AdministrationUI",
    "../UI/Contacts/Toolbars":"../UI/Contacts",
    "../UI/MailerUI/Toolbars":"../UI/MailerUI",
    "../UI/PreferencesUI/Toolbars":"../UI/PreferencesUI",
    "../UI/Scheduler/Toolbars":"../UI/Scheduler",
    # .js
    "../UI/WebServerResources/generic.js":"../UI/Common",
    "../UI/WebServerResources/UIxAclEditor.js":"../UI/Common",
    "../UI/WebServerResources/SOGoRootPage.js":"../UI/MainUI",
    "../UI/WebServerResources/SOGoRootPage.js":"../UI/MainUI",
    "../UI/WebServerResources/PasswordPolicy.js":"../UI/AdministrationUI",
    "../UI/WebServerResources/ContactsUI.js":"../UI/Contacts",
    "../UI/WebServerResources/UIxContactEditor.js":"../UI/Contacts",
    "../UI/WebServerResources/UIxContactsUserFolders.js":"../UI/Contacts",
    "../UI/WebServerResources/UIxContactsUserRightsEditor.js":"../UI/Contacts",
    "../UI/WebServerResources/MailerUI.js":"../UI/MailerUI",
    "../UI/WebServerResources/MailerUIdTree.js":"../UI/MailerUI",
    "../UI/WebServerResources/UIxMailEditor.js":"../UI/MailerUI",
    "../UI/WebServerResources/UIxMailSearch.js":"../UI/MailerUI",
    "../UI/WebServerResources/UIxMailUserRightsEditor.js":"../UI/MailerUI",
    "../UI/WebServerResources/UIxPreferences.js":"../UI/PreferencesUI",
    "../UI/WebServerResources/UIxFilterEditor.js":"../UI/PreferencesUI",
    "../UI/WebServerResources/SchedulerUI.js":"../UI/Scheduler",
    "../UI/WebServerResources/UIxCalUserRightsEditor.js":"../UI/Scheduler",
    "../UI/WebServerResources/UIxCalViewPrint.js":"../UI/Scheduler",
}

def get_translations(path, filename):
    try:
        transpath = dir_mappings.get(path)
        if not transpath:
            transpath = dir_mappings.get(path + '/' + filename)
        if not transpath:
            transpath = path
        transname = transpath + '/English.lproj/Localizable.strings'
        transall = open(transname).read()
    except:
        transall = ""
    return transall


def find_missing_translations(rootdir='.', extention='', recomp=None, greylist=()):
    for path, dirs, files in os.walk(rootdir):
        if (os.path.basename(path) in greylist):
            continue
        filelist = [f for f in files if f[(-1 * len(extention)):] == extention]
        if filelist:
            for filename in filelist:
                if filename in greylist:
                    print "%s is greylisted -- SKIPPING" % filename
                    continue
                pathname = path + '/' + filename
                lines = open(pathname).read().split("\n")
                values = [r.groups()[0] for r in [recomp.search(l) for l in lines] if r]
                if values:
                    #- Get the current english translations for the path
                    transgood = get_translations(path, filename)
                    if not transgood:
                        print "No translation file found for %s, skipping %s" % (path, pathname)
                        continue
                    notfound = list()
                    if DEBUG:print pathname
                    for value in values:
                        #- Try to find the value from the source file in the translation file
                        escaped_value = re.escape(value)
                        found = re.search('(%s|"%s")\s*=\s*"(.*?)";' % (escaped_value, escaped_value), transgood)
                        if found:
                            if DEBUG: print "\t", '[%s] FOUND -- "%s"' % found.groups()
                        else:
                            #notfound.append("-->\t[%s] ==== Not Found ====" % value)
                            notfound.append("""-->\t"%s" = "%s";""" % (value, value))
                    if notfound:
                        if not DEBUG:print pathname
                        print "\n".join(notfound)


def main():
    #- Only one option...
    if len(sys.argv) > 1: 
        if sys.argv[1] == '-g':
            global DEBUG
            DEBUG = True
        else:
            print 'Usage:', sys.argv[0], '[-g]\n\t\t-g: debug will show matching also'
            sys.exit(1)

    #- Get only the label:value from all lines
    recomp = re.compile('.label:[^=]*="([^$].*?)"')
    find_missing_translations('../UI', 'wox', recomp, ())

    #- [self labelForKey: @"Issuer"]
    recomp = re.compile('\[self labelForKey: @"(.*?)"\]')
    find_missing_translations('../UI', 'm', recomp, ())

    #- tooltip = "Switch to day view"
    recomp = re.compile(' tooltip = "(.*?)";')
    find_missing_translations('../UI', 'toolbar', recomp, ('Resources'))

    #- _("Reminder")
    recomp = re.compile(' _\("(.*?)"\)')
    find_missing_translations('../UI/WebServerResources', 'js', recomp, ())

main()
