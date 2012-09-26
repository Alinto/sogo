/* MAPIStoreCalendarEmbeddedMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2012 Inverse inc
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

#include <talloc.h>

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/SOGoUser.h>
#import "iCalEvent+MAPIStore.h"

#import "MAPIStoreAppointmentWrapper.h"
#import "MAPIStoreCalendarAttachment.h"
#import "MAPIStoreContext.h"
#import "MAPIStoreUserContext.h"
#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"

#import "MAPIStoreCalendarEmbeddedMessage.h"

#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreCalendarEmbeddedMessage

- (id) initInContainer: (id) newContainer
{
  MAPIStoreContext *context;
  MAPIStoreUserContext *userContext;
  MAPIStoreAppointmentWrapper *appointmentWrapper;

  if ((self = [super initInContainer: newContainer]))
    {
      context = [self context];
      userContext = [self userContext];
      appointmentWrapper
        = [MAPIStoreAppointmentWrapper
                wrapperWithICalEvent: [newContainer event]
                             andUser: [userContext sogoUser]
                      andSenderEmail: nil
                          inTimeZone: [userContext timeZone]
                  withConnectionInfo: [context connectionInfo]];
      [self addProxy: appointmentWrapper];
    }

  return self;
}

- (NSDate *) creationTime
{
  return [[container event] created];
}

- (NSDate *) lastModificationTime
{
  return [[container event] lastModified];
}

- (void) getMessageData: (struct mapistore_message **) dataPtr
               inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapistore_message *msgData;

  [super getMessageData: &msgData inMemCtx: memCtx];

  /* HACK: we know the first (and only) proxy is our appointment wrapper
     instance, but this might not always be true */
  [[proxies objectAtIndex: 0] fillMessageData: msgData
                                     inMemCtx: memCtx];
  *dataPtr = msgData;
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.OLE.CLASS.{00061055-0000-0000-C000-000000000046}");

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMessageFlags: (void **) data // TODO
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, MSGFLAG_UNMODIFIED);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagProcessed: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagResponseRequested: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

/* discarded properties */

- (int) getPidLidAppointmentLastSequence: (void **)
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidMeetingWorkspaceUrl: (void **)
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidContacts: (void **)
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidTagSensitivity: (void **)
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidPrivate: (void **)
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidNameKeywords: (void **)
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return MAPISTORE_ERR_NOT_FOUND;
}

- (int) getPidLidFExceptionalBody: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (void) save
{
// (gdb) po embeddedMessage->properties
// 2442592320 = "2012-07-11 22:30:00 +0000";
// 2448359488 = "2012-07-11 22:30:00 +0000";
// 2442723392 = "2012-07-11 22:30:00 +0000";
// 2442068032 = "2012-07-11 22:30:00 +0000";
// 2441740352 = "2012-07-11 23:00:00 +0000";
//  131083 = 1; 2442330115 = 2;
// 235339779 = 9;
// 6291520 = "2012-07-11 16:00:00 +0000";
// 2442526784 = "2012-07-11 23:00:00 +0000";
// 2818059 = 0;
// 1703967 = "IPM.OLE.CLASS.{00061055-0000-0000-C000-000000000046}";
//  3538947 = 0;
// 1071513603 = 28591; 805830720 = "2012-07-10 16:42:00 +0000";
//  2485977346 = <02013000 02001500 45006100 73007400
// 65007200 6e002000 53007400 61006e00 64006100 72006400 20005400 69006d00
// 65000200 02013e00 0000d607 00000000 00000000 00000000 00002c01 00000000
// 0000c4ff ffff0000 0a000000 05000200 00000000 00000000 04000000 01000200
// 00000000 00000201 3e000200 d7070000 00000000 00000000 00000000 2c010000
// 00000000 c4ffffff 00000b00 00000100 02000000 00000000 00000300 00000200
// 02000000 00000000>; 2454257728 = "2012-07-11 16:00:00 +0000"; 2442985475 =
// 118330; 1507331 = 1; 805765184 = "2012-07-09 18:32:00 +0000"; 2442657856 =
// "2012-07-11 23:00:00 +0000"; 2443051039 = "11.0"; 236912651 = 1; 2485911810 =
// <02013000 02001500 45006100 73007400 65007200 6e002000 53007400 61006e00
// 64006100 72006400 20005400 69006d00 65000200 02013e00 0000d607 00000000
// 00000000 00000000 00002c01 00000000 0000c4ff ffff0000 0a000000 05000200
// 00000000 00000000 04000000 01000200 00000000 00000201 3e000200 d7070000
// 00000000 00000000 00000000 2c010000 00000000 c4ffffff 00000b00 00000100
// 02000000 00000000 00000300 00000200 02000000 00000000>; 2441543683 = 30;
// 2442068032 = "2012-07-11 22:30:00 +0000";
// 1073348639 = "OpenChange User";
// 806027522 = <2d64f6f5 89a59243 992d29d1 49173b3a>; 6357056 = "2012-07-11
// 16:30:00 +0000"; 
//   */

// // 0x92490040 = 2454257728

// }

  SOGoUser *activeUser;

  activeUser = [[self context] activeUser];

  [[container event] updateFromMAPIProperties: properties
                                inUserContext: [self userContext]
                               withActiveUser: activeUser];
}

@end
