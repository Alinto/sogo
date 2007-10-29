/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "GCSChannelManager.h"
#include "NSURL+GCS.h"
#include "EOAdaptorChannel+GCS.h"
#include <GDLAccess/EOAdaptor.h>
#include <GDLAccess/EOAdaptorContext.h>
#include <GDLAccess/EOAdaptorChannel.h>
#include "common.h"

/*
  TODO:
  - implemented pooling
  - auto-close channels which are very old?! 
    (eg missing release due to an exception)
*/

@interface GCSChannelHandle : NSObject
{
@public
  NSURL            *url;
  EOAdaptorChannel *channel;
  NSDate           *creationTime;
  NSDate           *lastReleaseTime;
  NSDate           *lastAcquireTime;
}

- (EOAdaptorChannel *)channel;
- (BOOL)canHandleURL:(NSURL *)_url;
- (NSTimeInterval)age;

@end

@implementation GCSChannelManager

static BOOL           debugOn                = NO;
static BOOL           debugPools             = NO;
static int            ChannelExpireAge       = 180;
static NSTimeInterval ChannelCollectionTimer = 5 * 60;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn    = [ud boolForKey:@"GCSChannelManagerDebugEnabled"];
  debugPools = [ud boolForKey:@"GCSChannelManagerPoolDebugEnabled"];
  
  ChannelExpireAge = [[ud objectForKey:@"GCSChannelExpireAge"] intValue];
  if (ChannelExpireAge < 1)
    ChannelExpireAge = 180;
  
  ChannelCollectionTimer = 
    [[ud objectForKey:@"GCSChannelCollectionTimer"] intValue];
  if (ChannelCollectionTimer < 1)
    ChannelCollectionTimer = 5*60;
}

+ (NSString *)adaptorNameForURLScheme:(NSString *)_scheme {
  // TODO: map scheme to adaptors (eg 'postgresql://' to PostgreSQL
  return @"PostgreSQL";
}

+ (id)defaultChannelManager {
  static GCSChannelManager *cm = nil;
  if (cm == nil)
    cm = [[self alloc] init];
  return cm;
}

- (id)init {
  if ((self = [super init])) {
    self->urlToAdaptor      = [[NSMutableDictionary alloc] initWithCapacity:4];
    self->availableChannels = [[NSMutableArray alloc] initWithCapacity:16];
    self->busyChannels      = [[NSMutableArray alloc] initWithCapacity:16];

    self->gcTimer = [[NSTimer scheduledTimerWithTimeInterval:
				ChannelCollectionTimer
			      target:self selector:@selector(_garbageCollect:)
			      userInfo:nil repeats:YES] retain];
  }
  return self;
}

- (void)dealloc {
  if (self->gcTimer) [self->gcTimer invalidate];
  [self->gcTimer release];

  [self->busyChannels      release];
  [self->availableChannels release];
  [self->urlToAdaptor      release];
  [super dealloc];
}

/* DB key */

- (NSString *)databaseKeyForURL:(NSURL *)_url {
  /*
    We need to build a proper key that omits passwords and URL path components
    which are not required.
  */
  NSString *key;
  
  key = [NSString stringWithFormat:@"%@\n%@\n%@\n%@",
		  [_url host], [_url port],
		  [_url user], [_url gcsDatabaseName]];
  return key;
}

/* adaptors */

- (NSDictionary *)connectionDictionaryForURL:(NSURL *)_url {
  NSMutableDictionary *md;
  id tmp;
  
  md = [NSMutableDictionary dictionaryWithCapacity:4];

  if ((tmp = [_url host]) != nil) 
    [md setObject:tmp forKey:@"hostName"];
  if ((tmp = [_url port]) != nil) 
    [md setObject:tmp forKey:@"port"];
  if ((tmp = [_url user]) != nil) 
    [md setObject:tmp forKey:@"userName"];
  if ((tmp = [_url password]) != nil) 
    [md setObject:tmp forKey:@"password"];
  
  if ((tmp = [_url gcsDatabaseName]) != nil) 
    [md setObject:tmp forKey:@"databaseName"];
  
  [self debugWithFormat:@"build connection dictionary for URL %@: %@", 
	[_url absoluteString], md];
  return md;
}

