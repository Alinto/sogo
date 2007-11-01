/* SOGoMailReply.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <NGObjWeb/WOContext+SoObjects.h>

#import <SoObjects/SOGo/SOGoDateFormatter.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoMailObject+Draft.h"
#import "SOGoMailReply.h"

@implementation SOGoMailReply

- (id) init
{
  if ((self = [super init]))
    {
      sourceMail = nil;
      currentValue = nil;
    }

  return self;
}

- (void) dealloc
{
  [sourceMail release];
  [currentValue release];
  [super dealloc];
}

- (void) setRepliedMail: (SOGoMailObject *) newSourceMail
{
  ASSIGN (sourceMail, newSourceMail);
}

- (NSString *) date
{
  SOGoDateFormatter *formatter;

  formatter = [[context activeUser] dateFormatterInContext: context];

  return [formatter formattedDateAndTime: [sourceMail date]];
}

- (NSString *) from
{
  return [[sourceMail mailHeaders] objectForKey: @"from"];
}

- (NSString *) messageBody
{
  return [[sourceMail contentForEditing] stringByApplyingMailQuoting];
}

@end

@implementation SOGoMailEnglishReply
@end

@implementation SOGoMailFrenchReply
@end

@implementation SOGoMailGermanReply
@end
