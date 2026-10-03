
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

//____ q16_version() __________________________________________________________

int q16_version(void)
{
	return 1;
}

//____ q16_minCompressionBuffer() _____________________________________________

uint32_t q16_minCompressionBuffer(uint32_t nbPixels, uint32_t nbCalls)
{
	return nbPixels * 2 + nbPixels / 32 + nbCalls + 1;	// Worst case is storing everything as literals with a new opcode every 32 pixels and EOS at the end.
}


//____ q16_setupStaticTable() ___________________________________________________________

void q16_setupStaticTable( uint8_t pixelToIndexTable[65536] )
{
	// Generate pixelToIndexTable. Decides which of the 64 palette entries
	// each pixel should go into.

	for (uint32_t i = 0; i < 65536; i++)
	{
		uint16_t p = i;
		pixelToIndexTable[i] = (uint8_t)((p + (p >> 3) + (p >> 4) + (p >> 10)) & 63);
	}
}


//____ q16_readHeader() ______________________________________________________

int q16_readHeader( const q16_fileheader * header, uint16_t * width, uint16_t * height, uint8_t * version, uint8_t * flags )
{
	if (header->magic[0] != 'Q' || header->magic[1] != '5' || header->magic[2] != '6' || header->magic[3] != '5')
	{
		*width = 0;
		*height = 0;
		*version = 0;
		*flags = 0;
		return -1;				// Not a Q16 file.
	}


	* width = fromLittleEndian(header->width);
	* height = fromLittleEndian(header->height);
	* version = header->version;
	* flags = header->flags;

	if (header->version != 1)
		return -2;				// Version unsupported by this version of the library.

	return 0;
}


//____ q16_writeHeader() ______________________________________________________

void q16_writeHeader( q16_fileheader * header, uint16_t width, uint16_t height, uint8_t flags )
{
	header->magic[0] = 'Q';
	header->magic[1] = '5';
	header->magic[2] = '6';	
	header->magic[3] = '5';

	header->width = toLittleEndian(width);
	header->height = toLittleEndian(height);
	header->version = 1;
	header->flags = flags;
}

//____ q16_beginDecompression() ___________________________________________________________

void q16_beginDecompression(uint16_t instanceData[65])
{
	for (int i = 0; i < 65; i++)
		instanceData[i] = 0;
}


//____ q16_decompressData() __________________________________________________

q16_result q16_decompressData(	uint16_t * pDest, const uint8_t * pBegin, const uint8_t * pEnd, 
								uint16_t instanceData[65], const uint8_t staticData[65536] )
{
	const uint8_t * pixelToIndexTable = staticData;
	uint16_t*	palette = instanceData + 1;
	uint16_t	  lastPixel = instanceData[0];
	const uint8_t * pRead = pBegin;

	q16_result res;
	res.endOfStream = 0;

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

					palette[pixelToIndexTable[lastPixel]] = lastPixel;
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
				if (v == 0xD2)						// End of stream
				{
					res.endOfStream = 1;
					break;
				}


				int index = v & 0x7F;
				lastPixel += deltaTable[index][0];
				lastPixel -= deltaTable[index][1];

				*pDest++ = lastPixel;
				palette[pixelToIndexTable[lastPixel]] = lastPixel;
			}
		}
	}

	instanceData[0] = lastPixel;
	res.readEnd = pRead;
	res.writeEnd = pDest;
	return res;
}

//____ q16_beginCompression() ___________________________________________________________

void q16_beginCompression(uint16_t instanceData[65])
{
	for (int i = 0; i < 65; i++)
		instanceData[i] = 0;
}

//____ q16_compressData() __________________________________________________

uint8_t * q16_compressData( uint8_t * pDest, const uint16_t * pBegin, const uint16_t * pEnd, 
						 uint16_t instanceData[65], const uint8_t staticData[65536] )
{
	const uint8_t* pixelToIndexTable = staticData;

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
			uint8_t index = pixelToIndexTable[pixel];

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

						uint8_t nextIndex = pixelToIndexTable[nextPixel];
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

//____ q16_endCompression() ___________________________________________________

uint8_t* q16_endCompression(uint8_t* pDest)
{
	*pDest++ = 0xD2;
	return pDest;
}