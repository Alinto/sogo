/* UIxCalendarSelector.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
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

#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserSettings.h>

#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoWebAppointmentFolder.h>

#import "UIxCalendarSelector.h"

static inline unsigned int
_intValueFromHexChar (unichar hexChar)
{
  unichar base;

  if (hexChar >= '0' && hexChar <= '9')
    base = '0';
  else if (hexChar >= 'A' && hexChar <= 'F')
    base = 'A' - 10;
  else
    base = 'a' - 10;

  return (hexChar - base);
}

static inline unsigned int
_intValueFromHex (NSString *hexString)
{
  unsigned int value, count, max;

  value = 0;
  max = [hexString length];
  for (count = 0; count < max; count++)
    value = (value * 16
	     + _intValueFromHexChar([hexString characterAtIndex: count]));

  return value;
}

@implementation UIxCalendarSelector

- (id) init
{
  if ((self = [super init]))
    {
      calendars = nil;
      currentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [calendars release];
  [currentCalendar release];
  [super dealloc];
}

- (BOOL) isPublicAccessEnabled
{
  return [[SOGoSystemDefaults sharedSystemDefaults] enablePublicAccess];
}

- (NSArray *) calendars
{
  BOOL objectCreator, objectEraser, reloadOnLogin, synchronize, dirty;
  NSArray *folders, *allACLs;
  NSMutableArray *sortedFolders, *sortedFolderNames;
  NSMutableDictionary *moduleSettings, *calendar, *notifications, *urls, *acls;
  NSNumber *isActive, *fActiveTasks;
  NSString *userLogin, *folderName, *fDisplayName, *owner;
  NSInteger count, index, max;
  SOGoAppointmentFolder *folder;
  SOGoAppointmentFolders *co;
  SOGoUser *activeUser;
  SOGoUserSettings *us;

  if (!calendars)
    {
      co = [self clientObject];
      activeUser = [context activeUser];
      userLogin = [activeUser login];
      folders = [co subFolders];

      // Sort calendars according to user settings
      dirty = NO;
      us = [activeUser userSettings];
      moduleSettings = [us objectForKey: [co nameInContainer]];
      sortedFolders = [NSMutableArray arrayWithArray: [moduleSettings objectForKey: @"FoldersOrder"]];

      // We first start by replacing folder names with actual SOGoFolder instances
      max = [folders count];
      for (count = 0; count < max; count++)
        {
          folder = [folders objectAtIndex: count];
          folderName = [folder nameInContainer];
          index = [sortedFolders indexOfObject: folderName];
          if (index == NSNotFound)
            {
              // Calendar is missing from user's "FoldersOrder" setting; add it
              dirty = YES;
              [sortedFolders addObject: folder];
            }
          else
            [sortedFolders replaceObjectAtIndex: index withObject: folder];
        }

      // We then build our sorted folder list names, removing any deleted folders
      max = [sortedFolders count];
      sortedFolderNames = [NSMutableArray arrayWithCapacity: max];
      for (count = max-1; count >= 0; count--)
        {
          if ([[sortedFolders objectAtIndex: count] isKindOfClass: [NSString class]])
            {
              // Calendar no longer exists; remove it from user's "FoldersOrder" setting
              dirty = YES;
              [sortedFolders removeObjectAtIndex: count];
            }
          else
            {
              folder = [sortedFolders objectAtIndex: count];
              folderName = [folder nameInContainer];
              if (folderName)
                [sortedFolderNames addObject: folderName];
              else
                [self errorWithFormat: @"Unexpected entry in FoldersOrder setting: %@", folder];
            }
        }

      if (dirty)
        {
          // Synchronize user's settings
          [moduleSettings setObject: sortedFolderNames forKey: @"FoldersOrder"];
          [us synchronize];
        }

      max = [folders count];

      DESTROY(calendars);
      calendars = [[NSMutableArray alloc] initWithCapacity: max];

      for (count = 0; count < max; count++)
        {
          folder = [sortedFolders objectAtIndex: count];
          owner = [folder ownerInContext: context];
          calendar = [NSMutableDictionary dictionary];
          folderName = [folder nameInContainer];
          fDisplayName = [folder displayName];
          if (fDisplayName == nil)
            fDisplayName = @"";
          if ([fDisplayName isEqualToString: [co defaultFolderName]])
            fDisplayName = [self labelForKey: fDisplayName];
          fActiveTasks = [folder activeTasks];

          [calendar setObject: folderName forKey: @"id"];
          [calendar setObject: fDisplayName forKey: @"name"];
          [calendar setObject: [folder calendarColor] forKey: @"color"];
          isActive = [NSNumber numberWithBool: [folder isActive]];
          [calendar setObject: isActive forKey: @"active"];
          [calendar setObject: owner forKey: @"owner"];
          [calendar setObject: [NSNumber numberWithBool: [folder isWebCalendar]] forKey: @"isWebCalendar"];
          if (fActiveTasks > 0)
            [calendar setObject: fActiveTasks forKey:@"activeTasks" ];
          [calendar setObject: [NSNumber numberWithBool: [folder includeInFreeBusy]] forKey: @"includeInFreeBusy"];
          [calendar setObject: [NSNumber numberWithBool: [folder showCalendarAlarms]] forKey: @"showCalendarAlarms"];
          [calendar setObject: [NSNumber numberWithBool: [folder showCalendarTasks]] forKey: @"showCalendarTasks"];

          // We extract ACLs for this address book
          allACLs = ([owner isEqualToString: userLogin] ? nil : [folder aclsForUser: userLogin]);
          objectCreator = ([owner isEqualToString: userLogin] || [allACLs containsObject: SOGoRole_ObjectCreator]);
          objectEraser = ([owner isEqualToString: userLogin] || [allACLs containsObject: SOGoRole_ObjectEraser]);
          acls = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: objectCreator], @"objectCreator",
                                   [NSNumber numberWithBool: objectEraser], @"objectEraser", nil];


          if ([folder isKindOfClass: [SOGoWebAppointmentFolder class]])
            objectCreator = objectEraser = synchronize = NO;
          else
            synchronize = [folder synchronize];

          [calendar setObject: acls  forKey: @"acls"];

          if ([[folder nameInContainer] isEqualToString: @"personal"])
            synchronize = YES;

          [calendar setObject: [NSNumber numberWithBool: synchronize] forKey: @"synchronize"];

          if ([folder isWebCalendar])
            {
              urls = [NSMutableDictionary dictionaryWithObject: [folder folderPropertyValueInCategory: @"WebCalendars"]
                                                        forKey: @"webCalendarURL"];
              if ([folder respondsToSelector: @selector (reloadOnLogin)])
                reloadOnLogin = [(SOGoWebAppointmentFolder *) folder reloadOnLogin];
              else
                reloadOnLogin = NO;
              [calendar setObject: [NSNumber numberWithBool: reloadOnLogin] forKey: @"reloadOnLogin"];
            }
          else
            {
              urls = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                            [folder calDavURL], @"calDavURL",
                                          [folder webDavICSURL], @"webDavICSURL",
                                          [folder webDavXMLURL], @"webDavXMLURL",
                                          nil];
              if ([self isPublicAccessEnabled])
                {
                  [urls setObject: [folder publicCalDavURL] forKey: @"publicCalDavURL"];
                  [urls setObject: [folder publicWebDavICSURL] forKey: @"publicWebDavICSURL"];
                  [urls setObject: [folder publicWebDavXMLURL] forKey: @"publicWebDavXMLURL"];
                }
            }
          [calendar setObject: urls forKey: @"urls"];

          if ([userLogin isEqualToString: [folder ownerInContext: context]])
            {
              notifications = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool: [folder notifyOnPersonalModifications]],
                                                   @"notifyOnPersonalModifications",
                                                       [NSNumber numberWithBool: [folder notifyOnExternalModifications]],
                                                   @"notifyOnExternalModifications",
                                                       [NSNumber numberWithBool: [folder notifyUserOnPersonalModifications]],
                                                   @"notifyUserOnPersonalModifications",
                                                   nil];
              if ([folder notifiedUserOnPersonalModifications])
                [calendar setObject: [folder notifiedUserOnPersonalModifications] forKey: @"notifiedUserOnPersonalModifications"];
              [calendar setObject: notifications forKey: @"notifications"];
            }

          [calendars addObject: calendar];
        }
    }

  return calendars;
}

- (void) setCurrentCalendar: (NSDictionary *) newCalendar
{
  ASSIGN (currentCalendar, newCalendar);
}

- (NSDictionary *) currentCalendar
{
  return currentCalendar;
}

- (NSString *) currentCalendarClass
{
  return [currentCalendar
	   keysWithFormat: @"colorBox calendarFolder%{folder}"];
}

- (NSString *) currentCalendarStyle
{
  return [currentCalendar
	   keysWithFormat: @"color: %{color}; background-color: %{color};"];
}

/* code taken from Lightning 0.7 */
- (NSString *) contrastingTextColor
{
  NSString *bgColor;
  unsigned int red, green, blue;
  float brightness;

  bgColor = [[currentCalendar objectForKey: @"color"] substringFromIndex: 1];
  red = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (0, 2)]);
  green = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (2, 2)]);
  blue = _intValueFromHex ([bgColor substringFromRange: NSMakeRange (4, 2)]);
  brightness = (0.299 * red) + (0.587 * green) + (0.114 * blue);

  return ((brightness < 144) ? @"white" : @"black");
}

