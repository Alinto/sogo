/* MAPIStoreGCSMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>
#import <GDLContentStore/GCSFolder.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreTypes.h"

#import "MAPIStoreGCSMessageTable.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <libmapi/mapidefs.h>

@implementation MAPIStoreGCSMessageTable

- (NSArray *) _childKeysUsingRestrictions: (BOOL) useRestrictions
{
  static NSArray *fields = nil;
  NSArray *records;
  EOQualifier *componentQualifier, *fetchQualifier;
  NSArray *keys;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  componentQualifier = [self componentQualifier];

  if (useRestrictions
      && restrictionState != MAPIRestrictionStateAlwaysTrue)
    {
      if (restrictionState == MAPIRestrictionStateNeedsEval)
	{
	  fetchQualifier = [[EOAndQualifier alloc]
			     initWithQualifiers:
			       componentQualifier,
			     restriction,
			     nil];
	  [fetchQualifier autorelease];
	}
      else
	fetchQualifier = nil;
    }
  else
    fetchQualifier = componentQualifier;
    
  if (fetchQualifier)
    {
      records = [[folder ocsFolder] fetchFields: fields
			      matchingQualifier: fetchQualifier];
      keys = [records objectsForKey: @"c_name"
		     notFoundMarker: nil];
    }
  else
    keys = [NSArray array];

  return keys;
}

- (NSArray *) childKeys
{
  return [self _childKeysUsingRestrictions: NO];
}

- (NSArray *) restrictedChildKeys
{
  return [self _childKeysUsingRestrictions: YES];
}

- (MAPIRestrictionState) evaluateDatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
					   intoQualifier: (EOQualifier **) qualifier
{
  struct mapi_SPropertyRestriction translatedRes;
  NSCalendarDate *dateValue;
  int32_t longDate;

  translatedRes.ulPropTag = (res->ulPropTag & 0xffff0000) | PT_LONG;
  translatedRes.relop = res->relop;
  dateValue = NSObjectFromMAPISPropValue (&res->lpProp);
  longDate = (int32_t) [dateValue timeIntervalSince1970];
  translatedRes.lpProp.ulPropTag = translatedRes.ulPropTag;
  translatedRes.lpProp.value.l = longDate;

  return [super evaluatePropertyRestriction: &translatedRes
			      intoQualifier: qualifier];
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  if ((res->ulPropTag & 0x0040) == 0x0040) /* is date ? */
    rc = [self evaluateDatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				 intoQualifier: qualifier];
  else
    rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];

  return rc;
}

- (EOQualifier *) componentQualifier
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
