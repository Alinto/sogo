/* UIxAccountEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2017 Inverse inc.
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

#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxAccountEditor : UIxComponent
{
  NSString *accountId;
}

@end

@implementation UIxAccountEditor

- (id) init
{
  self = [super init];
  
  if (self)
    {
      accountId = nil;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(accountId);
  [super dealloc];
}


- (BOOL) _validateFilterId
{
  NSCharacterSet *digits;
  BOOL rc;
  
  digits = [NSCharacterSet decimalDigitCharacterSet];
  rc = ([accountId isEqualToString: @"new"]
        || [[accountId stringByTrimmingCharactersInSet: digits] length] == 0);
  
  return rc;
}

- (id <WOActionResults>) defaultAction
{
  id <WOActionResults> result;
  WORequest *request;

  request = [context request];
  ASSIGN (accountId, [request formValueForKey: @"account"]);
  if (accountId)
    {
      if ([self _validateFilterId])
        result = self;
      else
        result = [self responseWithStatus: 403
                                andString: @"Bad value for 'account'"];
    }
  else
    result = [self responseWithStatus: 403
                            andString: @"Missing 'account' parameter"];

  return result;
}

@end
