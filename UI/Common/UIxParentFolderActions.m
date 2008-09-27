/* UIxParentFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse inc.
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

#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>

#import <UI/Common/WODirectAction+SOGo.h>
#import <SoObjects/SOGo/SOGoParentFolder.h>

#import "UIxParentFolderActions.h"

@implementation UIxParentFolderActions

- (id <WOActionResults>) createFolderAction
{
  WOResponse *response;
  NSString *name, *nameInContainer;

  name = [[context request] formValueForKey: @"name"];
  if ([name length] > 0)
    {
      response = (WOResponse *) [[self clientObject] newFolderWithName: name
						     nameInContainer: &nameInContainer];
      if (!response)
	{
	  response = [self responseWithStatus: 201];
	  [response setHeader: @"text/plain; charset=us-ascii"
		    forKey: @"content-type"];
	  [response appendContentString: nameInContainer];
	}
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
                            reason: @"The name is missing"];
  
  return response;
}

@end
