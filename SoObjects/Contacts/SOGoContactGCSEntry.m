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

#import <NGCards/NGVCard.h>

#import "SOGoContactGCSEntry.h"

@implementation SOGoContactGCSEntry

- (id) init
{
  if ((self = [super init]))
    {
      card = nil;
    }

  return self;
}

- (void) dealloc
{
  if (card)
    [card release];
  [super dealloc];
}

/* content */

- (NGVCard *) vCard
{
  NSString *contentStr;

  if (!card)
    {
      contentStr = [self contentAsString];
      if ([contentStr hasPrefix:@"BEGIN:VCARD"])
        card = [NGVCard parseSingleFromSource: contentStr];
      else
        card = [NGVCard cardWithUid: [self nameInContainer]];
      [card retain];
    }

  return card;
}

/* DAV */

- (NSString *) davContentType
{
  return @"text/x-vcard";
}

/* specialized actions */

- (void) save
{
  NGVCard *vcard;

  vcard = [self vCard];

  [self saveContentString: [vcard versitString]];
}

/* message type */

- (NSString *) outlookMessageClass
{
  return @"IPM.Contact";
}

@end /* SOGoContactGCSEntry */
