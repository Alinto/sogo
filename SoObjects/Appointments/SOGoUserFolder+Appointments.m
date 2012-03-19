/* SOGoUserFolder+Appointments.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSString+DAV.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/WORequest+SOGo.h>

#import "SOGoAppointmentFolders.h"
#import "SOGoUserFolder+Appointments.h"

@interface SOGoUserFolder (private)

- (SOGoAppointmentFolders *) privateCalendars: (NSString *) key
				    inContext: (WOContext *) localContext;

@end

@implementation SOGoUserFolder (SOGoCalDAVSupport)

- (NSArray *) davCalendarUserAddressSet
{
  NSArray *tag;
  NSMutableArray *addresses;
  NSEnumerator *emails;
  NSMutableDictionary *doneEmails;
  NSString *currentEmail;
  SOGoUser *ownerUser;

  addresses = [NSMutableArray array];

  doneEmails = [NSMutableDictionary dictionary];
  ownerUser = [SOGoUser userWithLogin: owner];
  emails = [[ownerUser allEmails] objectEnumerator];
  while ((currentEmail = [emails nextObject]))
    {
      if (![doneEmails objectForKey: currentEmail])
        {
          tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                         [NSString stringWithFormat: @"mailto:%@", currentEmail],
                         nil];
          [addresses addObject: tag];
          [doneEmails setObject: [NSNull null] forKey: currentEmail];
        }
    }

  tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                 [NSString stringWithFormat: @"/SOGo/dav/%@/", nameInContainer],
                 nil];
  [addresses addObjectUniquely: tag];

  return addresses;
}

- (NSString *) davCalendarUserType
{
  /* FIXME: not always true */
  return @"INDIVIDUAL";
}

- (NSArray *) davEmailAddressSet
{
  NSArray *tag;
  NSMutableArray *addresses;
  NSEnumerator *emails;
  NSMutableDictionary *doneEmails;
  NSString *currentEmail;
  SOGoUser *ownerUser;

  addresses = [NSMutableArray array];

  doneEmails = [NSMutableDictionary dictionary];
  ownerUser = [SOGoUser userWithLogin: owner];
  emails = [[ownerUser allEmails] objectEnumerator];
  while ((currentEmail = [emails nextObject]))
    {
      if (![doneEmails objectForKey: currentEmail])
        {
          tag = [NSArray arrayWithObjects: @"email-address", XMLNS_CalendarServerOrg, @"cso",
                         [NSString stringWithFormat: @"%@", currentEmail],
                         nil];
          [addresses addObject: tag];
          [doneEmails setObject: [NSNull null] forKey: currentEmail];
        }
    }

  tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                 [NSString stringWithFormat: @"/SOGo/dav/%@/", nameInContainer],
                 nil];
  [addresses addObjectUniquely: tag];

  return addresses;
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
  SOGoAppointmentFolders *parent;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                 [parent davURLAsString], nil];

  return [NSArray arrayWithObject: tag];
}

- (NSArray *) _davSpecialCalendarURLWithName: (NSString *) name
{
  SOGoAppointmentFolders *parent;
  NSArray *tag, *response;
  NSString *parentURL;

  // We do NOT return the schedule-inbox-URL to iCal clients
  // if the current user isn't the owner of it. This is to prevent
  // iCal from doing a PROPFIND on it later on since it'll
  // ask for the schedule-inbox-URL.
  if ([[context request] isICal] && 
      [name isEqualToString: @"inbox"] &&
      ![owner isEqualToString: [[context activeUser] login]])
    return nil;

  parent = [self privateCalendars: @"Calendar" inContext: context];
  parentURL = [parent davURLAsString];
  tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                 [NSString stringWithFormat: @"%@%@/", parentURL, name],
                 nil];
  response = [NSArray arrayWithObject: tag];

  return response;
}

- (NSArray *) davCalendarScheduleInboxURL
{
  return [self _davSpecialCalendarURLWithName: @"inbox"];
}

- (NSArray *) davCalendarScheduleOutboxURL
{
  return [self _davSpecialCalendarURLWithName: @"personal"];
}

- (NSArray *) _calendarProxiedUsersWithWriteAccess: (BOOL) write
{
  NSMutableDictionary *proxiedUsers;
  NSArray *references, *elements;
  NSString *currentLogin;
  NSNumber *yesNumber;
  SOGoAppointmentFolders *parentFolder;
  SOGoUserSettings *us;
  int count, max;

  yesNumber = [NSNumber numberWithBool: YES];

  us = [[SOGoUser userWithLogin: owner] userSettings];
  references = [us subscribedCalendars];
  max = [references count];
  proxiedUsers = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      elements = [[references objectAtIndex: count]
                    componentsSeparatedByString: @":"];
      if ([elements count])
        {
          currentLogin = [elements objectAtIndex: 0];
          if (![proxiedUsers objectForKey: currentLogin])
            {
              parentFolder = [[container lookupName: currentLogin
                                          inContext: context
                                            acquire: NO]
                               lookupName: @"Calendar"
                                inContext: context acquire: NO];
              if ([parentFolder hasProxyCalendarsWithWriteAccess: write
                                                forUserWithLogin: owner])
                [proxiedUsers setObject: yesNumber forKey: currentLogin];
            }
        }
    }

  return [proxiedUsers allKeys];
}

- (void) _addGroupMembershipToArray: (NSMutableArray *) groups
                     forWriteAccess: (BOOL) write
{
  NSArray *proxiedUsers, *tag;
  NSString *appName, *groupId, *proxiedUser;
  int count, max;

  proxiedUsers = [self _calendarProxiedUsersWithWriteAccess: write];
  max = [proxiedUsers count];
  if (max)
    {
      appName = [[context request] applicationName];
      groupId = [NSString stringWithFormat: @"calendar-proxy-%@",
                        (write ? @"write" : @"read")];
      for (count = 0; count < max; count++)
        {
          proxiedUser = [proxiedUsers objectAtIndex: count];
          tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                         [NSString stringWithFormat: @"/%@/dav/%@/%@/",
                                   appName, proxiedUser, groupId],
                     nil];
          [groups addObject: tag];
        }
    }
}

- (NSArray *) davGroupMembership
{
  NSMutableArray *groups;

  groups = [NSMutableArray array];

  [self _addGroupMembershipToArray: groups
                    forWriteAccess: YES];
  [self _addGroupMembershipToArray: groups
                    forWriteAccess: NO];

  return groups;
}

- (NSMutableArray *) _davCalendarProxyForWrite: (BOOL) write
{
  NSMutableArray *proxyFor;
  NSArray *proxiedUsers, *tag;
  NSString *appName, *proxiedUser;
  int count, max;

  appName = [[context request] applicationName];

  proxiedUsers = [self _calendarProxiedUsersWithWriteAccess: write];
  max = [proxiedUsers count];
  proxyFor = [NSMutableArray arrayWithCapacity: max];
  if (max)
    {
      for (count = 0; count < max; count++)
        {
          proxiedUser = [proxiedUsers objectAtIndex: count];
          tag = [NSArray arrayWithObjects: @"href", XMLNS_WEBDAV, @"D",
                         [NSString stringWithFormat: @"/%@/dav/%@/",
                                   appName, proxiedUser],
                     nil];
          [proxyFor addObject: tag];
        }
    }

  return proxyFor;
}

- (NSArray *) davCalendarProxyWriteFor
{
  return [self _davCalendarProxyForWrite: YES];
}

- (NSArray *) davCalendarProxyReadFor
{
  return [self _davCalendarProxyForWrite: NO];
}

@end
