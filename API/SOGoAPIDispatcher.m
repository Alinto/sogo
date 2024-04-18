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

- (NSException *) dispatchRequest: (WORequest*) theRequest
                       inResponse: (WOResponse*) theResponse
                          context: (id) theContext
{
  NSAutoreleasePool *pool;
  id activeUser;
  NSString *method, *action;
  NSDictionary *form;
  NSMutableDictionary *ret;
  NSBundle *bundle;
  id classAction;
  Class clazz;


  pool = [[NSAutoreleasePool alloc] init];

  ASSIGN(context, theContext);

  activeUser = [context activeUser];

  //Get the api action, check it
  action = [theRequest uri]; //il retourne /SOGo/SOGoAPI


  bundle = [NSBundle bundleForClass: NSClassFromString(@"SOGoAPIProduct")];
  clazz = [bundle classNamed: @"SOGoAPIVersion"];
  classAction = [[clazz alloc] init];

  //Check user auth

  //retreive data if needed and execute action
  ret = [classAction action];

  //Make the response
  [theResponse setContent: [ret jsonRepresentation]];

  RELEASE(context);
  RELEASE(pool);

  return nil;
}

@end