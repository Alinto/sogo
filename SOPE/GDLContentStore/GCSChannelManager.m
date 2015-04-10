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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAdaptorContext.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import "GCSChannelManager.h"
#import "NSURL+GCS.h"
#import "EOAdaptorChannel+GCS.h"

/*
  TODO:
  - implemented pooling
  - auto-close channels which are very old?!
  (eg missing release due to an exception)
*/

@interface GCSChannelHandle : NSObject
{
@public
  NSURL *url;
  EOAdaptorChannel *channel;
  NSDate *creationTime;
  NSDate *lastReleaseTime;
  NSDate *lastAcquireTime;
}

- (EOAdaptorChannel *) channel;
- (BOOL) canHandleURL: (NSURL *) _url;
- (NSTimeInterval) age;

@end

@implementation GCSChannelManager

static BOOL debugOn = NO;
static BOOL debugPools = NO;
static int ChannelExpireAge = 180;
static NSTimeInterval ChannelCollectionTimer = 5 * 60;

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  debugOn = [ud boolForKey: @"GCSChannelManagerDebugEnabled"];
  debugPools = [ud boolForKey: @"GCSChannelManagerPoolDebugEnabled"];

  ChannelExpireAge = [[ud objectForKey: @"GCSChannelExpireAge"] intValue];
  if (ChannelExpireAge < 1)
    ChannelExpireAge = 180;

  ChannelCollectionTimer =
    [[ud objectForKey: @"GCSChannelCollectionTimer"] intValue];
  if (ChannelCollectionTimer < 1)
    ChannelCollectionTimer = 5*60;
}

+ (NSString *) adaptorNameForURLScheme: (NSString *) _scheme
{
  // TODO: map scheme to adaptors (eg 'postgresql: //' to PostgreSQL
  return @"PostgreSQL";
}

+ (id) defaultChannelManager
{
  static GCSChannelManager *cm = nil;

  if (!cm)
    cm = [self new];

  return cm;
}

- (id) init
{
  if ((self = [super init]))
    {
      urlToAdaptor = [[NSMutableDictionary alloc] initWithCapacity: 4];
      lastFailures = [[NSMutableDictionary alloc] initWithCapacity: 4];
      availableChannels = [[NSMutableArray alloc] initWithCapacity: 16];
      busyChannels = [[NSMutableArray alloc] initWithCapacity: 16];

      gcTimer = [[NSTimer scheduledTimerWithTimeInterval:
			    ChannelCollectionTimer
			  target: self selector: @selector (_garbageCollect:)
			  userInfo: nil repeats: YES] retain];
    }

  return self;
}

- (void) dealloc
{
  if (gcTimer)
    [gcTimer invalidate];

  [busyChannels release];
  [availableChannels release];
  [lastFailures release];
  [urlToAdaptor release];
  [super dealloc];
}

/* adaptors */

- (NSDictionary *) connectionDictionaryForURL: (NSURL *) _url
{
  NSMutableDictionary *md;
  id tmp;

  md = [NSMutableDictionary dictionaryWithCapacity: 4];

  if ((tmp = [_url host]))
    [md setObject: tmp forKey: @"hostName"];
  if ((tmp = [_url port]))
    [md setObject: tmp forKey: @"port"];
  if ((tmp = [_url user]))
    [md setObject: tmp forKey: @"userName"];
  if ((tmp = [_url password]))
    [md setObject: tmp forKey: @"password"];

  if ((tmp = [_url gcsDatabaseName]))
    [md setObject: tmp forKey: @"databaseName"];

  [self debugWithFormat: @"build connection dictionary for URL %@: %@",
	[_url absoluteString], md];

  return md;
}

- (EOAdaptor *) adaptorForURL: (NSURL *) _url
{
  EOAdaptor *adaptor;
  NSString *key;
  NSString *adaptorName;
  NSDictionary *condict;

  adaptor = nil;

  if (_url)
    {
      if ((key = [_url gcsURLId]))
	{
	  adaptor = [urlToAdaptor objectForKey: key];
	  if (adaptor)
	    [self debugWithFormat: @"using cached adaptor: %@", adaptor];
	  else
	    {
	      [self debugWithFormat: @"creating new adaptor for URL: %@", _url];
	  
	      if ([EOAdaptor respondsToSelector: @selector (adaptorForURL:)])
		adaptor = [EOAdaptor adaptorForURL: _url];
	      else
		{
		  adaptorName = [[self class]
				  adaptorNameForURLScheme: [_url scheme]];
		  if ([adaptorName length])
		    {
		      condict = [self connectionDictionaryForURL: _url];

		      adaptor = [EOAdaptor adaptorWithName: adaptorName];
		      if (adaptor)
			[adaptor setConnectionDictionary: condict];
		      else
			[self errorWithFormat:
				@"did not find adaptor '%@' for URL: %@",
			      adaptorName, _url];
		    }
		  else
		    [self errorWithFormat: @"cannot handle URL: %@", _url];
		}
	  
	      [urlToAdaptor setObject: adaptor forKey: key];
	    }
	}
    }

  return adaptor;
}

