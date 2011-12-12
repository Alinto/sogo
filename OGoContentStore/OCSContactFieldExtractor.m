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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLContentStore/GCSFieldExtractor.h>
#import <NGCards/NGVCard.h>
#import <NGCards/NGVList.h>

#import <SOGo/NSArray+Utilities.h>

@interface OCSContactFieldExtractor : GCSFieldExtractor
@end

@implementation OCSContactFieldExtractor

- (NSMutableDictionary *) extractQuickFieldsFromVCard: (NGVCard *) vCard
{
  NSMutableDictionary *fields;
  NSArray *values;
  CardElement *element;
  NSString *value;

  fields = [NSMutableDictionary dictionaryWithCapacity: 16];

  value = [vCard fn];
  if (value)
    [fields setObject: value forKey: @"c_cn"];
  element = [vCard n];
  [fields setObject: [element flattenedValueAtIndex: 0 forKey: @""]
             forKey: @"c_sn"];
  [fields setObject: [element flattenedValueAtIndex: 1 forKey: @""]
             forKey: @"c_givenName"];
  value = [vCard preferredTel];
  if (value)
    [fields setObject: value forKey: @"c_telephoneNumber"];
  value = [vCard preferredEMail];
  if (![value isNotNull])
    value = @"";
  [fields setObject: value forKey: @"c_mail"];
  element = [vCard org];
  [fields setObject: [element flattenedValueAtIndex: 0 forKey: @""]
             forKey: @"c_o"];
  [fields setObject: [element flattenedValueAtIndex: 1 forKey: @""]
             forKey: @"c_ou"];
  element = [vCard preferredAdr];
  if (element && ![element isVoid])
    [fields setObject: [element flattenedValueAtIndex: 3
                                               forKey: @""]
               forKey: @"c_l"];
  value = [[vCard uniqueChildWithTag: @"X-AIM"] flattenedValuesForKey: @""];
  [fields setObject: value forKey: @"c_screenname"];
  values = [[vCard categories] trimmedComponents];
  if ([values count] > 0)
    [fields setObject: [values componentsJoinedByString: @","]
               forKey: @"c_categories"];
  else
    [fields setObject: [NSNull null] forKey: @"c_categories"];
  [fields setObject: @"vcard" forKey: @"c_component"];

  return fields;
}

- (NSMutableDictionary *) extractQuickFieldsFromVList: (NGVList *) vList
{
  NSMutableDictionary *fields;
  NSString *value;

  fields = [NSMutableDictionary dictionaryWithCapacity: 1];

  value = [vList fn];
  if (value)
    [fields setObject: value forKey: @"c_cn"];
  [fields setObject: @"vlist" forKey: @"c_component"];

  return fields;
}

- (NSMutableDictionary *) extractQuickFieldsFromContent: (NSString *) content
{
  NSMutableDictionary *fields;
  NGVCard *vCard;
  NGVList *vList;
  NSString *upperContent;

  fields = nil;
  if ([content length] > 0)
    {
      upperContent = [content uppercaseString];
      if ([upperContent hasPrefix: @"BEGIN:VCARD"])
	{
	  vCard = [NGVCard parseSingleFromSource: content];
	  if (vCard)
	    fields = [self extractQuickFieldsFromVCard: vCard];
	  else
	    [self errorWithFormat: @"Could not parse VCARD content."];
	}
      else if ([upperContent hasPrefix: @"BEGIN:VLIST"])
	{
	  vList = [NGVList parseSingleFromSource: content];
	  if (vList)
	    fields = [self extractQuickFieldsFromVList: vList];
	  else
	    [self errorWithFormat: @"Could not parse VLIST content."];
	}
      else
	[self errorWithFormat: @"Content is unknown."];
    }
  else
    [self errorWithFormat: @"Content is empty."];

  return fields;
}

@end /* OCSContactFieldExtractor */
