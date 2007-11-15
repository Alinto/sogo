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
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>

#import "NSString+Mail.h"
#import "SOGoMailForward.h"
#import "SOGoMailObject+Draft.h"
#import "SOGoMailReply.h"

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

  subject = [self decodedSubject];
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


- (NSString *) _contentForEditingFromKeys: (NSArray *) keys
{
  NSArray *types;
  NSDictionary *parts;
  NSString *rawPart, *content, *contentKey;
  int index;
  BOOL htmlContent;

  if ([keys count])
    {
      types = [keys objectsForKey: @"mimeType"];
      index = [types indexOfObject: @"text/plain"];
      if (index == NSNotFound)
	{
	  index = [types indexOfObject: @"text/html"];
	  htmlContent = YES;
	}
      else
	htmlContent = NO;
      if (index == NSNotFound)
	content = @"";
      else
	{
	  contentKey = [keys objectAtIndex: index];
	  parts = [self fetchPlainTextStrings:
			  [NSArray arrayWithObject: contentKey]];
	  rawPart = [[parts allValues] objectAtIndex: 0];
	  if (htmlContent)
	    content = [rawPart htmlToText];
	  else
	    content = rawPart;
	}
    }
  else
    content = @"";

  return content;
}

- (NSString *) contentForEditing
{
  NSMutableArray *keys;
  NSArray *acceptedTypes;

  acceptedTypes
    = [NSArray arrayWithObjects: @"text/plain", @"text/html", nil];
  keys = [NSMutableArray new];
  [self addRequiredKeysOfStructure: [self bodyStructure]
	path: @"" toArray: keys acceptedTypes: acceptedTypes];

  return [self _contentForEditingFromKeys: keys];
}

- (NSString *) contentForReply
{
  SOGoUser *currentUser;
  NSString *pageName;
  SOGoMailReply *page;

  currentUser = [context activeUser];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Reply",
		       [currentUser language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setRepliedMail: self];

  return [[page generateResponse] contentAsString];
}

- (NSString *) filenameForForward
{
  NSString *subject;
  NSMutableString *newSubject;
  static NSString *sescape[] = { 
    @"/", @"..", @"~", @"\"", @"'", @" ", @".", nil 
  };
  unsigned int count, length;

  subject = [self decodedSubject];
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

  subject = [self decodedSubject];
  if ([subject length] > 0)
    newSubject = [NSString stringWithFormat: @"Fwd: %@", subject];
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