/* channels */

- (GCSChannelHandle *)
 findBusyChannelHandleForChannel: (EOAdaptorChannel *) _ch
{
  NSEnumerator *e;
  GCSChannelHandle *handle, *currentHandle;

  handle = NULL;

  e = [busyChannels objectEnumerator];
  while (!handle && (currentHandle = [e nextObject]))
    if ([currentHandle channel] == _ch)
      handle = currentHandle;

  return handle;
}

- (GCSChannelHandle *) findAvailChannelHandleForURL: (NSURL *) _url
{
  NSEnumerator *e;
  GCSChannelHandle *handle, *currentHandle;

  handle = nil;

  e = [availableChannels objectEnumerator];
  while (!handle && (currentHandle = [e nextObject]))
    if ([currentHandle canHandleURL: _url])
      handle = currentHandle;
    else if (debugPools)
      [self logWithFormat: @"DBPOOL: cannot use handle (%@ vs %@) ",
	    [_url absoluteString], [currentHandle->url absoluteString]];

  return handle;
}

- (EOAdaptorChannel *) _createChannelForURL: (NSURL *) _url
{
  EOAdaptor *adaptor;
  EOAdaptorContext *adContext;
  EOAdaptorChannel *adChannel;

  adChannel = nil;

  adaptor = [self adaptorForURL: _url];
  if (adaptor)
    {
      adContext = [adaptor createAdaptorContext];
      if (adContext)
	{
	  adChannel = [adContext createAdaptorChannel];
	  if (!adChannel)
	    [self errorWithFormat: @"could not create adaptor channel!"];
	}
      else
	[self errorWithFormat: @"could not create adaptor context!"];
    }

  return adChannel;
}

- (EOAdaptorChannel *) acquireOpenChannelForURL: (NSURL *) _url
{
  // TODO: naive implementation, add pooling!
  EOAdaptorChannel *channel;
  GCSChannelHandle *handle;
  NSCalendarDate *now, *lastFailure;
  NSString *urlId, *url;

  channel = nil;
  urlId = [_url gcsURLId];

  now = [NSCalendarDate date];
  lastFailure = [lastFailures objectForKey: urlId];
  if ([[lastFailure dateByAddingYears: 0 months: 0 days: 0
                                hours: 0 minutes: 0 seconds: 5]
        earlierDate: now] != now)
    {
      /* look for cached handles */

      handle = [self findAvailChannelHandleForURL: _url];
      if (handle)
        {
          // TODO: check age?
          [busyChannels addObject: handle];
          [availableChannels removeObject: handle];
          ASSIGN (handle->lastAcquireTime, now);

          channel = [handle channel];
          if (debugPools)
            [self logWithFormat: @"DBPOOL: reused cached DB channel! (%p)",
                  channel];
        }
      else
        {
          url = [NSString stringWithFormat: @"%@://%@%@", [_url scheme], [_url host], [_url path]];
          if (debugPools)
            {
              [self logWithFormat: @"DBPOOL: create new DB channel for %@", url];
            }

          /* create channel */
          channel = [self _createChannelForURL: _url];
          if (channel)
            {
              if ([channel isOpen]
                  || [channel openChannel])
                {
                  /* create handle for channel */

                  handle = [[GCSChannelHandle alloc] init];
                  handle->url = [_url retain];
                  handle->channel = [channel retain];
                  handle->creationTime = [now retain];
                  handle->lastAcquireTime = [now retain];

                  [busyChannels addObject: handle];
                  [handle release];

                  if (lastFailure)
                    {
                      [self logWithFormat: @"db for %@ is now back up", url];
                      [lastFailures removeObjectForKey: urlId];
                    }
                }
              else
                {
                  [self errorWithFormat: @"could not open channel %@ for %@", channel, url];
                  channel = nil;
                  [lastFailures setObject: now forKey: urlId];
                  [self warnWithFormat: @"  will prevent opening of this"
                        @" channel 5 seconds after %@", now];
                }
            }
        }
    }

  return channel;
}

- (void) releaseChannel: (EOAdaptorChannel *) _channel
{
  [self releaseChannel: _channel immediately: NO];
}

- (void) releaseChannel: (EOAdaptorChannel *) _channel
            immediately: (BOOL) _immediately
{
  GCSChannelHandle *handle;
  BOOL keepOpen;

  handle = [self findBusyChannelHandleForChannel: _channel];
  if (handle)
    {
      [handle retain];

      ASSIGN (handle->lastReleaseTime, [NSCalendarDate date]);
      [busyChannels removeObject: handle];

      keepOpen = NO;
      if (!_immediately && [_channel isOpen]
          && [handle age] < ChannelExpireAge)
	{
	  keepOpen = YES;
	  // TODO: consider age
	  [availableChannels addObject: handle];
	  if (debugPools)
	    [self logWithFormat:
		    @"DBPOOL: keeping channel (age %ds, #%d, %p) : %@",
		  (int)
		  [handle age], [availableChannels count],
		  [handle->url absoluteString],
		  _channel];
	}
      else if (debugPools)
	{
	  [self logWithFormat:
		  @"DBPOOL: freeing old channel (age %ds, %p) ", (int)
		[handle age], _channel];
	}
      if (!keepOpen && [_channel isOpen])
	[_channel closeChannel];
      [handle release];
    }
  else
    {
      if ([_channel isOpen])
	[_channel closeChannel];

      [_channel release];
    }
}

