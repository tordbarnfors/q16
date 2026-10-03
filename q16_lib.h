

/*
*  QOI-inspired fast and easy compression for 16-bit 565 pixels.
*
*	Q565 compression format:
*

	000 xxxxx		New pixels(1 - 32)
	001 xxxxx		Repeat previous pixel(1 - 32)
	01 xxxxxx		Pixel from index
	1 rrgggbb		Delta rgb values -2 > +1 for r and b, -4 > +3 for g
	1 1010010		Reserved, never written by the encoder. This equals Delta with no change of r, g or b.
					Decoders may place it after the pixel data in memory as a sentinel to detect end of data.

*
*	Alpha compression format (1-byte RLE from WonderGUI, without the primitive size byte):
*
	0 - 127			Copy the following 1-128 alpha values verbatim.
	-1 - -128		Repeat previous alpha value 1-128 times.

*	Neither stream has an end-of-stream marker, their lengths are given by pixelBytes and alphaBytes in the header.
*	An alpha stream (and each separately compressed chunk) always starts with a verbatim copy.
*
*	File layout:
*
*	q16_fileheader		20 bytes.
*	Pixel data			pixelBytes bytes.
*	Alpha data			alphaBytes bytes, 8-bit linear alpha. Only present if alphaBytes > 0.
*/


#include <stdint.h>

enum Q16_FLAGS
{
	Q16_LINEAR_RGB = 1
};

typedef struct q16_fileheader_struct
{
	char		magic[4];		// magic bytes "Q565"
	uint8_t		version;		// version of file format. Must be set to 1 for now.
	uint8_t 	flags;			// See Q16_FLAGS
	uint16_t	width;			// image width in pixels (little endian)
	uint16_t	height;			// image height in pixels (little endian)
	uint16_t	dummy;			// Padding for alignment of uint32_t below. Always 0.
	uint32_t	pixelBytes; 	// Bytes of pixel-data. (littleEndian)
	uint32_t	alphaBytes; 	// Bytes of alpha channel data. Set to 0 if no alpha channel provided. (littleEndian)
	
} q16_fileheader;

typedef struct q16_result_struct
{
	const uint8_t * readEnd;
	void *			writeEnd;
} q16_result;


int			q16_version(void);
uint32_t	q16_minPixelCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls);
uint32_t	q16_minAlphaCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls);

void 		q16_setupStaticTable( uint8_t staticData[65536] );

int 		q16_readHeader( const q16_fileheader * header, uint16_t * width, uint16_t * height, uint32_t * pixelBytes, uint32_t * alphaBytes, uint8_t * flags, uint8_t * version );
void 		q16_writeHeader( q16_fileheader * header, uint16_t width, uint16_t height, uint32_t pixelBytes, uint32_t alphaBytes, uint8_t flags );

void 		q16_beginPixelCompression( uint16_t instanceTable[65] );
uint8_t*	q16_compressPixels(	uint8_t* pDest, const uint16_t* pBegin, const uint16_t* pEnd,
								uint16_t instanceTable[65], const uint8_t staticTable[65536]);

uint8_t*	q16_compressAlpha(	uint8_t* pDest, const uint8_t* pBegin, const uint8_t* pEnd );


void 		q16_beginPixelDecompression(uint16_t instanceTable[65]);
q16_result	q16_decompressPixels( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd,
									uint16_t instanceTable[65], const uint8_t staticTable[65536] );

void 		q16_beginAlphaDecompression(uint8_t instanceTable[1]);
q16_result	q16_decompressAlpha( uint8_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd, uint8_t instanceTable[1] );

