/* NGVCard+Contact.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGiCal/NGVCardValue.h>

#import "NGVCardSimpleValue+Contact.h"
#import "NGVCard+Contact.h"

@implementation NGVCard (SOGOContactExtension)

- (NSString *) asString
{
  NSMutableString *vCardString;
  NSArray *infos;
  unsigned int count, max;

  vCardString = [NSMutableString new];
  [vCardString autorelease];

  [vCardString appendFormat: @"BEGIN:VCARD\r\n"
               @"VERSION:%@\r\n"
               @"PRODID:%@\r\n"
               @"PROFILE:%@\r\n",
               [self version], [self prodID], [self profile]];
  [vCardString appendFormat: @"FN:%@\r\n", [self fn]];
  [vCardString appendFormat: @"N:%@\r\n", [[self n] stringValue]];

  infos = [self email];
  if ([infos count] > 0)
    [vCardString appendFormat: @"EMAIL;TYPE=internet,pref:%@\r\n",
                 [infos objectAtIndex: 0]];

  infos = [self tel];
  max = [infos count];
  for (count = 0; count < max; count++)
    [vCardString appendFormat: @"%@\r\n",
                 [[infos objectAtIndex: count] vCardEntryString]];

//     }
// count = 
//   if ([infos count] > 0)
//     [vCardString appendFormat: @"EMAIL;TYPE=internet,pref:%@\r\n",
//                  [infos objectAtIndex: 0]];

//   [self _appendArrayedVCardValues:
//           [NSArray arrayWithObjects: @"sn", @"givenName", nil]
//         withFormat: @"N:%@;;;\r\n"
//         toVCard: vCardString];
//   [self _appendSingleVCardValue: @"telephoneNumber"
//         withFormat: @"TEL;TYPE=work,voice,pref:%@\r\n"
//         toVCard: vCardString];
//   [self _appendSingleVCardValue: @"facsimileTelephoneNumber"
//         withFormat: @"TEL;TYPE=work,fax:%@\r\n"
//         toVCard: vCardString];
//   [self _appendSingleVCardValue: @"homeTelephoneNumber"
//         withFormat: @"TEL;TYPE=home,voice:%@\r\n"
//         toVCard: vCardString];
//   [self _appendSingleVCardValue: @"mobile"
//         withFormat: @"TEL;TYPE=cell,voice:%@\r\n"
//         toVCard: vCardString];
//   [self _appendArrayedVCardValues:
//           [NSArray arrayWithObjects: @"l", @"departmentNumber", nil]
//         withFormat: @"ORG:%@\r\n"
//         toVCard: vCardString];
//   [self _appendMultilineVCardValue: @"postalAddress"
//         withFormat: @"ADR:TYPE=work,postal:%@\r\n"
//         toVCard: vCardString];
//   [self _appendMultilineVCardValue: @"homePostalAddress"
//         withFormat: @"ADR:TYPE=home,postal:%@\r\n"
//         toVCard: vCardString];
//   [self _appendSingleVCardValue: @"labelledURI"
//         withFormat: @"URL:%@\r\n"
//         toVCard: vCardString];

  [vCardString appendString: @"END:VCARD\r\n"];

  return vCardString;
}

@end
