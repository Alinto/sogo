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
// $Id$


#include "NGLogger.h"
#include <NGExtensions/NGExtensions.h>
#include "common.h"
#include "NGLogEvent.h"
#include "NGLogAppender.h"


@implementation NGLogger

- (id)init {
    self = [self initWithLogLevel:NGLogLevelAll];
    return self;
}

- (id)initWithLogLevel:(NGLogLevel)_level {
    if((self = [super init])) {
        NSUserDefaults *ud;
        NSString *appenderClassName;

        [self setLogLevel:_level];

#warning ** remove this as soon as we have a config
        ud = [NSUserDefaults standardUserDefaults];
        appenderClassName = [ud stringForKey:@"NGLogDefaultAppenderClass"];
        if(appenderClassName == nil)
            appenderClassName = @"NGLogConsoleAppender";
        self->_appender = [[NSClassFromString(appenderClassName) alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self->_appender release];
    [super dealloc];
}


- (void)setLogLevel:(NGLogLevel)_level {
    self->minLogLevel = _level;
}

- (NGLogLevel)logLevel {
    return self->minLogLevel;
}

- (void)logLevel:(NGLogLevel)_level withFormat:(NSString *)_fmt, ... {
    NSString *msg;
    NGLogEvent *event;
    va_list va;

    if(self->minLogLevel > _level)
        return;

    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);

    event = [[NGLogEvent alloc] initWithLevel:_level message:msg];

    // iterate appenders
    // TODO: as soon as we have more appenders, we need to iterate on them
    [self->_appender appendLogEvent:event];

    [event release];
    [msg release];
}

- (BOOL)isLogDebugEnabled {
    return self->minLogLevel >= NGLogLevelDebug;
}

- (BOOL)isLogInfoEnabled {
    return self->minLogLevel >= NGLogLevelInfo;
}

- (BOOL)isLogWarnEnabled {
    return self->minLogLevel >= NGLogLevelWarn;
}

- (BOOL)isLogErrorEnabled {
    return self->minLogLevel >= NGLogLevelError;
}

- (BOOL)isLogFatalEnabled {
    return self->minLogLevel >= NGLogLevelFatal;
}

@end
