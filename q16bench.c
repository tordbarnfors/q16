
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

			uint8_t * pCompressedEnd = q16_compressPixels( pCompressed, pRawInput, pRawInput + nbPixels, instanceTable, staticTable );
			pCompressedEnd = q16_endPixelCompression(pCompressedEnd);
			strcpy((char*)pCompressedEnd, "NANANANA");

			uint16_t* pRawOutput = malloc(nbPixels * 2 + 9);

			strcpy(((char*)pRawOutput) + nbPixels * 2, "DEADBEEF");

			q16_beginPixelDecompression(instanceTable);

			q16_result res = q16_decompressPixels(pRawOutput, pCompressed, pCompressedEnd, instanceTable, staticTable );

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
			else if (!res.endOfStream || res.readEnd != pCompressedEnd)
				printf("ERROR: End of pixel stream not detected where expected.\n");
			else
				pixelsOk = 1;

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

				res = q16_decompressAlpha(pRawAlphaOutput, pCompressedAlpha, pCompressedAlphaEnd);

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
