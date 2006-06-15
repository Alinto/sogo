// $Id: DHostView.m 46 2004-06-17 01:23:37Z helge $

#include <NGObjWeb/SoComponent.h>

@class EOAdaptorChannel;

@interface DHostView : SoComponent
{
  EOAdaptorChannel *channel;
  NSArray *userNames;
  NSArray *databaseNames;
  id item;
}

@end

#include "DSoHost.h"
#include "common.h"

@interface EOAdaptorChannel(ModelFetching)
- (NSArray *)describeUserNames;
- (NSArray *)describeDatabaseNames;
@end

@implementation DHostView

- (void)dealloc {
  if ([self->channel isOpen])
    [self->channel closeChannel];
  [self->channel release];
  
  [self->userNames     release];
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
  return [(DSoHost *)[self clientObject] adaptorInContext:[self context]];
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

- (NSArray *)userNames {
  if (self->userNames == nil)
    self->userNames = [[[self channel] describeUserNames] copy];
  return self->userNames;
}

- (NSArray *)databaseNames {
  if (self->databaseNames == nil)
    self->databaseNames = [[[self channel] describeDatabaseNames] copy];
  return self->databaseNames;
}

/* derived accessors */

// Note: it suxx that we need to write code for that ...

- (NSString *)dbLink {
  return [[@"Databases/" stringByAppendingString:[self item]]
	                 stringByAppendingString:@"/"];
}
- (NSString *)userLink {
  return [[@"Users/" stringByAppendingString:[self item]]
	             stringByAppendingString:@"/"];
}

@end /* DHostView */
