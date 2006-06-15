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

#include "UIxMailEditorAction.h"

@interface UIxMailReplyAction : UIxMailEditorAction
@end

#include <SoObjects/Mailer/SOGoMailObject.h>
#include <SoObjects/Mailer/SOGoDraftObject.h>
#include <NGImap4/NGImap4EnvelopeAddress.h>
#include <NGImap4/NGImap4Envelope.h>
#include "common.h"

@implementation UIxMailReplyAction

- (BOOL)hasReplyPrefix:(NSString *)_subject {
  static NSString *replyPrefixes[] = {
    @"Re:", // regular
    @"RE:", // Outlook v11 (English?)
    @"AW:", // German Outlook v11
    @"Re[", // numbered Re, eg "Re[2]:"
    nil
  };
  unsigned i;
  for (i = 0; replyPrefixes[i] != nil; i++) {
    if ([_subject hasPrefix:replyPrefixes[i]])
      return YES;
  }
  return NO;
}

- (NSString *)replySubject:(NSString *)_subject {
  if (![_subject isNotNull] || [_subject length] == 0)
    return _subject;
  
  if ([self hasReplyPrefix:_subject]) {
    /* do not do: "Re: Re: Re: My Mail" - a single Re is sufficient ;-) */
    return _subject;
  }
  
  return [@"Re: " stringByAppendingString:_subject];
}

- (void)addEMailsOfAddresses:(NSArray *)_addrs toArray:(NSMutableArray *)_ma {
  unsigned i, count;
  
  for (i = 0, count = [_addrs count]; i < count; i++)
    [_ma addObject:[(NGImap4EnvelopeAddress *)[_addrs objectAtIndex:i] email]];
}

- (void)fillInReplyAddresses:(NSMutableDictionary *)_info
  replyToAll:(BOOL)_replyToAll
  envelope:(NGImap4Envelope *)_envelope
{
  /*
    The rules as implemented by Thunderbird:
    - if there is a 'reply-to' header, only include that (as TO)
    - if we reply to all, all non-from addresses are added as CC
    - the from is always the lone TO (except for reply-to)
    
    Note: we cannot check reply-to, because Cyrus even sets a reply-to in the
          envelope if none is contained in the message itself! (bug or
          feature?)
    
    TODO: what about sender (RFC 822 3.6.2)
  */
  NSMutableArray *to;
  NSArray *addrs;
  
  to = [NSMutableArray arrayWithCapacity:2];

  /* first check for "reply-to" */
  
  addrs = [_envelope replyTo];
  if ([addrs count] == 0) {
    /* no "reply-to", try "from" */
    addrs = [_envelope from];
  }
  [self addEMailsOfAddresses:addrs toArray:to];
  [_info setObject:to forKey:@"to"];
  
  /* CC processing if we reply-to-all: add all 'to' and 'cc'  */
  
  if (_replyToAll) {
    to = [NSMutableArray arrayWithCapacity:8];
    
    [self addEMailsOfAddresses:[_envelope to] toArray:to];
    [self addEMailsOfAddresses:[_envelope cc] toArray:to];
    
    [_info setObject:to forKey:@"cc"];
  }
}

- (NSString *)contentForReplyOnParts:(NSDictionary *)_prts keys:(NSArray *)_k {
  static NSString *textPartSeparator = @"\n---\n";
  NSMutableString *ms;
  unsigned i, count;
  
  ms = [NSMutableString stringWithCapacity:16000];
  
  for (i = 0, count = [_k count]; i < count; i++) {
    NSString *k, *v;
    
    k = [_k objectAtIndex:i];
    
    // TODO: this is DUP code to SOGoMailObject
    if ([k isEqualToString:@"body[text]"])
      k = @"";
    else if ([k hasPrefix:@"body["]) {
      k = [k substringFromIndex:5];
      if ([k length] > 0) k = [k substringToIndex:([k length] - 1)];
    }
    
    v = [_prts objectForKey:k];
    if (![v isKindOfClass:[NSString class]]) {
      [self logWithFormat:@"Note: cannot show part %@", k];
      continue;
    }
    if ([v length] == 0)
      continue;
    
    if (i != 0) [ms appendString:textPartSeparator];
    [ms appendString:[v stringByApplyingMailQuoting]];
  }
  return ms;
}

- (NSString *)contentForReply {
  NSArray      *keys;
  NSDictionary *parts;
  
  keys = [[self clientObject] plainTextContentFetchKeys];
  if ([keys count] == 0)
    return nil;
  
  if ([keys count] > 1) {
    /* filter keys, only include top-level, or if none, the first */
    NSMutableArray *topLevelKeys = nil;
    unsigned i;
    
    for (i = 0; i < [keys count]; i++) {
      NSRange r;
      
      r = [[keys objectAtIndex:i] rangeOfString:@"."];
      if (r.length > 0)
	continue;
      
      if (topLevelKeys == nil) 
	topLevelKeys = [NSMutableArray arrayWithCapacity:4];
      [topLevelKeys addObject:[keys objectAtIndex:i]];
    }
    
    if ([topLevelKeys count] > 0) {
      /* use top-level keys if we have some */
      keys = topLevelKeys;
    }
    else {
      /* just take the first part */
      keys = [NSArray arrayWithObject:[keys objectAtIndex:0]];
    }
  }
  
  parts = [[self clientObject] fetchPlainTextStrings:keys];
  return [self contentForReplyOnParts:parts keys:keys];
}

- (id)replyToAll:(BOOL)_replyToAll {
  NSMutableDictionary *info;
  NSException *error;
  id result;
  id tmp;
  
  /* ensure mail exists and is filled */
  
  // TODO: we could transport the body structure in a hidden field of the mail
  //       viewer to avoid refetching the core-info?
  tmp = [[self clientObject] fetchCoreInfos];
  if ([tmp isKindOfClass:[NSException class]])
    return tmp;
  if (![tmp isNotNull])
    return [self didNotFindMailError];

  /* setup draft */
  
  if ((error = [self _setupNewDraft]) != nil)
    return error;
  
  /* fill draft info */
  
  info = [NSMutableDictionary dictionaryWithCapacity:16];
  
  [info setObject:[self replySubject:[[self clientObject] subject]]
	forKey:@"subject"];
  [self fillInReplyAddresses:info replyToAll:_replyToAll 
	envelope:[[self clientObject] envelope]];
  
  /* fill in text content */
  
  if ((tmp = [self contentForReply]) != nil)
    [info setObject:tmp forKey:@"text"];
  
  /* save draft info */

  if ((error = [self->newDraft storeInfo:info]) != nil)
    return error;
  
  // TODO: we might want to pass the original URL to the editor for a final
  //       redirect back to the message?
  result = [self redirectToEditNewDraft];
  [self reset];
  return result;
}

- (id)replyAction {
  return [self replyToAll:NO];
}
- (id)replyallAction {
  return [self replyToAll:YES];
}

@end /* UIxMailReplyAction */
