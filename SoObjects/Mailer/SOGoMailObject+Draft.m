/* SOGoMailObject+Draft.m - this file is part of SOGo
 *
 * Copyright (C) 2007-2008 Inverse inc.
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import <SoObjects/SOGo/NSArray+Utilities.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoUserDefaults.h>

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
  NSUInteger i;
  NSString *subject, *newSubject;

  hasPrefix = NO;

  subject = [self decodedSubject];
  if (![subject length]) subject = @"";

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

- (NSString *) _convertRawContentForEditing: (NSString *) raw
                                    rawHtml: (BOOL) html
{
  NSString *rc;
  SOGoUserDefaults *ud;
  BOOL htmlComposition;

  ud = [[context activeUser] userDefaults];
  htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];
  if (html && !htmlComposition)
    rc = [raw htmlToText];
  else if (!html && htmlComposition)
    rc = [raw stringByConvertingCRLNToHTML];
  else
    rc = raw;

  return rc;
}

- (NSString *) _contentForEditingFromKeys: (NSArray *) keys
{
  NSArray *types;
  NSDictionary *parts;
  NSString *rawPart, *content, *contentKey;
  SOGoUserDefaults *ud;
  NSUInteger index;
  BOOL htmlComposition, htmlContent;

  content = @"";

  if ([keys count])
    {
      ud = [[context activeUser] userDefaults];
      htmlComposition = [[ud mailComposeMessageType] isEqualToString: @"html"];
      htmlContent = NO;
      types = [keys objectsForKey: @"mimeType" notFoundMarker: @""];

      if (htmlComposition)
        {
          // Prefer HTML content
          index = [types indexOfObject: @"text/html"];
          if (index == NSNotFound)
            index = [types indexOfObject: @"text/plain"];
          else
            htmlContent = YES;
        }
      else
        {
          // Prefer text content
          index = [types indexOfObject: @"text/plain"];
          if (index == NSNotFound)
            {
              index = [types indexOfObject: @"text/html"];
              htmlContent = YES;
            }
        }

      if (index != NSNotFound)
        {
          contentKey = [keys objectAtIndex: index];
          parts = [self fetchPlainTextStrings:
                     [NSArray arrayWithObject: contentKey]];
          if ([parts count] > 0)
            {
              rawPart = [[parts allValues] objectAtIndex: 0];
              content = [self _convertRawContentForEditing: rawPart 
                                                   rawHtml: htmlContent];
            }
        }
    }

  return content;
}

- (NSString *) contentForEditing
{
  NSMutableArray *keys;
  NSArray *acceptedTypes;

  acceptedTypes
    = [NSArray arrayWithObjects: @"text/plain", @"text/html", nil];
  keys = [NSMutableArray array];
  [self addRequiredKeysOfStructure: [self bodyStructure]
	path: @"" toArray: keys acceptedTypes: acceptedTypes
        withPeek: NO];

  return [self _contentForEditingFromKeys: keys];
}

- (NSString *) contentForReply
{
  NSString *pageName;
  SOGoMailReply *page;
  SOGoUserDefaults *userDefaults;

  userDefaults = [[context activeUser] userDefaults];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Reply",
		       [userDefaults language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setSourceMail: self];
  [page setOutlookMode: [userDefaults mailUseOutlookStyleReplies]];
  [page setReplyPlacement: [userDefaults mailReplyPlacement]];
  [page setSignaturePlacement: [userDefaults mailSignaturePlacement]];
  
  return [[page generateResponse] contentAsString];
}

- (NSString *) filenameForForward
{
  NSString *subject;
  NSMutableString *newSubject;
  static NSString *sescape[] = { 
    @"/", @"..", @"~", @"\"", @"'", @" ", @".", nil 
  };
  NSUInteger count, length;

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
  SOGoUserDefaults *ud;
  NSString *pageName;
  SOGoMailForward *page;

  ud = [[context activeUser] userDefaults];
  pageName = [NSString stringWithFormat: @"SOGoMail%@Forward",
		       [ud language]];
  page = [[WOApplication application] pageWithName: pageName
				      inContext: context];
  [page setSourceMail: self];

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

  mimeType = [NSString stringWithFormat: @"%@/%@",
		       [part objectForKey: @"type"],
		       [part objectForKey: @"subtype"]];
  
  if (filename)
    {
      currentFile = [NSDictionary dictionaryWithObjectsAndKeys:
				    filename, @"filename",
				  [mimeType lowercaseString], @"mimetype",
				  path, @"path",
				  [part	objectForKey: @"encoding"], @"encoding", nil];
      [keys addObject: currentFile];
    }
  else
    {
      // We might end up here because of MUA that actually strips the
      // Content-Disposition (and thus, the filename) when mails containing
      // attachments have been forwarded. Thunderbird (2.x) does just that
      // when forwarding mails with images attached to them (using cid:...).
      if ([mimeType hasPrefix: @"application/"] ||
	  [mimeType hasPrefix: @"audio/"] ||
	  [mimeType hasPrefix: @"image/"] ||
	  [mimeType hasPrefix: @"video/"])
	{
	  currentFile = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSString stringWithFormat: @"unkown_%@", path], @"filename",
				      [mimeType lowercaseString], @"mimetype",
				      path, @"path",
				      [part objectForKey: @"encoding"], @"encoding",
				      nil];
	  [keys addObject: currentFile];
	}
    }
}

- (void) _fetchFileAttachmentKeysInPart: (NSDictionary *) part
                              intoArray: (NSMutableArray *) keys
			       withPath: (NSString *) path
{
  NSMutableDictionary *currentPart;
  NSString *newPath;
  NSArray *subparts;
  NSString *type;
  NSUInteger i;

  type = [[part objectForKey: @"type"] lowercaseString];
  if ([type isEqualToString: @"multipart"])
    {
      subparts = [part objectForKey: @"parts"];
      for (i = 1; i <= [subparts count]; i++)
	{
	  currentPart = [subparts objectAtIndex: i-1];
	  if (path)
	    newPath = [NSString stringWithFormat: @"%@.%d", path, i];
	  else
	    newPath = [NSString stringWithFormat: @"%d", i];
	  [self _fetchFileAttachmentKeysInPart: currentPart
		intoArray: keys
		withPath: newPath];
	}
    }
  else
    {
      if (!path)
        path = @"1";
      [self _fetchFileAttachmentKey: part intoArray: keys withPath: path];
    }
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
