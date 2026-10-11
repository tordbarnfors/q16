
#include "q16_lib.h"

#include <stddef.h>

#if defined(_WIN32)
#	if defined(_M_X64) || defined(_M_IX86)
#		define Q565_IS_BIG_ENDIAN 0
#		define Q565_IS_LITTLE_ENDIAN 1
#	endif
#else
	#if defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__) && defined(__ORDER_LITTLE_ENDIAN__)
	#	 if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	#		define Q565_IS_BIG_ENDIAN 1
	#		define Q565_IS_LITTLE_ENDIAN 0
	#	elif __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	#		define Q565_IS_BIG_ENDIAN 0
	#		define Q565_IS_LITTLE_ENDIAN 1
	#	endif
	#else
	#	ifdef __BIG_ENDIAN__
	#		if __BIG_ENDIAN__
	#			define Q565_IS_BIG_ENDIAN 1
	#			define Q565_IS_LITTLE_ENDIAN 0
	#		endif
	#	endif

	#	ifdef __LITTLE_ENDIAN__
	#		if __LITTLE_ENDIAN__
	#			define Q565_IS_BIG_ENDIAN 0
	#			define Q565_IS_LITTLE_ENDIAN 1
	#		endif
	#	endif
	#endif
#endif

#ifndef Q565_IS_BIG_ENDIAN
#error Could not detect endianness. You need to define Q565_IS_BIG_ENDIAN and Q565_IS_LITTLE_ENDIAN in q16_libc.c
#define Q565_IS_BIG_ENDIAN 0
#define Q565_IS_LITTLE_ENDIAN 0
#endif

// The file header must be 20 bytes without padding on all platforms.

typedef char q16_fileheader_size_check[ sizeof(q16_fileheader) == 20 ? 1 : -1 ];

// This table is used for quick addition and subtraction of pixel delta values.

static const uint16_t deltaTable[128][2] = {
	{0x0000, 0x1082},{0x0000, 0x1081},{0x0000, 0x1080},{0x0001, 0x1080},{0x0000, 0x1062},{0x0000, 0x1061},{0x0000, 0x1060},
	{0x0001, 0x1060},{0x0000, 0x1042},{0x0000, 0x1041},{0x0000, 0x1040},{0x0001, 0x1040},{0x0000, 0x1022},{0x0000, 0x1021},
	{0x0000, 0x1020},{0x0001, 0x1020},{0x0000, 0x1002},{0x0000, 0x1001},{0x0000, 0x1000},{0x0001, 0x1000},{0x0020, 0x1002},
	{0x0020, 0x1001},{0x0020, 0x1000},{0x0021, 0x1000},{0x0040, 0x1002},{0x0040, 0x1001},{0x0040, 0x1000},{0x0041, 0x1000},
	{0x0060, 0x1002},{0x0060, 0x1001},{0x0060, 0x1000},{0x0061, 0x1000},{0x0000, 0x0882},{0x0000, 0x0881},{0x0000, 0x0880},
	{0x0001, 0x0880},{0x0000, 0x0862},{0x0000, 0x0861},{0x0000, 0x0860},{0x0001, 0x0860},{0x0000, 0x0842},{0x0000, 0x0841},
	{0x0000, 0x0840},{0x0001, 0x0840},{0x0000, 0x0822},{0x0000, 0x0821},{0x0000, 0x0820},{0x0001, 0x0820},{0x0000, 0x0802},
	{0x0000, 0x0801},{0x0000, 0x0800},{0x0001, 0x0800},{0x0020, 0x0802},{0x0020, 0x0801},{0x0020, 0x0800},{0x0021, 0x0800},
	{0x0040, 0x0802},{0x0040, 0x0801},{0x0040, 0x0800},{0x0041, 0x0800},{0x0060, 0x0802},{0x0060, 0x0801},{0x0060, 0x0800},
	{0x0061, 0x0800},{0x0000, 0x0082},{0x0000, 0x0081},{0x0000, 0x0080},{0x0001, 0x0080},{0x0000, 0x0062},{0x0000, 0x0061},
	{0x0000, 0x0060},{0x0001, 0x0060},{0x0000, 0x0042},{0x0000, 0x0041},{0x0000, 0x0040},{0x0001, 0x0040},{0x0000, 0x0022},
	{0x0000, 0x0021},{0x0000, 0x0020},{0x0001, 0x0020},{0x0000, 0x0002},{0x0000, 0x0001},{0x0000, 0x0000},{0x0001, 0x0000},
	{0x0020, 0x0002},{0x0020, 0x0001},{0x0020, 0x0000},{0x0021, 0x0000},{0x0040, 0x0002},{0x0040, 0x0001},{0x0040, 0x0000},
	{0x0041, 0x0000},{0x0060, 0x0002},{0x0060, 0x0001},{0x0060, 0x0000},{0x0061, 0x0000},{0x0800, 0x0082},{0x0800, 0x0081},
	{0x0800, 0x0080},{0x0801, 0x0080},{0x0800, 0x0062},{0x0800, 0x0061},{0x0800, 0x0060},{0x0801, 0x0060},{0x0800, 0x0042},
	{0x0800, 0x0041},{0x0800, 0x0040},{0x0801, 0x0040},{0x0800, 0x0022},{0x0800, 0x0021},{0x0800, 0x0020},{0x0801, 0x0020},
	{0x0800, 0x0002},{0x0800, 0x0001},{0x0800, 0x0000},{0x0801, 0x0000},{0x0820, 0x0002},{0x0820, 0x0001},{0x0820, 0x0000},
	{0x0821, 0x0000},{0x0840, 0x0002},{0x0840, 0x0001},{0x0840, 0x0000},{0x0841, 0x0000},{0x0860, 0x0002},{0x0860, 0x0001},
	{0x0860, 0x0000},{0x0861, 0x0000}
};


