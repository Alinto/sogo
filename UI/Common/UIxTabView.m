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

#include "UIxTabView.h"
#include "common.h"
#include <NGObjWeb/NGObjWeb.h>
#include <NGExtensions/NGExtensions.h>
#include <EOControl/EOControl.h>
#include <NGObjWeb/WEClientCapabilities.h>

#if DEBUG
// #  define DEBUG_TAKEVALUES 1
#  define DEBUG_JS 1
#endif

/* context keys */
NSString *UIxTabView_HEAD      = @"UIxTabView_head";
NSString *UIxTabView_BODY      = @"UIxTabView_body";
NSString *UIxTabView_KEYS      = @"UIxTabView_keys";
NSString *UIxTabView_SCRIPT    = @"UIxTabView_script";
NSString *UIxTabView_ACTIVEKEY = @"UIxTabView_activekey";
NSString *UIxTabView_COLLECT   = @"~tv~";

@implementation UIxTabView

static NSNumber *YesNumber;

+ (void)initialize {
  if (YesNumber == nil)
    YesNumber = [[NSNumber numberWithBool:YES] retain];
}

+ (int)version {
  return [super version] + 0;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->selection          = WOExtGetProperty(_config, @"selection");
    
    self->headerStyle        = WOExtGetProperty(_config, @"headerStyle");
    self->bodyStyle          = WOExtGetProperty(_config, @"bodyStyle");
    self->tabStyle           = WOExtGetProperty(_config, @"tabStyle");
    self->selectedTabStyle   = WOExtGetProperty(_config, @"selectedTabStyle");

    self->bgColor            = WOExtGetProperty(_config, @"bgColor");
    self->nonSelectedBgColor = WOExtGetProperty(_config, @"nonSelectedBgColor");
    self->leftCornerIcon     = WOExtGetProperty(_config, @"leftCornerIcon");
    self->rightCornerIcon    = WOExtGetProperty(_config, @"rightCornerIcon");

    self->tabIcon            = WOExtGetProperty(_config, @"tabIcon");
    self->leftTabIcon        = WOExtGetProperty(_config, @"leftTabIcon");
    self->selectedTabIcon    = WOExtGetProperty(_config, @"selectedTabIcon");

    self->asBackground       = WOExtGetProperty(_config, @"asBackground");
    self->width              = WOExtGetProperty(_config, @"width");
    self->height             = WOExtGetProperty(_config, @"height");
    self->activeBgColor      = WOExtGetProperty(_config, @"activeBgColor");
    self->inactiveBgColor    = WOExtGetProperty(_config, @"inactiveBgColor");

    self->fontColor          = WOExtGetProperty(_config, @"fontColor");
    self->fontSize           = WOExtGetProperty(_config, @"fontSize");
    self->fontFace           = WOExtGetProperty(_config, @"fontFace");

    self->template = RETAIN(_subs);
  }
  return self;
}

- (void)dealloc {
  [self->selection release];

  [self->headerStyle release];
  [self->bodyStyle release];
  [self->tabStyle release];
  [self->selectedTabStyle release];

  RELEASE(self->bgColor);
  RELEASE(self->nonSelectedBgColor);
  RELEASE(self->leftCornerIcon);
  RELEASE(self->rightCornerIcon);

  RELEASE(self->leftTabIcon);
  RELEASE(self->selectedTabIcon);
  RELEASE(self->tabIcon);

  RELEASE(self->width);
  RELEASE(self->height);

  RELEASE(self->activeBgColor);
  RELEASE(self->inactiveBgColor);

  RELEASE(self->fontColor);
  RELEASE(self->fontSize);
  RELEASE(self->fontFace);
  
  RELEASE(self->template);
  [super dealloc];
}

/* nesting */

- (id)saveNestedStateInContext:(WOContext *)_ctx {
  return nil;
}
- (void)restoreNestedState:(id)_state inContext:(WOContext *)_ctx {
  if (_state == nil) return;
}

