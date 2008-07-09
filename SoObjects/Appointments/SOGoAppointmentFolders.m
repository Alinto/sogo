/* SOGoAppointmentFolders.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/NSException+HTTP.h>

#import "SOGoAppointmentFolder.h"

#import "SOGoAppointmentFolders.h"

@implementation SOGoAppointmentFolders

+ (NSString *) gcsFolderType
{
  return @"Appointment";
}

+ (Class) subFolderClass
{
  return [SOGoAppointmentFolder class];
}

- (NSString *) defaultFolderName
{
  return [self labelForKey: @"Personal Calendar"];
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id obj;
  WORequest *rq;

  obj = [super lookupName: name inContext: lookupContext acquire: NO];

  rq = [context request];
  if ([rq isSoWebDAVRequest]
      && [[rq method] isEqualToString: @"MKCALENDAR"])
    {
      if (obj)
	obj = [NSException exceptionWithHTTPStatus: 403];
      else
	{
	  obj = [self newFolderWithName: name andNameInContainer: name];
	  if (!obj)
	    obj = [super lookupName: name inContext: lookupContext acquire: NO];
	}
    }

  return obj;
}

- (id) doMKCALENDAR: (id) test
{
  return nil;
}

- (id) MKCALENDARAction: (id) localContext
{
  return nil;
}

#warning THIS CAUSES LIGHTNING TO FAIL (that is why its commented out)
// - (NSArray *) davComplianceClassesInContext: (id)_ctx
// {
//   NSMutableArray *classes;
//   NSArray *primaryClasses;

//   classes = [NSMutableArray new];
//   [classes autorelease];

//   primaryClasses = [super davComplianceClassesInContext: _ctx];
//   if (primaryClasses)
//     [classes addObjectsFromArray: primaryClasses];
//   [classes addObject: @"calendar-access"];
//   [classes addObject: @"calendar-schedule"];

//   return classes;
// }

// /* CalDAV support */
// - (NSArray *) davComplianceClassesInContext: (WOContext *) localContext
// {
//   NSMutableArray *newClasses;

//   newClasses
//     = [NSMutableArray arrayWithArray:
// 			[super davComplianceClassesInContext: localContext]];
//   [newClasses addObject: @"calendar-access"];

//   return newClasses;
// }

// - (NSArray *) davCalendarHomeSet
// {
//   /*
//     <C:calendar-home-set xmlns:D="DAV:"
//         xmlns:C="urn:ietf:params:xml:ns:caldav">
//       <D:href>http://cal.example.com/home/bernard/calendars/</D:href>
//     </C:calendar-home-set>

//     Note: this is the *container* for calendar collections, not the
//           collections itself. So for use its the home folder, the
// 	  public folder and the groups folder.
//   */
//   NSArray *tag;

//   tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
//                  [self davURL], nil];

//   return [NSArray arrayWithObject: tag];
// }

// - (NSArray *) davCalendarUserAddressSet
// {
//   NSArray *tag, *allEmails;
//   NSMutableArray *addresses;
//   NSEnumerator *emails;
//   NSString *currentEmail;

//   addresses = [NSMutableArray array];

//   allEmails = [[context activeUser] allEmails];
//   emails = [allEmails objectEnumerator];
//   while ((currentEmail = [emails nextObject]))
//     {
//       tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
// 		     [NSString stringWithFormat: @"mailto:%@", currentEmail],
// 		     nil];
//       [addresses addObject: tag];
//     }

//   return addresses;
// }

// - (NSArray *) davCalendarScheduleInboxURL
// {
//   NSArray *tag;

//   tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
//                  [NSString stringWithFormat: @"%@personal/", [self davURL]],
// 		 nil];

//   return [NSArray arrayWithObject: tag];
// }

// - (NSString *) davCalendarScheduleOutboxURL
// {
//   NSArray *tag;

//   tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
//                  [NSString stringWithFormat: @"%@personal/", [self davURL]],
// 		 nil];

//   return [NSArray arrayWithObject: tag];
// }

// - (NSString *) davDropboxHomeURL
// {
//   NSArray *tag;

//   tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
//                  [NSString stringWithFormat: @"%@personal/", [self davURL]],
// 		 nil];

//   return [NSArray arrayWithObject: tag];
// }

// - (NSString *) davNotificationsURL
// {
//   NSArray *tag;

//   tag = [NSArray arrayWithObjects: @"href", @"DAV:", @"D",
//                  [NSString stringWithFormat: @"%@personal/", [self davURL]],
// 		 nil];

//   return [NSArray arrayWithObject: tag];
// }

@end
