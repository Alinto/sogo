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

#ifndef __GDLContentStore_GCSChannelManager_H__
#define __GDLContentStore_GCSChannelManager_H__


/*
  GCSChannelManager

  This object manages the connection pooling.
*/

@class NSURL, NSMutableDictionary, NSMutableArray, NSTimer;
@class EOAdaptorChannel, EOAdaptor;

@interface GCSChannelManager : NSObject
{
  NSMutableDictionary *urlToAdaptor;

  NSMutableDictionary *lastFailures;

  NSMutableArray *availableChannels;
  NSMutableArray *busyChannels;
  NSTimer        *gcTimer;
}

+ (id)defaultChannelManager;

/* channels */

- (EOAdaptorChannel *)acquireOpenChannelForURL:(NSURL *)_url;
- (void)releaseChannel:(EOAdaptorChannel *)_channel;
- (void)releaseChannel:(EOAdaptorChannel *)_channel
           immediately:(BOOL)_immediately;
- (void) releaseAllChannels;

/* checking for tables */

- (BOOL)canConnect:(NSURL *)_url;

@end

#endif /* __GDLContentStore_GCSChannelManager_H__ */
