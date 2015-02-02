/*
  Copyright (C) 2014 Inverse inc. 

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSBundle.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoFolder.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

@interface SOGoMicrosoftActiveSyncActions : WODirectAction
@end

@implementation SOGoMicrosoftActiveSyncActions

//
// Invoked on POST actions
//
- (WOResponse *) microsoftServerActiveSyncAction
{
  WOResponse *response;
  WORequest *request;
  NSBundle *bundle;
  NSException *ex;
  id dispatcher;
  Class clazz;

  request = [context request];
  response = [self responseWithStatus: 200];

  bundle = [NSBundle bundleForClass: NSClassFromString(@"ActiveSyncProduct")];
  clazz = [bundle classNamed: @"SOGoActiveSyncDispatcher"];
  dispatcher = [[clazz alloc] init];

  ex = [dispatcher dispatchRequest: request  inResponse: response  context: context];

  //[[self class] memoryStatistics];

  if (ex)
    {
      return [NSException exceptionWithHTTPStatus: 500];
    }

  RELEASE(dispatcher);

  [[SOGoCache sharedCache] killCache];

  return response;
}

@end