- (NSArray *)collectKeysInContext:(WOContext *)_ctx {
  /* collect mode, collects all keys */
  [_ctx setObject:UIxTabView_COLLECT forKey:UIxTabView_HEAD];
  
  [self->template appendToResponse:nil inContext:_ctx];
  
  [_ctx removeObjectForKey:UIxTabView_HEAD];
  return [_ctx objectForKey:UIxTabView_KEYS];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  id       nestedState;
  NSString *activeTabKey;
  
  activeTabKey = [self->selection stringValueInComponent:[_ctx component]];
  NSLog(@"%s activeTabKey:%@", __PRETTY_FUNCTION__, activeTabKey);
  nestedState = [self saveNestedStateInContext:_ctx];
  [_ctx appendElementIDComponent:@"b"];
  [_ctx appendElementIDComponent:activeTabKey];
  
  [_ctx setObject:activeTabKey forKey:UIxTabView_BODY];
  
#if DEBUG_TAKEVALUES
  [[_ctx component] debugWithFormat:@"UIxTabView: body takes values, eid='%@'",
                    [_ctx elementID]];
#endif
  
  [self->template takeValuesFromRequest:_req inContext:_ctx];
  
  [_ctx removeObjectForKey:UIxTabView_BODY];
  [_ctx deleteLastElementIDComponent]; // activeKey
  [_ctx deleteLastElementIDComponent]; /* 'b' */
  [self restoreNestedState:nestedState inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *key;
  id       result;
  id       nestedState;
  
  if ((key = [_ctx currentElementID]) == nil)
    return nil;
  
  result      = nil;
  nestedState = [self saveNestedStateInContext:_ctx];
    
  if ([key isEqualToString:@"h"]) {
    /* header action */
    //NSString *urlKey;
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"h"];
#if 0
    if ((urlKey = [_ctx currentElementID]) == nil) {
      [[_ctx application]
             debugWithFormat:@"missing active head tab key !"];
    }
    else {
      //NSLog(@"clicked: %@", urlKey);
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:urlKey];
    }
#endif
    
    [_ctx setObject:self->selection forKey:UIxTabView_HEAD];
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
    [_ctx removeObjectForKey:UIxTabView_HEAD];

#if 0
    if (urlKey)
      [_ctx deleteLastElementIDComponent]; // active key
#endif
    [_ctx deleteLastElementIDComponent]; // 'h'
  }
  else if ([key isEqualToString:@"b"]) {
    /* body action */
    NSString *activeTabKey, *urlKey;
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"b"];
      
    if ((urlKey = [_ctx currentElementID]) == nil) {
      [[_ctx application]
             debugWithFormat:@"missing active body tab key !"];
    }
    else {
      //NSLog(@"clicked: %@", urlKey);
      [_ctx consumeElementID];
      [_ctx appendElementIDComponent:urlKey];
    }
    
    activeTabKey = [self->selection stringValueInComponent:[_ctx component]];
    [_ctx setObject:activeTabKey forKey:UIxTabView_BODY];
    
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
      
    [_ctx removeObjectForKey:UIxTabView_BODY];

    if (urlKey)
      [_ctx deleteLastElementIDComponent]; // active key
    [_ctx deleteLastElementIDComponent]; // 'b'
  }
  else {
    [[_ctx application]
           debugWithFormat:@"unknown tab container key '%@'", key];
  }
    
  [self restoreNestedState:nestedState inContext:_ctx];
  return result;
}

- (NSString *)_tabViewCountInContext:(WOContext *)_ctx {
  int count;
  count = [[_ctx valueForKey:@"UIxTabViewScriptDone"] intValue];
  return [NSString stringWithFormat:@"%d",count];
}

- (NSString *)scriptHref:(UIxTabItemInfo *)_info
  inContext:(WOContext *)_ctx
  isLeft:(BOOL)_isLeft
  keys:(NSArray *)_keys
{
  NSMutableString *result = [NSMutableString string];
  UIxTabItemInfo *tmp;
  NSString       *activeKey;
  int            i, cnt;
  NSString       *elID;
  NSString       *tstring;
  
  activeKey = [self->selection stringValueInComponent:[_ctx component]];
  [result appendString:@"JavaScript:showTab("];
  [result appendString:_info->key];
  [result appendString:@"Tab);"];
  
  [result appendString:@"swapCorners("];
  tstring = (!_isLeft)
    ? @"tabCorner%@,tabCornerLeft%@);"
    : @"tabCornerLeft%@,tabCorner%@);";
  elID = [self _tabViewCountInContext:_ctx];
  [result appendString:[NSString stringWithFormat:tstring,elID,elID]];
  
  for (i=0, cnt = [_keys count]; i < cnt; i++) {
    tmp = [_keys objectAtIndex:i];

    if ((tmp->isScript || [tmp->key isEqualToString:activeKey])
        && ![tmp->key isEqualToString:_info->key]) {
      [result appendString:@"hideTab("];
      [result appendString:tmp->key];
      [result appendString:@"Tab);"];
    }
  }
  return result;
}