- (EOAdaptor *)adaptorForURL:(NSURL *)_url {
  EOAdaptor *adaptor;
  NSString  *key;
  
  if (_url == nil)
    return nil;
  if ((key = [self databaseKeyForURL:_url]) == nil)
    return nil;
  if ((adaptor = [self->urlToAdaptor objectForKey:key]) != nil) {
    [self debugWithFormat:@"using cached adaptor: %@", adaptor];
    return adaptor; /* cached :-) */
  }
  
  [self debugWithFormat:@"creating new adaptor for URL: %@", _url];
  
  if ([EOAdaptor respondsToSelector:@selector(adaptorForURL:)]) {
    adaptor = [EOAdaptor adaptorForURL:_url];
  }
  else {
    NSString     *adaptorName;
    NSDictionary *condict;
    
    adaptorName = [[self class] adaptorNameForURLScheme:[_url scheme]];
    if ([adaptorName length] == 0) {
      [self errorWithFormat:@"cannot handle URL: %@", _url];
      return nil;
    }
  
    condict = [self connectionDictionaryForURL:_url];
  
    if ((adaptor = [EOAdaptor adaptorWithName:adaptorName]) == nil) {
      [self errorWithFormat:@"did not find adaptor '%@' for URL: %@", 
	    adaptorName, _url];
      return nil;
    }
  
    [adaptor setConnectionDictionary:condict];
  }
  
  [self->urlToAdaptor setObject:adaptor forKey:key];
  return adaptor;
}

/* channels */

- (GCSChannelHandle *)findBusyChannelHandleForChannel:(EOAdaptorChannel *)_ch {
  NSEnumerator *e;
  GCSChannelHandle *handle;
  
  e = [self->busyChannels objectEnumerator];
  while ((handle = [e nextObject])) {
    if ([handle channel] == _ch)
      return handle;
  }
  return nil;
}
- (GCSChannelHandle *)findAvailChannelHandleForURL:(NSURL *)_url {
  NSEnumerator *e;
  GCSChannelHandle *handle;
  
  e = [self->availableChannels objectEnumerator];
  while ((handle = [e nextObject])) {
    if ([handle canHandleURL:_url])
      return handle;
    
    if (debugPools) {
      [self logWithFormat:@"DBPOOL: cannot use handle (%@ vs %@)",
	      [_url absoluteString], [handle->url absoluteString]];
    }
  }
  return nil;
}

- (EOAdaptorChannel *)_createChannelForURL:(NSURL *)_url {
  EOAdaptor        *adaptor;
  EOAdaptorContext *adContext;
  EOAdaptorChannel *adChannel;
  
  if ((adaptor = [self adaptorForURL:_url]) == nil)
    return nil;
  
  if ((adContext = [adaptor createAdaptorContext]) == nil) {
    [self errorWithFormat:@"could not create adaptor context!"];
    return nil;
  }
  if ((adChannel = [adContext createAdaptorChannel]) == nil) {
    [self errorWithFormat:@"could not create adaptor channel!"];
    return nil;
  }
  return adChannel;
}

- (EOAdaptorChannel *)acquireOpenChannelForURL:(NSURL *)_url {
  // TODO: naive implementation, add pooling!
  EOAdaptorChannel *channel;
  GCSChannelHandle *handle;
  NSCalendarDate   *now;

  now = [NSCalendarDate date];
  
  /* look for cached handles */
  
  if ((handle = [self findAvailChannelHandleForURL:_url]) != nil) {
    // TODO: check age?
    [self->busyChannels      addObject:handle];
    [self->availableChannels removeObject:handle];
    ASSIGN(handle->lastAcquireTime, now);
    
    if (debugPools)
      [self logWithFormat:@"DBPOOL: reused cached DB channel!"];
    return [[handle channel] retain];
  }

  if (debugPools) {
    [self logWithFormat:@"DBPOOL: create new DB channel for URL: %@",
	    [_url absoluteString]];
  }
  
  /* create channel */
  
  if ((channel = [self _createChannelForURL:_url]) == nil)
    return nil;
  
  if ([channel isOpen])
    ;
  else if (![channel openChannel]) {
    [self errorWithFormat:@"could not open channel %@ for URL: %@",
	    channel, [_url absoluteString]];
    return nil;
  }
  
  /* create handle for channel */
  
  handle = [[GCSChannelHandle alloc] init];
  handle->url             = [_url retain];
  handle->channel         = [channel retain];
  handle->creationTime    = [now retain];
  handle->lastAcquireTime = [now retain];
  
  [self->busyChannels addObject:handle];
  [handle release];
  
  return [channel retain];
}
- (void)releaseChannel:(EOAdaptorChannel *)_channel {
  GCSChannelHandle *handle;
  
  if ((handle = [self findBusyChannelHandleForChannel:_channel]) != nil) {
    NSCalendarDate *now;

    now = [NSCalendarDate date];
    
    handle = [handle retain];
    ASSIGN(handle->lastReleaseTime, now);
    
    [self->busyChannels removeObject:handle];
    
    if ([[handle channel] isOpen] && [handle age] < ChannelExpireAge) {
      // TODO: consider age
      [self->availableChannels addObject:handle];
      if (debugPools) {
	[self logWithFormat:
		@"DBPOOL: keeping channel (age %ds, #%d): %@", 
	        (int)[handle age], [self->availableChannels count],
	        [handle->url absoluteString]];
      }
      [_channel release];
      [handle release];
      return;
    }

    if (debugPools) {
      [self logWithFormat:
	      @"DBPOOL: freeing old channel (age %ds)", (int)[handle age]];
    }
    
    /* not reusing channel */
    [handle release]; handle = nil;
  }
  
  if ([_channel isOpen])
    [_channel closeChannel];
  
  [_channel release];
}

