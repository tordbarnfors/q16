/* The C Q16 library with prefixed names, so it can be linked together with
*  the assembly decoder, which uses some of the same names. */

#define q16_version						c_q16_version
#define q16_minPixelCompressionBuffer	c_q16_minPixelCompressionBuffer
#define q16_minAlphaCompressionBuffer	c_q16_minAlphaCompressionBuffer
#define q16_setupStaticTable			c_q16_setupStaticTable
#define q16_readHeader					c_q16_readHeader
#define q16_writeHeader					c_q16_writeHeader
#define q16_beginPixelCompression		c_q16_beginPixelCompression
#define q16_compressPixels				c_q16_compressPixels
#define q16_compressPixelsT				c_q16_compressPixelsT
#define q16_compressAlpha				c_q16_compressAlpha
#define q16_beginPixelDecompression		c_q16_beginPixelDecompression
#define q16_decompressPixels			c_q16_decompressPixels
#define q16_decompressPixelsT			c_q16_decompressPixelsT
#define q16_beginAlphaDecompression		c_q16_beginAlphaDecompression
#define q16_decompressAlpha				c_q16_decompressAlpha

#include "../q16_lib.c"
