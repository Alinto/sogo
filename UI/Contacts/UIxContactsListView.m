/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSString+misc.h>

#import <Contacts/SOGoContactObject.h>
#import <Contacts/SOGoContactFolder.h>
#import <Contacts/SOGoContactFolders.h>

#import "UIxContactsListView.h"

@implementation UIxContactsListView

- (id) init
{
  if ((self = [super init]))
    {
      selectorComponentClass = nil;
      contactInfos = nil;
    }

  return self;
}

- (void) dealloc
{
  [contactInfos release];
  [super dealloc];
}

/* accessors */

- (void) setCurrentContact: (NSDictionary *) _contact
{
  currentContact = _contact;
}

- (NSDictionary *) currentContact
{
  return currentContact;
}

- (NSString *) currentCName
{
  NSString *cName;

  cName = [currentContact objectForKey: @"c_name"];

  return [cName stringByEscapingURL];
}

- (id <WOActionResults>) mailerContactsAction
{
  selectorComponentClass = @"UIxContactsMailerSelection";

  return self;
}

- (NSString *) selectorComponentClass
{
  return selectorComponentClass;
}

- (NSString *) defaultSortKey
{
  return @"displayName";
}

- (NSString *) sortKey
{
  NSString *s;
  
  s = [self queryParameterForKey: @"sort"];
  if (![s length])
    s = [self defaultSortKey];

  return s;
}

- (NSArray *) contactInfos
{
  id <SOGoContactFolder> folder;
  NSString *ascending, *searchText, *valueText;
  NSComparisonResult ordering;

  if (!contactInfos)
    {
      folder = [self clientObject];

      ascending = [self queryParameterForKey: @"asc"];
      ordering = ((![ascending length] || [ascending boolValue])
		  ? NSOrderedAscending : NSOrderedDescending);

      searchText = [self queryParameterForKey: @"search"];
      if ([searchText length] > 0)
	valueText = [self queryParameterForKey: @"value"];
      else
	valueText = nil;

      [contactInfos release];
      contactInfos = [folder lookupContactsWithFilter: valueText
			     sortBy: [self sortKey]
			     ordering: ordering];
      [contactInfos retain];
    }

  return contactInfos;
}

/* actions */

- (BOOL) shouldTakeValuesFromRequest: (WORequest *) _rq
                           inContext: (WOContext*) _c
{
  return YES;
}

@end /* UIxContactsListView */
