/* SOGoCredentialsFile.m - this file is part of SOGo
 *
 * Copyright (C) 2013 Inverse inc.
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

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>

#import "SOGoCredentialsFile.h"

@implementation SOGoCredentialsFile

+ (id) credentialsFromFile: (NSString *) file
{
  SOGoCredentialsFile *newCreds;
  newCreds = [[self  alloc] initFromFile: file
                            withEncoding: NSUTF8StringEncoding];
  [newCreds autorelease];
  return newCreds;
}


- (id) init
{
  if ((self = [super init]))
    {
      _username = nil;
      _password = nil;
      _credentialsFile = nil;
    }
  return self;
}

- (void) dealloc
{
  [_username release];
  [_password release];
  [_credentialsFile release];
  [super dealloc];
}

- (id) initFromFile: (NSString *) file
       withEncoding: (NSStringEncoding) enc
{
  id ret;
  NSData *credentialsData;
  NSRange r;
  NSString *creds;

  ret = nil;
  if (file)
    {
      if ((self = [self init]))
        {
          credentialsData = [NSData dataWithContentsOfFile: file];
          if (credentialsData == nil)
            NSLog(@"Failed to load credentials file: %@", file);
          else
            {
              creds = [[NSString alloc] initWithData: credentialsData
                                            encoding: enc];
              [creds autorelease];
              creds = [creds stringByTrimmingCharactersInSet: 
                [NSCharacterSet characterSetWithCharactersInString: @"\r\n"]];
              r = [creds rangeOfString: @":"];
              if (r.location == NSNotFound)
                NSLog(@"Invalid credentials file content, missing ':' separator (%@)", file);
              else
                {
                  _username = [[creds substringToIndex: r.location] retain];
                  _password = [[creds substringFromIndex: r.location+1] retain];
                  _credentialsFile = [file retain];
                  ret = self;
                }
            }
        }
    }
  return ret;
}


- (NSString *) username
{
  return self->_username;
}

- (NSString *) password
{
  return self->_password;
}

- (NSString *) credentialsFile
{
  return self->_credentialsFile;
}

@end
