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

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SoObjects/SOGo/SOGoUser.h>

#import "SOGoMailForward.h"
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

- (NSString *) contentForEditingOnParts: (NSDictionary *) _prts
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
	  [ms appendString: v];
	}
      else
	[self logWithFormat:@"Note: cannot show part %@", k];
    }

  return ms;
}

#warning this method should be fixed to return the first available text/plain \
         part, and otherwise the first text/html part converted to text
- (NSString *) contentForEditing
{
  NSArray *keys;
  NSDictionary *parts;
  NSMutableArray *topLevelKeys = nil;
  unsigned int count, max;
  NSRange r;
  NSString *contentForEditing;

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
      contentForEditing = [self contentForEditingOnParts: parts
				keys: keys];
    }
  else
    contentForEditing = nil;

  return contentForEditing;
}

- (NSString *) contentForReply
{
  return [[self contentForEditing] stringByApplyingMailQuoting];
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

- (NSString *) contentForInlineForward
{
  SOGoUser *currentUser;
  NSString *pageName;
  SOGoMailForward *page;

  currentUser = [context activeUser];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Forward",
		       [currentUser language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setForwardedMail: self];

  return [[page generateResponse] contentAsString];
}

- (void) _fetchFileAttachmentKey: (NSDictionary *) part
		       intoArray: (NSMutableArray *) keys
		        withPath: (NSString *) path
{
  NSDictionary *disposition, *currentFile;
  NSString *filename, *mimeType;

  disposition = [part objectForKey: @"disposition"];
  filename = [[disposition objectForKey: @"parameterList"]
	       objectForKey: @"filename"];
  if (filename)
    {
      mimeType = [NSString stringWithFormat: @"%@/%@",
			   [part objectForKey: @"type"],
			   [part objectForKey: @"subtype"]];
      currentFile = [NSDictionary dictionaryWithObjectsAndKeys:
				    filename, @"filename",
				  [mimeType lowercaseString], @"mimetype",
				  [part
				    objectForKey: @"encoding"], @"encoding",
				  path, @"path", nil];
      [keys addObject: currentFile];
    }
}

- (void) _fetchFileAttachmentKeysInPart: (NSDictionary *) part
                              intoArray: (NSMutableArray *) keys
			       withPath: (NSString *) path
{
  NSEnumerator *subparts;
  NSString *type;
  unsigned int count;
  NSDictionary *currentPart;
  NSString *newPath;

  type = [[part objectForKey: @"type"] lowercaseString];
  if ([type isEqualToString: @"multipart"])
    {
      subparts = [[part objectForKey: @"parts"] objectEnumerator];
      currentPart = [subparts nextObject];
      count = 1;
      while (currentPart)
	{
	  if (path)
	    newPath = [NSString stringWithFormat: @"%@.%d", path, count];
	  else
	    newPath = [NSString stringWithFormat: @"%d", count];
	  [self _fetchFileAttachmentKeysInPart: currentPart
		intoArray: keys
		withPath: newPath];
	  currentPart = [subparts nextObject];
	  count++;
	}
    }
  else
    [self _fetchFileAttachmentKey: part intoArray: keys withPath: path];
}

#warning we might need to handle parts with a "name" attribute
- (NSArray *) fetchFileAttachmentKeys
{
  NSMutableArray *keys;

  keys = [NSMutableArray array];
  [self _fetchFileAttachmentKeysInPart: [self bodyStructure]
	intoArray: keys withPath: nil];

  return keys;
}

@end
