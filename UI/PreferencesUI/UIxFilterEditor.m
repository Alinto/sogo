/* UIxFilterEditor.m - this file is part of SOGo
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

#import <Foundation/NSCharacterSet.h>

#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>

#import <SOGoUI/UIxComponent.h>

@interface UIxFilterEditor : UIxComponent
{
  NSString *filterId;
}

@end

@implementation UIxFilterEditor

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

- (NSString *) firstMailAccount
{
  NSArray *accounts;
  NSDictionary *account;
  NSString *login, *accountName;
  SOGoUser *ownerUser;

  login = [[self clientObject] nameInContainer];
  ownerUser = [SOGoUser userWithLogin: login];

  accounts = [ownerUser mailAccounts];
  if ([accounts count] > 0)
    {
      account = [accounts objectAtIndex: 0];
      accountName = [[account objectForKey: @"name"] asCSSIdentifier];
    }
  else
    accountName = @"";

  return accountName;
}

@end
