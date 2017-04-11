/* SOGoGroup.m - this file is part of SOGo
 *
 * Copyright (C) 2009-2014 Inverse inc.
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

  dn: cn=inverse,ou=groups,dc=inverse,dc=ca
  objectClass: groupOfUniqueNames
  objectClass: top
  objectClass: extensibleObject
  uniqueMember: uid=flachapelle,ou=users,dc=inverse,dc=ca
  uniqueMember: uid=lmarcotte,ou=users,dc=inverse,dc=ca
  uniqueMember: uid=wsourdeau,ou=users,dc=inverse,dc=ca
  cn: inverse
  mail: inverse@inverse.ca

 */

#include "SOGoGroup.h"


#include "SOGoCache.h"
#include "SOGoSource.h"
#include "SOGoSystemDefaults.h"
#include "SOGoUserManager.h"
#include "SOGoUser.h"

#import <NGLdap/NGLdapEntry.h>

#define CHECK_CLASS(o) ({ \
  if ([o isKindOfClass: [NSString class]]) \
    o = [NSArray arrayWithObject: o]; \
})

@implementation SOGoGroup

- (id) initWithIdentifier: (NSString *) theID
		   domain: (NSString *) theDomain
		   source: (NSObject <SOGoSource> *) theSource
		    entry: (NGLdapEntry *) theEntry
{
  self = [super init];

  if (self)
    {
      ASSIGN(_identifier, theID);
      ASSIGN(_domain, theDomain);
      ASSIGN(_source, theSource);
      ASSIGN(_entry, theEntry);
      _members = nil;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(_identifier);
  RELEASE(_domain);
  RELEASE(_source);
  RELEASE(_entry);
  RELEASE(_members);

  [super dealloc];
}

+ (id) groupWithIdentifier: (NSString *) theID
                  inDomain: (NSString *) domain
{
  NSRange r;
  NSString *uid, *inDomain;
  SOGoSystemDefaults *sd;

  uid = [theID hasPrefix: @"@"] ? [theID substringFromIndex: 1] : theID;
  inDomain = domain;

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([sd enableDomainBasedUID])
    {
      /* Split domain from uid */
      r = [uid rangeOfString: @"@" options: NSBackwardsSearch];
      if (r.location != NSNotFound)
        {
          if (!domain)
            inDomain = [uid substringFromIndex: r.location + 1];
          uid = [uid substringToIndex: r.location];
        }
    }

  return [SOGoGroup groupWithValue: uid
                 andSourceSelector: @selector (lookupGroupEntryByUID:inDomain:)
                          inDomain: inDomain];
}

+ (id) groupWithEmail: (NSString *) theEmail
             inDomain: (NSString *) domain
{
  return [SOGoGroup groupWithValue: theEmail
                 andSourceSelector: @selector (lookupGroupEntryByEmail:inDomain:)
                          inDomain: domain];
}

//
// Returns nil if theValue doesn't match to a group
//  (so its objectClass isn't a group)
//
+ (id) groupWithValue: (NSString *) theValue
    andSourceSelector: (SEL) theSelector
             inDomain: (NSString *) domain
{
  NSArray *allSources;
  NGLdapEntry *entry;
  NSObject <SOGoSource, SOGoDNSource> *source;
  id o;
  NSEnumerator *gclasses;
  NSString *gclass;
  
  int i;

  // Don't bother looking in all sources if the
  // supplied value is nil.
  if (!theValue)
    return nil;

  allSources = [[SOGoUserManager sharedUserManager]
                 sourceIDsInDomain: domain];
  entry = nil;
  o = nil;

  for (i = 0; i < [allSources count]; i++)
    {
      source = (NSObject <SOGoSource, SOGoDNSource> *) [[SOGoUserManager sharedUserManager] sourceWithID: [allSources objectAtIndex: i]];

      // Our different sources might not all implements groups support
      if ([source respondsToSelector: theSelector])
        entry = [source performSelector: theSelector
                             withObject: theValue
                             withObject: domain];
      if (entry)
	break;

      entry = nil;
    }
  
  if (entry)
    {
      NSArray *classes;

      // We check to see if it's a group
      classes = [[entry asDictionary] objectForKey: @"objectclass"];

      if (classes)
	{
          /* LDAP records returned as dictionaries may contain NSString or
             NSArray values, depending on whether the amount of values
             assigned to a key is 1 or more. Since this can occur with
             "objectclass" too, we need to check whether "classes" is actually
             an NSString instance... */
          if ([classes isKindOfClass: [NSString class]])
            classes = [NSArray arrayWithObject:
                                 [(NSString *) classes lowercaseString]];
          else
            {
              int i, c;
	  
              classes = [NSMutableArray arrayWithArray: classes];
              c = [classes count];
              for (i = 0; i < c; i++)
                [(id)classes replaceObjectAtIndex: i
                     withObject: [[classes objectAtIndex: i] lowercaseString]];
            }
	}

        gclasses = [[source groupObjectClasses] objectEnumerator];
        while ((gclass = [gclasses nextObject]))
          if ([classes containsObject: gclass])
           {
          // Found a group, let's return it.
	  o = [[self alloc] initWithIdentifier: theValue
			                domain: domain
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
  NSMutableArray *dns, *uids, *logins;
  NSString *dn, *login;
  SOGoUserManager *um;
  NSDictionary *d;
  SOGoUser *user;
  NSArray *o;
  NSAutoreleasePool *pool;
  int i, c;

  if (!_members)
    {
      _members = [NSMutableArray new];
      uids = [NSMutableArray array];
      dns = [NSMutableArray array];
      logins = [NSMutableArray array];

      // We check if it's a static group  
      // Fetch "members" - we get DNs
      d = [_entry asDictionary];
      o = [d objectForKey: @"member"];
      CHECK_CLASS(o);
      if (o) [dns addObjectsFromArray: o];

      // Fetch "uniqueMembers" - we get DNs
      o = [d objectForKey: @"uniquemember"];
      CHECK_CLASS(o);
      if (o) [dns addObjectsFromArray: o];
  
      // Fetch "memberUid" - we get UID (like login names)
      o = [d objectForKey: @"memberuid"];
      CHECK_CLASS(o);
      if (o) [uids addObjectsFromArray: o];

      c = [dns count] + [uids count];

      // We deal with a static group, let's add the members
      if (c)
        {
          um = [SOGoUserManager sharedUserManager];

          // We add members for whom we have their associated DN
          for (i = 0; i < [dns count]; i++)
            { 
              pool = [NSAutoreleasePool new];
              dn = [dns objectAtIndex: i];
              login = [um getLoginForDN: [dn lowercaseString]];
              user = [SOGoUser userWithLogin: login  roles: nil];
              if (user)
                {
                  [logins addObject: login];
                  [_members addObject: user];
                }
              [pool release];
            }

          // We add members for whom we have their associated login name
          for (i = 0; i < [uids count]; i++)
            {
              pool = [NSAutoreleasePool new];
              login = [uids objectAtIndex: i];
              user = [SOGoUser userWithLogin: login  roles: nil];
              
              if (user)
                {
                  [logins addObject: [user loginInDomain]];
                  [_members addObject: user];
                }
              [pool release];
            }


          // We are done fetching members, let's cache the members of the group
          // (ie., their UIDs) in memcached to speed up -hasMemberWithUID.
          [[SOGoCache sharedCache] setValue: [logins componentsJoinedByString: @","]
            forKey: [NSString stringWithFormat: @"%@+%@", _identifier, _domain]];
        }
      else
        {
          // We deal with a dynamic group, let's search all users for whom
          // memberOf is equal to our group's DN.
          // We also need to look for labelelURI?
        }
    }
  
  return _members;
}

//
//
//
- (BOOL) hasMemberWithUID: (NSString *) memberUID
{

  BOOL rc;

  rc = NO;

  // If _members is initialized, we use it as it's very accurate.
  // Otherwise, we fallback on memcached in order to avoid
  // decomposing the group all the time just to see if a user
  // is a member of it.
  if (_members)
    {
      NSString *currentUID;
	
      int count, max;
      max = [_members count];
      for (count = 0; !rc && count < max; count++)
	{
	  currentUID = [[_members objectAtIndex: count] login];
	  rc = [memberUID isEqualToString: currentUID];
	}

    }
  else
    {
      NSString *key, *value;;
      NSArray *a;

      key = [NSString stringWithFormat: @"%@+%@", _identifier, _domain];
      value = [[SOGoCache sharedCache] valueForKey: key];


      // If the value isn't in memcached, that probably means -members was never called.
      // We call it only once here.
      if (!value)
	{
	  [self members];
	  value = [[SOGoCache sharedCache] valueForKey: key];
	}

      a = [value componentsSeparatedByString: @","];
      rc = [a containsObject: memberUID];
    }

  return rc;
}

@end