static inline uint16_t endianSwap16( uint16_t in )
{
	return ((in >> 8) | (in << 8));
}

static inline uint16_t toLittleEndian( uint16_t value )
{
	if( Q565_IS_LITTLE_ENDIAN )
		return value;
	else
		return endianSwap16(value);
}

static inline uint16_t fromLittleEndian( uint16_t value )
{
	if( Q565_IS_LITTLE_ENDIAN )
		return value;
	else
		return endianSwap16(value);
}

static inline uint32_t endianSwap32( uint32_t in )
{
	return (in >> 24) | ((in >> 8) & 0x0000FF00) | ((in << 8) & 0x00FF0000) | (in << 24);
}

static inline uint32_t toLittleEndian32( uint32_t value )
{
	if( Q565_IS_LITTLE_ENDIAN )
		return value;
	else
		return endianSwap32(value);
}

static inline uint32_t fromLittleEndian32( uint32_t value )
{
	if( Q565_IS_LITTLE_ENDIAN )
		return value;
	else
		return endianSwap32(value);
}

//____ q16_version() __________________________________________________________

int q16_version(void)
{
	return 1;
}

//____ q16_minPixelCompressionBuffer() ________________________________________

uint32_t q16_minPixelCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls)
{
	return nbPixels * 2 + nbPixels / 32 + nbCalls;		// Worst case is storing everything as literals with a new opcode every 32 pixels.
}

//____ q16_minAlphaCompressionBuffer() ________________________________________

uint32_t q16_minAlphaCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls)
{
	return nbPixels + nbPixels / 128 + nbCalls;			// Worst case is storing everything verbatim with a new opcode every 128 values.
}


//____ pixelToIndex() ________________________________________________________
//
// Palette index of a pixel. The static table holds this for every pixel.

static inline uint8_t pixelToIndex( uint16_t p )
{
	return (uint8_t)((p + (p >> 3) + (p >> 4) + (p >> 10)) & 63);
}

// The pixel compression and decompression functions are written once and
// inlined into the functions without the table (useTable is 0, the palette
// index is calculated) and the ...T functions (useTable is 1, the palette
// index is looked up in pixelToIndexTable). useTable is a constant in each,
// so the compiler removes the test.

