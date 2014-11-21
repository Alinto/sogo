/* UIxFilterEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2014 Inverse inc.
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

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>

#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoSystemDefaults.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxFilterEditor : UIxComponent
{
  NSString *filterId;
  NSDictionary *labels;
}

@end

@implementation UIxFilterEditor

- (id) init
{
  self = [super init];
  
  if (self)
    {
      filterId = nil;
      labels = nil;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(filterId);
  RELEASE(labels);
  [super dealloc];
}


/* convert and save */
- (BOOL) _validateFilterId
{
  NSCharacterSet *digits;
  BOOL rc;

  digits = [NSCharacterSet decimalDigitCharacterSet];
  rc = ([filterId isEqualToString: @"new"]
        || [[filterId stringByTrimmingCharactersInSet: digits] length] == 0);

  return rc;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> result;
  WORequest *request;

  request = [context request];
  ASSIGN (filterId, [request formValueForKey: @"filter"]);
  if (filterId)
    {
      if ([self _validateFilterId])
        result = self;
      else
        result = [self responseWithStatus: 403
                                andString: @"Bad value for 'filter'"];
    }
  else
    result = [self responseWithStatus: 403
                            andString: @"Missing 'filter' parameter"];

  return result;
}

- (NSString *) filterId
{
  return filterId;
}

- (NSString *) labels
{
  if (!labels)
    {
      ASSIGN(labels, [[[context activeUser] userDefaults] mailLabelsColors]);
    }
  
  return [labels jsonRepresentation];
}

- (NSString *) sieveFolderEncoding
{
  return [[SOGoSystemDefaults sharedSystemDefaults] sieveFolderEncoding];
}

@end
