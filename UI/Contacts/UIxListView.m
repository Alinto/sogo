/* UIxListView.m - this file is part of SOGo
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
#import <NGCards/NGVList.h>
#import <NGCards/NGVCard.h>

#import "UIxListView.h"

@implementation UIxListView


- (NSString *) listName
{
  return [list fn];
}

- (BOOL) hasNickname
{
  return [list nickname] != nil;
}
- (NSString *) listNickname
{
  return [list nickname];
}

- (BOOL) hasDescription
{
  return [list description] != nil;
}
- (NSString *) listDescription
{
  return [list description];
}

- (NSArray *) components
{
  return [list cardReferences];
}
- (NSString *) itemText
{
  NSString *rc;

  rc = [NSString stringWithFormat: @"%@ <%@>", [item fn], [item email]];

  return rc;
}

- (id <WOActionResults>) defaultAction
{
  id rc;

  list = [[self clientObject] vList];
  //TODO: make sure references are valid

  if (list)
    rc = self;
  else
    rc = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
                                       reason: @"could not locate contact"];

  return rc;
}

@end