#if defined(__GNUC__)
#	define Q16_ALWAYS_INLINE	static inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#	define Q16_ALWAYS_INLINE	static __forceinline
#else
#	define Q16_ALWAYS_INLINE	static inline
#endif

#define PIXEL_INDEX(p)		(useTable ? pixelToIndexTable[p] : pixelToIndex(p))


//____ q16_setupStaticTable() ___________________________________________________________

#ifndef Q16_NO_STATIC_TABLE
void q16_setupStaticTable( uint8_t pixelToIndexTable[65536] )
{
	// Generate pixelToIndexTable. Decides which of the 64 palette entries
	// each pixel should go into.

	for (uint32_t i = 0; i < 65536; i++)
		pixelToIndexTable[i] = pixelToIndex((uint16_t)i);
}
#endif


//____ q16_readHeader() ______________________________________________________

int q16_readHeader( const q16_fileheader * header, uint16_t * width, uint16_t * height, uint32_t * pixelBytes, uint32_t * alphaBytes, uint8_t * flags, uint8_t * version )
{
	if (header->magic[0] != 'Q' || header->magic[1] != '5' || header->magic[2] != '6' || header->magic[3] != '5')
	{
		*width = 0;
		*height = 0;
		*pixelBytes = 0;
		*alphaBytes = 0;
		*flags = 0;
		*version = 0;
		return -1;				// Not a Q16 file.
	}


	* width = fromLittleEndian(header->width);
	* height = fromLittleEndian(header->height);
	* pixelBytes = fromLittleEndian32(header->pixelBytes);
	* alphaBytes = fromLittleEndian32(header->alphaBytes);
	* flags = header->flags;
	* version = header->version;

	if (header->version != 1)
		return -2;				// Version unsupported by this version of the library.

	return 0;
}


//____ q16_writeHeader() ______________________________________________________

void q16_writeHeader( q16_fileheader * header, uint16_t width, uint16_t height, uint32_t pixelBytes, uint32_t alphaBytes, uint8_t flags )
{
	header->magic[0] = 'Q';
	header->magic[1] = '5';
	header->magic[2] = '6';	
	header->magic[3] = '5';

	header->version = 1;
	header->flags = flags;
	header->width = toLittleEndian(width);
	header->height = toLittleEndian(height);
	header->dummy = 0;
	header->pixelBytes = toLittleEndian32(pixelBytes);
	header->alphaBytes = toLittleEndian32(alphaBytes);
}

//____ q16_beginPixelDecompression() ______________________________________________________

void q16_beginPixelDecompression(uint16_t instanceData[65])
{
	for (int i = 0; i < 65; i++)
		instanceData[i] = 0;
}


//____ q16_decompressPixels() / q16_decompressPixelsT() ________________________

Q16_ALWAYS_INLINE q16_result decompressPixels( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd,
											  uint16_t instanceData[65], const uint8_t * pixelToIndexTable, const int useTable )
{
	uint16_t*	palette = instanceData + 1;
	uint16_t	  lastPixel = instanceData[0];
	const uint8_t * pRead = pBegin;

	while (pRead < pEnd)
	{
		uint8_t v = *pRead++;

		if (v < 0x40)
		{
			if (v < 0x20)
			{
				int nbPixels = v + 1;
				if ((size_t)(pEnd - pRead) < 2 * nbPixels)
				{ 
					pRead--; 
					break; 
				}

				for (int i = 0; i < nbPixels; i++)
				{
					lastPixel = *pRead++;
					lastPixel |= ((uint16_t)(*pRead++)) << 8;
					*pDest++ = lastPixel;

					palette[PIXEL_INDEX(lastPixel)] = lastPixel;
				}
			}
			else
			{
				int nbPixels = (v & 0x1F) + 1;
				for (int i = 0; i < nbPixels; i++)
					*pDest++ = lastPixel;
			}
		}
		else
		{
			if (v < 0x80)
			{
				int index = v & 0x3F;
				lastPixel = palette[index];
				*pDest++ = lastPixel;
			}
			else
			{
				int index = v & 0x7F;
				lastPixel += deltaTable[index][0];
				lastPixel -= deltaTable[index][1];

				*pDest++ = lastPixel;
				palette[PIXEL_INDEX(lastPixel)] = lastPixel;
			}
		}
	}

	instanceData[0] = lastPixel;

	q16_result res;
	res.readEnd = pRead;
	res.writeEnd = pDest;
	return res;
}

