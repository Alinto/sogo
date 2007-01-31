/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/WODynamicElement.h>

@interface IcalComponent : WODynamicElement
{
  WOAssociation *cname;
  WOElement     *template;
}
@end

@interface IcalProperty : WODynamicElement
{
  WOAssociation *pname;
  WOElement     *template;
  NSDictionary  *parameters;
  WOAssociation *value;
  WOAssociation *valueType;
}
@end

#include "common.h"

static inline NSDictionary *ExtractParameters(NSDictionary *_set) {
  /* extracts ? parameters */
  NSMutableDictionary *paras = nil;
  NSMutableArray      *paraKeys = nil;
  NSEnumerator        *keys;
  NSString            *key;
  
  // locate query parameters
  keys = [_set keyEnumerator];
  while ((key = [keys nextObject])) {
    if ([key hasPrefix:@"?"]) {
      WOAssociation *value;

      if ([key isEqualToString:@"?wosid"])
        continue;

      value = [_set objectForKey:key];
          
      if (paraKeys == nil)
        paraKeys = [NSMutableArray arrayWithCapacity:8];
      if (paras == nil)
        paras = [NSMutableDictionary dictionaryWithCapacity:8];
          
      [paraKeys addObject:key];
      [paras setObject:value forKey:[key substringFromIndex:1]];
    }
  }

  // remove query parameters
  if (paraKeys) {
    unsigned cnt, count;
    for (cnt = 0, count = [paraKeys count]; cnt < count; cnt++) {
      [(NSMutableDictionary *)_set removeObjectForKey:
                                     [paraKeys objectAtIndex:cnt]];
    }
  }

  // assign parameters
  return [paras copy];
}

static inline id GetProperty(NSDictionary *_set, NSString *_name) {
  id propValue = [_set objectForKey:_name];

  if (propValue) {
    propValue = RETAIN(propValue);
    [(id)_set removeObjectForKey:_name];
  }
  return propValue;
}

@implementation IcalComponent

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->cname = GetProperty(_config, @"name");
    self->template = RETAIN(_t);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->template);
  RELEASE(self->cname);
  [super dealloc];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *n;
  
  n = [self->cname stringValueInComponent:[_ctx component]];
  
  [_response appendContentString:@"BEGIN:"];
  [_response appendContentString:n];
  [self->template appendToResponse:_response inContext:_ctx];
  [_response appendContentString:@"END:"];
  [_response appendContentString:n];
}

@end /* IcalComponent */

@implementation IcalProperty

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->pname      = GetProperty(_config, @"name");
    self->value      = GetProperty(_config, @"value");
    self->valueType  = GetProperty(_config, @"valueType");
    self->template   = RETAIN(_t);
    self->parameters = ExtractParameters(_config);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->value);
  RELEASE(self->valueType);
  RELEASE(self->parameters);
  RELEASE(self->template);
  RELEASE(self->pname);
  [super dealloc];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent  *sComponent;
  NSString     *n;
  NSEnumerator *keys;
  NSString     *key;
  id           val;
  NSString     *valType;

  sComponent = [_ctx component];
  n       = [self->pname     stringValueInComponent:sComponent];
  val     = [self->value     valueInComponent:sComponent];
  valType = [self->valueType stringValueInComponent:sComponent];

  /* add name */
  [_response appendContentString:n];

  /* add parameters */
  keys = [self->parameters keyEnumerator];
  while ((key = [keys nextObject])) {
    WOAssociation *val;
    NSString *s;
    
    val = [self->parameters objectForKey:key];
    s   = [val stringValueInComponent:sComponent];
    
    if ([s length] > 0) {
      [_response appendContentString:@";"];
      [_response appendContentString:key];
      [_response appendContentString:@"="];
      [_response appendContentString:s];
    }
  }
  
  /* add value */
  [_response appendContentString:@":"];

  if ([valType length] == 0) {
    val = [val stringValue];
  }
  else if ([valType isEqualToString:@"datetime"]) {
    static NSString *calfmt = @"%Y%m%dT%H%M00Z";
    
    if ([val respondsToSelector:@selector(descriptionWithCalendarFormat:)]) {
      static NSTimeZone *gmt = nil;
      if (gmt == nil) gmt = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
      [val setTimeZone:gmt];
      val = [val descriptionWithCalendarFormat:calfmt];
    }
    else
      val = [val stringValue];
  }
  else
    val = [val stringValue];
  
  [_response appendContentString:val];
  [self->template appendToResponse:_response inContext:_ctx];
}

@end /* IcalProperty */
