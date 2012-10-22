/* iCalPerson+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2012 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>

#import "iCalPerson+SOGo.h"

static SOGoUserManager *um = nil;

@implementation iCalPerson (SOGoExtension)

- (NSString *) mailAddress
{
  NSString *cn, *email, *mailAddress;
  unsigned int len;

  cn = [self cnWithoutQuotes];
  email = [self rfc822Email];
  len = [cn length];
  
  if (len)
    {
      // We must check if we have to double-quote properly the person's name,
      // in case for example we find a comma
      if ([cn characterAtIndex: 0] != '"' &&
	  [cn characterAtIndex: len-1] != '"' &&
	  [cn rangeOfString: @","].length)
	mailAddress = [NSString stringWithFormat:@"\"%@\" <%@>", cn, email];
      else
	mailAddress = [NSString stringWithFormat:@"%@ <%@>", cn, email];
    }
  else
    mailAddress = email;

  return mailAddress;
}

- (NSString *) uid
{
  if (!um)
    um = [SOGoUserManager sharedUserManager];

  return [um getUIDForEmail: [self rfc822Email]];
}

- (NSString *) contactIDInContext: (WOContext *) context
{
  NSString *domain, *uid;
  NSArray *contacts;
  NSDictionary *contact;

  if (!um)
    um = [SOGoUserManager sharedUserManager];

  uid = nil;
  domain = [[context activeUser] domain];
  contacts = [um fetchContactsMatching: [self rfc822Email] inDomain: domain];
  if ([contacts count] == 1)
    {
      contact = [contacts lastObject];
      uid = [contact valueForKey: @"c_uid"];
    }
      
  return uid;
}

- (BOOL) hasSentBy
{
  NSString *mail;

  mail = [self value: 0 ofAttribute: @"SENT-BY"];

  return ([mail length] > 7);
}

- (NSString *) sentBy
{
  NSString *mail;
  
  mail = [self value: 0 ofAttribute: @"SENT-BY"];

  if ([mail length] > 7)
    {
      if ([mail characterAtIndex: 0] == '"' && [mail hasSuffix: @"\""])
	mail = [mail substringWithRange: NSMakeRange(1, [mail length]-2)];
      
      return [mail substringFromIndex: 7];
    }
  
  return @"";
}

@end
