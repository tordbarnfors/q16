
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

	uint8_t * pixelToIndexTable = malloc(65536);

	uint16_t palette[64];
	uint16_t lastPixel = 0;

	q16_setup( palette, pixelToIndexTable );


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
		stbi_uc* data = stbi_load(pInputFilename, &width, &height, &channels, 0);

		if (data && (channels == 3 || channels == 4) )
		{
			uint16_t * 	pRaw16 = malloc(width * height*2);
			uint8_t * 	pRead = (uint8_t*) data;

			int skipAlpha = channels - 3;

			for( int i = 0 ; i < width * height ; i++ )
			{
				uint8_t r = * pRead++ >> 3;
				uint8_t g = * pRead++ >> 2;
				uint8_t b = * pRead++ >> 3;
				pRead += skipAlpha;

				pRaw16[i] = (r << 11) | (g << 5) | b; 
			}

			stbi_image_free(data);

			uint8_t * pCompressed = malloc(width*height*3);

			uint8_t * pCompressedEnd = q16_compressData( pCompressed, pRaw16, pRaw16 + width * height, palette, pixelToIndexTable, &lastPixel );

			q16_fileheader header;
			q16_writeHeader( &header, width, height, 0 );


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

			if( fwrite( pCompressed, pCompressedEnd - pCompressed, 1, fp ) != 1 )
			{
				printf( "ERROR: Couldn't write '%s'.\n", pOutputFilename );
				fclose(fp);
				goto cleanup;				
			}

			fclose(fp);
			
			printf( "Converted '%s' to '%s'\n", pInputFilename, pOutputFilename );
			
cleanup:
			free( pRaw16 );
			free( pCompressed );
		}
		else
		{
		  printf( "ERROR: Couldn't read '%s' as an image file. File non-existant or not a supported image type.\n", pInputFilename );
		}
	}

	free( pixelToIndexTable );

	return 0;
}
