#include "q16_lib.h"

#include <stdio.h>

/*=========================================================================
*
*   q16info
*
*   Displays the information stored in the header of Q16 files.
*
*   Q565 is a very fast and simple but still surprisingly efficient lossless
*   compression method for 16-bit images in RGB-565 format. It is based upon the
*   QOI-format (Quite OK Image Format) by Dominic Szablewski and adapted by
*   Tord Bärnfors for working with RGB-565 pixels instead.
*
*=========================================================================*/

int main( int argc, char * argv[] )
{
	if( argc <= 1 )
	{
		printf( "Displays header information of Q16 files.\n\n" );
		printf( "usage: inputFile1 [inputFile2 [...]]\n" );
		return -1;
	}

	for( int file = 1 ; file < argc ; file++ )
	{
		char * pInputFilename = argv[file];

		if( file > 1 )
			printf( "\n" );

		FILE * fp = fopen( pInputFilename, "rb" );
		if( fp == NULL )
		{
			printf( "ERROR: Couldn't open '%s'.\n", pInputFilename );
			continue;
		}

		q16_fileheader header;

		size_t bytesRead = fread( &header, 1, sizeof(q16_fileheader), fp );

		fseek( fp, 0, SEEK_END );
		long fileSize = ftell( fp );
		fclose( fp );

		if( bytesRead != sizeof(q16_fileheader) )
		{
			printf( "ERROR: '%s' is not a Q16 file.\n", pInputFilename );
			continue;
		}

		uint16_t width, height;
		uint32_t pixelBytes, alphaBytes;
		uint8_t flags;
		uint8_t version;

		int res = q16_readHeader( &header, &width, &height, &pixelBytes, &alphaBytes, &flags, &version );

		if( res == -1 )
		{
			printf( "ERROR: '%s' is not a Q16 file.\n", pInputFilename );
			continue;
		}

		printf( "%s:\n", pInputFilename );
		printf( "  Version:      %d%s\n", version, res == -2 ? " (unsupported by this version of the library)" : "" );

		if( res == -2 )
			continue;		// Rest of header might have a different layout.

		printf( "  Size:         %d x %d pixels\n", width, height );
		printf( "  Flags:        0x%02X%s\n", flags, (flags & Q16_LINEAR_RGB) ? " (linear RGB)" : "" );
		printf( "  Pixel data:   %u bytes\n", pixelBytes );

		if( alphaBytes > 0 )
			printf( "  Alpha data:   %u bytes\n", alphaBytes );
		else
			printf( "  Alpha data:   none\n" );

		printf( "  File size:    %ld bytes\n", fileSize );

		long expectedSize = (long) sizeof(q16_fileheader) + pixelBytes + alphaBytes;
		if( fileSize != expectedSize )
			printf( "  WARNING: Header says file should be %ld bytes.\n", expectedSize );
	}

	return 0;
}
