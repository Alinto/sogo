/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include "SOGoAPIDispatcher.h"

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoPermissions.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOCoreApplication.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalPerson.h>

#import <NGExtensions/NGBase64Coding.h>

#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSString+Encoding.h>

#import <SOGo/NSArray+DAV.h>
#import <SOGo/NSDictionary+DAV.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoCacheGCSObject.h>
#import <SOGo/SOGoDAVAuthenticator.h>
#import <SOGo/SOGoMailer.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/GCSSpecialQueries+SOGoCacheObject.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/WORequest+SOGo.h>
#import <SOGo/WOResponse+SOGo.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoPermissions.h>

void handle_api_terminate(int signum)
{
  NSLog(@"Forcing termination of API loop.");
  apiShouldTerminate = YES;
  [[WOCoreApplication application] terminateAfterTimeInterval: 1];
}

@implementation SOGoAPIDispatcher

- (id) init
{
  [super init];

  debugOn = [[SOGoSystemDefaults sharedSystemDefaults] apiDebugEnabled];
  apiShouldTerminate = NO;

  signal(SIGTERM, handle_api_terminate);

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (void) _sendAPIErrorResponse: (WOResponse* ) response
                   withMessage: (NSString *) message
                    withStatus: (unsigned int) status
{
  NSDictionary *msg;
  msg = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  message, @"error",
                                  nil];
  [response setStatus: status];
  [response setContent: [msg jsonRepresentation]];
}

- (NSString *) _getActionFromUri: (NSString *) _uri
{
  /*
  _uri always start with /SOGo/SOGoAPI
  full _uri example /SOGo/SOGoAPI/Action/subaction1?param1&param2
  */
  
  NSString *uriWithoutParams, *action, *prefix;
  NSArray *uriSplits;

  prefix = @"/SOGo/SOGoAPI";
  action = @"";

  uriWithoutParams = [_uri urlWithoutParameters];
  if(![uriWithoutParams hasPrefix: prefix])
  {
    [self errorWithFormat: @"Uri for API request does not start with /SOGo/SOGoAPI: %@", uriWithoutParams];
    return nil;
  }
  else
  {
    uriWithoutParams = [uriWithoutParams substringFromIndex:[prefix length]];
  }

  //remove first and last '/'' if needed
  if([uriWithoutParams hasPrefix: @"/"])
  {
    uriWithoutParams = [uriWithoutParams substringFromIndex:1];
  }
  if([uriWithoutParams hasSuffix: @"/"])
  {
      uriWithoutParams = [uriWithoutParams substringToIndex:([uriWithoutParams length] -1)];
  }
  if([uriWithoutParams length] == 0)
  {
    [self warnWithFormat: @"Uri for API request has no action, make Version instead: %@", uriWithoutParams];
    return @"SOGoAPIVersion";
  }
  else
  {
    uriSplits = [uriWithoutParams componentsSeparatedByString: @"/"];
    action = [@"SOGoAPI" stringByAppendingString: [uriSplits objectAtIndex: 0]];
    if(debugOn)
      [self logWithFormat: @"API request, action made is %@", action];
  }

  return action;
}



- (NSException *) dispatchRequest: (WORequest*) theRequest
                       inResponse: (WOResponse*) theResponse
                          context: (id) theContext
{
  NSAutoreleasePool *pool;
  id activeUser;
  NSString *method, *action, *error;
  NSDictionary *form;
  NSMutableDictionary *ret;
  NSBundle *bundle;
  id classAction;
  Class clazz;


  pool = [[NSAutoreleasePool alloc] init];
  ASSIGN(context, theContext);

  activeUser = [context activeUser];

  //Get the api action, check it
  action = [self _getActionFromUri: [theRequest uri]];
  if(!action)
  {
    error = [NSString stringWithFormat: @"No actions found for request to API: %@", [theRequest uri]];
    [self errorWithFormat: error];
    [self _sendAPIErrorResponse: theResponse withMessage: error withStatus: 400];
    return nil;
  }

  //Get the class for this action, check it
  bundle = [NSBundle bundleForClass: NSClassFromString(@"SOGoAPIProduct")];
  clazz = [bundle classNamed: action];
  if(!clazz)
  {
    error = [NSString stringWithFormat: @"No backend API found for action: %@", action];
    [self errorWithFormat: error];
    [self _sendAPIErrorResponse: theResponse withMessage: error withStatus: 400];
    return nil;
  }

  //try to instantiate the class
  NS_DURING
  {
    classAction = [[clazz alloc] init];
  }
  NS_HANDLER
  {
    error = [NSString stringWithFormat: @"Can't alloc and init class: %@", classAction];
    [self errorWithFormat: error];
    [self _sendAPIErrorResponse: theResponse withMessage: error withStatus: 500];
  }
  NS_ENDHANDLER;
  

  //Check user auth


  //Check method


  //Check parameters


  //Execute action
  ret = [classAction action];

  //Make the response
  [theResponse setContent: [ret jsonRepresentation]];

  RELEASE(context);
  RELEASE(pool);

  return nil;
}

@end