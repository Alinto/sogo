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

#include "WOContext+UIxMailer.h"
#include "UIxMailFormatter.h"
#include "common.h"

#include <SoObjects/SOGo/SOGoUser.h>

@implementation WOContext(UIxMailer)

// TODO: make configurable
// TODO: cache!

- (NSFormatter *)mailSubjectFormatter {
  return [[[UIxSubjectFormatter alloc] init] autorelease];
}

- (NSFormatter *)mailDateFormatter
{
  NSTimeZone *userTZ;
  NSString *userTZString;
  id userPrefs;
  static id dateFormatter = nil;

  if (!dateFormatter)
    {
      dateFormatter = [UIxMailDateFormatter new];
      userPrefs = [[self activeUser] userDefaults];
      userTZString = [userPrefs stringForKey: @"timezonename"];
      if ([userTZString length] > 0)
	{
	  userTZ = [NSTimeZone timeZoneWithName: userTZString];
	  [dateFormatter setTimeZone: userTZ];
	}
    }

  return dateFormatter;
}

- (NSFormatter *)mailEnvelopeAddressFormatter {
  return [[[UIxEnvelopeAddressFormatter alloc] init] autorelease];
}
- (NSFormatter *)mailEnvelopeFullAddressFormatter {
  return [[[UIxEnvelopeAddressFormatter alloc] 
	    initWithMaxLength:256 generateFullEMail:YES] autorelease];
}

@end /* WOContext(UIxMailer) */
