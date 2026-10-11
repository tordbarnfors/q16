
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include "q16_lib.h"
#include <string.h>

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
		stbi_uc* data = stbi_load(pInputFilename, &width, &height, &channels, 4);	// Always expand to RGBA.

		if (data)
		{
			int nbPixels = width * height;

			uint16_t * 	pRawInput = malloc(nbPixels * 2);
			uint8_t *	pRawAlphaInput = malloc(nbPixels);
			uint8_t * 	pRead = (uint8_t*) data;

			int hasAlpha = 0;

			for( int i = 0 ; i < nbPixels ; i++ )
			{
				uint8_t r = * pRead++ >> 3;
				uint8_t g = * pRead++ >> 2;
				uint8_t b = * pRead++ >> 3;
				uint8_t a = * pRead++;

				pRawInput[i] = (r << 11) | (g << 5) | b; 
				pRawAlphaInput[i] = a;

				if( a != 255 )
					hasAlpha = 1;
			}

			stbi_image_free(data);

			// Pixels

			uint8_t * pCompressed = malloc(q16_minPixelCompressionBuffer(nbPixels, 1) + 9);

			q16_beginPixelCompression(instanceTable);

			uint8_t * pCompressedEnd = q16_compressPixels( pCompressed, pRawInput, pRawInput + nbPixels, instanceTable );
			strcpy((char*)pCompressedEnd, "NANANANA");

			uint16_t* pRawOutput = malloc(nbPixels * 2 + 9);

			strcpy(((char*)pRawOutput) + nbPixels * 2, "DEADBEEF");

			q16_beginPixelDecompression(instanceTable);

			q16_result res = q16_decompressPixels(pRawOutput, pCompressed, pCompressedEnd, instanceTable );

			int nbWritten = (int) (((uint16_t*)res.writeEnd) - pRawOutput);
			int nbCompared = nbWritten < nbPixels ? nbWritten : nbPixels;

			int ofs = 0;
			while (ofs < nbCompared && pRawOutput[ofs] == pRawInput[ofs])
				ofs++;

			int pixelsOk = 0;

			if (ofs < nbCompared)
				printf("ERROR: Pixel start being different at offset %d.\n", ofs);
			else if (strncmp(((char*)pRawOutput) + nbPixels * 2, "DEADBEEF", 8) != 0)
				printf("ERROR: Wrote beyond end of pixel output.\n");
			else if (nbWritten != nbPixels)
				printf("ERROR: Decompressed %d pixels, expected %d.\n", nbWritten, nbPixels);
			else if (res.readEnd != pCompressedEnd)
				printf("ERROR: Pixel decompression stopped before end of stream.\n");
			else
				pixelsOk = 1;

			// The ...T versions with the static table must give the same results.

			if (pixelsOk)
			{
				uint8_t * pCompressedT = malloc(q16_minPixelCompressionBuffer(nbPixels, 1));
				uint16_t * pRawOutputT = malloc(nbPixels * 2);

				q16_beginPixelCompression(instanceTable);
				uint8_t * pCompressedEndT = q16_compressPixelsT( pCompressedT, pRawInput, pRawInput + nbPixels, instanceTable, staticTable );

				q16_beginPixelDecompression(instanceTable);
				q16_result resT = q16_decompressPixelsT( pRawOutputT, pCompressed, pCompressedEnd, instanceTable, staticTable );

				if (pCompressedEndT - pCompressedT != pCompressedEnd - pCompressed || memcmp(pCompressedT, pCompressed, pCompressedEnd - pCompressed) != 0)
				{
					printf("ERROR: q16_compressPixelsT() gives a different stream.\n");
					pixelsOk = 0;
				}
				else if (resT.readEnd != pCompressedEnd || resT.writeEnd != pRawOutputT + nbPixels || memcmp(pRawOutputT, pRawInput, nbPixels * 2) != 0)
				{
					printf("ERROR: q16_decompressPixelsT() gives different pixels.\n");
					pixelsOk = 0;
				}
				free( pCompressedT );
				free( pRawOutputT );
			}

			// Alpha

			int alphaOk = 1;
			uint8_t * pCompressedAlpha = NULL;
			uint8_t * pCompressedAlphaEnd = NULL;
			uint8_t * pRawAlphaOutput = NULL;

			if (pixelsOk && hasAlpha)
			{
				alphaOk = 0;

				pCompressedAlpha = malloc(q16_minAlphaCompressionBuffer(nbPixels, 1) + 9);
				pCompressedAlphaEnd = q16_compressAlpha(pCompressedAlpha, pRawAlphaInput, pRawAlphaInput + nbPixels);
				strcpy((char*)pCompressedAlphaEnd, "NANANANA");

				pRawAlphaOutput = malloc(nbPixels + 9);
				strcpy(((char*)pRawAlphaOutput) + nbPixels, "DEADBEEF");

				uint8_t alphaInstanceTable[1];

				q16_beginAlphaDecompression(alphaInstanceTable);
				res = q16_decompressAlpha(pRawAlphaOutput, pCompressedAlpha, pCompressedAlphaEnd, alphaInstanceTable);

				nbWritten = (int) (((uint8_t*)res.writeEnd) - pRawAlphaOutput);
				nbCompared = nbWritten < nbPixels ? nbWritten : nbPixels;

				ofs = 0;
				while (ofs < nbCompared && pRawAlphaOutput[ofs] == pRawAlphaInput[ofs])
					ofs++;

				if (ofs < nbCompared)
					printf("ERROR: Alpha start being different at offset %d.\n", ofs);
				else if (strncmp(((char*)pRawAlphaOutput) + nbPixels, "DEADBEEF", 8) != 0)
					printf("ERROR: Wrote beyond end of alpha output.\n");
				else if (nbWritten != nbPixels)
					printf("ERROR: Decompressed %d alpha values, expected %d.\n", nbWritten, nbPixels);
				else if (res.readEnd != pCompressedAlphaEnd)
					printf("ERROR: Alpha decompression stopped before end of stream.\n");
				else
					alphaOk = 1;
			}

			if (pixelsOk && alphaOk)
			{
				if (hasAlpha)
					printf("SUCCESS (pixels: %d bytes, alpha: %d bytes)\n", (int)(pCompressedEnd - pCompressed), (int)(pCompressedAlphaEnd - pCompressedAlpha));
				else
					printf("SUCCESS (pixels: %d bytes, no alpha)\n", (int)(pCompressedEnd - pCompressed));
			}

			free( pRawInput );
			free( pRawAlphaInput );
			free( pRawOutput );
			free( pRawAlphaOutput );
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
