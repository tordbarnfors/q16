

/*
*  QOI-inspired fast and easy compression for 16-bit 565 pixels.
*
*	Q565 compression format:
*
	000 xxxxx		New pixels(1 - 32)
	001 xxxxx		Repeat previous pixel(1 - 32)
	01 xxxxxx		Pixel from index
	1 rrgggbb		Delta rgb values -2 > +1 for r and b, -4 > +3 for g
*/

#include <stdint.h>

enum Q16_FLAGS
{
	Q16_LINEAR_RGB = 1
};

typedef struct q16_fileheader_struct
{
	char		magic[4]; // magic bytes "Q565"
	uint16_t	width; // image width in pixels (BE)
	uint16_t	height; // image height in pixels (BE)
	uint8_t 	flags; // See Q16_FLAGS
	uint8_t		dummy; // dummy
} q16_fileheader;


int 		q16_setup( uint16_t palette[64], uint8_t pixelToIndexTable[65536] );

int 		q16_readHeader( q16_fileheader * header, uint16_t * width, uint16_t * height, uint8_t * flags );
void 		q16_writeHeader( q16_fileheader * header, uint16_t width, uint16_t height, uint8_t flags );

int 		q16_reset( uint16_t palette[64] );

uint16_t *	q16_decompressData( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd, 
						 uint16_t palette[64], const uint8_t pixelToIndexTable[65536] );

uint8_t *	q16_compressData( uint8_t * pDest, const uint16_t * pBegin, const uint16_t * pEnd, 
						 uint16_t palette[64], const uint8_t pixelToIndexTable[65536], uint16_t lastPixel[1] );
