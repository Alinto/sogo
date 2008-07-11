/*
  Copyright (C) 2004 SKYRIX Software AG

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
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/iCalCalendar.h>

#import <SoObjects/Appointments/iCalRepeatableEntityObject+SOGo.h>

#import "OCSiCalFieldExtractor.h"

@implementation OCSiCalFieldExtractor

+ (id) sharedICalFieldExtractor
{
  static OCSiCalFieldExtractor *extractor = nil;

  if (!extractor)
    extractor = [self new];

  return extractor;
}

/* operations */

- (CardGroup *) firstElementFromCalendar: (iCalCalendar *) ical
{
  NSArray *elements;
  CardGroup *element;
  unsigned int count;
 
  elements = [ical allObjects];
  count = [elements count];
  if (count)
    element = [elements objectAtIndex: 0];
  else
    {
      [self logWithFormat: @"ERROR: given calendar contains no elements: %@", ical];
      element = nil;
    }

  return element;
}

- (NSMutableDictionary *) extractQuickFieldsFromContent: (NSString *) _content
{
  NSMutableDictionary *fields;
  id cal;

  fields = nil;
 
  if ([_content length])
    {
      cal = [iCalCalendar parseSingleFromSource: _content];
      if (cal)
	{
	  if ([cal isKindOfClass: [iCalCalendar class]])
	    cal = [self firstElementFromCalendar: cal];

	  if ([cal isKindOfClass: [iCalRepeatableEntityObject class]])
	    fields = [cal quickRecord];
	  else if ([cal isNotNull])
	    [self logWithFormat: @"ERROR: unexpected iCalendar parse result: %@",
		  cal];
	}
      else
	[self logWithFormat: @"ERROR: parsing source didn't return anything"];
    }

  return fields;
}

@end /* OCSiCalFieldExtractor */
