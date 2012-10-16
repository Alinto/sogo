/* SOGoSession.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2011 Inverse inc.
 *
 * Author: Ludovic Marcotte <lmarcotte@inverse.ca>
 *         Francis Lachapelle <flachapelle@inverse.ca>

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

#include "SOGoSession.h"

#include "SOGoCache.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <GDLContentStore/GCSSessionsFolder.h>
#import <GDLContentStore/GCSFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import <NGExtensions/NGBase64Coding.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#import "SOGoSystemDefaults.h"

@implementation SOGoSession

+ (NSString *) valueForSessionKey: (NSString *) theSessionKey
{
  NSString *value, *key;
  SOGoCache *cache;

  cache = [SOGoCache sharedCache];

  key = [NSString stringWithFormat: @"session:%@", theSessionKey];
  value = [cache valueForKey: key];

  // We go check in the database
  if (!value)
    {
      GCSSessionsFolder *folder;
      NSDictionary *d;

      folder = [[GCSFolderManager defaultFolderManager] sessionsFolder];
      d = [folder recordForEntryWithID: theSessionKey];

      if (d)
	{
	  // We cache back the result in memcached
	  value = [d objectForKey: @"c_value"];
	  [cache setValue: value   forKey: key];
	  
	  // We update c_lastseen. We do this only when we get a cache miss from memcached
	  // and when the data was reloaded from the database to avoid updating it too often.
	  // This is good enough since this information would be mostly used to cleanup
	  // dead sessions - and not really to know when was the last time a user
	  // invoke an action method on SOGo.
	  [folder writeRecordForEntryWithID: theSessionKey
		  value: value
		  creationDate: [NSDate dateWithTimeIntervalSince1970: [[d objectForKey: @"c_creationdate"] intValue]]
		  lastSeenDate: [NSCalendarDate date]];
	}
    }
  
  return value;
}

+ (void) setValue: (NSString *) theValue
    forSessionKey: (NSString *) theSessionKey
{
  GCSSessionsFolder *folder;
  NSCalendarDate *now;
  SOGoCache *cache;
  NSString *key;

  cache = [SOGoCache sharedCache];

  key = [NSString stringWithFormat: @"session:%@", theSessionKey];
  
  [cache setValue: theValue   forKey: key];

  // We store it inside the database
  folder = [[GCSFolderManager defaultFolderManager] sessionsFolder];
 
  now = [NSCalendarDate date];
  [folder writeRecordForEntryWithID: theSessionKey
	  value: theValue
	  creationDate: now
	  lastSeenDate: now];
}

//
//
//
+ (void) deleteValueForSessionKey: (NSString *) theSessionKey
{
  GCSSessionsFolder *folder;
  
  folder = [[GCSFolderManager defaultFolderManager] sessionsFolder];

  [folder deleteRecordForEntryWithID: theSessionKey];
  [[SOGoCache sharedCache] removeValueForKey: [NSString stringWithFormat: @"session:%@", theSessionKey]];
}

//
//
//
+ (NSString *) generateKeyForLength: (unsigned int) theLength
{
  char *buf;
  int fd;
  
  fd = open("/dev/urandom", O_RDONLY);

  if (fd > 0)
    {
      NSData *data;
      NSString *s;

      buf = (char *)malloc(theLength);
      read(fd, buf, theLength);
      close(fd);

      // We encode the bytes in base64 with a line lenght fixed to 1024 since
      // we want to avoid folding the values
      data = [NSData dataWithBytesNoCopy: buf  length: theLength  freeWhenDone: YES];
    
      s = [[NSString alloc] initWithData: [data dataByEncodingBase64WithLineLength: 1024]
			    encoding: NSASCIIStringEncoding];
      return [s autorelease];
    }

  return nil;
}

//
// The key will likely be longer than the password. We don't care
// that much about this for now.
//
+ (NSString *) securedValue: (NSString *) theValue
		   usingKey: (NSString *) theKey
{
  NSData *data;
  NSString *s;

  char *buf, *key, *pass;
  int i, klen;

  // Get the key length and its bytes
  data = [theKey dataByDecodingBase64];
  key = (char *)[data bytes];
  klen = [data length];

  // Get the key - padding it with 0 with key length
  pass = (char *)malloc(klen);
  memset(pass, 0, klen);
  [theValue getCString: pass  maxLength: klen  encoding: NSUTF8StringEncoding];

  // Target buffer
  buf = (char *)malloc(klen);
 
  for (i = 0; i < klen; i++)
    {
      buf[i] = key[i] ^ pass[i];
    }

  free(pass);

  data = [NSData dataWithBytesNoCopy: buf  length: klen  freeWhenDone: YES];
  
  s = [[NSString alloc] initWithData: [data dataByEncodingBase64WithLineLength: 1024]
			encoding: NSASCIIStringEncoding];
  return [s autorelease];
}


+ (NSString *) valueFromSecuredValue: (NSString *) theValue
			    usingKey: (NSString *) theKey
{
  NSData *data;
  NSString *s;
  
  char *buf, *key, *pass;
  int i, klen;

  // Get the key length and its bytes
  data = [theKey dataByDecodingBase64];
  key = (char *)[data bytes];
  klen = [data length];

  // Get the secured password
  pass = (char *)[[theValue dataByDecodingBase64] bytes];
  
  // Target buffer
  buf = (char *)malloc(klen);

  for (i = 0; i < klen; i++)
    {
      buf[i] = key[i] ^ pass[i];
    }

  // buf is now our C string in UTF8
  s = [NSString stringWithCString: buf  encoding: NSUTF8StringEncoding];
  free(buf);

  return s;
}

/**
 *
 * @param theValue
 * @param theKey
 * @param theLogin
 * @param theDomain
 * @param thePassword
 * @see [SOGoUser initWithLogin:roles:trust:]
 */
+ (void) decodeValue: (NSString *) theValue
	    usingKey: (NSString *) theKey
               login: (NSString **) theLogin
              domain: (NSString **) theDomain
            password: (NSString **) thePassword
{
  NSString *decodedValue;
  NSRange r;
  SOGoSystemDefaults *sd;
   
  decodedValue = [SOGoSession valueFromSecuredValue: theValue
			      usingKey: theKey];
  
  r = [decodedValue rangeOfString: @":"];
  *theLogin = [decodedValue substringToIndex: r.location];
  *thePassword = [decodedValue substringFromIndex: r.location+1];
  *theDomain = nil;
  
  sd = [SOGoSystemDefaults sharedSystemDefaults];
  if ([sd enableDomainBasedUID])
    {
      r = [*theLogin rangeOfString: @"@" options: NSBackwardsSearch];
      if (r.location != NSNotFound)
        {
          // The domain is probably appended to the username;
          // make sure it is defined as a domain in the configuration.
          *theDomain = [*theLogin substringFromIndex: (r.location + r.length)];
          if ([[sd domainIds] containsObject: *theDomain])
            *theLogin = [*theLogin substringToIndex: r.location];
          else
            *theDomain = nil;
        }
    }
}

@end
