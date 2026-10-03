
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include "q16_lib.h"

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

int main( int argc, char * argv[] )
{
	if( argc <= 1 )
	{
	        printf( "Generates Q565 compressed 16-bit images from PNG/JPG/TGA/GIF/BMP.\n\n");
		printf( "usage: inputFile1 [inputFile2 [...]]\n" );
		return -1;
	}

	uint8_t * staticTable = malloc(65536);

	uint16_t instanceTable[65];

	q16_setupStaticTable( staticTable );


	for( int file = 1 ; file < argc ; file++ )
	{
                char temp[512];

                char * pInputFilename = argv[file];
                
                int len = strlen( pInputFilename );
                
                int ofs;
                for( ofs = len ; ofs > 0 ; ofs-- )
                  if( pInputFilename[ofs] == '.' )
                    break;

                if( ofs == 0 )
                  ofs = len;
        
                strncpy( temp, pInputFilename, ofs );
                strncpy( temp + ofs, ".q16", 5 );
	        char * pOutputFilename = temp;
	
		int width, height, channels;
		stbi_uc* data = stbi_load(pInputFilename, &width, &height, &channels, 4);	// Always expand to RGBA.

		int nbPixels = width * height;

		if( data && (width > 65535 || height > 65535) )
		{
			printf( "ERROR: '%s' is %dx%d pixels. Max size for Q16 is 65535x65535.\n", pInputFilename, width, height );
			stbi_image_free(data);
		}
		else if (data)
		{
			uint16_t * 	pRaw16 = malloc(nbPixels*2);
			uint8_t *	pRawAlpha = malloc(nbPixels);
			uint8_t * 	pRead = (uint8_t*) data;

			int hasAlpha = 0;

			for( int i = 0 ; i < width * height ; i++ )
			{
				uint8_t r = * pRead++ >> 3;
				uint8_t g = * pRead++ >> 2;
				uint8_t b = * pRead++ >> 3;
				uint8_t a = * pRead++;

				pRaw16[i] = (r << 11) | (g << 5) | b; 
				pRawAlpha[i] = a;

				if( a != 255 )
					hasAlpha = 1;		// Only store alpha channel if image isn't fully opaque.
			}

			stbi_image_free(data);

			uint8_t * pCompressed = malloc(q16_minPixelCompressionBuffer(nbPixels, 1));
			uint8_t * pCompressedAlpha = malloc(q16_minAlphaCompressionBuffer(nbPixels, 1));

			q16_beginPixelCompression(instanceTable);
			uint8_t * pCompressedEnd = q16_endPixelCompression( q16_compressPixels( pCompressed, pRaw16, pRaw16 + nbPixels, instanceTable, staticTable ) );

			uint8_t * pCompressedAlphaEnd = pCompressedAlpha;
			if( hasAlpha )
				pCompressedAlphaEnd = q16_compressAlpha( pCompressedAlpha, pRawAlpha, pRawAlpha + nbPixels );

			uint32_t pixelBytes = (uint32_t) (pCompressedEnd - pCompressed);
			uint32_t alphaBytes = (uint32_t) (pCompressedAlphaEnd - pCompressedAlpha);

			q16_fileheader header;
			q16_writeHeader( &header, width, height, pixelBytes, alphaBytes, 0 );


			FILE * fp = fopen( pOutputFilename, "wb" );
			if( fp == NULL )
			{
				printf( "ERROR: Couldn't open '%s' for writing.\n", pOutputFilename );
				goto cleanup;
			}	

			if( fwrite( &header, sizeof(q16_fileheader), 1, fp ) != 1 )
			{
				printf( "ERROR: Couldn't write '%s'.\n", pOutputFilename );
				fclose(fp);
				goto cleanup;
			}	

			if( fwrite( pCompressed, pixelBytes, 1, fp ) != 1 )
			{
				printf( "ERROR: Couldn't write '%s'.\n", pOutputFilename );
				fclose(fp);
				goto cleanup;				
			}

			if( alphaBytes > 0 && fwrite( pCompressedAlpha, alphaBytes, 1, fp ) != 1 )
			{
				printf( "ERROR: Couldn't write '%s'.\n", pOutputFilename );
				fclose(fp);
				goto cleanup;				
			}

			fclose(fp);
			
			if( hasAlpha )
				printf( "Converted '%s' to '%s' (with alpha)\n", pInputFilename, pOutputFilename );
			else
				printf( "Converted '%s' to '%s'\n", pInputFilename, pOutputFilename );
			
cleanup:
			free( pRaw16 );
			free( pRawAlpha );
			free( pCompressed );
			free( pCompressedAlpha );
		}
		else
		{
		  printf( "ERROR: Couldn't read '%s' as an image file. File non-existant or not a supported image type.\n", pInputFilename );
		}
	}

	free( staticTable );

	return 0;
}
