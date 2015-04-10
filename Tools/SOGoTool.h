/* SOGoTool.h - this file is part of SOGo
 *
 * Copyright (C) 2009-2015 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef SOGOTOOL_H
#define SOGOTOOL_H

#import <Foundation/NSObject.h>

// void printStringOnChannel(int channel, NSString * format, ...);

@interface SOGoTool : NSObject
{
  BOOL verbose;
  NSArray *arguments;
  NSArray *sanitizedArguments; /* arguments w/o args from NSArgumentDomain */
}

+ (NSString *) command;
+ (NSString *) description;

+ (BOOL) runToolWithArguments: (NSArray *) toolArguments
                      verbose: (BOOL) isVerbose;

- (void) setArguments: (NSArray *) newArguments;
- (void) setSanitizedArguments: (NSArray *) newArguments;
- (void) setVerbose: (BOOL) newVerbose;
- (BOOL) run;

@end

#endif /* SOGOTOOL_H */
