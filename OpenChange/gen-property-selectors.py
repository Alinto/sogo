#!/usr/bin/python

include_dirs = [ "/usr/include" ]

output = "-"

import os
import sys

m_template = """/* %(filename)s (auto-generated) - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <objc/objc.h>
#include <stdint.h>

#import "%(h_filename)s"

const NSUInteger MAPIStorePropertyGettersCount = %(nbr_getters)d;
const NSUInteger MAPIStoreLastPropertyIdx = %(last_property)d;
const NSUInteger MAPIStoreSupportedPropertiesCount = %(nbr_supported_properties)d;

const enum MAPITAGS MAPIStoreSupportedProperties[] = {
%(supported_properties)s
};

static const uint16_t MAPIStorePropertyGettersIdx[] = {
%(getters_idx)s
};

static const SEL MAPIStorePropertyGetterSelectors[] = {
%(getters)s
};

#include "code-%(filename)s"
"""

h_template = """/* %(filename)s (auto-generated) - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef %(h_exclusion)s
#define %(h_exclusion)s 1

#import <Foundation/NSObjCRuntime.h>

#include <stdbool.h>
#include <talloc.h>
#include <util/time.h>
#include <gen_ndr/exchange.h>

extern const NSUInteger MAPIStorePropertyGettersCount;
extern const NSUInteger MAPIStoreLastPropertyIdx;

extern const NSUInteger MAPIStoreSupportedPropertiesCount;
extern const enum MAPITAGS MAPIStoreSupportedProperties[];

#import "MAPIStoreObject.h"

@interface MAPIStoreObject (MAPIStorePropertySelectors)

%(prototypes)s

@end

#include "code-%(filename)s"

#endif /* %(h_exclusion)s */
"""

# hack: some properties have multiple and incompatible types. Sometimes those
# props are not related at all...
bannedProps = set(["PidTagBodyHtml", "PidTagFavAutosubfolders",
                   "PidTagAttachDataObj", "PidTagAclTable", "PidTagAclData",
                   "PidTagRulesTable", "PidTagRulesData",
                   "PidTagDisableWinsock",
                   "PidTagHierarchyServer", "PidTagOfflineAddrbookEntryid",
                   "PidTagShorttermEntryidFromObject",
                   "PidTagNormalMessageSizeExtended",
                   "PidTagAssocMessageSizeExtended",
                   "PidTagMessageSizeExtended",
                   "PidTagOabContainerGuid",
                   "PidTagOfflineAddressBookMessageClass", "PidTagScriptData",
                   "PidTagOfflineAddressBookTruncatedProperties",
                   "PidTagOfflineAddressBookContainerGuid",
                   "PidTagOfflineAddressBookDistinguishedName",
                   "PidTagOfflineAddressBookShaHash",
                   "PidTagSenderTelephoneNumber",
                   "PidTagGatewayNeedsToRefresh",
                   "PidTagWlinkType", "PidTagWlinkFlags",
                   "PidTagWlinkGroupClsid", "PidTagWlinkGroupName",
                   "PidTagWlinkGroupHeaderID",
                   "PidTagScheduleInfoDelegatorWantsCopy",
                   "PidTagWlinkOrdinal",
                   "PidTagWlinkSection", "PidTagWlinkCalendarColor",
                   "PidTagWlinkAddressBookEID", "PidTagWlinkFolderType",
                   "PidTagScheduleInfoDelegateNames",
                   "PidTagScheduleInfoDelegateEntryIds", 
                   "PidTagBusiness2TelephoneNumbers",
                   "PidTagHome2TelephoneNumbers",
                   "PidTagAttachDataObject",
                   "PidTagShorttermEntryIdFromObject",
                   ])

def ParseExchangeH(names, lines):
    state = 0
    maxlines = len(lines)
    x = 0
    while x < maxlines and state != 3:
        stripped = lines[x].strip()
        if state == 0:
            if stripped == "enum MAPITAGS":
                state = 1
        elif state == 1:
            if stripped == "{":
                state = 2
        elif state == 2:
            if stripped == "}":
                state = 3
            else:
                ParseExchangeHDefinition(names, stripped)
        x = x + 1

def ParseExchangeHDefinition(names, line):
    stripped = line.strip()
    eqIdx = stripped.find("=")
    if eqIdx == -1:
        raise Exception, "line does not contain a '='"

    propName = stripped[0:eqIdx]
    if not propName.endswith("_Error") and not propName.endswith("_string8") \
            and propName not in bannedProps:
        intIdx = stripped.find("(int", eqIdx)
        valueIdx = stripped.find("0x", intIdx + 1)
        endIdx = stripped.find(")", valueIdx)
        value = int(stripped[valueIdx:endIdx], 16)
        if value < 0x80000000:
            names[propName] = value

