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
#import <NGObjWeb/SoObjectWebDAVDispatcher.h>

#include <NGObjWeb/SoObject+SoDAV.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>

#import <Foundation/NSArray.h>

@interface SoObjectWebDAVDispatcher (ActiveSync)

- (id)_callObjectMethod:(NSString *)_method inContext:(WOContext *)_ctx;
- (id) doOPTIONS:(WOContext *)_ctx;

@end

@implementation SoObjectWebDAVDispatcher (ActiveSync)

- (id) doOPTIONS:(WOContext *)_ctx 
{
  WOResponse *response;
  
  /*
    See example: http://msdn.microsoft.com/en-us/library/ee204257(v=exchg.80).aspx
  */
  if ([[[_ctx request] requestHandlerKey] isEqualToString: @"Microsoft-Server-ActiveSync"])
    {
      response = [_ctx response];
      [response setStatus: 200];
      
      [response setHeader: @"private"  forKey: @"Cache-Control"];
      [response setHeader: @"OPTIONS, POST"  forKey: @"Allow"];
      [response setHeader: @"14.1"  forKey: @"MS-Server-ActiveSync"];
      [response setHeader: @"2.5,12.0,12.1,14.0,14.1"  forKey: @"MS-ASProtocolVersions"];
      [response setHeader: @"Sync,SendMail,SmartForward,SmartReply,GetAttachment,GetHierarchy,CreateCollection,DeleteCollection,MoveCollection,FolderSync,FolderCreate,FolderDelete,FolderUpdate,MoveItems,GetItemEstimate,MeetingResponse,Search,Settings,Ping,ItemOperations,ResolveRecipients,ValidateCert"  forKey: @"MS-ASProtocolCommands"];
      [response setHeader: @"OPTIONS, POST"  forKey: @"Public"];
    }
  else
    {
      NSArray    *tmp;
      id         result;
      
      /* this checks whether the object provides a specific OPTIONS method */
      if ((result = [self _callObjectMethod:@"OPTIONS" inContext:_ctx]) != nil)
        return result;
      
      response = [_ctx response];
      [response setStatus:200 /* OK */];
      
      if ((tmp = [self->object davAllowedMethodsInContext:_ctx]) != nil) 
        [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"allow"];
      
      if ([[[_ctx request] clientCapabilities] isWebFolder]) {
        /*
          As described over here:
          http://teyc.editthispage.com/2005/06/02
          
          This page also says that: "MS-Auth-Via header is not required to work
       with Web Folders".
        */
        [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"public"];
      }
      
      if ((tmp = [self->object davComplianceClassesInContext:_ctx]) != nil) 
        [response setHeader:[tmp componentsJoinedByString:@", "] forKey:@"dav"];
    }
  
  return response;
}

@end
