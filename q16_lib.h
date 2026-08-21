

/*
*  QOI-inspired fast and easy compression for 16-bit 565 pixels.
*
*	Q565 compression format:
*

	000 xxxxx		New pixels(1 - 32)
	001 xxxxx		Repeat previous pixel(1 - 32)
	01 xxxxxx		Pixel from index
	1 rrgggbb		Delta rgb values -2 > +1 for r and b, -4 > +3 for g
	1 1010010		End of stream. This equals Delta with no change of r, g or b, which is forbidden.
*/


#include <stdint.h>

enum Q16_FLAGS
{
	Q16_LINEAR_RGB = 1
};

typedef struct q16_fileheader_struct
{
	char		magic[4];	// magic bytes "Q565"
	uint16_t	width;		// image width in pixels (little endian)
	uint16_t	height;		// image height in pixels (little endian)
	uint8_t		version;	// version of file format. Must be set to 1 for now.
	uint8_t 	flags;		// See Q16_FLAGS
} q16_fileheader;

typedef struct q16_result_struct
{
	const uint8_t * readEnd;
	uint16_t *		writeEnd;
	int				endOfStream;	// 1 = true, 0 = false
} q16_result;


int			q16_version(void);
uint32_t	q16_minCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls);

void 		q16_setupStaticTable( uint8_t staticData[65536] );

int 		q16_readHeader( const q16_fileheader * header, uint16_t * width, uint16_t * height, uint8_t * version, uint8_t * flags );
void 		q16_writeHeader( q16_fileheader * header, uint16_t width, uint16_t height, uint8_t flags );

void 		q16_beginCompression( uint16_t instanceTable[65] );
uint8_t*	q16_compressData(	uint8_t* pDest, const uint16_t* pBegin, const uint16_t* pEnd,
								uint16_t instanceTable[65], const uint8_t staticTable[65536]);
uint8_t*	q16_endCompression(uint8_t* pDest);



void 		q16_beginDecompression(uint16_t instanceTable[65]);
q16_result	q16_decompressData( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd,
								uint16_t instanceTable[65], const uint8_t staticTable[65536] );


