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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoFreeBusyObject.h>
#import <Contacts/SOGoContactFolders.h>
#import <Mailer/SOGoMailAccounts.h>

#import "SOGoPermissions.h"
#import "SOGoUser.h"

#import "SOGoUserFolder.h"

@implementation SOGoUserFolder

+ (void) initialize
{
  SoClassSecurityInfo *sInfo;
  NSArray *basicRoles;

  sInfo = [self soClassSecurityInfo];
  [sInfo declareObjectProtected: SoPerm_View];

  basicRoles = [NSArray arrayWithObject: SoRole_Authenticated];

  /* require Authenticated role for View and WebDAV */
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_View];
  [sInfo declareRoles: basicRoles asDefaultForPermission: SoPerm_WebDAVAccess];
}

/* accessors */

- (NSString *) login
{
  return nameInContainer;
}

/* hierarchy */

- (NSArray *) toManyRelationshipKeys
{
  NSMutableArray *children;
  SOGoUser *currentUser;

  children = [NSMutableArray arrayWithCapacity: 4];

  currentUser = [context activeUser];
  if ([currentUser canAccessModule: @"Calendar"])
    [children addObject: @"Calendar"];
  [children addObject: @"Contacts"];
  if ([currentUser canAccessModule: @"Mail"])
    [children addObject: @"Mail"];
  [children addObject: @"Preferences"];

  return children;
}

/* ownership */

- (NSString *) ownerInContext: (WOContext *) _ctx
{
  return nameInContainer;
}

/* looking up shared objects */

- (SOGoUserFolder *) lookupUserFolder
{
  return self;
}

// - (SOGoGroupsFolder *) lookupGroupsFolder
// {
//   return [self lookupName: @"Groups" inContext: nil acquire: NO];
// }

/* name lookup */

// - (NSString *) permissionForKey: (NSString *) key
// {
//   return ([key isEqualToString: @"freebusy.ifb"]
//           ? SoPerm_WebDAVAccess
//           : [super permissionForKey: key]);
// }

- (SOGoAppointmentFolders *) privateCalendars: (NSString *) _key
				    inContext: (WOContext *) _ctx
{
  SOGoAppointmentFolders *calendars;
  
  calendars = [$(@"SOGoAppointmentFolders") objectWithName: _key inContainer: self];
  [calendars setBaseOCSPath: [NSString stringWithFormat: @"/Users/%@/Calendar",
				       nameInContainer]];

  return calendars;
}

- (SOGoContactFolders *) privateContacts: (NSString *) _key
                               inContext: (WOContext *) _ctx
{
  SOGoContactFolders *contacts;

  contacts = [$(@"SOGoContactFolders") objectWithName:_key inContainer: self];
  [contacts setBaseOCSPath: [NSString stringWithFormat: @"/Users/%@/Contacts",
				      nameInContainer]];

  return contacts;
}

// - (id) groupsFolder: (NSString *) _key
//           inContext: (WOContext *) _ctx
// {
//   return [$(@"SOGoGroupsFolder") objectWithName: _key inContainer: self];
// }

- (id) mailAccountsFolder: (NSString *) _key
                inContext: (WOContext *) _ctx
{
  return [$(@"SOGoMailAccounts") objectWithName: _key inContainer: self];
}

- (id) freeBusyObject: (NSString *) _key
            inContext: (WOContext *) _ctx
{
  return [$(@"SOGoFreeBusyObject") objectWithName: _key inContainer: self];
}

- (id) lookupName: (NSString *) _key
        inContext: (WOContext *) _ctx
          acquire: (BOOL) _flag
{
  id obj;
  SOGoUser *currentUser;
  
  /* first check attributes directly bound to the application */
  obj = [super lookupName: _key inContext: _ctx acquire: NO];
  if (!obj)
    {
      currentUser = [_ctx activeUser];
      if ([_key isEqualToString: @"Calendar"]
	  && [currentUser canAccessModule: _key])
	obj = [self privateCalendars: @"Calendar" inContext: _ctx];
//           if (![_key isEqualToString: @"Calendar"])
//             obj = [obj lookupName: [_key pathExtension] 
//                        inContext: _ctx acquire: NO];
      else if ([_key isEqualToString: @"Contacts"])
        obj = [self privateContacts: _key inContext: _ctx];
//       else if ([_key isEqualToString: @"Groups"])
//         obj = [self groupsFolder: _key inContext: _ctx];
      else if ([_key isEqualToString: @"Mail"]
	       && [currentUser canAccessModule: _key])
        obj = [self mailAccountsFolder: _key inContext: _ctx];
      else if ([_key isEqualToString: @"Preferences"])
        obj = [$(@"SOGoPreferencesFolder") objectWithName: _key
		inContainer: self];
      else if ([_key isEqualToString: @"freebusy.ifb"])
        obj = [self freeBusyObject:_key inContext: _ctx];
      else
        obj = [NSException exceptionWithHTTPStatus: 404 /* Not Found */];
    }

  return obj;
}

// /* FIXME: here is a vault of hackish ways to gain access to subobjects by
//    granting ro access to the homepage depending on the subobject in question.
//    This is wrong and dangerous. */
// - (NSString *) roleOfUser: (NSString *) uid
//                 inContext: (WOContext *) context
// {
//   NSArray *roles, *traversalPath;
//   NSString *objectName, *role;

//   role = nil;
//   traversalPath = [context objectForKey: @"SoRequestTraversalPath"];
//   if ([traversalPath count] > 1)
//     {
//       objectName = [traversalPath objectAtIndex: 1];
//       if ([objectName isEqualToString: @"Calendar"]
//           || [objectName isEqualToString: @"Contacts"])
//         {
//           roles = [[context activeUser]
//                     rolesForObject: [self lookupName: objectName
//                                           inContext: context
//                                           acquire: NO]
//                     inContext: context];
//           if ([roles containsObject: SOGoRole_Assistant]
//               || [roles containsObject: SOGoRole_Delegate])
//             role = SOGoRole_Assistant;
//         }
//       else if ([objectName isEqualToString: @"freebusy.ifb"])
//         role = SOGoRole_Assistant;
//     }

//   return role;
// }

/* WebDAV */

- (NSArray *) fetchContentObjectNames
{
  static NSArray *cos = nil;
  
  if (!cos)
    cos = [[NSArray alloc] initWithObjects: @"freebusy.ifb", nil];

  return cos;
}

- (BOOL) davIsCollection
{
  return YES;
}

/* CalDAV support */
- (NSArray *) davCalendarHomeSet
{
  /*
    <C:calendar-home-set xmlns:D="DAV:"
        xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:href>http://cal.example.com/home/bernard/calendars/</D:href>
    </C:calendar-home-set>

    Note: this is the *container* for calendar collections, not the
          collections itself. So for use its the home folder, the
	  public folder and the groups folder.
  */
  NSArray *tag;

  tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
                 [self baseURLInContext: context], nil];

  return [NSArray arrayWithObject: tag];
}

@end /* SOGoUserFolder */