- (void)appendLink:(UIxTabItemInfo *)_info
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isActive:(BOOL)_isActive isLeft:(BOOL)_isLeft
  doScript:(BOOL)_doScript keys:(NSArray *)_keys
{
  NSString *headUri    = nil;
  NSString *label      = nil;
  NSString *styleName  = nil;
  WEClientCapabilities *ccaps;
  WOComponent *comp;

  ccaps = [[_ctx request] clientCapabilities];

  comp = [_ctx component];
  headUri = _info->uri;

  if ((label = _info->label) == nil)
    label = _info->key;
  
  if (_isActive) {
    styleName = (_info->selectedTabStyle)
      ? _info->selectedTabStyle
      : [self->selectedTabStyle stringValueInComponent:comp];
  }
  else {
    styleName = (_info->tabStyle)
      ? _info->tabStyle
      : [self->tabStyle stringValueInComponent:comp];
  }
  
  [_response appendContentString:@"<td align='center' valign='middle'"];
  
  if (styleName) {
      [_response appendContentString:@" class='"];
      [_response appendContentHTMLAttributeValue:styleName];
      [_response appendContentCharacter:'\''];
  }

  // click on td background
  if ([ccaps isInternetExplorer] && [ccaps isJavaScriptBrowser]) {
      [_response appendContentString:@" onclick=\"window.location.href='"];
      [_response appendContentHTMLAttributeValue:headUri];
      [_response appendContentString:@"'\""];
  }
  
  [_response appendContentCharacter:'>'];

  [_response appendContentString:@"<a href=\""];
  
  [_response appendContentHTMLAttributeValue:headUri];
  
  [_response appendContentString:@"\" "];
  [_response appendContentString:
               [NSString stringWithFormat:@"name='%@TabLink'", _info->key]];
  [_response appendContentString:@">"];
  
  if ([label length] < 1)
      label = _info->key;
  [_response appendContentString:@"<nobr>"];
  [_response appendContentHTMLString:label];
  [_response appendContentString:@"</nobr>"];
  
  [_response appendContentString:@"</a>"];

  [_response appendContentString:@"</td>"];
}

- (void)appendSubmitButton:(UIxTabItemInfo *)_info
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  isActive:(BOOL)_isActive isLeft:(BOOL)_left
  doScript:(BOOL)_doScript   keys:(NSArray *)_keys
{
  [self appendLink:_info
        toResponse:_response
        inContext:_ctx
        isActive:_isActive isLeft:_left
        doScript:NO keys:_keys];
}

- (void)_appendTabViewJSScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [_response appendContentString:
               @"<script language=\"JavaScript\">\n<!--\n\n"
               @"function showTab(obj) {\n"
#if DEBUG_JS
               @"  if (obj==null) { alert('missing tab obj ..'); return; }\n"
               @"  if (obj['Div']==null) {"
               @"    alert('missing div key in ' + obj); return; }\n"
               @"  if (obj['Div'].style==null) {"
               @"    alert('missing style key in div ' + obj['Div']);return; }\n"
#endif
               @"  obj['Div'].style.display = \"\";\n"
               @"  obj['Img'].src = obj[\"Ar\"][1].src;\n"
               @"  obj['link'].href = obj[\"href2\"];\n"
               @"}\n"
               @"function hideTab(obj) {\n"
#if DEBUG_JS
               @"  if (obj==null) { alert('missing tab obj ..'); return; }\n"
               @"  if (obj['Div']==null) {"
               @"    alert('missing div key in ' + obj); return; }\n"
               @"  if (obj['Div'].style==null) {"
               @"    alert('missing style key in div ' + obj['Div']);return; }\n"
#endif
               @" obj['Div'].style.display = \"none\";\n"
               @" obj['Img'].src = obj[\"Ar\"][0].src;\n"
               @" obj['link'].href = obj[\"href1\"];\n"
               @"}\n"
               @"function swapCorners(obj1,obj2) {\n"
               @"   if (obj1==null) { alert('missing corner 1'); return; }\n"
               @"   if (obj2==null) { alert('missing corner 2'); return; }\n"
               @"   obj1.style.display = \"none\";\n"
               @"   obj2.style.display = \"\";\n"
               @"}\n"
               @"//-->\n</script>"];
}

