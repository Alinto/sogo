/*
  Copyright (C) 2000-2004 SKYRIX Software AG

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
// $Id: UIxTabItem.m 31 2004-06-11 15:47:50Z znek $

#include "UIxTabView.h"
#include "common.h"

#if DEBUG
#  define DEBUG_JS 1
#endif

/* context keys */
extern NSString *UIxTabView_HEAD;
extern NSString *UIxTabView_BODY;
extern NSString *UIxTabView_KEYS;
extern NSString *UIxTabView_SCRIPT;
extern NSString *UIxTabView_ACTIVEKEY;
extern NSString *UIxTabView_COLLECT;

@implementation UIxTabItem

static Class StrClass = Nil;

+ (int)version {
  return [super version] + 0;
}
+ (void)initialize {
  StrClass = [NSString class];
}

static NSString *retStrForInt(int i) {
  switch(i) {
  case 0:  return @"0";
  case 1:  return @"1";
  case 2:  return @"2";
  case 3:  return @"3";
  case 4:  return @"4";
  case 5:  return @"5";
  case 6:  return @"6";
  case 7:  return @"7";
  case 8:  return @"8";
  case 9:  return @"9";
  case 10: return @"10";
    // TODO: find useful count!
  default:
    return [[StrClass alloc] initWithFormat:@"%i", i];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->key      = WOExtGetProperty(_config, @"key");
    self->label    = WOExtGetProperty(_config, @"label");

    self->isScript = WOExtGetProperty(_config, @"isScript");
    self->href     = WOExtGetProperty(_config, @"href");

    self->icon     = WOExtGetProperty(_config, @"icon");
    self->action   = WOExtGetProperty(_config, @"action");

    self->tabStyle         = WOExtGetProperty(_config, @"tabStyle");
    self->selectedTabStyle = WOExtGetProperty(_config, @"selectedTabStyle");

    self->tabIcon         = WOExtGetProperty(_config, @"tabIcon");
    self->leftTabIcon     = WOExtGetProperty(_config, @"leftTabIcon");
    self->selectedTabIcon = WOExtGetProperty(_config, @"selectedTabIcon");
    
    self->asBackground    = WOExtGetProperty(_config, @"asBackground");
    self->width           = WOExtGetProperty(_config, @"width");
    self->height          = WOExtGetProperty(_config, @"height");
    self->activeBgColor   = WOExtGetProperty(_config, @"activeBgColor");
    self->inactiveBgColor = WOExtGetProperty(_config, @"inactiveBgColor");
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->key      release];
  [self->label    release];

  [self->href   release];

  [self->action   release];

  [self->isScript release];
  [self->template release];

  [self->tabStyle release];
  [self->selectedTabStyle release];

  [self->icon     release];
  [self->leftTabIcon     release];
  [self->selectedTabIcon release];
  [self->tabIcon         release];

  [self->asBackground release];
  [self->width        release];
  [self->height       release];

  [self->activeBgColor   release];
  [self->inactiveBgColor release];
  
  [super dealloc];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *activeTabKey;
  NSString *myTabKey;
  BOOL     doCheck;
  
  if ([_ctx objectForKey:UIxTabView_HEAD]) {
    /* head clicks */
    [[_ctx component] debugWithFormat:
                        @"UIxTabItem: head takes (no) values, eid='%@'",
                        [_ctx elementID]];
    return;
  }

  if ((activeTabKey = [_ctx objectForKey:UIxTabView_BODY]) == nil) {
    [[_ctx component] debugWithFormat:@"UIxTabItem: invalid state"];
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
    return;
  }
  
  myTabKey = [self->key      stringValueInComponent:[_ctx component]];
  doCheck  = [self->isScript boolValueInComponent:[_ctx component]];
    
  if ([activeTabKey isEqualToString:myTabKey] || doCheck) {
#if ADD_OWN_ELEMENTIDS
    [_ctx appendElementIDComponent:activeTabKey];
#endif
      
#if DEBUG_TAKEVALUES
    [[_ctx component] debugWithFormat:
                          @"UIxTabItem: body takes values, eid='%@'",
                          [_ctx elementID]];
#endif
      
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
#if ADD_OWN_ELEMENTIDS
    [_ctx deleteLastElementIDComponent];
#endif
  }
#if DEBUG_TAKEVALUES
  else {
      [[_ctx component] debugWithFormat:
                          @"UIxTabItem: body takes no values, eid='%@'",
                          [_ctx elementID]];
  }
#endif
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  id            result;
  WOAssociation *tmp;
  NSString      *activeTabKey;
  
  if ((tmp = [_ctx objectForKey:UIxTabView_HEAD])) {
    /* click on tab icon */
    NSString      *tabkey;
    
    tabkey = [_ctx currentElementID];
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:tabkey];
    
    if ([tmp isValueSettable])
      [tmp setValue:tabkey inComponent:[_ctx component]];
    
#if 0
    result = [self->action valueInComponent:[_ctx component]];
#endif

    [_ctx deleteLastElementIDComponent];
  }
  else if ((activeTabKey = [_ctx objectForKey:UIxTabView_BODY])) {
    /* clicked somewhere in the (active) body */
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  else {
    [[_ctx component] logWithFormat:@"UIxTabItem: invalid invoke state"];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  
  return result;
}

/* info collection */

- (void)_collectInContext:(WOContext *)_ctx key:(NSString *)k {
  BOOL  isLeft = NO;
  NSMutableArray *keys;
  UIxTabItemInfo  *info;
  WOComponent    *cmp;
      
  cmp  = [_ctx component];
  keys = [_ctx objectForKey:UIxTabView_KEYS];
  if (keys == nil) {
    keys = [[[NSMutableArray alloc] init] autorelease];
    [_ctx setObject:keys forKey:UIxTabView_KEYS];
    isLeft = YES;
  }
      
  if (k == nil) {
    /* auto-assign a key */
    k = retStrForInt([keys count]);
  }
  else
    k = [k retain];
  [_ctx appendElementIDComponent:k];
  
  info = [[UIxTabItemInfo alloc] init];
  info->key      = [k copy];
  info->label    = [[self->label stringValueInComponent:cmp] copy];
  info->icon     = [[self->icon  stringValueInComponent:cmp] copy];
#if 0
  info->uri      = [[_ctx componentActionURL] copy];
#else
  info->uri      = [[self->href stringValueInComponent:cmp] copy];
#endif
  info->isScript = [self->isScript boolValueInComponent:cmp];
  info->tabIcon  = [[self->tabIcon stringValueInComponent:cmp] copy];
  info->leftIcon = [[self->leftTabIcon stringValueInComponent:cmp] copy];
  info->selIcon  = [[self->selectedTabIcon stringValueInComponent:cmp]
                                           copy];
  info->tabStyle         = [[self->tabStyle stringValueInComponent:cmp] copy];
  info->selectedTabStyle = [[self->selectedTabStyle stringValueInComponent:cmp]
                                                    copy];

  if (self->asBackground == nil)
    info->asBackground = 0;
  else {
    info->asBackground
      = ([self->asBackground boolValueInComponent:cmp]) ? 1 : -1;
  }
  info->width        = [[self->width  stringValueInComponent:cmp] copy];
  info->height       = [[self->height stringValueInComponent:cmp] copy];
  info->activeBg     = [[self->activeBgColor stringValueInComponent:cmp]
                                             copy];
  info->inactiveBg   = [[self->inactiveBgColor stringValueInComponent:cmp]
                                               copy];
      
  if (info->leftIcon == nil) info->leftIcon = [info->tabIcon copy];
      
  [keys addObject:info];
  [info release];
  [k release];
      
  [_ctx deleteLastElementIDComponent];
}

/* header generation */

- (void)_appendHeadToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  activeKey:(NSString *)activeKey
  key:(NSString *)k
{
  /* head is currently generated in UIxTabView */
#if 0
  // note: some associations can be inherited by UIxTabView !
  BOOL        doImages;
  WOComponent *comp;
  BOOL        doBgIcon;
  NSString    *label;
  NSString    *w, *h;
  
  doImages = ![[[_ctx request] clientCapabilities] isTextModeBrowser];
  comp     = [_ctx component];
  
  doBgIcon = self->asBackground && doImages
    ? [self->asBackground boolValueInComponent:comp] ? YES : NO
    : NO;
  
  if ((label = [self->label stringValueInComponent:comp]) == nil)
    label = k;

  if (doImages) {
    /* lookup image */
    NSString *imgName = nil;
    // ...
    
    imgUri = WEUriOfResource(imgName, _ctx);
    if ([imgUri length] < 1)
      doImages = NO;
  }
  
  // .... _isActive
#endif
}

/* body generation */

- (void)_appendBodyToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  activeKey:(NSString *)tmp
  key:(NSString *)k
{
  BOOL doScript;
  BOOL isScript_;
  BOOL isActive;

  doScript  = [[_ctx objectForKey:UIxTabView_SCRIPT] boolValue];
  isScript_ = [self->isScript boolValueInComponent:[_ctx component]];
  isActive  = [tmp isEqualToString:k];
    
  if (doScript && (isActive || isScript_)) {
    [_response appendContentString:@"<div id=\""];
    [_response appendContentString:k];
    [_response appendContentString:@"TabLayer\" style=\"display: none;\">\n"];
  }
  
  if (isActive || (doScript && isScript_)) {
    /* content is active or used as layer*/
#if ADD_OWN_ELEMENTIDS
    [_ctx appendElementIDComponent:k];
#endif
#if DEBUG && 0
    NSLog(@"TAB: %@", k);
#endif
    
    [self->template appendToResponse:_response inContext:_ctx];
    
#if ADD_OWN_ELEMENTIDS
    [_ctx deleteLastElementIDComponent];
#endif
  }
    
  if (doScript && (isActive || isScript_)) {
    NSString *jsout;
    [_response appendContentString:@"</div>"];

    jsout = [NSString alloc];
    jsout = [jsout initWithFormat:
                   @"<script language=\"JavaScript\">\n<!--\n"
                   @"%@Tab[\"Div\"] = %@TabLayer;\n",
                   k, k];
    
    [_response appendContentString:jsout];
    [jsout release];
    
#if DEBUG_JS
    jsout = [NSString alloc];
    jsout = [jsout initWithFormat:
                     @"if (%@Tab[\"Div\"].style==null) {"
                     @"alert('missing style in div for tab %@');}",
                     k, k];
    
    [_response appendContentString:jsout];
    [jsout release];
#endif
    
    if (isActive) {
      [_response appendContentString:@"showTab("];
      [_response appendContentString:k];
      [_response appendContentString:@"Tab);\n"];
    }
    [_response appendContentString:@"//-->\n</script>"];
  }
}

/* master generation method */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *k;
  BOOL     doForm;
  id       tmp;
  
  doForm = [_ctx isInForm];
  k = [self->key stringValueInComponent:[_ctx component]];
  
  if ((tmp = [_ctx objectForKey:UIxTabView_HEAD])) {
    if ([tmp isEqual:UIxTabView_COLLECT]) {
      [self _collectInContext:_ctx key:k];
    }
    else {
      [self _appendHeadToResponse:_response inContext:_ctx
            activeKey:tmp key:k];
    }
  }
  else if ((tmp = [_ctx objectForKey:UIxTabView_BODY])) {
    [self _appendBodyToResponse:_response inContext:_ctx
          activeKey:tmp key:k];
  }
  else {
    NSLog(@"WARNING(%s): invalid UIxTabItem state !!!", __PRETTY_FUNCTION__);
    [_response appendContentString:@"[invalid state]"];
  }
}

@end /* UIxTabItem */

@implementation UIxTabItemInfo

- (void)dealloc {
  [self->uri                release];
  [self->icon               release];
  [self->label              release];
  [self->key                release];
  [self->tabStyle           release];
  [self->selectedTabStyle   release];
  [self->tabIcon            release];
  [self->selIcon            release];
  [self->leftIcon           release];
  [self->width              release];
  [self->height             release];
  [self->activeBg           release];
  [self->inactiveBg         release];

  [super dealloc];
}

/* accessors */

- (NSString *)key {
  return self->key;
}
- (NSString *)label {
  return self->label;
}
- (NSString *)icon {
  return self->icon;
}
- (NSString *)uri {
  return self->uri;
}
- (BOOL)isScript {
  return self->isScript;
}

- (int)asBackground {
  return self->asBackground;
}

- (NSString *)width {
  return self->width;
}

- (NSString *)height {
  return self->height;
}

- (NSString *)activeBg {
  return self->activeBg;
}

- (NSString *)inactiveBg {
  return self->inactiveBg;
}

@end /* UIxTabItemInfo */
