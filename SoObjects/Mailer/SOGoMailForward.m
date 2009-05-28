/* SOGoMailForward.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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
#import "SOGoMailForward.h"

@implementation SOGoMailForward

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

- (void) setSourceMail: (SOGoMailObject *) newSourceMail
{
  ASSIGN (sourceMail, newSourceMail);
}

- (NSString *) subject
{
  return [sourceMail decodedSubject];
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

- (NSString *) _headerField: (NSString *) fieldName
{
  if (![field isEqualToString: fieldName])
    {
      [currentValue release];
      currentValue = [[sourceMail mailHeaders] objectForKey: fieldName];
      [currentValue retain];
    }

  return currentValue;
}

- (BOOL) hasReplyTo
{
  return ([[self _headerField: @"reply-to"] length] > 0);
}

- (NSString *) replyTo
{
  return ([NSString stringWithFormat: @"%@\n",
		    [self _headerField: @"reply-to"]]);
}

- (BOOL) hasOrganization
{
  return ([[self _headerField: @"organization"] length] > 0);
}

- (NSString *) organization
{
  return ([NSString stringWithFormat: @"%@\n",
		    [self _headerField: @"organization"]]);
}

- (NSString *) to
{
  return [[sourceMail mailHeaders] objectForKey: @"to"];
}

- (BOOL) hasCc
{
  return ([[self _headerField: @"cc"] length] > 0);
}

- (NSString *) cc
{
  return ([NSString stringWithFormat: @"%@\n",
		    [self _headerField: @"cc"]]);
}

- (BOOL) hasNewsGroups
{
  return ([[self _headerField: @"newsgroups"] length] > 0);
}

- (NSString *) newsgroups
{
  return ([NSString stringWithFormat: @"%@\n",
		    [self _headerField: @"newsgroups"]]);
}

- (BOOL) hasReferences
{
  return ([[self _headerField: @"references"] length] > 0);
}

- (NSString *) references
{
  return ([NSString stringWithFormat: @"%@\n",
		    [self _headerField: @"references"]]);
}

- (NSString *) messageBody
{
  return [sourceMail contentForEditing];
}

- (NSString *) signature
{
  NSString *signature, *mailSignature;

  signature = [[context activeUser] signature];
  if ([signature length])
    mailSignature = [NSString stringWithFormat: @"-- \n%@", signature];
  else
    mailSignature = @"";

  return mailSignature;
}

@end

@implementation SOGoMailDutchForward
@end

@implementation SOGoMailEnglishForward
@end

@implementation SOGoMailFrenchForward
@end

@implementation SOGoMailGermanForward
@end

@implementation SOGoMailItalianForward
@end

@implementation SOGoMailSpanishForward
@end

@implementation SOGoMailRussianForward
@end
