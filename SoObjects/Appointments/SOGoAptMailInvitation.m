/*
  Copyright (C) 2010-2012 Inverse

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

#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/iCalEvent.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoUser.h>
#import "iCalPerson+SOGo.h"

#import "SOGoAptMailNotification.h"

@interface SOGoAptMailInvitation : SOGoAptMailNotification
@end

@implementation SOGoAptMailInvitation

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
  NSString *body;

  if (!values)
    [self setupValues];

  body = [[self generateResponse] contentAsString];

  return [body stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
