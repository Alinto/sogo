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

#include <SOGo/NSString+URL.h>

#include <SOGoUI/UIxComponent.h>

@interface UIxMailAccountsView : UIxComponent
{
}

@end

#include "common.h"

@implementation UIxMailAccountsView

- (NSString *)panelTitle {
  return [self labelForKey:@"SOGo Mail Accounts"];
}

- (id) defaultAction
{
  NSArray *c;
  NSString *inbox;
  id actionResult;

  c = [[self clientObject] toManyRelationshipKeys];
  if ([c count] == 1)
    {
      inbox = [NSString stringWithFormat: @"%@/INBOX",
                        [c objectAtIndex: 0]];
      actionResult = [self redirectToLocation: inbox];
    }
  else
    actionResult = self;

  return actionResult;
}

- (id) composeAction
{
  NSArray *c;
  NSString *inbox, *url, *parameter;
  NSMutableDictionary *urlParams;
  id actionResult;

  c = [[self clientObject] toManyRelationshipKeys];
  if ([c count] > 0)
    {
      urlParams = [NSMutableDictionary new];
      [urlParams autorelease];

      parameter = [self queryParameterForKey: @"mailto"];
      if (parameter)
        [urlParams setObject: parameter
                   forKey: @"mailto"];
      inbox = [NSString stringWithFormat: @"%@/INBOX",
                        [c objectAtIndex: 0]];
      url = [inbox composeURLWithAction: @"compose"
                   parameters: urlParams
                   andHash: NO];
      actionResult = [self redirectToLocation: url];
    }
  else
    actionResult = self;

  return actionResult;
}

@end /* UIxMailAccountsView */
