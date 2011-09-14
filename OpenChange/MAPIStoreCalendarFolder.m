/* MAPIStoreCalendarFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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
#import <Foundation/NSURL.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <EOControl/EOQualifier.h>
#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoAppointmentObject.h>

#import "MAPIApplication.h"
#import "MAPIStoreCalendarContext.h"
#import "MAPIStoreCalendarMessage.h"
#import "MAPIStoreCalendarMessageTable.h"

#import "MAPIStoreCalendarFolder.h"

static Class MAPIStoreCalendarMessageK;

@implementation MAPIStoreCalendarFolder

+ (void) initialize
{
  MAPIStoreCalendarMessageK = [MAPIStoreCalendarMessage class];
}

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  SOGoUserFolder *userFolder;
  SOGoAppointmentFolders *parentFolder;
  WOContext *woContext;

  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      woContext = [newContext woContext];
      userFolder = [SOGoUserFolder objectWithName: [newURL user]
                                      inContainer: MAPIApp];
      [parentContainersBag addObject: userFolder];
      [woContext setClientObject: userFolder];

      parentFolder = [userFolder lookupName: @"Calendar"
                                  inContext: woContext
                                    acquire: NO];
      [parentContainersBag addObject: parentFolder];
      [woContext setClientObject: parentFolder];
      
      sogoObject = [parentFolder lookupName: @"personal"
                                  inContext: woContext
                                    acquire: NO];
      [sogoObject retain];
    }

  return self;
}

- (Class) messageClass
{
  return MAPIStoreCalendarMessageK;
}

- (MAPIStoreMessageTable *) messageTable
{
  [self synchroniseCache];
  return [MAPIStoreCalendarMessageTable tableForContainer: self];
}

- (EOQualifier *) componentQualifier
{
  static EOQualifier *componentQualifier = nil;

  if (!componentQualifier)
    componentQualifier
      = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
				operatorSelector: EOQualifierOperatorEqual
					   value: @"vevent"];

  return componentQualifier;
}

- (MAPIStoreMessage *) createMessageWithMID: (uint64_t) mid
{
  MAPIStoreMessage *newMessage;
  SOGoAppointmentObject *newEntry;
  NSString *name;

  name = [NSString stringWithFormat: @"%@.ics",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoAppointmentObject objectWithName: name
                                       inContainer: sogoObject];
  [newEntry setIsNew: YES];
  newMessage = [MAPIStoreCalendarMessage mapiStoreObjectWithSOGoObject: newEntry
                                                           inContainer: self];

  
  return newMessage;
}

@end
