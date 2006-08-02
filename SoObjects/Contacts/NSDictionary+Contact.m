/* NSDictionary+Contact.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse groupe conseil
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

#import "NSDictionary+Contact.h"

@implementation NSDictionary (SOGoContact)

- (void) _appendSingleVCardValue: (NSString *) value
                      withFormat: (NSString *) format
                         toVCard: (NSMutableString *) vCard
{
  NSString *info;
  
  info = [self objectForKey: value];
  if (info && [info length] > 0)
    [vCard appendFormat: format, info];
}

- (NSString *) vcardContentFromSOGoContactRecord
{
  NSMutableString *newVCard;
  NSString *info, *info2;

  newVCard = [NSMutableString new];
  [newVCard autorelease];

  [newVCard appendString: @"BEGIN:VCARD\r\n"
            "VERSION:3.0\r\n"
            "PRODID:-//OpenGroupware.org//LSAddress v5.3.85\r\n"
            "PROFILE:vCard\r\n"];

  [self _appendSingleVCardValue: @"cn"
        withFormat: @"FN:%@\r\n"
        toVCard: newVCard];

  info = [self objectForKey: @"givenName"];
  if (!info || [info length] < 1)
    info = @"";
  info2 = [self objectForKey: @"sn"];
  if (!info2 || [info2 length] < 1)
    info2 = @"";
  [newVCard appendFormat: @"N:%@;%@;;;\r\n",
            info2, info];

  [self _appendSingleVCardValue: @"telephoneNumber"
        withFormat: @"TEL;TYPE=work,voice,pref:%@\r\n"
        toVCard: newVCard];
  [self _appendSingleVCardValue: @"facsimileTelephoneNumber"
        withFormat: @"TEL;TYPE=work,fax:%@\r\n"
        toVCard: newVCard];
  [self _appendSingleVCardValue: @"homeTelephoneNumber"
        withFormat: @"TEL;TYPE=home,voice:%@\r\n"
        toVCard: newVCard];
  [self _appendSingleVCardValue: @"mobile"
        withFormat: @"TEL;TYPE=cell,voice:%@\r\n"
        toVCard: newVCard];

  info = [self objectForKey: @"l"];
  if (!info || [info length] < 1)
    info = @"";
  info2 = [self objectForKey: @"departmentNumber"];
  if (!info2 || [info2 length] < 1)
    info2 = @"";
  [newVCard appendFormat: @"ORG:%@;%@\r\n",
            info, info2];

  info = [[self objectForKey: @"postalAddress"]
           stringByReplacingString: @"\r\n"
           withString: @";"];
  if (info && [info length] > 0)
    [newVCard appendFormat: @"ADR:TYPE=work,postal:%@\r\n", info];
  info = [[self objectForKey: @"homePostalAddress"]
           stringByReplacingString: @"\r\n"
           withString: @";"];
  if (info && [info length] > 0)
    [newVCard appendFormat: @"ADR:TYPE=home,postal:%@\r\n", info];

  [self _appendSingleVCardValue: @"mail"
        withFormat: @"EMAIL;TYPE=internet,pref:%@\r\n"
        toVCard: newVCard];
  [self _appendSingleVCardValue: @"labelledURI"
        withFormat: @"URL:%@\r\n"
        toVCard: newVCard];

  [newVCard appendString: @"END:VCARD\r\n"];

  return newVCard;
}

@end
