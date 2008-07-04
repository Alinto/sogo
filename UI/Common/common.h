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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>

#import <NGObjWeb/WOAssociation.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WODynamicElement.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOResourceManager.h>
#import <NGObjWeb/WOSession.h>
#import <NGExtensions/NSObject+Logs.h>

@interface WOContext(WOExtensionsPrivate)
- (void)addActiveFormElement:(WOElement *)_element;
@end

static inline id WOExtGetProperty(NSDictionary *_set, NSString *_name) {
    id propValue = [_set objectForKey:_name];
    
    if (propValue) {
        propValue = [propValue retain];
        [(NSMutableDictionary *)_set removeObjectForKey:_name];
    }
    return propValue;
}

static inline NSString *WEUriOfResource(NSString *_name, WOContext *_ctx) {
    NSArray           *languages;
    WOResourceManager *resourceManager;
    NSString          *uri;
    
    if (_name == nil)
        return nil;
    
    languages = [_ctx hasSession]
        ? [[_ctx session] languages]
        : [[_ctx request] browserLanguages];
    
    resourceManager = [[_ctx application] resourceManager];
    
    uri = [resourceManager urlForResourceNamed:_name
                                   inFramework:nil
                                     languages:languages
                                       request:[_ctx request]];
    if ([uri rangeOfString:@"/missingresource?"].length > 0)
        uri = nil;
    
    return uri;
}

static inline void WEAppendFont(WOResponse *_resp,
                                NSString   *_color,
                                NSString   *_face,
                                NSString   *_size)
{
    [_resp appendContentString:@"<font"];
    if (_color) {
        [_resp appendContentString:@" color=\""];
        [_resp appendContentHTMLAttributeValue:_color];
        [_resp appendContentCharacter:'"'];
    }
    if (_face) {
        [_resp appendContentString:@" face=\""];
        [_resp appendContentHTMLAttributeValue:_face];
        [_resp appendContentCharacter:'"'];
    }
    if (_size) {
        [_resp appendContentString:@" size=\""];
        [_resp appendContentHTMLAttributeValue:_size];
        [_resp appendContentCharacter:'"'];
    }
    [_resp appendContentCharacter:'>'];
}

static inline void WEAppendTD(WOResponse *_resp,
                              NSString   *_align,
                              NSString   *_valign,
                              NSString   *_bgColor)
{
    [_resp appendContentString:@"<td"];
    if (_bgColor) {
        [_resp appendContentString:@" bgcolor=\""];
        [_resp appendContentHTMLAttributeValue:_bgColor];
        [_resp appendContentCharacter:'"'];
    }
    if (_align) {
        [_resp appendContentString:@" align=\""];
        [_resp appendContentHTMLAttributeValue:_align];
        [_resp appendContentCharacter:'"'];
    }
    if (_valign) {
        [_resp appendContentString:@" valign=\""];
        [_resp appendContentHTMLAttributeValue:_valign];
        [_resp appendContentCharacter:'"'];
    }
    [_resp appendContentCharacter:'>'];
}

static inline WOElement *WECreateElement(NSString *_className,
                                         NSString *_name,
                                         NSDictionary *_config,
                                         WOElement *_template)
{
    Class               c;
    WOElement           *result = nil;
    NSMutableDictionary *config = nil;
    
    if ((c = NSClassFromString(_className)) == Nil) {
        NSLog(@"%s: missing '%@' class", __PRETTY_FUNCTION__, _className);
        return nil;
    }
    config = [NSMutableDictionary dictionaryWithCapacity:4];
    {
        NSEnumerator *keyEnum;
        id           key;
        
        keyEnum = [_config keyEnumerator];
        
        while ((key = [keyEnum nextObject])) {
            WOAssociation *a;
            
            a = [WOAssociation associationWithValue:[_config objectForKey:key]];
            [config setObject:a forKey:key];
        }
    }
    result = [[c alloc] initWithName:_name
                        associations:config
                            template:_template];
    return [result autorelease];
}

#define OWGetProperty WOExtGetProperty