- (void)_appendHeaderRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  keys:(NSArray *)keys activeKey:(NSString *)activeKey
  doScript:(BOOL)doScript
{
  unsigned  i, count;
  BOOL      doForm;
  NSString  *styleName;
  
  doForm = NO;  /* generate form controls ? */
  
  [_response appendContentString:@"<tr><td colspan='2'>"];
  
  styleName = [self->headerStyle stringValueInComponent:[_ctx component]];
  if(styleName) {
      [_response appendContentString:
          @"<table border='0' cellpadding='0' cellspacing='0' class='"];
      [_response appendContentHTMLAttributeValue:styleName];
      [_response appendContentString:@"'><tr>"];
  }
  else {
      [_response appendContentString:
          @"<table border='0' cellpadding='0' cellspacing='0'><tr>"];
  }

  for (i = 0, count = [keys count]; i < count; i++) {
    UIxTabItemInfo *info;
    NSString       *key;
    BOOL           isActive;
    
    info     = [keys objectAtIndex:i];
    key      = info->key;
    isActive = [key isEqualToString:activeKey];
    
    [_ctx appendElementIDComponent:key];
    
    if (doForm) {
      /* tab is inside of a FORM, so produce submit buttons */
      [self appendSubmitButton:info
            toResponse:_response
            inContext:_ctx
            isActive:isActive
            isLeft:(i == 0) ? YES : NO
            doScript:NO
            keys:keys];
    }
    else {
      /* tab is not in a FORM, generate hyperlinks for tab */
      [self appendLink:info
            toResponse:_response
            inContext:_ctx
            isActive:isActive
            isLeft:(i == 0) ? YES : NO
            doScript:NO
            keys:keys];
    }
    
    [_ctx deleteLastElementIDComponent];
  }
  //  [_response appendContentString:@"<td></td>"];
  [_response appendContentString:@"</tr></table>"];
  [_response appendContentString:@"</td></tr>"];
}

- (void)_appendHeaderFootRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  bgcolor:(NSString *)bgcolor
  doScript:(BOOL)doScript
  isLeftActive:(BOOL)isLeftActive
{
  NSString *styleName;
  [_response appendContentString:@"  <tr"];
    
  styleName = [self->bodyStyle stringValueInComponent:[_ctx component]];
  if(styleName) {
    [_response appendContentString:@" class='"];
    [_response appendContentHTMLAttributeValue:styleName];
    [_response appendContentCharacter:'\''];
  }
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentString:@"\""];
  }
  [_response appendContentString:@">\n"];
    
  /* left corner */
  [_response appendContentString:@"    <td align=\"left\" width=\"10\">"];
  
  if (isLeftActive)
    [_response appendContentString:@"&nbsp;"];
  
  if (!isLeftActive) {
    NSString *uri;
    
    uri = [self->leftCornerIcon stringValueInComponent:[_ctx component]];
    if ((uri = WEUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  
  [_response appendContentString:@"</td>"];

  /* right corner */
  [_response appendContentString:@"    <td align=\"right\">"];
  {
    NSString *uri;
      
    uri = [self->rightCornerIcon stringValueInComponent:[_ctx component]];
    if ((uri = WEUriOfResource(uri, _ctx))) {
      [_response appendContentString:@"<img border=\"0\" alt=\"\" src=\""];
      [_response appendContentString:uri];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:@"&nbsp;"];
  }
  [_response appendContentString:@"</td>\n"];
    
  [_response appendContentString:@"  </tr>\n"];
}

- (void)_appendBodyRowToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  bgcolor:(NSString *)bgcolor
  activeKey:(NSString *)activeKey
{
  WEClientCapabilities *ccaps;
  BOOL indentContent;
  NSString *styleName;

  styleName = [self->bodyStyle stringValueInComponent:[_ctx component]];
  ccaps = [[_ctx request] clientCapabilities];

  /* put additional padding table into content ??? */
  indentContent = [ccaps isFastTableBrowser] && ![ccaps isTextModeBrowser];
  
  [_response appendContentString:@"<tr"];
  if(styleName) {
    [_response appendContentString:@" class='"];
    [_response appendContentHTMLAttributeValue:styleName];
    [_response appendContentCharacter:'\''];
  }
  [_response appendContentString:@"><td colspan='2'"];
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentCharacter:'\"'];
  }
  [_response appendContentCharacter:'>'];
    
  if (indentContent) {
    /* start padding table */
    [_response appendContentString:
               @"<table border='0' width='100%'"
               @" cellpadding='10' cellspacing='0'>"];
    [_response appendContentString:@"<tr><td>"];
  }
    
  [_ctx appendElementIDComponent:@"b"];
  [_ctx appendElementIDComponent:activeKey];
  
  /* generate currently active body */
  {
    [_ctx setObject:activeKey forKey:UIxTabView_BODY];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx removeObjectForKey:UIxTabView_BODY];
  }
  
  [_ctx deleteLastElementIDComponent]; // activeKey
  [_ctx deleteLastElementIDComponent]; // 'b'
    
  if (indentContent)
    /* close padding table */
    [_response appendContentString:@"</td></tr></table>"];
    
  [_response appendContentString:@"</td></tr>"];
}

