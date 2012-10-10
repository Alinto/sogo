/* MAPIStoreDBMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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

#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>

#import "MAPIStoreTypes.h"
#import "MAPIStoreDBMessage.h"

#import "MAPIStoreDBMessageTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class MAPIStoreDBMessageK = Nil;

@implementation MAPIStoreDBMessageTable

+ (void) initialize
{
  MAPIStoreDBMessageK = [MAPIStoreDBMessage class];
}

+ (Class) childObjectClass
{
  return MAPIStoreDBMessageK;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return [NSString stringWithFormat: @"%@", MAPIPropertyKey (property)];
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;
  NSNumber *version;
  uint64_t cVersion;

  if ((uint32_t) res->ulPropTag == PidTagChangeNumber)
    {
      value = NSObjectFromMAPISPropValue (&res->lpProp);
      cVersion = exchange_globcnt (([value unsignedLongLongValue] >> 16)
                                   & 0x0000ffffffffffffLL);
      version = [NSNumber numberWithUnsignedLongLong: cVersion];
      [self logWithFormat: @"change number from oxcfxics: %.16lx", [value unsignedLongLongValue]];
      [self logWithFormat: @"  version: %.16lx", cVersion];
      *qualifier = [[EOKeyValueQualifier alloc] initWithKey: @"version"
                                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                                      value: version];
      [*qualifier autorelease];
      rc = MAPIRestrictionStateNeedsEval;
    }
  else if ((uint32_t) res->ulPropTag == PR_SUBJECT_UNICODE)
    {
      EOQualifier *subjectQualifier, *nSubjectQualifier, *subjectPQualifier;
      EOQualifier *orQualifier, *andQualifier;
      struct mapi_SPropertyRestriction subRes;
      char *colPtr, *prefix;

      [super evaluatePropertyRestriction: res
                           intoQualifier: &subjectQualifier];

      subRes.relop = res->relop;
      subRes.ulPropTag = PR_NORMALIZED_SUBJECT_UNICODE;
      subRes.lpProp.ulPropTag = PR_NORMALIZED_SUBJECT_UNICODE;

      colPtr = strstr (res->lpProp.value.lpszW, ":");
      if (colPtr)
        subRes.lpProp.value.lpszW = colPtr + 1;
      else
        subRes.lpProp.value.lpszW = res->lpProp.value.lpszW;

      [self evaluatePropertyRestriction: &subRes
                          intoQualifier: &nSubjectQualifier];
      if (colPtr)
        {
          prefix = strndup (res->lpProp.value.lpszW, (colPtr - res->lpProp.value.lpszW));

          subRes.relop = RELOP_EQ;
          subRes.ulPropTag = PR_SUBJECT_PREFIX_UNICODE;
          subRes.lpProp.ulPropTag = PR_SUBJECT_PREFIX_UNICODE;
          subRes.lpProp.value.lpszW = prefix;
          [self evaluatePropertyRestriction: &subRes
                              intoQualifier: &subjectPQualifier];
          free (prefix);

          andQualifier = [[EOOrQualifier alloc]
                          initWithQualifiers:
                             subjectPQualifier, nSubjectQualifier, nil];
          orQualifier = [[EOOrQualifier alloc]
                          initWithQualifiers:
                            subjectQualifier, andQualifier, nil];
          [andQualifier release];
        }
      else
        orQualifier = [[EOOrQualifier alloc]
                          initWithQualifiers:
                          subjectQualifier, nSubjectQualifier, nil];
      [orQualifier autorelease];
      *qualifier = orQualifier;
      rc = MAPIRestrictionStateNeedsEval;
    }
  else
    rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];

  return rc;
}

@end
