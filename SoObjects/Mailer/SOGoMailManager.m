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
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGImap4/NGImap4Connection.h>
#import <NGImap4/NGImap4ConnectionManager.h>

#import "SOGoMailManager.h"

/*
  Could check read-write state:
    dict = [[self->context client] select:[self absoluteName]];
    self->isReadOnly = 
      [[dict objectForKey:@"access"] isEqualToString:@"READ-WRITE"]
      ? NoNumber : YesNumber;
  
  TODO: to implement copy, use "uid copy" instead of "copy" as used by
        NGImap4Client.
*/

@implementation NGImap4ConnectionManager (SOGoMailManager)

- (NSException *) copyMailURL: (NSURL *) srcurl 
		  toFolderURL: (NSURL *) desturl
		     password: (NSString *) pwd
{
  NGImap4Connection *entry;
  NSNumber *destPort, *srcPort;
  NSException *error;
 
  /* check connection cache */
  
  entry = [self connectionForURL: srcurl password: pwd];
  if (entry)
    {
      /* check whether URLs are on different servers */
      srcPort = [srcurl port];
      destPort = [desturl port];

      if ([[desturl host] isEqualToString: [srcurl host]]
	  && (srcPort == destPort
	      || [destPort isEqualToNumber: srcPort]))
	error = [entry copyMailURL: srcurl toFolderURL: desturl];
      else
	error = [NSException exceptionWithHTTPStatus: 502 /* Bad Gateway */
			     reason: @"source and destination on different servers"];
    }
  else
    error = [NSException exceptionWithHTTPStatus: 404 /* Not Found */
			 reason: @"Did not find mail URL"];

  return error;
}

@end /* NGImap4ConnectionManager(SOGoMailManager) */
