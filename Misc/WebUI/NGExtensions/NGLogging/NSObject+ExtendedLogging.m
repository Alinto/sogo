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


#import "NSObject+ExtendedLogging.h"
#import "NGLogger.h"


@implementation NSObject (NGExtendedLogging)

- (id)sharedLogger {
    static id sharedLogger = nil;
    if(sharedLogger == nil) {
        sharedLogger = [[NGLogger alloc] init];
    }
    return sharedLogger;
}

- (id)logger {
    return [self sharedLogger];
}

- (void)logDebugWithFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [self logLevel:NGLogLevelDebug withFormat:msg];
    [msg release];
}

- (void)logInfoWithFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [self logLevel:NGLogLevelInfo withFormat:msg];
    [msg release];
}

- (void)logWarnWithFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [self logLevel:NGLogLevelWarn withFormat:msg];
    [msg release];
}

- (void)logErrorWithFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [self logLevel:NGLogLevelError withFormat:msg];
    [msg release];
}

- (void)logFatalWithFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [self logLevel:NGLogLevelFatal withFormat:msg];
    [msg release];
}

- (void)logLevel:(NGLogLevel)_level withFormat:(NSString *)_fmt, ... {
    NSString *msg;
    va_list va;
    
    va_start(va, _fmt);
    msg = [[NSString alloc] initWithFormat:_fmt arguments:va];
    va_end(va);
    [[self logger] logLevel:_level withFormat:msg];
    [msg release];
}

- (BOOL)isLogDebugEnabled {
    return [[self logger] isLogDebugEnabled];
}

- (BOOL)isLogInfoEnabled {
    return [[self logger] isLogInfoEnabled];
}

- (BOOL)isLogWarnEnabled {
    return [[self logger] isLogWarnEnabled];
}

- (BOOL)isLogErrorEnabled {
    return [[self logger] isLogErrorEnabled];
}

- (BOOL)isLogFatalEnabled {
    return [[self logger] isLogFatalEnabled];
}

@end
