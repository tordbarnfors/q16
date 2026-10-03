
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include "q16_lib.h"

/*=========================================================================
*
*   q16bench
*
*   Program for testing and benchmarking Q16 library.
*
*	Files entered on the commandline are first compressed and then decompressed, 
*	reporting speed and compression ratio.
*
*	Decompressed result is also checked against original pixel data and any
*	inaccuracy is flagged.
* 
*   Q565 is a very fast and simple but still quite efficient lossless
*   compression method for 16-bit images in RGB-565 format. It is based upon the 
*   QOI-format (Quite OK Image Format) by Dominic Szablewski and adapted by
*   Tord Bärnfors for working with RGB-565 pixels instead.
*
*=========================================================================*/

int main( int argc, char * argv[] )
{
	if( argc <= 1 )
	{
	    printf( "Benchmarks Q16 compression and validates that no pixel changed.\n");
		printf("Input format can be PNG/JPG/TGA/GIF/BMP.\n\n");
			
		printf( "usage: inputFile1 [inputFile2 [...]]\n" );
		return -1;
	}

	uint8_t * staticTable = malloc(65536);

	uint16_t instanceTable[65];

	q16_setupStaticTable( staticTable );


	for( int file = 1 ; file < argc ; file++ )
	{
		char * pInputFilename = argv[file];
 
		printf("Processing %s... ", pInputFilename);

		int width, height, channels;
		stbi_uc* data = stbi_load(pInputFilename, &width, &height, &channels, 0);

		if (data && (channels == 3 || channels == 4) )
		{
			uint16_t * 	pRawInput = malloc(width * height*2);
			uint8_t * 	pRead = (uint8_t*) data;

			int skipAlpha = channels - 3;

			for( int i = 0 ; i < width * height ; i++ )
			{
				uint8_t r = * pRead++ >> 3;
				uint8_t g = * pRead++ >> 2;
				uint8_t b = * pRead++ >> 3;
				pRead += skipAlpha;

				pRawInput[i] = (r << 11) | (g << 5) | b; 
			}

			stbi_image_free(data);

			int nbPixels = width * height;

			uint8_t * pCompressed = malloc(nbPixels * 2 + nbPixels / 32 + 2 + 9);

			q16_beginCompression(instanceTable);

			uint8_t * pCompressedEnd = q16_compressData( pCompressed, pRawInput, pRawInput + nbPixels, instanceTable, staticTable );
			pCompressedEnd = q16_endCompression(pCompressedEnd);
			strcpy((char*)pCompressedEnd, "NANANANA");

			uint16_t* pRawOutput = malloc(nbPixels * 2 + 9);

			strcpy(((char*)pRawOutput) + nbPixels * 2, "DEADBEEF");

			q16_beginDecompression(instanceTable);

			q16_result res = q16_decompressData(pRawOutput, pCompressed, pCompressedEnd, instanceTable, staticTable );

			int nbWritten = (int) (res.writeEnd - pRawOutput);
			int nbCompared = nbWritten < nbPixels ? nbWritten : nbPixels;

			int ofs = 0;
			while (ofs < nbCompared && pRawOutput[ofs] == pRawInput[ofs])
				ofs++;

			if (ofs < nbCompared)
				printf("ERROR: Pixel start being different at offset %d.\n", ofs);
			else if (strncmp(((char*)pRawOutput) + nbPixels * 2, "DEADBEEF", 8) != 0)
				printf("ERROR: Wrote beyond end of output.\n");
			else if (nbWritten != nbPixels)
				printf("ERROR: Decompressed %d pixels, expected %d.\n", nbWritten, nbPixels);
			else if (!res.endOfStream || res.readEnd != pCompressedEnd)
				printf("ERROR: End of stream not detected where expected.\n");
			else
				printf("SUCCESS\n");

			free( pRawInput );
			free(pRawOutput);
			free( pCompressed );
		}
		else
		{
		  printf( "ERROR: Couldn't read '%s' as an image file. File non-existant or not a supported image type.\n", pInputFilename );
		}
	}

	free( staticTable );

	return 0;
}