- (BOOL)isLeftActiveInKeys:(NSArray *)keys activeKey:(NSString *)activeKey{
  unsigned i, count;
  BOOL isLeftActive;
  
  isLeftActive = NO;
  
  for (i = 0, count = [keys count]; i < count; i++) {
    UIxTabItemInfo *info;
    
    info = [keys objectAtIndex:i];
    
    if ((i == 0) && [info->key isEqualToString:activeKey])
      isLeftActive = YES;
  }
  
  return isLeftActive;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent  *cmp;
  NSString     *bgcolor;
  BOOL         isLeftActive;
  id           nestedState;
  NSString     *activeKey;
  NSArray      *keys;
  int          tabViewCount; /* used for image id's and writing script once */
  
  tabViewCount  = [[_ctx valueForKey:@"UIxTabViewScriptDone"] intValue];
  cmp           = [_ctx component];
  
  /* save state */
  
  nestedState = [self saveNestedStateInContext:_ctx];
  
  /* configure */
  
  activeKey = [self->selection stringValueInComponent:cmp];
  
  bgcolor = [self->bgColor stringValueInComponent:cmp];
  bgcolor = [bgcolor stringValue];
  
  [_ctx appendElementIDComponent:@"h"];
  
  /* collect & process keys (= available tabs) */
  
  keys = [self collectKeysInContext:_ctx];
  
  if (![[keys valueForKey:@"key"] containsObject:activeKey])
    /* selection is not available in keys */
    activeKey = nil;
  
  if ((activeKey == nil) && ([keys count] > 0)) {
    /* no or invalid selection, use first key */
    activeKey = [[keys objectAtIndex:0] key];
    if ([self->selection isValueSettable])
      [self->selection setValue:activeKey inComponent:[_ctx component]];
  }
  
  /* start appending */
  
  /* count up for unique tabCorner/tabCornerLeft images */
  [_ctx takeValue:[NSNumber numberWithInt:(tabViewCount + 1)]
        forKey:@"UIxTabViewScriptDone"];
  
  [_response appendContentString:
               @"<table border='0' width='100%'"
               @" cellpadding='0' cellspacing='0'>"];
  
  /* find out whether left is active */
  
  isLeftActive = [self isLeftActiveInKeys:keys activeKey:activeKey];
  
  /* generate header row */
  
  [self _appendHeaderRowToResponse:_response inContext:_ctx
        keys:keys activeKey:activeKey
        doScript:NO];
  
  [_ctx deleteLastElementIDComponent]; // 'h' for head
  [_ctx removeObjectForKey:UIxTabView_HEAD];

  /* body row */
  
  [self _appendBodyRowToResponse:_response inContext:_ctx
        bgcolor:bgcolor
        activeKey:activeKey];
  
  /* close table */
  
  [_response appendContentString:@"</table>"];
  [_ctx removeObjectForKey:UIxTabView_ACTIVEKEY];
  [_ctx removeObjectForKey:UIxTabView_KEYS];
  [self restoreNestedState:nestedState inContext:_ctx];
}

@end /* UIxTabView */
