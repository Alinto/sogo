// $Id: UIxPageFrame.m 59 2004-06-22 13:40:19Z znek $

#include <NGObjWeb/SoComponent.h>
#include <NGObjWeb/SoHTTPAuthenticator.h>
#include <NGObjWeb/SoUser.h>


@interface UIxPageFrame : SoComponent
{
  NSString *title;
}

@end

#include "common.h"

@implementation UIxPageFrame

- (void)dealloc {
  [self->title release];
  [super dealloc];
}

/* accessors */

- (void)setTitle:(NSString *)_value {
  ASSIGN(self->title, _value);
}

- (NSString *)title {
  return self->title;
}

- (NSString *)login {
    WOContext *ctx;
    SoUser *user;
    
    ctx = [self context];
    user = [[[self clientObject] authenticatorInContext:ctx]
                                 userInContext:ctx];
    return [user login];
}

@end /* UIxPageFrame */
