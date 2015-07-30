#!/usr/bin/env python

import sys
import os
import re

DEBUG=True
DEBUG=False

dir_mappings = {"../UI/Templates":"../UI/Common",
                "../UI/Templates/AdministrationUI":"../UI/AdministrationUI",
                "../UI/Templates/Appointments":"../UI/Common",
                "../UI/Templates/ContactsUI":"../UI/Contacts",
                "../UI/Templates/MailerUI":"../UI/MailerUI",
                "../UI/Templates/MailPartViewers":"../UI/MailPartViewers",
                "../UI/Templates/MainUI":"../UI/MainUI",
                "../UI/Templates/PreferencesUI":"../UI/PreferencesUI",
                "../UI/Templates/SchedulerUI":"../UI/Scheduler"
               }

def get_translations(path):
    try:
        transpath = dir_mappings.get(path, path)
        #print "Transpath:", transpath
        transname = transpath + '/English.lproj/Localizable.strings'
        transall = open(transname).read().split('\n')
        transgood = [l.strip() for l in transall if len(l.strip()) and l.strip()[0] != '#']
    except:
        transgood = ()
    return transgood


def find_missing_translations(rootdir='.', extention='', recomp=None, greylist=()):
    for path, dirs, files in os.walk(rootdir):
        #print path, files
        filelist = [f for f in files if f[(-1 * len(extention)):] == extention]
        if filelist:
            for filename in filelist:
                if filename in greylist:
                    print "%s is greylisted -- SKIPPING" % filename
                    continue
                pathname = path + '/' + filename
                lines = open(pathname).read().split("\n")
                regex_results = [recomp.search(l) for l in lines]
                values = [r.groups()[0] for r in regex_results if r]
                #print pathname, values
                if values:
                    #- Get the current english translations for the path
                    transgood = get_translations(path)
                    if not transgood:
                        print "No translation file found for %s, skipping %s" % (path, pathname)
                        continue
                    notfound = list()
                    if DEBUG:print pathname
                    #- Only 'good' lines (not empty, not comment)
                    for value in values:
                        #print "\t", "[%s]" % value
                        #- Try to find the value from the vox file in the translation file
                        found = [line for line in transgood if value in line]
                        if found:
                            if DEBUG: print "\t", "[%s] FOUND --" % value, found[0].split("=")[0]
                        else:
                            #notfound.append("-->\t[%s] ==== TRANSLATION NOT FOUND ====" % value)
                            notfound.append("-->\t[%s] ==== Not Found ====" % value)
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

    greylist = ('UIxFilterEditor.wox')

    #- Get only the label:value from all lines
    recomp = re.compile('<var:string label:value="(.*?)"')
    find_missing_translations('../UI', 'wox', recomp, greylist)

    #- [self labelForKey: @"Issuer"]
    recomp = re.compile('\[self labelForKey: @"(.*?)"\]')
    find_missing_translations('../UI', 'm', recomp, ())

main()
