/*
  Copyright (C) 2004 SKYRIX Software AG

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

#include <SOGoUI/UIxComponent.h>

/*
  UIxSieveEditor
  
  An editor component which works on SOGoSieveScriptObject's.
*/

@class NSArray, NSString;

@interface UIxSieveEditor : UIxComponent
{
  NSString *scriptName;
  NSString *scriptText;
}

@end

#include <SoObjects/Sieve/SOGoSieveScriptObject.h>
#include "common.h"

@implementation UIxSieveEditor

- (void)dealloc {
  [self->scriptText release];
  [self->scriptName release];
  [super dealloc];
}

/* accessors */

- (void)setScriptName:(NSString *)_value {
  ASSIGNCOPY(self->scriptName, _value);
}
- (NSString *)scriptName {
  return self->scriptName ? self->scriptName : @"";
}

- (void)setScriptText:(NSString *)_value {
  ASSIGNCOPY(self->scriptText, _value);
}
- (NSString *)scriptText {
  return [self->scriptText isNotNull] ? self->scriptText : @"";
}

- (NSString *)panelTitle {
  return [self labelForKey:@"Edit Mail Filter"];
}

/* requests */

- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c {
  return YES;
}

/* actions */

- (id)defaultAction {
  return [self redirectToLocation:@"edit"];
}

- (id)editAction {
#if 0
  [self logWithFormat:@"edit action, load content from: %@",
	  [self clientObject]];
#endif
  
  [self setScriptName:[[self clientObject] nameInContainer]];
  [self setScriptText:[[self clientObject] contentAsString]];
  
  return self;
}

- (id)saveAction {
  NSException *error;
  NSString *text;
  
  text = [self scriptText];
  if ((error = [[self clientObject] writeContent:text]) != nil)
    return error;
  
  return self;
}

- (id)deleteAction {
  NSException *error;
  
  if ((error = [[self clientObject] delete]) != nil)
    return error;
  
  return nil;
}

@end /* UIxSieveEditor */
