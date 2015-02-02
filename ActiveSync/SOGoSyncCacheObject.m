/*

Copyright (c) 2014, Inverse inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Inverse inc. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

#include "SOGoSyncCacheObject.h"

#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

@implementation SOGoSyncCacheObject

- (id) init
{
  if ((self = [super init]))
    {
      _uid = nil;
      _sequence = nil;
    }

  return self;
}

+ (id) syncCacheObjectWithUID: (id) theUID  sequence:  (id) theSequence;
{
  id o;

  o = [[self alloc] init];
 
  [o setUID: theUID];
  [o setSequence: theSequence];
  
  return [o autorelease];
}

- (void) dealloc
{
  RELEASE(_uid);
  RELEASE(_sequence);
  [super dealloc];
}

- (id) uid
{
  return _uid;
}

- (void) setUID: (id) theUID
{
  ASSIGN(_uid, theUID);
}

- (id) sequence
{
  return _sequence;
}

- (void) setSequence: (id) theSequence
{
  ASSIGN(_sequence, theSequence);
}


- (NSComparisonResult) compareUID: (SOGoSyncCacheObject *) theSyncCacheObject
{
  return [[self uid] compare: [theSyncCacheObject uid]];
}

//
// We might get NSNull values here, so if both are NSNull instances,
// we sort by UID. If both sequences are equal, we also sort by UID.
//
- (NSComparisonResult) compareSequence: (SOGoSyncCacheObject *) theSyncCacheObject
{
  if ([[self sequence] isEqual: [NSNull null]] &&
      [[theSyncCacheObject sequence] isEqual: [NSNull null]])
    return [self compareUID: theSyncCacheObject];
  
  if (![[self sequence] isEqual: [NSNull null]] && [[theSyncCacheObject sequence] isEqual: [NSNull null]])
    return NSOrderedDescending;
  
  if ([[self sequence] isEqual: [NSNull null]] && ![[theSyncCacheObject sequence] isEqual: [NSNull null]])
    return NSOrderedAscending;
  
  // Must check this here, to avoid comparing NSNull objects
  if ([[self sequence] compare: [theSyncCacheObject sequence]] == NSOrderedSame)
    return [self compareUID: theSyncCacheObject];
  
  return [[self sequence] compare: [theSyncCacheObject sequence]];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@-%@", _uid, _sequence];
}

@end
