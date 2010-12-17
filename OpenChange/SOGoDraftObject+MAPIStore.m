/* SOGoDraftObject+MAPIStore.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext+SoObjects.h>

#import <NGExtensions/NSObject+Logs.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "MAPIStoreTypes.h"

#import "SOGoDraftObject+MAPIStore.h"

@implementation SOGoDraftObject (MAPIStoreMessage)

- (void) setMAPIProperties: (NSDictionary *) properties
{
  static NSString *recIds[] = { @"to", @"cc", @"bcc" };
  NSArray *list;
  NSDictionary *recipients, *identity;
  NSMutableDictionary *newHeaders;
  NSString *recId, *body;
  NSUInteger count;
  id value;

  newHeaders = [NSMutableDictionary dictionaryWithCapacity: 6];
  recipients = [properties objectForKey: @"recipients"];
  if (recipients)
    {
      for (count = 0; count < 3; count++)
	{
	  recId = recIds[count];
	  list = [recipients objectForKey: recId];
	  if ([list count] > 0)
	    [newHeaders setObject: [list objectsForKey: @"email"
					 notFoundMarker: nil]
			forKey: recId];
	}
    }
  else
    [self errorWithFormat: @"message without recipients"];

  /*
    message properties (20):
    recipients: {to = ({email = "wsourdeau@inverse.ca"; fullName = "wsourdeau@inverse.ca"; }); }
    0x1000001f (PR_BODY_UNICODE): text body (GSCBufferString)
    0x0037001f (PR_SUBJECT_UNICODE): Test without (GSCBufferString)
    0x30070040 (PR_CREATION_TIME): 2010-11-24 13:45:38 -0500 (NSCalendarDate)
e)
    2010-11-24 13:45:38.715 samba[25685]   0x0e62000b (PR_URL_COMP_NAME_SET):
    0 (NSIntNumber) */

  value = [properties
	    objectForKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
  if (!value)
  value = [properties objectForKey: MAPIPropertyKey (PR_SUBJECT_UNICODE)];
  if (value)
    [newHeaders setObject: value forKey: @"subject"];

  identity = [[context activeUser] primaryIdentity];
  [newHeaders setObject: [identity keysWithFormat: @"%{fullName} <%{email}>"]
	      forKey: @"from"];
  [self setHeaders: newHeaders];

  value = [properties objectForKey: MAPIPropertyKey (PR_HTML)];
  if (value)
    {
      [self setIsHTML: YES];
      // TODO: encoding
      body = [[NSString alloc] initWithData: value
			       encoding: NSUTF8StringEncoding];
      [self setText: body];
      [body release];
    }
  else
    {
      value = [properties objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
      if (value)
	{
	  [self setIsHTML: NO];
	  [self setText: value];
	}
    }
}

- (void) MAPISubmit
{
  [self logWithFormat: @"sending message"];
  [self sendMail];
}

- (void) MAPISave
{
  [self logWithFormat: @"saving message"];
  [self save];
}

@end
