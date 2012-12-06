//
//  main.cpp
//  packer
//
//  Created by John Holdsworth on 31/01/2012.
//  Copyright (c) 2012 John Holdsworth. All rights reserved.
//

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <zlib.h>

int main (int argc, const char * argv[])
{
    struct { short length; char nlen, name[251]; } hdr; 
    Bytef buffin[1024*1024], buffout[64*1024];

    if ( chdir( argv[1] ) < 0 )
        exit( 1 );

    FILE *out = fopen( argv[2], "w" );
    if ( !out ) exit( 2 );

    for ( int f=3; f<argc ; f++ ) {
        const char *file = argv[f];
        printf( "Pack: %s\n", file );
        
        FILE *in = fopen( file, "r" );
        if ( !in ) exit( 3 );

        uLong bytes = fread( buffin, 1, sizeof buffin, in ), clen = sizeof buffout;

        if ( compress(buffout, &clen, buffin, bytes) != Z_OK )
            exit( 4 );
        
        hdr.length = clen;
        hdr.nlen = strlen( file );
        strcpy( hdr.name, file );

        fwrite( &hdr, 1, sizeof(hdr.length)+1+strlen(hdr.name), out );
#if 1
        static int key = 76734527;
        for ( int i=0 ; i<clen ; i++ ) {
            int buffi = buffout[i];
            buffout[i] ^= (key += 546745674) >> 8;
            key -= buffi * 333;
        }
#endif
        if ( fwrite( buffout, 1, clen, out ) != clen )
            exit( 5 );

        fclose( in );
    }

    fclose( out );
    exit( 0 );
}