q16_result q16_decompressPixels( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd, uint16_t instanceData[65] )
{
	return decompressPixels( pDest, pBegin, pEnd, instanceData, NULL, 0 );
}

#ifndef Q16_NO_STATIC_TABLE
q16_result q16_decompressPixelsT( uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd,
								  uint16_t instanceData[65], const uint8_t staticData[65536] )
{
	return decompressPixels( pDest, pBegin, pEnd, instanceData, staticData, 1 );
}
#endif

//____ q16_beginPixelCompression() ________________________________________________________

void q16_beginPixelCompression(uint16_t instanceData[65])
{
	for (int i = 0; i < 65; i++)
		instanceData[i] = 0;
}

//____ q16_compressPixels() / q16_compressPixelsT() __________________________

Q16_ALWAYS_INLINE uint8_t * compressPixels( uint8_t * pDest, const uint16_t * pBegin, const uint16_t * pEnd,
											uint16_t instanceData[65], const uint8_t * pixelToIndexTable, const int useTable )
{
	uint16_t* palette = instanceData + 1;
	uint16_t lastPixel = instanceData[0];

	const uint16_t* pRead = pBegin;
	uint8_t* pWrite = pDest;
	while (pRead < pEnd)
	{
		uint16_t pixel = *pRead++;
		 
		if (pixel == lastPixel)
		{
			uint16_t count = 1;
			while (pRead < pEnd && *pRead == pixel && count < 32)
			{
				count++;
				pRead++;
			}

			*pWrite++ = 0x20 | (count - 1);						// Store as repeat of previous value
		}
		else
		{
			uint8_t index = PIXEL_INDEX(pixel);

			if (palette[index] == pixel)
				*pWrite++ = 0x40 | index;						// Store as index lookup
			else
			{
				uint16_t lastR = (lastPixel >> 11) & 0x001F;
				uint16_t lastG = (lastPixel >> 5) & 0x003F;
				uint16_t lastB = lastPixel & 0x001F;

				uint16_t r = (pixel >> 11) & 0x001F;
				uint16_t g = (pixel >> 5) & 0x003F;
				uint16_t b = pixel & 0x001F;

				uint16_t diffR = r - lastR + 2;
				uint16_t diffG = g - lastG + 4;
				uint16_t diffB = b - lastB + 2;


				if (diffR < 4 && diffG < 8 && diffB < 4)
				{
					*pWrite++ = 0x80 | (diffR << 5) | (diffG << 2) | diffB;		// Store as RGB-delta
					palette[index] = pixel;
				}
				else
				{
					uint8_t * pCounter = pWrite;

					*pWrite++ = 1;
					*pWrite++ = (uint8_t)pixel;
					*pWrite++ = (uint8_t)(pixel >> 8);

					palette[index] = pixel;

					int count = 1;
					while (pRead < pEnd && count < 32)
					{
						uint16_t nextPixel = *pRead;

						if (nextPixel == pixel)
							break;				// Next pixel is start of repetive section

						uint8_t nextIndex = PIXEL_INDEX(nextPixel);
						if (palette[nextIndex] == nextPixel)
							break;				// Next pixel can be taken from index;

						uint16_t nextR = (nextPixel >> 11) & 0x001F;
						uint16_t nextG = (nextPixel >> 5) & 0x003F;
						uint16_t nextB = nextPixel & 0x001F;

						uint16_t diffB = nextB - b + 2;
						uint16_t diffG = nextG - g + 4;
						uint16_t diffR = nextR - r + 2;

						if (diffR < 4 && diffG < 8 && diffB < 4)
							break;				// Next pixel can be stored as RGB-delta.

						palette[nextIndex] = nextPixel;

						pixel = nextPixel;

						r = nextR;
						g = nextG;
						b = nextB;

						*pWrite++ = (uint8_t)pixel;
						*pWrite++ = (uint8_t)(pixel >> 8);

						pRead++;
						count++;
					}

					*pCounter = count - 1;
				}

			}
		}

		lastPixel = pixel;
	}
	
	instanceData[0] = lastPixel;
	return pWrite;
}

