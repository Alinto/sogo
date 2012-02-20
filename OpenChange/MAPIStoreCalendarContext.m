/* MAPIStoreCalendarContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSString.h>
#import <Appointments/SOGoAppointmentFolders.h>

#import "MAPIStoreMapping.h"
#import "MAPIStoreCalendarFolder.h"
#import "MAPIStoreUserContext.h"

#import "MAPIStoreCalendarContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class MAPIStoreCalendarFolderK;

@implementation MAPIStoreCalendarContext

+ (void) initialize
{
  MAPIStoreCalendarFolderK = [MAPIStoreCalendarFolder class];
}

+ (NSString *) MAPIModuleName
{
  return @"calendar";
}

+ (enum mapistore_context_role) MAPIContextRole
{
  return MAPISTORE_CALENDAR_ROLE;
}

- (Class) MAPIStoreFolderClass
{
  return MAPIStoreCalendarFolderK;
}

+ (NSString *) folderNameSuffix
{
  return @"c";
}

@end
