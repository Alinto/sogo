/* SOGoMailObject+Draft.m - this file is part of SOGo
 *
 * Copyright (C) 2007 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <Foundation/NSArray.h>

#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "SOGoMailObject+Draft.h"

#define maxFilenameLength 64

@implementation SOGoMailObject (SOGoDraftObjectExtensions)

- (NSString *) subjectForReply
{
  static NSString *replyPrefixes[] = {
    @"Re:", // regular
    @"RE:", // Outlook v11 (English?)
    @"AW:", // German Outlook v11
    @"Re[", // numbered Re, eg "Re[2]:"
    nil
  };
  BOOL hasPrefix;
  unsigned int i;
  NSString *subject, *newSubject;

  hasPrefix = NO;

  subject = [[self envelope] subject];
  i = 0;
  while (!hasPrefix && replyPrefixes[i])
    if ([subject hasPrefix: replyPrefixes[i]])
      hasPrefix = YES;
    else
      i++;

  if (hasPrefix)
    newSubject = subject;
  else
    newSubject = [NSString stringWithFormat: @"Re: %@", subject];

  return newSubject;
}

- (NSString *) contentForReplyOnParts: (NSDictionary *) _prts
                                 keys: (NSArray *) _k
{
  static NSString *textPartSeparator = @"\n---\n";
  NSMutableString *ms;
  unsigned int count, max;
  NSString *k, *v;
  
  ms = [NSMutableString stringWithCapacity: 16000];

  max = [_k count];
  for (count = 0; count < max; count++)
    {
      k = [_k objectAtIndex: count];
   
    // TODO: this is DUP code to SOGoMailObject
      if ([k isEqualToString: @"body[text]"])
	k = @"";
      else if ([k hasPrefix: @"body["]) {
	k = [k substringFromIndex: 5];
	if ([k length] > 0)
	  k = [k substringToIndex: ([k length] - 1)];
      }

      v = [_prts objectForKey: k];
      if ([v isKindOfClass: [NSString class]]
	  && [v length] > 0)
	{
	  if (count > 0)
	    [ms appendString: textPartSeparator];
	  [ms appendString: [v stringByApplyingMailQuoting]];
	}
      else
	[self logWithFormat:@"Note: cannot show part %@", k];
    }

  return ms;
}

#warning this method should be fixed to return the first available text/plain \
         part, and otherwise the first text/html part converted to text
- (NSString *) contentForReply
{
  NSArray *keys;
  NSDictionary *parts;
  NSMutableArray *topLevelKeys = nil;
  unsigned int count, max;
  NSRange r;
  NSString *contentForReply;

//   SOGoMailObject *co;

//   co = self;
//   keys = [co plainTextContentFetchKeys];
//   infos = [co fetchCoreInfos];
//   partInfos = [infos objectForKey: keys];
//   NSLog (@"infos: '%@'", infos);

  keys = [self plainTextContentFetchKeys];
  max = [keys count];
  if (max > 0)
    {
      if (max > 1)
	{
	  /* filter keys, only include top-level, or if none, the first */
	  for (count = 0; count < max; count++)
	    {
	      r = [[keys objectAtIndex: count] rangeOfString: @"."];
	      if (!r.length)
		{
		  if (!topLevelKeys)
		    topLevelKeys = [NSMutableArray arrayWithCapacity: 4];
		  [topLevelKeys addObject: [keys objectAtIndex: count]];
		}
	    }

	  if ([topLevelKeys count] > 0)
	    /* use top-level keys if we have some */
	    keys = topLevelKeys;
	  else
	    /* just take the first part */
	    keys = [NSArray arrayWithObject: [keys objectAtIndex: 0]];
	}

      parts = [self fetchPlainTextStrings: keys];
      contentForReply = [self contentForReplyOnParts: parts
			      keys: keys];
    }
  else
    contentForReply = nil;

  return contentForReply;
}

- (NSString *) filenameForForward
{
  NSString *subject;
  NSMutableString *newSubject;
  static NSString *sescape[] = { 
    @"/", @"..", @"~", @"\"", @"'", @" ", @".", nil 
  };
  unsigned int count, length;

  subject = [[self envelope] subject];
  length = [subject length];
  if (!length)
    {
      subject = @"forward";
      length = [subject length];
    }

  if (length > maxFilenameLength)
    length = maxFilenameLength;
  newSubject = [NSMutableString
		 stringWithString: [subject substringToIndex: length]];
  count = 0;
  while (sescape[count])
    {
      [newSubject replaceString: sescape[count]
		  withString: @"_"];
      count++;
    }
  [newSubject appendString: @".eml"];

  return newSubject;
}

- (NSString *) subjectForForward
{
  NSString *subject, *newSubject;

  subject = [[self envelope] subject];
  if ([subject length] > 0)
    newSubject = [NSString stringWithFormat: @"[Fwd: %@]", subject];
  else
    newSubject = subject;

  return newSubject;
}

@end
