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

+ (id) entryPhotoWithID: (int) photoID
            inContainer: (id) container
{
  id photo;

  photo
    = [super objectWithName: [NSString stringWithFormat: @"photo%d", photoID]
                inContainer: container];
  [photo setPhotoID: photoID];

  return photo;
}

- (void) setPhotoID: (int) newPhotoID
{
  photoID = newPhotoID;
}

- (NGVCardPhoto *) photo
{
  NGVCardPhoto *photo;
  NSArray *photoElements;

  photoElements = [[container vCard] childrenWithTag: @"photo"];
  if ([photoElements count] > photoID)
    photo = [photoElements objectAtIndex: photoID];
  else
    photo = nil;

  return photo;
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
    data = [[photo value: 0] dataUsingEncoding: NSISOLatin1StringEncoding];
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
