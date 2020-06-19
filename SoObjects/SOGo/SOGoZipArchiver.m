/* SOGoZipArchiver.m - this file is part of SOGo
 *
 * Copyright (C) 2020 Inverse inc.
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

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>

#import "SOGoZipArchiver.h"

@implementation SOGoZipArchiver

+ (id)archiverAtPath:(NSString *)file
{
    id newArchiver = [[self alloc] initFromFile: file];
    [newArchiver autorelease];
    return newArchiver;
}

- (id)init
{
    if ((self = [super init])) {
        z = NULL;
    }
    return self;
}

- (void)dealloc
{
    [self close];
    [super dealloc];
}

- (id)initFromFile:(NSString *)file
{
    id ret;

    ret = nil;
    if (file) {
        if ((self = [self init])) {
            int errorp;
            self->z = zip_open([file cString], ZIP_CREATE | ZIP_EXCL, &errorp);
            if (self->z == NULL) {
#ifdef LIBZIP_VERSION
                zip_error_t ziperror;
                zip_error_init_with_code(&ziperror, errorp);
                NSLog(@"Failed to open zip output file %@: %@", file,
                        [NSString stringWithCString: zip_error_strerror(&ziperror)]);
#else
                NSLog(@"Failed to open zip output file %@: %@", file, zip_strerror(self->z));
#endif
            } else {
                ret = self;
            }
        }
    }

    return ret;
}

- (BOOL)putFileWithName:(NSString *)filename andData:(NSData *)data
{
    if (self->z == NULL) {
        NSLog(@"Failed to add file, archive is not open");
        return NO;
    }

    struct zip_source *source = zip_source_buffer(self->z, [data bytes], [data length], 0);
    if (source == NULL) {
        NSLog(@"Failed to create zip source from buffer: %@", [NSString stringWithCString: zip_strerror(self->z)]);
        return NO;
    }

#ifdef ZIP_FL_ENC_UTF_8
    if (zip_file_add(self->z, [filename UTF8String], source, ZIP_FL_ENC_UTF_8) < 0) {
        NSLog(@"Failed to add file %@: %@", filename, [NSString stringWithCString: zip_strerror(self->z)]);
        zip_source_free(source);
    }
#else
    if (zip_add(self->z, [filename UTF8String], source) < 0) {
      NSLog(@"Failed to add file %@: %@", filename, [NSString stringWithCString: zip_strerror(self->z)]);
      zip_source_free(source);
    }
#endif

    return YES;
}

- (BOOL)close
{
    BOOL success = YES;
    if (self->z != NULL) {
        if (zip_close(self->z) != 0) {
            NSLog(@"Failed to close zip archive: %@", [NSString stringWithCString: zip_strerror(self->z)]);
            zip_discard(self->z);
            success = NO;
        }
        self->z = NULL;
    }
    return success;
}

@end
