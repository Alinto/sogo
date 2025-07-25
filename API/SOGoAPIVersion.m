/*
  Copyright (C) todo...
*/

#import <SOGoAPIVersion.h>


@implementation SOGoAPIVersion

- (id) init
{
  [super init];

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (BOOL) needAuth
{
  return NO;
}

- (NSDictionary *) action: (WOContext*) ctx withParam: (NSDictionary *) param
{
NSDictionary* result;

result = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  [NSNumber numberWithInt:SOGO_MAJOR_VERSION], @"major",
                                  [NSNumber numberWithInt:SOGO_MINOR_VERSION], @"minor",
                                  [NSNumber numberWithInt:SOGO_PATCH_VERSION], @"patch",
                                  nil];

[result autorelease];
return result;
}


@end /* SOGoAPIVersion */