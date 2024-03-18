/*
  Copyright (C) todo...
*/

#import <SOGoAPI.h>


@implementation SOGoAPI

- (NSDictionary *) sogoVersionAction {
NSDictionary* result;

result = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  @"major", SOGO_MAJOR_VERSION,
                                  @"minor", SOGO_MINOR_VERSION,
                                  @"patch", SOGO_PATCH_VERSION,
                                  nil];
[result autorelease];
return result;
}


@end /* SOGoAPI */