/* UIxFolderActions.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/SoSecurityManager.h>

#import <SoObjects/SOGo/LDAPUserManager.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoObject.h>
#import <SoObjects/SOGo/SOGoPermissions.h>

#import "UIxFolderActions.h"

@implementation UIxFolderActions

#warning some of this code could probably be moved in one of the \
         clientObject classes...

- (void) _setupContext
{
  NSString *clientClass, *mailInvitationParam;
  SOGoUser *activeUser;

  activeUser = [context activeUser];
  login = [activeUser login];
  clientObject = [self clientObject];
  owner = [clientObject ownerInContext: nil];

  clientClass = NSStringFromClass([clientObject class]);
  if ([clientClass isEqualToString: @"SOGoContactGCSFolder"])
    baseFolder = @"Contacts";
  else if ([clientClass isEqualToString: @"SOGoAppointmentFolder"])
    baseFolder = @"Calendar";
  else
    baseFolder = nil;

  um = [LDAPUserManager sharedUserManager];
  ud = [activeUser userSettings];
  moduleSettings = [ud objectForKey: baseFolder];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary new];
      [moduleSettings autorelease];
    }
  [ud setObject: moduleSettings forKey: baseFolder];

  subscriptionPointer = [NSMutableString stringWithFormat: @"%@:%@",
					 owner, baseFolder];
  if ([baseFolder isEqualToString: @"Contacts"])
    [subscriptionPointer appendFormat: @"/%@",
			 [clientObject nameInContainer]];

  mailInvitationParam
    = [[context request] formValueForKey: @"mail-invitation"];
  isMailInvitation = [mailInvitationParam boolValue];
}

- (WOResponse *) _realActionWithFolderName: (NSDictionary *) folderDict
{
  WOResponse *response;
  NSMutableDictionary *folderSubscription;
  NSString *mailInvitationURL;

  response = [context response];
  if ([owner isEqualToString: login])
    {
      [response setStatus: 403];
      [response appendContentString:
		 @"You cannot (un)subscribe to a folder that you own!"];
    }
  else
    {
      folderSubscription
	= [moduleSettings objectForKey: @"SubscribedFolders"];
      if (!folderSubscription)
	{
	  folderSubscription = [NSMutableDictionary dictionary];
	  [moduleSettings setObject: folderSubscription
			  forKey: @"SubscribedFolders"];
	}
      if (folderDict)
	[folderSubscription setObject: folderDict
			    forKey: subscriptionPointer];
      else
	[folderSubscription removeObjectForKey: subscriptionPointer];

      [ud synchronize];

      if (isMailInvitation)
	{
	  mailInvitationURL
	    = [[clientObject soURLToBaseContainerForCurrentUser]
		absoluteString];
	  [response setStatus: 302];
	  [response setHeader: mailInvitationURL
		    forKey: @"location"];
	}
      else
	[response setStatus: 204];
    }

  return response;
}

- (WOResponse *) subscribeAction
{
  NSString *email;
  NSMutableDictionary *folderDict;
  NSString *folderName;

  [self _setupContext];
  email = [NSString stringWithFormat: @"%@ <%@>",
		    [um getCNForUID: owner],
		    [um getEmailForUID: owner]];
  if ([baseFolder isEqualToString: @"Contacts"])
    folderName = [NSString stringWithFormat: @"%@ (%@)",
			   [clientObject nameInContainer], email];
  else
    folderName = email;

  folderDict = [NSMutableDictionary dictionary];
  [folderDict setObject: folderName forKey: @"displayName"];
  [folderDict setObject: [NSNumber numberWithBool: NO] forKey: @"active"];

  return [self _realActionWithFolderName: folderDict];
}

- (WOResponse *) unsubscribeAction
{
  [self _setupContext];

  return [self _realActionWithFolderName: nil];
}

- (WOResponse *) canAccessContentAction
{
  WOResponse *response;

  response = [context response];
  [response setStatus: 204];

  return response;
}

- (WOResponse *) _realFolderActivation: (BOOL) makeActive
{
  WOResponse *response;
  NSMutableDictionary *folderSubscription, *folderDict;
  NSNumber *active;
  
  response = [context response];

  [self _setupContext];
  active = [NSNumber numberWithBool: makeActive];
  if ([owner isEqualToString: login])
    [moduleSettings setObject: active forKey: @"activateUserFolder"];
  else
    {
      folderSubscription
	= [moduleSettings objectForKey: @"SubscribedFolders"];
      if (folderSubscription)
	{
          folderDict = [folderSubscription objectForKey: subscriptionPointer];
          if (folderDict)
            [folderDict setObject: active
                        forKey: @"active"];
	}
    }

  [ud synchronize];
  [response setStatus: 204];

  return response;
}

- (WOResponse *) activateFolderAction
{
  return [self _realFolderActivation: YES];
}

- (WOResponse *) deactivateFolderAction
{
  return [self _realFolderActivation: NO];
}

@end
