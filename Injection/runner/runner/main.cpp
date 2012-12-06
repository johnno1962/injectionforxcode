//
//  main.cpp
//  runner
//
//  Created by John Holdsworth on 31/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <iostream>
#include <zlib.h>

int main (int argc, const char * argv[])
{
    struct { short length; char nlen, name[251]; } hdr; 
    Bytef buffin[64*1024], buffout[1024*1024];

    FILE *chk = popen( "/usr/bin/perl -w '-'", "w" );
    fprintf( chk, "exit (getppid()&0x3f);\n" ); fflush( chk );
    if ( (pclose( chk )>>8) != (getpid()&0x3f) )
        exit(1);    

    FILE *in = fopen( argv[1], "r" );
    if  ( !in )
        exit(2);

    FILE *out = popen( ((std::string)"/usr/bin/perl -w '-' "+argv[2]).c_str(), "w" );
    if ( !out )
        exit(3);

    while ( fread( &hdr, 1, sizeof(hdr.length)+1, in ) > 0 ) {
        fread( &hdr.name, 1, hdr.nlen, in );
        hdr.name[hdr.nlen] = '\000';
        
        char toOutput =
            strcmp( hdr.name, "common.pm" ) == 0 ||
            strcmp( hdr.name, argv[3] ) == 0;

        if ( toOutput )
            fprintf( out, "# line 1 \"%s\"\n", hdr.name );

        uLong bytes = hdr.length, clen = sizeof buffout;
        if ( fread( buffin, 1, bytes, in ) != bytes )
            exit(4);
#if 1
        static int key = 76734527;
        for ( int i=0 ; i<bytes ; i++ )
            key -= (buffin[i] ^= (key += 546745674) >> 8) * 333;
#endif
       if ( uncompress(buffout, &clen, buffin, bytes) != Z_OK )
            exit(5);
        
        if ( toOutput )
            if ( fwrite( buffout, 1, clen, out ) != clen )
                exit(6);
    }

    exit( pclose( out )>>8 );
}

