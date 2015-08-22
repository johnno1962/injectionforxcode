//
//  main.mm
//  unhide
//
//  $Id: //depot/unhide/main.mm#10 $
//
//  exports "hidden" symbols in a set of object files allowing them
//  to be used to create a Swift framework that can be "injected".
//  This is required as dynamic loading a class in the framework can
//  require access to "internal" methods, functions and variables.
//  These symbols now have "hidden" visibility since Swift 1.2.
//
//  Created by John Holdsworth on 13/05/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach-o/stab.h>

#import <string>
#import <map>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if ( argc < 2  ) {
            fprintf( stderr, "Usage: unhide framework objects...\n" );
            exit(1);
        }

        std::map<std::string,int> seen;

        const char *framework = argv[1];
        framework = [[NSString stringWithFormat:@"%zu%@", strlen(framework),
                      [NSString stringWithUTF8String:framework]] UTF8String];

        for ( int fileno = 2 ; fileno < argc ; fileno++ ) {
            char buffer[PATH_MAX];
            strcpy( buffer, argv[fileno] );
            while ( fileno+1 < argc && strcmp( buffer+strlen(buffer)-2, ".o" ) != 0 ) {
                strcat( buffer, " " );
                strcat( buffer, argv[++fileno] );
            }

            NSString *file = [NSString stringWithUTF8String:buffer];
            NSData *data = [[NSMutableData alloc] initWithContentsOfFile:file];

            if ( !data ) {
                fprintf( stderr, "unhide: Could not read %s\n", [file UTF8String] );
                exit(1);
            }

            struct mach_header_64 *object = (struct mach_header_64 *)[data bytes];

            if ( object->magic != MH_MAGIC_64 ) {
                fprintf( stderr, "unhide: Invalid magic 0x%x != 0x%x (bad arch?)\n",
                        object->magic, MH_MAGIC_64 );
                exit(1);
            }

            struct symtab_command *symtab = NULL;
            struct dysymtab_command *dylib = NULL;

            for ( struct load_command *cmd = (struct load_command *)((char *)object + sizeof *object) ;
                 cmd < (struct load_command *)((char *)object + object->sizeofcmds) ;
                 cmd = (struct load_command *)((char *)cmd + cmd->cmdsize) ) {

                if ( cmd->cmd == LC_SYMTAB )
                    symtab = (struct symtab_command *)cmd;
                else if ( cmd->cmd == LC_DYSYMTAB )
                    dylib = (struct dysymtab_command *)cmd;
            }

            if ( !symtab || !dylib ) {
                fprintf( stderr, "unhide: Missing symtab or dylib cmd %s: %p & %p\n",
                        strrchr( [file UTF8String], '/' )+1, symtab, dylib );
                continue;
            }
            struct nlist_64 *all_symbols64 = (struct nlist_64 *)((char *)object + symtab->symoff);
#if 1
            struct nlist_64 *end_symbols64 = all_symbols64 + symtab->nsyms;

            printf( "%s.%s: local: %d %d ext: %d %d undef: %d %d extref: %d %d indirect: %d %d extrel: %d %d localrel: %d %d symlen: 0%lo\n",
                   framework, strrchr( [file UTF8String], '/' )+1,
                   dylib->ilocalsym, dylib->nlocalsym,
                   dylib->iextdefsym, dylib->nextdefsym,
                   dylib->iundefsym, dylib->nundefsym,
                   dylib->extrefsymoff, dylib->nextrefsyms,
                   dylib->indirectsymoff, dylib->nindirectsyms,
                   dylib->extreloff, dylib->nextrel,
                   dylib->locreloff, dylib->nlocrel,
                   (char *)&end_symbols64->n_un - (char *)object );

            dylib->iextdefsym -= dylib->nlocalsym;
            dylib->nextdefsym += dylib->nlocalsym;
            dylib->nlocalsym = 0;
#endif
            for ( int i=0 ; i<symtab->nsyms ; i++ ) {
                struct nlist_64 &symbol = all_symbols64[i];
                const char *symname = (char *)object + symtab->stroff + symbol.n_un.n_strx;

                if ( strncmp( symname, "__swift_", 8 ) != 0 &&
                        strstr( symname, framework ) != NULL &&
                        symbol.n_sect && !seen[symname]++ ) {
                    symbol.n_type |= N_EXT;
                    symbol.n_type &= ~N_PEXT;
                    symbol.n_desc = N_GSYM;
                    printf( "exported: #%d 0%lo 0x%x 0x%x %3d %s\n", i,
                           (char *)&symbol.n_type - (char *)object,
                           symbol.n_type, symbol.n_desc,
                           symbol.n_sect, symname );
                }
            }

            if ( ![data writeToFile:file atomically:NO] ) {
                fprintf( stderr, "unhide: Could not write %s\n", [file UTF8String] );
                exit(1);
            }
        }
    }

    return 0;
}