def ParseMapistoreNameIDH(names, lines):
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#define Pid"):
            ParseMapistoreNameIDHDefinition(names, stripped)

def ParseMapistoreNameIDHDefinition(names, line):
    stripped = line.strip()
    pidIdx = stripped.find("Pid")
    if pidIdx == -1:
        raise Exception, "line does not contain a 'Pid'"
    valueIdx = stripped.find("0x")
    propName = stripped[pidIdx:valueIdx].strip()
    if not propName.startswith("PidLidUnknown") and propName not in bannedProps:
        value = int(stripped[valueIdx:], 16)
        names[propName] = value

def FindHFile(filename):
    found = None

    for dirname in include_dirs:
        full_filename = "%s/%s" % (dirname, filename)
        if os.path.exists(full_filename):
            found = full_filename

    if found is None:
        raise Exception, "'%s' not found in include dirs" % filename

    return found

def ProcessHeaders(names, hdict):
    for filename in hdict:
        header_filename = FindHFile(filename)
        header_file = open(header_filename, "r")
        lines = header_file.readlines()
        header_file.close()
        hdict[filename](names, lines)

if __name__ == "__main__":
    arg_count = len(sys.argv)
    x = 0
    while x < arg_count:
        arg = sys.argv[x]
        argname = None
        if arg.startswith("-"):
            argname = arg[1]
            if len(arg) == 2:
                argvalue = sys.argv[x + 1]
                x = x + 1
            else:
                argvalue = arg[2:]
        x = x + 1

        if argname == "o":
            output = argvalue
        elif argname == "I":
            include_dirs.append(argvalue)

    names = {}
    ProcessHeaders(names,
                   {"gen_ndr/exchange.h": ParseExchangeH,
                    "mapistore/mapistore_nameid.h": ParseMapistoreNameIDH})

    getters = []
    getters_idx = []
    # setters = []
    # preferred_types = []
    prototypes = []
    
    for x in xrange(0x10000):
        getters_idx.append("  0xffff")
        # setters.append("  NULL")

    prop_types = {}
    # sanitization: only take unicode version of text properties
    for name, prop_tag in names.iteritems():
        prop_id = prop_tag >> 16
        prop_type = prop_tag & 0xffff
        if not prop_id in prop_types:
            prop_types[prop_id] = []
        prop_types[prop_id].append(prop_type)
        if (prop_type & 0xfff) == 0x001e:
            prop_tag = (prop_tag & 0xfffff000) | 0x001f
        names[name] = prop_tag

    #sanitization: report multiple types for the same keynames
    for prop_id, xtypes in prop_types.iteritems():
        cnt = len(xtypes)
        if cnt > 1:
            print "%d types available for prop id 0x%.4x: %s" % (cnt, prop_id, ", ".join(["%.4x" % x for x in xtypes]))

    supported_properties = []
    current_getter_idx = 0
    highest_prop_idx = 0
    for name, prop_tag in names.iteritems():
        supported_properties.append("  0x%.8x" % prop_tag);
        prop_idx = (prop_tag & 0xffff0000) >> 16
        getters_idx[prop_idx] = "  0x%.4x" % current_getter_idx
        if prop_idx > highest_prop_idx:
            highest_prop_idx = prop_idx
        getters.append("  @selector (get%s:inMemCtx:)" % name)
        # preferred_types.append("  0x%.4x" % (prop_tag & 0xffff))
        prototypes.append("- (int) get%s: (void **) data inMemCtx: (TALLOC_CTX *) memCtx;" % name)
        current_getter_idx = current_getter_idx + 1
        # setters[prop_idx] = "  @selector (set%s:)" % name
        # prototypes.append("- (int) set%s: (void **) data;" % name)
        # prototypes.append("")

    filename = "%s.m" % output
    h_filename = "%s.h" % output
    outf = open(filename, "wb+")
    outf.write(m_template % {"getters_idx": ",\n".join(getters_idx),
                             "getters": ",\n".join(getters),
                             "nbr_getters": len(getters),
                             "last_property": highest_prop_idx,
                             "nbr_supported_properties": len(supported_properties),
                             "supported_properties": ",\n".join(supported_properties),
                             "filename": filename,
                             "h_filename": h_filename})
    outf.close()

    outf = open(h_filename, "wb+")
    exclusion = ""
    for x in h_filename.upper():
        if ord(x) < 65 or ord(x) > 90:
            x = "_"
        exclusion = exclusion + x
    outf.write(h_template % {"prototypes": "\n".join(prototypes),
                             "h_exclusion": exclusion,
                             "filename": h_filename })
    outf.close()
