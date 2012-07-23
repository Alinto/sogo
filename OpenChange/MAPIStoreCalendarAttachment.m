/* MAPIStoreCalendarAttachment.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>

#import "iCalEvent+MAPIStore.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreCalendarEmbeddedMessage.h"

#import "MAPIStoreCalendarAttachment.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreCalendarAttachment

- (id) init
{
  if ((self = [super init]))
    {
      event = nil;
    }

  return self;
}

- (void) dealloc
{
  [event release];
  [super dealloc];
}

- (void) setEvent: (iCalEvent *) newEvent
{
  ASSIGN (event, newEvent);
}

- (iCalEvent *) event
{
  return event;
}

- (int) getPidTagAttachmentHidden: (void **) data
                         inMemCtx: (TALLOC_CTX *) localMemCtx
{
  *data = MAPIBoolValue (localMemCtx, YES);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachmentFlags: (void **) data
                        inMemCtx: (TALLOC_CTX *) localMemCtx
{
  *data = MAPILongValue (localMemCtx, 0x00000002); /* afException */

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAttachMethod: (void **) data
                     inMemCtx: (TALLOC_CTX *) localMemCtx
{
  *data = MAPILongValue (localMemCtx, afEmbeddedMessage);

  return MAPISTORE_SUCCESS;
}

// case PidTagExceptionStartTime:
// case PidTagExceptionEndTime:
// case PidTagExceptionReplaceTime:

/* subclasses */
- (MAPIStoreCalendarEmbeddedMessage *) openEmbeddedMessage
{
  MAPIStoreCalendarEmbeddedMessage *msg;

  msg = [MAPIStoreCalendarEmbeddedMessage
          mapiStoreObjectInContainer: self];

  return msg;
}

- (MAPIStoreCalendarEmbeddedMessage *) createEmbeddedMessage
{
  MAPIStoreCalendarEmbeddedMessage *msg;

  msg = [self openEmbeddedMessage];
  [msg setIsNew: YES];

  return msg;
}

@end
