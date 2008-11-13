/* iCalPerson+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2008 Inverse inc.
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

#import <Foundation/NSString.h>

#import "iCalPerson+SOGo.h"

static LDAPUserManager *um = nil;

@implementation iCalPerson (SOGoExtension)

- (NSString *) mailAddress
{
  NSString *cn, *email, *mailAddress;

  cn = [self cnWithoutQuotes];
  email = [self rfc822Email];
  if ([cn length])
    mailAddress = [NSString stringWithFormat:@"%@ <%@>", cn, email];
  else
    mailAddress = email;

  return mailAddress;
}

- (NSString *) uid
{
  if (!um)
    um = [LDAPUserManager sharedUserManager];

  return [um getUIDForEmail: [self rfc822Email]];
}

- (BOOL) hasSentBy
{
  NSString *mail;

  mail = [self value: 0  ofAttribute: @"SENT-BY"];

  return ([mail length] > 7);
}

- (NSString *) sentBy
{
  NSString *mail;
  
  mail = [self value: 0  ofAttribute: @"SENT-BY"];

  if ([mail length] > 7)
    {
      if ([mail characterAtIndex: 0] == '"' && [mail hasSuffix: @"\""])
	mail = [mail substringWithRange: NSMakeRange(1, [mail length]-2)];
      
      return [mail substringFromIndex: 7];
    }
  
  return @"";
}

@end
