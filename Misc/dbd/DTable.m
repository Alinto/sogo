// $Id: DTable.m 60 2004-06-23 13:32:21Z helge $

#include <NGObjWeb/SoComponent.h>

@class EOAdaptorChannel;

@interface DTable : SoComponent
{
  EOAdaptorChannel *channel;
  NSArray *attributes;
  NSArray *columnNames;
  id item;
}

@end

#include "DSoTable.h"
#include "common.h"

@implementation DTable

- (void)dealloc {
  if ([self->channel isOpen])
    [self->channel closeChannel];
  [self->channel release];
  
  [self->attributes  release];
  [self->columnNames release];
  [self->item        release];
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
  return [(DSoTable *)[self clientObject] adaptorInContext:[self context]];
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

- (EOModel *)_describeModel {
  NSArray *tableNames;
  
  tableNames = [NSArray arrayWithObject:[[self clientObject] tableName]];
  return [[self channel] describeModelWithTableNames:tableNames];
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSArray *)attributes {
  EOModel *model;

  if (self->attributes)
    return self->attributes;
  
  model            = [self _describeModel];
  self->attributes = [[[[model entities] lastObject] attributes] retain];
  return self->attributes;
}
- (NSArray *)columnNames {
  if (self->columnNames)
    return self->columnNames;
  
  self->columnNames = [[[self attributes] valueForKey:@"columnName"] copy];
  return self->columnNames;
}

- (NSString *)columnLink {
  return [[[self item] columnName] stringByAppendingString:@"/"];
}
- (NSString *)itemSlashLink {
  // this suxx, a) we need to write code, b) we need to attach the / manually
  return [[self item] stringByAppendingString:@"/"];
}

@end /* DTable */