/* checking for tables */

- (BOOL) canConnect: (NSURL *) _url
{
  /*
    this can check for DB connect as well as for table URLs (whether a table
    exists)
  */
  EOAdaptorChannel *channel;
  NSString *table;
  BOOL result;

  channel = [self acquireOpenChannelForURL: _url];
  if (channel)
    {
      if (debugOn)
	[self debugWithFormat: @"acquired channel: %@", channel];

      /* check whether table exists */
      table = [_url gcsTableName];
      if ([table length] > 0)
	result = [channel tableExistsWithName: table];
      else
	result = YES; /* could open channel */
      
      /* release channel */
      [self releaseChannel: channel];
    }
  else
    {
      if (debugOn)
	[self debugWithFormat: @"could not acquire channel: %@", _url];
      result = NO;
    }

  return result;
}

/* collect old channels */

- (void) _garbageCollect: (NSTimer *) _timer
{
  NSMutableArray *handlesToRemove;
  unsigned i, count;
  GCSChannelHandle *handle;

  count = [availableChannels count];
  if (count)
    {
      /* collect channels to expire */

      handlesToRemove = [[NSMutableArray alloc] initWithCapacity: count];
      for (i = 0; i < count; i++)
	{
	  handle = [availableChannels objectAtIndex: i];
	  if ([[handle channel] isOpen])
	    {
	      if ([handle age] > ChannelExpireAge)
		[handlesToRemove addObject: handle];
	    }
	  else
	    [handlesToRemove addObject: handle];
	}

      /* remove channels */
      count = [handlesToRemove count];
      if (debugPools)
	[self logWithFormat: @"DBPOOL: garbage collecting %d channels.", count];
      for (i = 0; i < count; i++)
	{
	  handle = [handlesToRemove objectAtIndex: i];
	  [handle retain];
	  [availableChannels removeObject: handle];
	  if ([[handle channel] isOpen])
	    [[handle channel] closeChannel];
	  [handle release];
	}

      [handlesToRemove release];
    }
}

/* debugging */

- (BOOL) isDebuggingEnabled
{
  return debugOn;
}

/* description */

- (NSString *) description
{
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity: 256];
  [ms appendFormat: @"<0x%p[%@]: ", self, NSStringFromClass ([self class])];

  [ms appendFormat: @" #adaptors=%d", [urlToAdaptor count]];

  [ms appendString: @">"];
  return ms;
}

@end /* GCSChannelManager */

@implementation GCSChannelHandle

- (void) dealloc
{
  [channel release];
  [creationTime release];
  [lastReleaseTime release];
  [lastAcquireTime release];
  [super dealloc];
}

/* accessors */

- (EOAdaptorChannel *) channel
{
  return channel;
}

- (BOOL) canHandleURL: (NSURL *) _url
{
  BOOL result;

  result = NO;

  if (_url)
    {
      if (_url == url
	  || [[_url scheme] isEqualToString: @"sqlite"])
	result = YES;
      else if ([[url host] isEqual: [_url host]])
	{
	  if ([[url gcsDatabaseName]
		isEqualToString: [_url gcsDatabaseName]])
	    {
	      if ([[url user] isEqual: [_url user]])
		{
		  if ([[url port] intValue] == [[_url port] intValue])
		    result = YES;
		  else if (debugOn)
		    [self logWithFormat:
			    @"MISMATCH: different port (%@ vs %@) ..",
			  [url port], [_url port]];
		}
	      else if (debugOn)
		[self logWithFormat: @"MISMATCH: different user .."];
	    }
	  else if (debugOn)
	    [self logWithFormat: @"MISMATCH: different db .."];
	}
      else if (debugOn)
	[self logWithFormat: @"MISMATCH: different host (%@ vs %@) ",
	      [url host], [_url host]];
    }
  else if (debugOn)
    [self logWithFormat: @"MISMATCH: no url .."];

  return result;
}

- (NSTimeInterval) age
{
  return [[NSCalendarDate calendarDate]
	   timeIntervalSinceDate: creationTime];
}

/* NSCopying */

- (id) copyWithZone: (NSZone *) _zone
{
  return [self retain];
}

/* description */

- (NSString *) description
{
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity: 256];
  [ms appendFormat: @"<0x%p[%@]: ", self, NSStringFromClass ([self class])];

  [ms appendFormat: @" channel=0x%p", channel];
  if (creationTime)
    [ms appendFormat: @" created=%@", creationTime];
  if (lastReleaseTime)
    [ms appendFormat: @" last-released=%@", lastReleaseTime];
  if (lastAcquireTime)
    [ms appendFormat: @" last-acquired=%@", lastAcquireTime];

  [ms appendString: @">"];

  return ms;
}

@end /* GCSChannelHandle */
