//
//  InDirectory.m
//  Injection
//
//  Created by John Holdsworth on 26/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "InDirectory.h"

@implementation InDirectory

#import <sys/stat.h>
#import <dirent.h>

typedef void (^block_t)( struct stat *st, OOStringArray &out );

- (void)scan:(block_t)block into:(OOStringArray)out {
    DIR *d = opendir( path );

    if ( !d )
        perror( path );
    else {
        struct dirent *ent;
        struct stat st;

        while ( (ent = readdir( d )) ) {
            strcpy( end, ent->d_name );

            if ( stat( path, &st ) == 0 &&
                    !S_ISDIR( st.st_mode ) && ent->d_name[0] != '.' ) 
                block( &st, out );
        }

        closedir( d );
        *end = '\000';
    }
}

- initPath:(const char *)aPath {
    if ( self = [super init] ) {
        strcpy( path, aPath );
        end = path + strlen( path );

        [self scan:^ void(struct stat *st, OOStringArray &out){
            mtimes[path] = st->st_mtimespec.tv_sec;
        } into:OONil];
    }

    return self;
}

- (OOStringArray)changed {
    OOStringArray changed;
    [self scan:^ void(struct stat *st, OOStringArray &out){
        if ( mtimes[path] != st->st_mtimespec.tv_sec ) {
            out += OOString(path);
            mtimes[path] = st->st_mtimespec.tv_sec;
        }
    } into:changed.alloc()];
    return changed; 
}

@end
