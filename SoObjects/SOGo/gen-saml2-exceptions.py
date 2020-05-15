#!/usr/bin/python

include_dirs = []

output = "-"

import os
import sys

m_template = """/* %(module)s.m (auto-generated) */

#include <objc/objc.h>
#include <stdint.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import "%(module)s.h"

%(exception_init)s

static NSMutableDictionary *exceptionTable = nil;

@implementation NSException (SOGoSAML2Extension)

static void
InitExceptionTable ()
{
  exceptionTable = [NSMutableDictionary new];
  %(exception_table_init)s
}

+ (void) raiseSAML2Exception: (lasso_error_t) lassoError
{
  NSString *exceptionName, *reason;

  if (!exceptionTable)
    InitExceptionTable ();

  exceptionName = [exceptionTable objectForKey: [NSNumber numberWithInt: lassoError]];
  if (!exceptionName)
    exceptionName = NSGenericException;

  reason = [NSString stringWithUTF8String: lasso_strerror (lassoError)];
  if (!reason)
    reason = @"unspecified";

  [self raise: exceptionName format: @"%%@", reason];
}

@end
"""

h_template = """/* %(module)s.h (auto-generated) */

#ifndef %(h_exclusion)s
#define %(h_exclusion)s 1

#include <lasso/errors.h>
#import <Foundation/NSException.h>

@class NSString;

%(exception_decls)s

@interface NSException (SOGoSAML2Extension)

+ (void) raiseSAML2Exception: (lasso_error_t) lassoError;

@end

#endif /* %(h_exclusion)s */
"""

def ParseErrorsHLine(line):
    result = None
    if line.startswith("#define LASSO_"):
        next_space = line.find(" ", 19)
        result = line[8:next_space]

    return result

def ParseIncludeDirs(args):
    dirs = ["/usr/include", "/usr/local/include"]
    ignore = True
    for arg in args:
        if ignore:
            if arg == "-I":
                ignore = False
            elif arg.startswith("-I"):
                dirs.append(arg[2:])
        else:
            dirs.append(arg)
            ignore = True

    return dirs

def FindHFile(args, filename):
    found = None

    include_dirs = ParseIncludeDirs(args)
    for dirname in include_dirs:
        full_filename = "%s/%s" % (dirname, filename)
        if os.path.exists(full_filename):
            found = full_filename

    if found is None:
        raise Exception("'%s' not found in include dirs" % filename)

    return found

def ErrorCodeToName(name):
    parts = name.split("_")
    cap_parts = [part.capitalize() for part in parts]

    return "".join(cap_parts)

if __name__ == "__main__":
    errors_filename = FindHFile(sys.argv, os.path.join("lasso", "errors.h"))

    inf = open(errors_filename)
    error_codes = {}
    line = inf.readline()
    while line != "":
        error_code = ParseErrorsHLine(line)
        if error_code:
            error_codes[error_code] = ErrorCodeToName(error_code)
        line = inf.readline()
    inf.close()

    exception_decls = []
    exception_init = []
    exception_table_init = []

    exc_table_format \
        = ("  [exceptionTable setObject: %s\n"
           "                     forKey: [NSNumber numberWithInt: %s]];")
    for error_code in error_codes:
        name = error_codes[error_code];
        exception_init.append("NSString * const %s = @\"%s\";" % (name, name))
        exception_decls.append("extern NSString * const %s;" % name)
        exception_table_init.append(exc_table_format % (name, error_code))

    module = "SOGoSAML2Exceptions"
    outvars = {"module": module,
               "h_exclusion": "%s_H" % module.upper(),
               "exception_decls": "\n".join(exception_decls),
               "exception_init": "\n".join(exception_init),
               "exception_table_init": "\n".join(exception_table_init)}

    outf = open("%s.m" % module, "w+")
    outf.write(m_template % outvars)
    outf.close()

    outf = open("%s.h" % module, "w+")
    outf.write(h_template % outvars)
    outf.close()
