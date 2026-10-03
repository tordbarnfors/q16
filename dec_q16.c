
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include "q16_lib.h"

#include <stdio.h>
#include <string.h>

/*=========================================================================
*
*   gen_q16
*
*   Generates Q565 compressed 16-bit images form popular image formats
*   such as PNG, JPG, TGA, GIF and BMP.
*
*   The fileformat is called Q16 and has a small header followed by compressed
*   image data.
*
*   Q565 is a very fast and simple but still surprisingly efficient lossless
*   compression method for 16-bit images in RGB-565 format. It is based upon the 
*   QOI-format (Quite OK Image Format) by Dominic Szablewski and adapted by
*   Tord Bärnfors for working with RGB-565 pixels instead.
*
*=========================================================================*/

enum FORMAT { PNG, JPG, BMP, TGA, UNKNOWN };

const static char extensions_lc[4][5] = { ".png", ".jpg", ".bmp", ".tga" };
const static char extensions_uc[4][5] = { ".PNG", ".JPG", ".BMP", ".TGA" };

int determine_output_format( const char * pNameOfPrg );



int main( int argc, char * argv[] )
{

	int format = determine_output_format( argv[0] );

	if( format == UNKNOWN )
	{
	  printf( "ERROR: Don't know what format to covert to.\n\n" );
	  printf( "You specify the output format by naming this program as follows:\n\n" );
		printf( "        q16topng - Convert to PNG\n" );
		printf( "        q16tojpg - Convert to JPG\n" );
		printf( "        q16tobmp - Convert to BMP\n" );
		printf( "        q16totga - Convert to TGA\n" );

		return 2;
	}

	const char * pExtensionUC = extensions_uc[format];
	const char * pExtensionLC = extensions_lc[format];


	if( argc <= 1 )
	{
	  printf( "Decode Q16 images to %s.\n\n", pExtensionUC );
		printf( "usage: inputFile1 [inputFile2 [...]]\n" );
		printf( "\n" );
		printf( "Rename this program to output different image formats as follows:\n" );
		printf( "\n" );
		printf( "        q16topng - Convert to PNG\n" );
		printf( "        q16tojpg - Convert to JPG\n" );
		printf( "        q16tobmp - Convert to BMP\n" );
		printf( "        q16totga - Convert to TGA\n" );
		printf( "\n" );
		printf( "Note: PNG encoder is simple and primitive and results in 30-50%% larger\n" );
		printf( "      file than normal.\n" );

		return -1;
	}

	uint8_t * staticTable = malloc(65536);

	uint16_t instanceTable[65];

	q16_setupStaticTable( staticTable );


	for( int file = 1 ; file < argc ; file++ )
	{
		void * pLoadedQ16 = NULL;
		uint16_t * pRawPixels = NULL;
		uint8_t * pRawAlpha = NULL;
		uint8_t * pConvertedSrc = NULL;

		// Set input and output filenames

    char * pInputFilename = argv[file];
    char 		outputFilename[512];

    int len = strlen( pInputFilename );
    
    int ofs;
    for( ofs = len ; ofs > 0 ; ofs-- )
      if( pInputFilename[ofs] == '.' )
        break;

    if( ofs == 0 )
      ofs = len;
    
    strncpy( outputFilename, pInputFilename, ofs );
    strncpy( outputFilename + ofs, pExtensionLC, 5 );

    // Load Q16 file
	
		FILE * fp = fopen( pInputFilename, "rb" );
		if( fp == NULL )
		{
			printf( "ERROR: Couldn't open '%s'.\n", pInputFilename );
			goto cleanup;
		}	

		if( fseek( fp, 0, SEEK_END ) != 0 )
		{
			printf( "ERROR: Couldn't seek to end of '%s'.\n", pInputFilename );
			fclose(fp);
			goto cleanup;
		}

		long size = ftell( fp );
		fseek( fp, 0, SEEK_SET );

		printf( "Size of file: %d\n", (int)size );

		pLoadedQ16 = malloc(size);

		if( fread( pLoadedQ16, 1, size, fp ) != size )
		{
			printf( "ERROR: Couldn't read '%s'.\n", pInputFilename );
			fclose(fp);
			goto cleanup;			
		}

		fclose(fp);

		// Read header

		if( size < (long) sizeof(q16_fileheader) )
		{
			printf( "ERROR: '%s' is not a Q16 file.\n", pInputFilename );
			goto cleanup;
		}

		uint16_t width, height;
		uint32_t pixelBytes, alphaBytes;
		uint8_t flags;
		uint8_t version;

		int res = q16_readHeader((q16_fileheader*)pLoadedQ16, &width, &height, &pixelBytes, &alphaBytes, &flags, &version);

		if( res == -1 )
		{
			printf( "ERROR: '%s' is not a Q16 file.\n", pInputFilename );
			goto cleanup;
		}

		if (res == -2)
		{
			printf("ERROR: '%s' is in version %d of the Q16 format. I only support <= %d.\n", pInputFilename, version, q16_version() );
			goto cleanup;
		}


		if( (uint64_t) sizeof(q16_fileheader) + pixelBytes + alphaBytes > (uint64_t) size )
		{
			printf( "ERROR: '%s' is truncated.\n", pInputFilename );
			goto cleanup;
		}

		int nbPixels = width*height;

		// Unpack Q16 to raw 565 BGR.

		pRawPixels = (uint16_t*) malloc(nbPixels*2);


		uint8_t * pBeginCompressedPixels = ((uint8_t*)pLoadedQ16) + sizeof(q16_fileheader);
		uint8_t * pEndCompressedPixels = pBeginCompressedPixels + pixelBytes;

		q16_beginPixelDecompression( instanceTable );
		q16_result decompRes = q16_decompressPixels( pRawPixels, pBeginCompressedPixels, pEndCompressedPixels, 
						 instanceTable, staticTable );

		if( decompRes.endOfStream != 1 || decompRes.readEnd != pEndCompressedPixels || decompRes.writeEnd != pRawPixels + nbPixels )
		{
			printf( "ERROR: Something went wrong when decompressing pixels of '%s'\n", pInputFilename);
			goto cleanup;
		}

		// Unpack alpha channel if present.

		if( alphaBytes > 0 )
		{
			pRawAlpha = (uint8_t*) malloc(nbPixels);

			uint8_t * pBeginCompressedAlpha = pEndCompressedPixels;
			uint8_t * pEndCompressedAlpha = pBeginCompressedAlpha + alphaBytes;

			uint8_t alphaInstanceTable[1];

			q16_beginAlphaDecompression( alphaInstanceTable );
			decompRes = q16_decompressAlpha( pRawAlpha, pBeginCompressedAlpha, pEndCompressedAlpha, alphaInstanceTable );

			if( decompRes.readEnd != pEndCompressedAlpha || decompRes.writeEnd != pRawAlpha + nbPixels )
			{
				printf( "ERROR: Something went wrong when decompressing alpha of '%s'\n", pInputFilename);
				goto cleanup;
			}
		}

		// Convert pixels to 8-bit RGB or RGBA

		int channels = pRawAlpha ? 4 : 3;

		pConvertedSrc = (uint8_t*) malloc(nbPixels*channels);

		uint16_t * pSrc = pRawPixels;
		uint8_t * pDst = pConvertedSrc;

		for( int i = 0 ; i < nbPixels ; i++ )
		{
			uint16_t pixel = * pSrc++;

			* pDst++ = (pixel >> 8) & 0xF8;		// red
			* pDst++ = (pixel >> 3) & 0xFC;		// green
			* pDst++ = (pixel << 3) & 0xF8;		// blue

			if( pRawAlpha )
				* pDst++ = pRawAlpha[i];		// alpha
		}

		// Save output file

		int writeOk;
		switch( format )
		{
			case PNG:
				writeOk = stbi_write_png(outputFilename, width, height, channels, pConvertedSrc, width*channels);
				break;
			case JPG:
				writeOk = stbi_write_jpg(outputFilename, width, height, channels, pConvertedSrc, 90);	// JPG ignores alpha.
				break;
			case BMP:
				writeOk = stbi_write_bmp(outputFilename, width, height, channels, pConvertedSrc);
				break;
			default:
				writeOk = stbi_write_tga(outputFilename, width, height, channels, pConvertedSrc);
				break;
		}

		if( writeOk == 0 )
		{
			printf( "ERROR: Could not generate or write '%s'.\n", outputFilename );
			goto cleanup;
		}
 
		printf( "Converted '%s' to '%s'\n", pInputFilename, outputFilename );
			
cleanup:
		free( pLoadedQ16 );
		free( pRawPixels );
		free( pRawAlpha );
		free( pConvertedSrc );
	}

	free( staticTable );

	return 0;
}

//____ determine_output_format() ______________________________________________

int determine_output_format( const char * pNameOfPrg )
{
	int len = strlen(pNameOfPrg);
	int sub = 8;

	if (strcmp(".exe", pNameOfPrg + len - 4) == 0)
		sub = 12;

	int ofs = strlen(pNameOfPrg) - sub;
	if( ofs < 0 )
		return UNKNOWN;

	pNameOfPrg += ofs;

	if( strncmp("q16topng",pNameOfPrg, 8) == 0 )
		return PNG;

	if( strncmp("q16tojpg",pNameOfPrg, 8) == 0 )
		return JPG;

	if( strncmp("q16tobmp",pNameOfPrg, 8) == 0 )
		return BMP;

	if( strncmp("q16totga",pNameOfPrg, 8) == 0 )
		return TGA;

	return UNKNOWN;
}