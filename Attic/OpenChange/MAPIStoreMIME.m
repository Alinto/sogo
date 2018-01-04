/* MAPIStoreMIME.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSString.h>

#import "MAPIStoreMIME.h"

/* Seems common to all distros ? */
#define MAPIStoreMIMEFile @"/etc/mime.types"

@implementation MAPIStoreMIME

+ (id) sharedMAPIStoreMIME
{
  static MAPIStoreMIME *sharedInstance = nil;

  if (!sharedInstance)
    sharedInstance = [self new];

  return sharedInstance;
}

- (void) _parseLine: (const char *) line
         withLength: (NSUInteger) length
{
  NSUInteger count = 0, lastWord = 0;
  NSString *mimeType = nil, *word;
  NSData *wordData;
  BOOL comment = NO;

  while (count < length && !comment)
    {
      while (count < length
             && (line[count] == ' ' || line[count] == '\t'))
        count++;
      lastWord = count;
      while (count < length
             && line[count] != ' ' && line[count] != '\t'
             && !comment)
        {
          if (line[count] == '#')
            comment = YES;
          else
            count++;
        }
      if (count > lastWord)
        {
          wordData = [NSData dataWithBytes: line + lastWord
                                    length: count - lastWord];
          word = [[NSString alloc] initWithData: wordData
                                       encoding: NSASCIIStringEncoding];
          if (word)
            {
              if (mimeType)
                {
                  [mimeDict setObject: mimeType forKey: word];
                  [word release];
                }
              else
                mimeType = word;
            }
        }
    }

  [mimeType release];
}

- (void) _parseContent: (NSData *) content
{
  const char *data;
  NSUInteger lineStart = 0, bytesRead = 0, max;

  data = [content bytes];
  max = [content length];
  bytesRead = 0;
  lineStart = 0;

  while (bytesRead < max)
    {
      if (data[bytesRead] == '\n')
        {
          [self _parseLine: data + lineStart withLength: bytesRead - lineStart];
          lineStart = bytesRead + 1;
        }
      else if (data[bytesRead] == '\r')
        {
          [self _parseLine: data + lineStart withLength: bytesRead - lineStart];
          if (bytesRead < (max - 1) && data[bytesRead] == '\n')
            lineStart = bytesRead + 2;
          else
            lineStart = bytesRead + 1;
        }
      bytesRead++;
    }

  if (bytesRead > (lineStart + 1))
    [self _parseLine: data + lineStart withLength: bytesRead - lineStart];
}

- (void) _readMIMEFile
{
  NSFileHandle *inH;
  NSData *content;

  inH = [NSFileHandle fileHandleForReadingAtPath: MAPIStoreMIMEFile];
  content = [inH readDataToEndOfFile];
  [self _parseContent: content];
}

- (id) init
{
  if ((self = [super init]))
    {
      mimeDict = [NSMutableDictionary new];
      [self _readMIMEFile];
    }

  return self;
}

- (void) dealloc
{
  [mimeDict release];
  [super dealloc];
}

- (NSString *) mimeTypeForExtension: (NSString *) extension
{
  return [mimeDict objectForKey: [extension lowercaseString]];
}

@end
