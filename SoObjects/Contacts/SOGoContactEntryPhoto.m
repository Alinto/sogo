/* SOGoContactEntryPhoto.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardPhoto.h>

#import "SOGoContactObject.h"

#import "SOGoContactEntryPhoto.h"

@implementation SOGoContactEntryPhoto

- (NGVCardPhoto *) photo
{
  return (NGVCardPhoto *) [[container vCard] firstChildWithTag: @"photo"];
}

- (id) GETAction: (WOContext *) localContext
{
  NGVCardPhoto *photo;
  NSData     *data;
  id response;

  photo = [self photo];
  if ([photo isInline])
    data = [photo decodedContent];
  else
    data = [[photo flattenedValuesForKey: @""]
             dataUsingEncoding: NSISOLatin1StringEncoding];
  if (data)
    {
      response = [localContext response];

      [response setHeader: [self davContentType] forKey: @"content-type"];
      [response setHeader: [NSString stringWithFormat:@" %d",
                                     [data length]]
                   forKey: @"content-length"];
      [response setContent: data];
    }
  else
    response = nil;

  return response;
}

- (NSString *) davContentType
{
  NGVCardPhoto *photo;
  NSString *type, *contentType;

  photo = [self photo];
  if ([photo isInline])
    {
      type = [[photo type] lowercaseString];
      contentType = [NSString stringWithFormat: @"image/%@", type];
    }
  else
    contentType = @"text/plain";

  return contentType;
}

@end
