/*
  Copyright (C) todo...
*/

#import <SOGoAPI.h>


@implementation SOGoAPI

- (id) init
{
  [super init];

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (NSArray *) methodAllowed
{
  NSArray *result;

  result = [NSArray arrayWithObjects:@"GET",nil];
  return result;
}

- (BOOL) needAuth
{
  return YES;
}

- (NSArray *) paramNeeded
{
  return nil;
}

- (NSDictionary *) action: (WOContext*) ctx withParam: (NSDictionary *) param
{
  NSDictionary* result;

  result = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    @"API not defined", @"error", 
                                    nil];
  [result autorelease];
  return result;
}


@end /* SOGoAPI */