/* checking for tables */

- (BOOL)canConnect:(NSURL *)_url {
  /* 
     this can check for DB connect as well as for table URLs (whether a table
     exists)
  */
  EOAdaptorChannel *channel;
  NSString *table;
  BOOL     result;
  
  if ((channel = [self acquireOpenChannelForURL:_url]) == nil) {
    if (debugOn) [self debugWithFormat:@"could not acquire channel: %@", _url];
    return NO;
  }
  if (debugOn) [self debugWithFormat:@"acquired channel: %@", channel];
  result = YES; /* could open channel */
  
  /* check whether table exists */
  
  table = [_url gcsTableName];
  if ([table length] > 0)
    result = [channel tableExistsWithName:table];
  
  /* release channel */
  
  [self releaseChannel:channel]; channel = nil;
  
  return result;
}

/* collect old channels */

- (void)_garbageCollect:(NSTimer *)_timer {
  NSMutableArray *handlesToRemove;
  unsigned i, count;
  
  if ((count = [self->availableChannels count]) == 0)
    /* no available channels */
    return;

  /* collect channels to expire */
  
  handlesToRemove = [[NSMutableArray alloc] initWithCapacity:4];
  for (i = 0; i < count; i++) {
    GCSChannelHandle *handle;
    
    handle = [self->availableChannels objectAtIndex:i];
    if (![[handle channel] isOpen]) {
      [handlesToRemove addObject:handle];
      continue;
    }
    if ([handle age] > ChannelExpireAge) {
      [handlesToRemove addObject:handle];
      continue;
    }
  }
  
  /* remove channels */
  count = [handlesToRemove count];
  if (debugPools) 
    [self logWithFormat:@"DBPOOL: garbage collecting %d channels.", count];
  for (i = 0; i < count; i++) {
    GCSChannelHandle *handle;
    
    handle = [[handlesToRemove objectAtIndex:i] retain];
    [self->availableChannels removeObject:handle];
    if ([[handle channel] isOpen])
      [[handle channel] closeChannel];
    [handle release];
  }
  
  [handlesToRemove release];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" #adaptors=%d", [self->urlToAdaptor count]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* GCSChannelManager */

@implementation GCSChannelHandle

- (void)dealloc {
  [self->channel         release];
  [self->creationTime    release];
  [self->lastReleaseTime release];
  [self->lastAcquireTime release];
  [super dealloc];
}

/* accessors */

- (EOAdaptorChannel *)channel {
  return self->channel;
}

- (BOOL)canHandleURL:(NSURL *)_url {
  BOOL isSQLite;
  
  if (_url == nil) {
    [self logWithFormat:@"MISMATCH: no url .."];
    return NO;
  }
  if (_url == self->url)
    return YES;

  isSQLite = [[_url scheme] isEqualToString:@"sqlite"];
  
  if (!isSQLite && ![[self->url host] isEqual:[_url host]]) {
    [self logWithFormat:@"MISMATCH: different host (%@ vs %@)",
	    [self->url host], [_url host]];
    return NO;
  }
  if (![[self->url gcsDatabaseName] isEqualToString:[_url gcsDatabaseName]]) {
    [self logWithFormat:@"MISMATCH: different db .."];
    return NO;
  }
  if (!isSQLite) {
    if (![[self->url user] isEqual:[_url user]]) {
      [self logWithFormat:@"MISMATCH: different user .."];
      return NO;
    }
    if ([[self->url port] intValue] != [[_url port] intValue]) {
      [self logWithFormat:@"MISMATCH: different port (%@ vs %@) ..",
  	  [self->url port], [_url port]];
      return NO;
    }
  }
  return YES;
}

- (NSTimeInterval)age {
  return [[NSCalendarDate calendarDate] 
	                  timeIntervalSinceDate:self->creationTime];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" channel=0x%p", self->channel];
  if (self->creationTime) [ms appendFormat:@" created=%@", self->creationTime];
  if (self->lastReleaseTime) 
    [ms appendFormat:@" last-released=%@", self->lastReleaseTime];
  if (self->lastAcquireTime) 
    [ms appendFormat:@" last-acquired=%@", self->lastAcquireTime];
  
  [ms appendString:@">"];
  return ms;
}

@end /* GCSChannelHandle */
