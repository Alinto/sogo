/*
  Copyright (C) 2010 Inverse

  This file is part of SOGo

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <NGCards/iCalEvent.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoDateFormatter.h>
#import <SOGo/SOGoUser.h>
#import "iCalPerson+SOGo.h"

#import "SOGoAptMailNotification.h"

@interface SOGoAptMailInvitation : SOGoAptMailNotification
@end

@implementation SOGoAptMailInvitation

- (void) setupValues
{
  SOGoDateFormatter *dateFormatter;
  NSCalendarDate *date;
  NSString *description;

  [super setupValues];


  dateFormatter = [[context activeUser] dateFormatterInContext: context];

  date = [self newStartDate];
  [values setObject: [dateFormatter shortFormattedDate: date]
             forKey: @"StartDate"];
  [values setObject: [dateFormatter formattedTime: date]
             forKey: @"StartTime"];

  date = [self newEndDate];
  [values setObject: [dateFormatter shortFormattedDate: date]
             forKey: @"EndDate"];
  [values setObject: [dateFormatter formattedTime: date]
             forKey: @"EndTime"];

  description = [[self apt] comment];
  [values setObject: (description ? description : @"")
	  forKey: @"Description"];
}

- (NSString *) getSubject
{
  NSString *subjectFormat;

  if (!values)
    [self setupValues];

  subjectFormat = [self labelForKey: @"Event Invitation: \"%{Summary}\""
                          inContext: context];

  return [values keysWithFormat: subjectFormat];
}

- (NSString *) getBody
{
  NSString *bodyFormat;

  if (!values)
    [self setupValues];

  bodyFormat = [self labelForKey: @"%{Organizer} %{SentByText}has invited you to %{Summary}.\n\nStart: %{StartDate} at %{StartTime}\nEnd: %{EndDate} at %{EndTime}\nDescription: %{Description}"
                       inContext: context];

  return [values keysWithFormat: bodyFormat];
}

@end
