/* UIxListEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2008 Inverse inc.
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

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>

#import <Contacts/SOGoContactGCSFolder.h>

#import "UIxListEditor.h"

@implementation UIxListEditor

- (NSString *) saveURL
{
  return [NSString stringWithFormat: @"%@/saveAsList",
                   [[self clientObject] baseURL]];
}

#warning Could this be part of a common parent with UIxAppointment/UIxTaskEditor/UIxListEditor ?
- (id) newAction
{
  NSString *objectId, *method, *uri;
  id <WOActionResults> result;
  SOGoContactGCSFolder *co;

  co = [self clientObject];
  objectId = [co globallyUniqueObjectId];
  if ([objectId length] > 0)
    {
      method = [NSString stringWithFormat:@"%@/%@.vls/editAsList",
                         [co soURL], objectId];
      uri = [self completeHrefForMethod: method];
      result = [self redirectToLocation: uri];
    }
  else
    result = [NSException exceptionWithHTTPStatus: 500 /* Internal Error */
                          reason: @"could not create a unique ID"];

  return result;
}

@end
