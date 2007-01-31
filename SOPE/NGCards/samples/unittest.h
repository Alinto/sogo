/* unittest.h - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2006 Inverse groupe conseil
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#ifndef UNITTEST_H
#define UNITTEST_H

#import <Foundation/NSObject.h>

@interface unittest : NSObject

- (void) run;

@end

#define testEqual(x,y) \
        if ((x) != (y)) { \
                  NSLog (@"%s: values not equal at line %d", \
                         __PRETTY_FUNCTION__, __LINE__); \
                  return NO; \
        }

#define testObjectsEqual(x,y) \
        if (![(x) isEqual: (y)]) { \
                  NSLog (@"%s: objects not equal at line %d", \
                         __PRETTY_FUNCTION__, __LINE__); \
                  return NO; \
        }

#define testStringsEqual(x,y) \
        if (!([(x) isKindOfClass: [NSString class]] \
            && [(y) isKindOfClass: [NSString class]] ) \
            || ![(x) isEqualToString: (y)]) { \
                  NSLog (@"%s: strings \"%@\" and \"%@\" not equal at" \
                         @" line %d", __PRETTY_FUNCTION__, (x), (y), \
                          __LINE__); \
                  return NO; \
        }

#define testNotEqual(x,y) \
        if ((x) == (y)) { \
                  NSLog (@"%s: values equal at line %d", \
                         __PRETTY_FUNCTION__, __LINE__); \
                  return NO; \
        }

#define testObjectsNotEqual(x,y) \
        if ([(x) isEqual: (y)]) { \
                  NSLog (@"%s: objects not equal at line %d", \
                         __PRETTY_FUNCTION__, __LINE__); \
                  return NO; \
        }

#define testStringsNotEqual(x,y) \
        if (!([(x) isKindOfClass: [NSString class]] \
            && [(y) isKindOfClass: [NSString class]]) \
            || [(x) isEqualToString: (y)]) { \
                  NSLog (@"%s: strings not equal at line %d", \
                         __PRETTY_FUNCTION__, __LINE__); \
                  return NO; \
        }

@interface unittest (OptionalMethods)

- (void) setUp;
- (void) tearDown;

@end

#endif /* UNITTEST_H */
