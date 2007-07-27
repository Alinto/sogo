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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSNull+misc.h>

#import <SoObjects/Mailer/SOGoMailObject.h>
#import <SoObjects/Mailer/SOGoDraftObject.h>

#import "UIxMailEditorAction.h"

@interface UIxMailForwardAction : UIxMailEditorAction
@end


@implementation UIxMailForwardAction

- (NSString *)getAttachmentNameForSubject:(NSString *)_subject {
  /* SOGoDraftObject disallows some strings - anything else required? */
  static NSString *sescape[] = { 
    @"/", @"..", @"~", @"\"", @"'", @" ", @".", nil 
  };
  static int maxFilenameLength = 64;
  NSString *s;
  unsigned i;
  
  if (![_subject isNotNull] || [_subject length] == 0)
    return _subject;
  s = _subject;
  
  if ([s length] > maxFilenameLength)
    s = [s substringToIndex:maxFilenameLength];
  
  for (i = 0; sescape[i] != nil; i++)
    s = [s stringByReplacingString:sescape[i] withString:@"_"];
  
  return [s stringByAppendingString:@".mail"];
}

- (NSString *)forwardSubject:(NSString *)_subject {
  if (![_subject isNotNull] || [_subject length] == 0)
    return _subject;
  
  /* Note: this is how Thunderbird 1.0 creates the subject */
  _subject = [@"[Fwd: " stringByAppendingString:_subject];
  _subject = [_subject stringByAppendingString:@"]"];
  return _subject;
}

- (id)forwardAction {
  NSException  *error;
  NSData       *content;
  NSDictionary *info, *attachment;
  id result;

  /* fetch message */
  
  if ((content = [[self clientObject] content]) == nil)
    return [self didNotFindMailError];
  if ([content isKindOfClass:[NSException class]])
    return content;
  
  /* setup draft */
  
  if ((error = [self _setupNewDraft]) != nil)
    return error;
  
  /* set subject (do we need to set anything else?) */
  
  info = [NSDictionary dictionaryWithObjectsAndKeys:
			 [self forwardSubject:[[self clientObject] subject]],
		         @"subject",
		       nil];
  if ((error = [newDraft storeInfo:info]) != nil)
    return error;
  
  /* attach message */
  
  // TODO: use subject for filename?
  error = [newDraft saveAttachment:content withName:@"forward.mail"];
  if (error != nil)
    return error;
  
  // TODO: we might want to pass the original URL to the editor for a final
  //       redirect back to the message?
  result = [self redirectToEditNewDraft];
  [self reset];
  return result;
}

@end /* UIxMailForwardAction */
