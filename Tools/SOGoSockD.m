/* SOGoSockD.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2017 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSUserDefaults.h>

#import <NGStreams/NGActiveSocket.h>
#import <NGStreams/NGLocalSocketAddress.h>
#import <NGStreams/NGPassiveSocket.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoSockDScanner.h"
#import "SOGoSockD.h"

@implementation SOGoSockD

- (void) _setupListeningSocket
{
  NGLocalSocketAddress *address;
  NSString *path;
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  path = [ud stringForKey: @"SOGoSLAPDSocketPath"];
  if (!path)
    path = @"/var/run/sogo/sogo-sockd.sock";

  address = [NGLocalSocketAddress addressWithPath: path];
  ASSIGN (listeningSocket, [NGPassiveSocket socketBoundToAddress: address]);
  [listeningSocket listenWithBacklog: 5];
  [self logWithFormat: @"listening on %@", path];
}

- (BOOL) _startRunLoopWithSocket: (NGPassiveSocket *) socket
{
  NSRunLoop *runLoop;
  NSDate *limitDate;
  BOOL terminate;
  void *fdPtr;

  runLoop = [NSRunLoop currentRunLoop];
#if LONG_MAX > INT_MAX
  fdPtr = (void *) ([socket fileDescriptor] & 0xFFFFFFFFFFFFFFFF);
#else
  fdPtr = (void *) [socket fileDescriptor];
#endif
  [runLoop addEvent: fdPtr type: ET_RDESC
            watcher: self forMode: NSDefaultRunLoopMode];

  terminate = NO;
  while (!terminate)
    {
      limitDate = [runLoop limitDateForMode: NSDefaultRunLoopMode];
      [runLoop runMode: NSDefaultRunLoopMode beforeDate: limitDate];
    }

  return YES;
}

- (BOOL) run
{
  BOOL rc;

  [self _setupListeningSocket];
  if (listeningSocket)
    rc = [self _startRunLoopWithSocket: listeningSocket];
  else
    rc = NO;

  return rc;
}

- (BOOL) _handleData: (NSData *) socketData
            onSocket: (id <NGActiveSocket>) responseSocket
{
  NSString *stringData;
  SOGoSockDScanner *scanner;
  SOGoSockDOperation *operation;
  BOOL rc;

  stringData = [[NSString alloc] initWithData: socketData
                                     encoding: NSASCIIStringEncoding];
  if (stringData)
    {
      scanner = [SOGoSockDScanner scannerWithString: stringData];
      operation = [scanner operation];
      if (operation)
        {
          rc = YES;
          [operation respondOnSocket: (NGActiveSocket *) responseSocket];
        }
      else
        rc = NO;
    }
  else
    rc = NO;

  return rc;
}

- (void) _acceptAndHandle
{
  id <NGActiveSocket> socket;
  char buffer[1024];
  unsigned int count;
  NSMutableData *socketData;
  BOOL done;
  NSAutoreleasePool *pool;

  pool = [NSAutoreleasePool new];
  socketData = [NSMutableData dataWithCapacity: 16384];

  socket = [listeningSocket accept];
  done = NO;

  while (!done)
    {
      count = [socket readBytes: buffer count: 1024];
      if (count == NGStreamError)
        done = YES;
      else
        {
          if (buffer[count-2] == '\n' && buffer[count-1] == '\n')
            {
              done = YES;
              count -= 2;
            }
          [socketData appendBytes: buffer length: count];
          [self _handleData: socketData onSocket: socket];
          socketData = [NSMutableData dataWithCapacity: 16384];
        }
    }
  [pool release];
}

- (void) receivedEvent: (void*) data
		  type: (RunLoopEventType) type
		 extra: (void*) extra
	       forMode: (NSString*) mode
{
  if (type == ET_RDESC)
    [self _acceptAndHandle];
}

@end
