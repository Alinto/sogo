/*
  Copyright (C) 2014-2016 Inverse inc.

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


#import <SOGo/SOGoCache.h>
#import <SOGo/NSObject+Utilities.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>

#import <API/SOGoAPIDispatcher.h>

@interface SOGoAPIActions : WODirectAction
@end

@implementation SOGoAPIActions


- (WOResponse *) sogoAPIAction
{
  WOResponse *response;
  WORequest *request;
  NSBundle *bundle;
  NSException *ex;
  id dispatcher;
  Class clazz;

  request = (WORequest *)[context request];
  response = (WOResponse *)[context response];
  [response setStatus: 200];
  [response setHeader: @"application/json; charset=utf-8"  forKey: @"content-type"];

  bundle = [NSBundle bundleForClass: NSClassFromString(@"SOGoAPIProduct")];
  clazz = [bundle classNamed: @"SOGoAPIDispatcher"];
  dispatcher = [[clazz alloc] init];

  ex = [dispatcher dispatchRequest: request  inResponse: response  context: context];

  //[[self class] memoryStatistics];

  if (ex)
    {
      return [NSException exceptionWithHTTPStatus: 500];
    }

  RELEASE(dispatcher);

  //[[SOGoCache sharedCache] killCache];

  return response;
}

@end
