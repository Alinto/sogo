/*
  Copyright (C) 2005 SKYRIX Software AG

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

#import <NGObjWeb/SoObject.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WODirectAction.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

@interface UIxMailPartICalAction : WODirectAction
@end

@implementation UIxMailPartICalAction

- (id)redirectToViewerWithError:(NSString *)_error {
  WOResponse *r;
  NSString *viewURL;
  id mail;
  
  mail = [[self clientObject] valueForKey:@"mailObject"];
  [self logWithFormat:@"MAIL: %@", mail];
  
  viewURL = [mail baseURLInContext:[self context]];
  [self logWithFormat:@"  url: %@", viewURL];
  
  viewURL = [viewURL stringByAppendingString:
		       [viewURL hasSuffix:@"/"] ? @"view" : @"/view"];

  if ([_error isNotNull] && [_error length] > 0) {
    viewURL = [viewURL stringByAppendingString:@"?error="];
    viewURL = [viewURL stringByAppendingString:
			 [_error stringByEscapingURL]];
  }
  
  r = [[self context] response];
  [r setStatus:302 /* moved */];
  [r setHeader:viewURL forKey:@"location"];
  return r;
}

- (id)changePartStatusAction:(NSString *)_newStatus {
  [self logWithFormat:@"TODO: should %@: %@", _newStatus, [self clientObject]];
  return [self redirectToViewerWithError:
		 [_newStatus stringByAppendingString:@" not implemented!"]];
}

- (id)markAcceptedAction {
  return [self changePartStatusAction:@"ACCEPTED"];
}
- (id)markDeclinedAction {
  return [self changePartStatusAction:@"DECLINED"];
}
- (id)markTentativeAction {
  return [self changePartStatusAction:@"TENTATIVE"];
}

@end /* UIxMailPartICalAction */
