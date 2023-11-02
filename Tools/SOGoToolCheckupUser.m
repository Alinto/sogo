/* SOGoToolCheckup.m - this file is part of SOGo
 *
 * Copyright (C) 2017-2020 Inverse inc.
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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>

#import <GDLAccess/EOAdaptorChannel.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/NSURL+GCS.h>

#import <SOGo/SOGoUserManager.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/NGVCard.h>

#import "SOGoTool.h"

@interface SOGoToolCheckup : SOGoTool
{
  NSArray *usersToCheckup;
  BOOL delete;
}

@end

@implementation SOGoToolCheckup

+ (NSString *) command
{
  return @"checkup";
}

+ (NSString *) description
{
  return @"checkup integrity of user(s) data";
}

- (id) init
{
  if ((self = [super init]))
    {
      usersToCheckup = nil;
      delete = NO;
    }

  return self;
}

- (void) dealloc
{
  [usersToCheckup release];
  [super dealloc];
}

- (void) usage
{
  fprintf (stderr, "checkup [-d] user...\n\n"
	   "           -d         delete the corrupted records\n"
           "           user       the user to check the records or ALL for everybody\n\n"
           "Example:   sogo-tool checkup jdoe\n");
}

- (BOOL) fetchUserIDs: (NSArray *) users
{
  NSAutoreleasePool *pool;
  SOGoUserManager *lm;
  NSDictionary *infos;
  NSString *user;
  id allUsers;
  int count, max;

  lm = [SOGoUserManager sharedUserManager];

  max = [users count];
  user = [users objectAtIndex: 0];
  if (max == 1 && [user isEqualToString: @"ALL"])
    {
      GCSFolderManager *fm;
      GCSChannelManager *cm;
      NSURL *folderLocation;
      EOAdaptorChannel *fc;
      NSArray *attrs;
      NSMutableArray *allSqlUsers;
      NSString *sql;

      fm = [GCSFolderManager defaultFolderManager];
      cm = [fm channelManager];
      folderLocation = [fm folderInfoLocation];
      fc = [cm acquireOpenChannelForURL: folderLocation];
      if (fc)
        {
          allSqlUsers = [NSMutableArray new];
          sql = [NSString stringWithFormat: @"SELECT DISTINCT c_path2 FROM %@",
                          [folderLocation gcsTableName]];
          [fc evaluateExpressionX: sql];
          attrs = [fc describeResults: NO];
          while ((infos = [fc fetchAttributes: attrs withZone: NULL]))
            {
              user = [infos objectForKey: @"c_path2"];
              if (user)
                [allSqlUsers addObject: user];
            }
          [cm releaseChannel: fc  immediately: YES];

          users = allSqlUsers;
          max = [users count];
          [allSqlUsers autorelease];
        }
    }

  pool = [[NSAutoreleasePool alloc] init];
  allUsers = [NSMutableArray new];
  for (count = 0; count < max; count++)
    {
      if (count > 0 && count%100 == 0)
        {
          DESTROY(pool);
          pool = [[NSAutoreleasePool alloc] init];
        }

      user = [users objectAtIndex: count];
      infos = [lm contactInfosForUserWithUIDorEmail: user];
      if (infos)
        [allUsers addObject: infos];
      else
        {
          // We haven't found the user based on the GCS table name
          // Let's try to strip the domain part and search again.
          // This can happen when using SOGoEnableDomainBasedUID (YES)
          // but login in SOGo using a UID without domain (DomainLessLogin gets set)
          NSRange r;

          r = [user rangeOfString: @"@"];

          if (r.location != NSNotFound)
            {
              user = [user substringToIndex: r.location];
              infos = [lm contactInfosForUserWithUIDorEmail: user];
              if (infos)
                [allUsers addObject: infos];
              else
                NSLog (@"user '%@' unknown", user);
            }
          else
            NSLog (@"user '%@' unknown", user);
        }
    }
  [allUsers autorelease];

  ASSIGN (usersToCheckup, allUsers);
  DESTROY(pool);

  return ([usersToCheckup count] > 0);
}

- (BOOL) parseArguments
{
  BOOL rc;
  int max;

  max = [arguments count];
  if (max > 0)
    {
      delete = [[arguments objectAtIndex: 0] isEqualToString: @"-d"];

      if (delete && max > 1)
	arguments = RETAIN([arguments subarrayWithRange: NSMakeRange(1, max-1)]);

      rc = [self fetchUserIDs: arguments];
    }
  else
    {
      [self usage];
      rc = NO;
    }

  return rc;
}

- (BOOL) checkupFolder: (NSString *) folder
                withFM: (GCSFolderManager *) fm
{
  NSString *content, *c_name;
  GCSFolder *gcsFolder;
  NSArray *objects;

  unsigned int i, count;
  BOOL rc, is_calendar;
  
  gcsFolder = [fm folderAtPath: folder];
  is_calendar = ([[gcsFolder folderTypeName] caseInsensitiveCompare: @"Appointment"] == NSOrderedSame);
  objects = [gcsFolder fetchFields: [NSArray arrayWithObjects: @"c_name", @"c_content", nil]  fetchSpecification: nil];
  count = [objects count];

  for (i = 0; i < count; i++)
  {
    content = [[[objects objectAtIndex: i] objectForKey: @"c_content"] stringByTrimmingSpaces];
    c_name = [[objects objectAtIndex: i] objectForKey: @"c_name"];
    if (is_calendar)
	  {
	    // We check for
	    // BEGIN:VCALENDAR
	    // ..
	    // END:VCALENDAR
	    iCalCalendar *calendar;
	      
	    if ([content length] < 30 ||
	      [[content substringToIndex: 15] caseInsensitiveCompare: @"BEGIN:VCALENDAR"] != NSOrderedSame ||
	      [[content substringFromIndex: [content length]-13] caseInsensitiveCompare: @"END:VCALENDAR"] != NSOrderedSame)
	    {
	      NSLog(@"Corrupted calendar item (missing tags) in path %@ with c_name = %@", folder, c_name);
	      if (delete)
		      [gcsFolder deleteContentWithName: c_name];
	      rc = NO;
	    }
	    else
	    {
	      calendar = [iCalCalendar parseSingleFromSource: content];
	      if (!calendar)
		    {
		      NSLog(@"Corrupted calendar item (unparsable) in path %@ with c_name = %@", folder, c_name);
		      if (delete)
		        [gcsFolder deleteContentWithName: c_name];
		      rc = NO;
		    }
        else
        {
          iCalEvent *event;

          event = (iCalEvent *) [calendar firstChildWithTag: @"vevent"];
          if (event)
          {
            iCalDateTime *startDate, *endDate;

            startDate = (iCalDateTime *) [event uniqueChildWithTag: @"dtstart"];
            if (![startDate dateTime])
            {
              NSLog(@"Missing start date of event in path %@ with c_name = %@ (%@)", folder, c_name, [event summary]);
              if (delete)
                [gcsFolder deleteContentWithName: c_name];
              rc = NO;
            }
            endDate = (iCalDateTime *) [event uniqueChildWithTag: @"dtend"];
            if (![endDate dateTime] && ![event hasDuration])
            {
              NSLog(@"Missing end date of event in path %@ with c_name = %@ (%@)", folder, c_name, [event summary]);
              if (delete)
                [gcsFolder deleteContentWithName: c_name];
              rc = NO;
            }
            if ([startDate dateTime] && [endDate dateTime])
            {
              NSComparisonResult comparison;

              comparison = [[startDate dateTime] compare: [endDate dateTime]];
              if (([event isAllDay] && comparison == NSOrderedDescending) ||
                  (![event isAllDay] && comparison != NSOrderedAscending))
              {
                NSLog(@"Start date (%@) is not before end date (%@) for event in path %@ with c_name = %@ (%@)",
                      [startDate dateTime], [endDate dateTime], folder, c_name, [event summary]);
                if (delete)
                  [gcsFolder deleteContentWithName: c_name];
                rc = NO;
              }
            }
          }
        }
	    }
	  }
    else
	  {
	    NGVCard *card;

	    card = [NGVCard parseSingleFromSource: content];

	    if (!card)
	    {
	      NSLog(@"Corrupted card item (unparsable) in path %@ with c_name = %@", folder, c_name);
	      if (delete)
		      [gcsFolder deleteContentWithName: c_name];
	      rc = NO;
	    }
	  }
  }

  return rc;
}

- (BOOL) checkupUserFolders: (NSString *) uid
{
  GCSFolderManager *fm;
  NSArray *folders;
  int count, max;
  NSString *basePath, *folder;

  NSLog(@"Checking folders of user %@", uid);
  fm = [GCSFolderManager defaultFolderManager];
  basePath = [NSString stringWithFormat: @"/Users/%@", uid];
  folders = [fm listSubFoldersAtPath: basePath recursive: YES];
  max = [folders count];
  for (count = 0; count < max; count++)
    {
      folder = [NSString stringWithFormat: @"%@/%@", basePath, [folders objectAtIndex: count]];
      [self checkupFolder: folder withFM: fm];
    }

  return YES;
}

- (BOOL) checkupUser: (NSDictionary *) theUser
{
  NSString *gcsUID, *domain;
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  domain = [theUser objectForKey: @"c_domain"];
  gcsUID = [theUser objectForKey: @"c_uid"];

  if ([sd enableDomainBasedUID] && [gcsUID rangeOfString: @"@"].location == NSNotFound)
    gcsUID = [NSString stringWithFormat: @"%@@%@", gcsUID, domain];

  return [self checkupUserFolders: gcsUID];
}

- (BOOL) proceed
{
  NSAutoreleasePool *pool;
  int count, max;
  BOOL rc;

  rc = YES;

  pool = [NSAutoreleasePool new];

  max = [usersToCheckup count];
  for (count = 0; rc && count < max; count++)
    {
      rc = [self checkupUser: [usersToCheckup objectAtIndex: count]];
      if ((count % 10) == 0)
        [pool emptyPool];
    }

  [pool release];

  return rc;
}

- (BOOL) run
{
  return ([self parseArguments] && [self proceed]);
}

@end
