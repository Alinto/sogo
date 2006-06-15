// $Id: DDatabaseManager.m 46 2004-06-17 01:23:37Z helge $

#include <NGObjWeb/SoComponent.h>

@class EOAdaptorChannel;

@interface DDatabaseManager : SoComponent
{
  EOAdaptorChannel *channel;
  NSArray *databaseNames;
  id item;
}

@end

#include "DSoHost.h"
#include "DSoDatabaseManager.h"
#include "common.h"

@interface EOAdaptorChannel(ModelFetching)
- (NSArray *)describeDatabaseNames;
@end

@implementation DDatabaseManager

- (void)dealloc {
  if ([self->channel isOpen])
    [self->channel closeChannel];
  [self->channel release];
  
  [self->databaseNames release];
  [self->item          release];
  [super dealloc];
}

/* notifications */

- (void)sleep {
  if ([self->channel isOpen])
    [self->channel closeChannel];
  
  [super sleep];
}

/* DB things */

- (EOAdaptor *)adaptor {
  return [[(DSoDatabaseManager *)[self clientObject] 
				 host] adaptorInContext:[self context]];
}

- (EOAdaptorChannel *)channel {
  EOAdaptorContext *ctx;
  
  if (self->channel)
    return self->channel;

  ctx = [[self adaptor] createAdaptorContext];
  self->channel = [[ctx createAdaptorChannel] retain];
  if (![self->channel openChannel]) {
    [self->channel release];
    self->channel = nil;
  }

  return self->channel;
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSArray *)databaseNames {
  if (self->databaseNames == nil)
    self->databaseNames = [[[self channel] describeDatabaseNames] copy];
  return self->databaseNames;
}

- (NSString *)dbLink {
  // this suxx, a) we need to write code, b) we need to attach the / manually
  return [[self item] stringByAppendingString:@"/"];
}

@end /* DDatabaseManager */
