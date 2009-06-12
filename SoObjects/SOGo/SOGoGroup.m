/* SOGoGroup.m - this file is part of SOGo
 *
 * Copyright (C) 2009 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
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

/*
  Here are some group samples:


  [ POSIX group ]

  dn: cn=it-staff,ou=Group,dc=zzz,dc=xxx,dc=yyy
  objectClass: posixGroup
  objectClass: top
  cn: it-staff
  userPassword: {crypt}x
  gidNumber: 8000
  memberUid: lsa
  memberUid: mrm
  memberUid: ij
  memberUid: no
  memberUid: ld
  memberUid: db
  memberUid: rgl
  memberUid: ja
  memberUid: hbt
  memberUid: hossein

 */

#include "SOGoGroup.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#include "LDAPSource.h"
#include "LDAPUserManager.h"
#include "SOGoUser.h"

#import <NGLdap/NGLdapConnection.h>
#import <NGLdap/NGLdapAttribute.h>
#import <NGLdap/NGLdapEntry.h>

@implementation SOGoGroup

- (id) initWithIdentifier: (NSString *) theID
		   source: (LDAPSource *) theSource
		    entry: (NGLdapEntry *) theEntry
{
  self = [super init];

  if (self)
    {
      ASSIGN(_identifier, theID);
      ASSIGN(_source, theSource);
      ASSIGN(_entry, theEntry);
    }

  return self;
}

- (void) dealloc
{
  RELEASE(_identifier);
  RELEASE(_source);
  RELEASE(_entry);

  [super dealloc];
}

+ (id) groupWithIdentifier: (NSString *) theID
{
  NSString *uid;

  uid = [theID hasPrefix: @"@"] ? [theID substringFromIndex: 1] : theID;
  return [SOGoGroup groupWithValue: uid andSourceSelector: @selector (lookupGroupEntryByUID:)];
}

+ (id) groupWithEmail: (NSString *) theEmail
{
  return [SOGoGroup groupWithValue: theEmail andSourceSelector: @selector (lookupGroupEntryByEmail:)];
}

//
// Returns nil if theValue doesn't match to a group
//  (so its objectClass isn't a group)
//
+ (id) groupWithValue: (NSString *) theValue
    andSourceSelector: (SEL) theSelector
{
  NSArray *allSources;
  NGLdapEntry *entry;
  LDAPSource *source;
  id o;
  
  int i;

  // Don't bother looking in all sources if the
  // supplied value is nil.
  if (!theValue)
    return nil;

  allSources = [[LDAPUserManager sharedUserManager] sourceIDs];
  o = nil;

  for (i = 0; i < [allSources count]; i++)
    {
      source = [[LDAPUserManager sharedUserManager] sourceWithID: [allSources objectAtIndex: i]];
      entry = [source performSelector: theSelector
		      withObject: theValue];

      if (entry)
	break;

      entry = nil;
    }
  
  if (entry)
    {
      NSArray *classes;
      
      // We check to see if it's a group
      classes = [[entry attributeWithName: @"objectClass"] allStringValues];
      NSLog(@"classes for %@ = %@", theValue, classes);

      // Found a group, let's return it.
      if ([classes containsObject: @"group"] ||
	  [classes containsObject: @"groupOfNames"] ||
	  [classes containsObject: @"groupOfUniqueNames"] ||
	  [classes containsObject: @"posixGroup"])
	{
	  o = [[self alloc] initWithIdentifier: theValue
			    source: source
			    entry: entry];
	  AUTORELEASE(o);
	}
    }
  
  return o;
}

//
// This method actually try to obtain all members
// from either dynamic of static groups.
//
- (NSArray *) members
{
  NSMutableArray *dns, *uids;
  NSMutableArray *array;
  NSString *dn, *login;
  SOGoUser *user;
  NSArray *o;
  LDAPUserManager *um;
  int i, c;

  array = [NSMutableArray array];
  uids = [NSMutableArray array];
  dns = [NSMutableArray array];

  // We check if it's a static group
  //NSLog(@"attributes = %@", [_entry attributes]);
  
  // Fetch "members" - we get DNs
  o = [[_entry attributeWithName: @"member"] allStringValues];
  if (o) [dns addObjectsFromArray: o];

  // Fetch "uniqueMembers" - we get DNs
  o = [[_entry attributeWithName: @"uniqueMember"] allStringValues];
  if (o) [dns addObjectsFromArray: o];
  
  // Fetch "memberUid" - we get UID (like login names)
  o = [[_entry attributeWithName: @"memberUid"] allStringValues];
  if (o) [uids addObjectsFromArray: o];

  c = [dns count] + [uids count];

  NSLog(@"members count (static group): %d", c);

  // We deal with a static group, let's add the members
  if (c)
    {
      um = [LDAPUserManager sharedUserManager];

      // We add members for whom we have their associated DN
      for (i = 0; i < [dns count]; i++)
	{
	  dn = [dns objectAtIndex: i];
	  login = [um getLoginForDN: dn];
	  //NSLog(@"member = %@", login);
	  user = [SOGoUser userWithLogin: login roles: nil];
	  if (user)
	    [array addObject: user];
	}

      // We add members for whom we have their associated login name
      for (i = 0; i < [uids count]; i++)
	{
	  login = [uids objectAtIndex: i];
	  NSLog(@"member = %@", login);
	  user = [SOGoUser userWithLogin: login  roles: nil];
	  
	  if (user)
	    [array addObject: user];
	}
    }
  else
    {
      // We deal with a dynamic group, let's search all users for whom
      // memberOf is equal to our group's DN.
      // We also need to look for labelelURI?
    }
  
  return array;
}

@end
