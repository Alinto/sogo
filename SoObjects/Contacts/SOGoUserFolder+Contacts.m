/* SOGoUserFolder+Contacts.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2009 Inverse inc.
 *
 * Author: Francis Lachapelle <flachapelle@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+DAV.h>

#import "SOGoContactFolders.h"

#import "SOGoUserFolder+Contacts.h"

@interface SOGoUserFolder (private)

- (SOGoContactFolders *) privateContacts: (NSString *) key
                               inContext: (WOContext *) localContext;

@end

@implementation SOGoUserFolder (SOGoCalDAVSupport)

/* CalDAV support */
- (NSArray *) davAddressbookHomeSet
{
  NSArray *tag;
  SOGoContactFolders *parent;

  parent = [self privateContacts: @"Contacts" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [parent davURLAsString], nil];

  return [NSArray arrayWithObject: tag];
}

- (NSArray *) davDirectoryGateway
{
  NSArray *tag, *sources;
  SOGoContactFolders *parent;
  SOGoUserManager *um;
  NSString *domain, *url;

  domain = [[context activeUser] domain];
  um = [SOGoUserManager sharedUserManager];
  sources = [um addressBookSourceIDsInDomain: domain];
  if ([sources count] > 0)
    {
      parent = [self privateContacts: @"Contacts" inContext: context];
      url = [NSString stringWithFormat: @"%@%@/", [parent davURLAsString],
                      [sources objectAtIndex: 0]];
      tag = [NSArray arrayWithObject:
                       [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                                url, nil]];
    }
  else
    tag = nil;

  return tag;
}


@end