uint8_t * q16_compressPixels( uint8_t * pDest, const uint16_t * pBegin, const uint16_t * pEnd, uint16_t instanceData[65] )
{
	return compressPixels( pDest, pBegin, pEnd, instanceData, NULL, 0 );
}

#ifndef Q16_NO_STATIC_TABLE
uint8_t * q16_compressPixelsT( uint8_t * pDest, const uint16_t * pBegin, const uint16_t * pEnd,
							   uint16_t instanceData[65], const uint8_t staticData[65536] )
{
	return compressPixels( pDest, pBegin, pEnd, instanceData, staticData, 1 );
}
#endif

//____ q16_compressAlpha() ____________________________________________________
//
// Port of the 1-byte RLE compressor from WonderGUI, without the primitive size byte.

uint8_t* q16_compressAlpha( uint8_t* pDest, const uint8_t* pBegin, const uint8_t* pEnd )
{
	if( pBegin >= pEnd )
		return pDest;

	const uint8_t* pRead = pBegin;
	uint8_t* pWrite = pDest;

	uint8_t* pSpanHead = pWrite++;
	uint8_t last = *pRead++;
	*pWrite++ = last;

	int span = 1;

	while( pRead < pEnd )
	{
		if( (pRead + 1) < pEnd && pRead[0] == last && pRead[1] == last )
		{
			*pSpanHead = (uint8_t)(span - 1);

			long repeats = 2;					// long, since a run can be longer than a 16-bit int.
			while( repeats < pEnd - pRead && pRead[repeats] == last )
				repeats++;

			while( repeats >= 2 )
			{
				int nToWrite = repeats < 128 ? (int) repeats : 128;
				*pWrite++ = (uint8_t)(-nToWrite);
				repeats -= nToWrite;
				pRead += nToWrite;
			}

			if( pRead == pEnd )
				return pWrite;

			pSpanHead = pWrite++;
			span = 0;
		}
		else
		{
			if( span == 128 )
			{
				*pSpanHead = 127;
				pSpanHead = pWrite++;
				span = 0;
			}
		}

		last = *pRead++;
		*pWrite++ = last;
		span++;
	}

	*pSpanHead = (uint8_t)(span - 1);
	return pWrite;
}

//____ q16_beginAlphaDecompression() __________________________________________

void q16_beginAlphaDecompression(uint8_t instanceData[1])
{
	instanceData[0] = 0;
}

//____ q16_decompressAlpha() __________________________________________________

q16_result q16_decompressAlpha( uint8_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd, uint8_t instanceData[1] )
{
	uint8_t lastAlpha = instanceData[0];
	const uint8_t * pRead = pBegin;
	uint8_t * pWrite = pDest;

	while( pRead < pEnd )
	{
		int length = (int8_t) *pRead++;

		if( length >= 0 )
		{
			length++;
			if( pEnd - pRead < length )
			{
				pRead--;
				break;
			}

			for( int i = 0 ; i < length ; i++ )
				*pWrite++ = *pRead++;

			lastAlpha = pRead[-1];
		}
		else
		{
			for( int i = 0 ; i < -length ; i++ )
				*pWrite++ = lastAlpha;
		}
	}

	instanceData[0] = lastAlpha;

	q16_result res;
	res.readEnd = pRead;
	res.writeEnd = pWrite;
	return res;
}