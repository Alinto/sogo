// $Id: MainPage.m 43 2004-06-16 16:06:59Z helge $

#include <NGObjWeb/SoComponent.h>

@interface MainPage : SoComponent
{
  NSString *hostName;
  NSString *databaseName;
}

@end

#include "common.h"

@implementation MainPage

- (id)initWithContext:(id)_ctx {
  if ((self = [super initWithContext:_ctx])) {
    self->hostName = @"localhost";
  }
  return self;
}

- (void)dealloc {
  [self->hostName     release];
  [self->databaseName release];
  [super dealloc];
}

/* accessors */

- (void)setHostName:(NSString *)_value {
  ASSIGNCOPY(self->hostName, _value);
}
- (NSString *)hostName {
  return self->hostName;
}

- (void)setDatabaseName:(NSString *)_value {
  ASSIGNCOPY(self->databaseName, _value);
}
- (NSString *)databaseName {
  return self->databaseName;
}

/* actions */

- (id)connectAction {
  NSString *url;
  
  [self takeFormValuesForKeys:@"databaseName", @"hostName", nil];
  
  if ([[self hostName] length] == 0)
    return nil;
  
  url = [@"/" stringByAppendingString:[[self hostName] stringByEscapingURL]];
  if ([[self databaseName] length] > 0) {
    url = [url stringByAppendingString:@"/Databases/"];
    url = [url stringByAppendingString:
		 [[self databaseName] stringByEscapingURL]];
  }
  if (![url hasSuffix:@"/"])
    url = [url stringByAppendingString:@"/"];
  
  url = [[self context] urlWithRequestHandlerKey:@"so" 
			path:url queryString:nil];
  return [self redirectToLocation:url];
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *rhk;
  
  rhk = [[_ctx request] requestHandlerKey];
  if ([rhk length]==0 || [[self application] requestHandlerForKey:rhk]==nil) {
    /* a small hack to redirect to a valid URL */
    NSString *url;
    
    url = [_ctx urlWithRequestHandlerKey:@"so" path:@"/" queryString:nil];
    [_response setStatus:302 /* moved */];
    [_response setHeader:url forKey:@"location"];
    [self logWithFormat:@"URL: %@", url];
    return;
  }
  
  [super appendToResponse:_response inContext:_ctx];
}

@end /* MainPage */