/**
 * @api {get} /so/:username/Calendar/calendarslist Get calendars
 * @apiVersion 1.0.0
 * @apiName GetCalendarsList
 * @apiGroup Calendar
 * @apiExample {curl} Example usage:
 *     curl -i http://localhost/SOGo/so/sogo1/Calendar/calendarslist
 *
 * @apiSuccess (Success 200) {Object[]} calendars                   List of calendars
 * @apiSuccess (Success 200) {String} calendars.id                  Calendar ID
 * @apiSuccess (Success 200) {String} calendars.name                Human readable name
 * @apiSuccess (Success 200) {String} calendars.owner               User ID of owner
 * @apiSuccess (Success 200) {String} calendars.color               Calendar's hex color code
 * @apiSuccess (Success 200) {Number} calendars.active              1 if the calendar is enabled
 * @apiSuccess (Success 200) {Number} [calendars.activeTasks]       Number of incompleted tasks
 * @apiSuccess (Success 200) {Number} calendars.includeInFreeBusy   1 if calendar must be include in freebusy
 * @apiSuccess (Success 200) {Number} calendars.showCalendarAlarms  1 if alarms must be enabled
 * @apiSuccess (Success 200) {Number} calendars.showCalendarTasks   1 if tasks must be enabled
 * @apiSuccess (Success 200) {Number} calendars.isWebCalendar       1 if calendar is a read-only external WebDAV calendar
 * @apiSuccess (Success 200) {Number} calendars.reloadOnLogin       1 if calendar is a Web calendar that must be reload when user logins
 * @apiSuccess (Success 200) {Object} [calendars.notifications]     Notification (if active user is the calendar's owner)
 * @apiSuccess (Success 200) {Number} calendars.notifications.notifyOnPersonalModifications 1 if a mail is sent for each modification made by the owner
 * @apiSuccess (Success 200) {Number} calendars.notifications.notifyOnExternalModifications 1 if a mail is sent for each modification made by someone else
 * @apiSuccess (Success 200) {Number} calendars.notifications.notifyUserOnPersonalModifications 1 if a mail is sent to an external address for modification made by the owner
 * @apiSuccess (Success 200) {String} [calendars.notifications.notifiedUserOnPersonalModifications] Email address to notify changes
 * @apiSuccess (Success 200) {Object[]} urls                        URLs to this calendar
 * @apiSuccess (Success 200) {String} [urls.calDavURL]              CalDAV URL
 * @apiSuccess (Success 200) {String} [urls.webDavXMLURL]           WebDAV XML URL
 * @apiSuccess (Success 200) {String} [urls.webDavICSURL]           WebDAV ICS URL
 * @apiSuccess (Success 200) {String} [urls.publicWebDavXMLURL]     Public WebDAV XML URL
 * @apiSuccess (Success 200) {String} [urls.publicWebDavICSURL      Public WebDAV ICS URL
 * @apiSuccess (Success 200) {String} [urls.publicCalDavURL]        Public CalDAV URL
 * @apiSuccess (Success 200) {String} [urls.webCalendarURL]         External WebDAV ICS URL
 */
- (WOResponse *) calendarsListAction
{
  NSDictionary *data;
  WOResponse *response;

  data = [NSDictionary dictionaryWithObject: [self calendars]
                                     forKey: @"calendars"];
  response = [self responseWithStatus: 200 andJSONRepresentation: data];

  return response;
}

@end /* UIxCalendarSelector */
