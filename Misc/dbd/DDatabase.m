// $Id: DDatabase.m 46 2004-06-17 01:23:37Z helge $

#include <NGObjWeb/SoComponent.h>

@class EOAdaptorChannel;

@interface DDatabase : SoComponent
{
  EOAdaptorChannel *channel;
  NSArray *tableNames;
  id item;
}

@end

#include "DSoDatabase.h"
#include "common.h"

@implementation DDatabase

- (void)dealloc {
  if ([self->channel isOpen])
    [self->channel closeChannel];
  [self->channel release];
  
  [self->tableNames release];
  [self->item       release];
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
  return [(DSoDatabase *)[self clientObject] adaptorInContext:[self context]];
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

- (NSArray *)tableNames {
  if (self->tableNames == nil)
    self->tableNames = [[[self channel] describeTableNames] copy];
  return self->tableNames;
}

- (NSString *)tabLink {
  // this suxx, a) we need to write code, b) we need to attach the / manually
  return [[self item] stringByAppendingString:@"/"];
}

@end /* DDatabase */
