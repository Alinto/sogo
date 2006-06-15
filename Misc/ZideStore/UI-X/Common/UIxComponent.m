/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OGo

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
// $Id: UIxComponent.m 84 2004-06-29 22:34:55Z znek $


#include "UIxComponent.h"
#include <Foundation/Foundation.h>
#include <NGObjWeb/NGObjWeb.h>
#include <NGExtensions/NGExtensions.h>


@interface UIxComponent (PrivateAPI)
- (void)_parseQueryString:(NSString *)_s;
@end


@implementation UIxComponent

- (id)init {
    if ((self = [super init])) {
        self->queryParameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self->queryParameters release];
    [super dealloc];
}


- (void)awake {
    WORequest *req;
    NSString *uri;
    NSRange r;

    [super awake];

    req = [[self context] request];
    uri = [req uri];
    r = [uri rangeOfString:@"?"];
    if(r.length > 0) {
        NSString *qs;
        
        qs = [uri substringFromIndex:(r.location + r.length)];
        [self->queryParameters removeAllObjects];
        [self _parseQueryString:qs];
    }    
}

- (void)_parseQueryString:(NSString *)_s {
    NSEnumerator *e;
    NSString *part;
    
    e = [[_s componentsSeparatedByString:@"&"] objectEnumerator];
    while ((part = [e nextObject])) {
        NSRange  r;
        NSString *key, *value;
        
        r = [part rangeOfString:@"="];
        if (r.length == 0) {
            /* missing value of query parameter */
            key   = [part stringByUnescapingURL];
            value = @"1";
        }
        else {
            key   = [[part substringToIndex:r.location] stringByUnescapingURL];
            value = [[part substringFromIndex:(r.location + r.length)] 
                stringByUnescapingURL];
        }
        [self->queryParameters setObject:value forKey:key];
    }
}

- (NSString *)queryParameterForKey:(NSString *)_key {
    return [self->queryParameters objectForKey:_key];
}

- (void)setQueryParameter:(NSString *)_param forKey:(NSString *)_key {
    if(_key == nil)
        return;

    if(_param != nil)
        [self->queryParameters setObject:_param forKey:_key];
    else
        [self->queryParameters removeObjectForKey:_key];
}

- (NSDictionary *)queryParameters {
    return self->queryParameters;
}

- (NSString *)completeHrefForMethod:(NSString *)_method {
    NSDictionary *qp;
    NSString *qs;
    
    qp = [self queryParameters];
    if([qp count] == 0)
        return _method;
    
    qs = [[self context] queryStringFromDictionary:qp];
    return [_method stringByAppendingFormat:@"?%@", qs];
}

- (NSString *)ownMethodName {
    NSString *uri;
    NSRange  r;
    
    uri = [[[self context] request] uri];
    
    /* first: cut off query parameters */
    
    r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
    if (r.length > 0)
        uri = [uri substringToIndex:r.location];
    
    /* next: strip trailing slash */
    
    if ([uri hasSuffix:@"/"]) uri = [uri substringToIndex:([uri length] - 1)];
    r = [uri rangeOfString:@"/" options:NSBackwardsSearch];
    
    /* then: cut of last path component */
    
    if (r.length == 0) // no slash? are we at root?
        return @"/";
    
    return [uri substringFromIndex:(r.location + 1)];
}

/* date */

- (NSCalendarDate *)selectedDate {
    NSString *s;
    
    s = [self queryParameterForKey:@"day"];
    if(s) {
        return [self dateForDateString:s];
    }
    return [NSCalendarDate date];
}

- (NSString *)dateStringForDate:(NSCalendarDate *)_date {
    return [_date descriptionWithCalendarFormat:@"%Y%m%d"];
}

- (NSCalendarDate *)dateForDateString:(NSString *)_dateString {
    return [NSCalendarDate dateWithString:_dateString calendarFormat:@"%Y%m%d"];
}

@end
