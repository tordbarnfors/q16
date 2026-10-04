#ifndef Q16DEC_DOT_H
#define Q16DEC_DOT_H

/*=========================================================================
*
*   q16dec.h - C interface to q16dec.s, a Q16 image decoder for 68020/68030.
*
*   Decodes Q16 images (RGB565 pixels with optional 8-bit linear alpha)
*   that have been loaded into memory in their entirety. See ../q16_lib.h
*   for a description of the file format.
*
*   Typical use:
*
*       unsigned char * pFile;          // Whole Q16 file loaded here.
*       unsigned char * pStaticTable;   // 65536 bytes.
*
*       unsigned short width, height;
*       unsigned long pixelBytes, alphaBytes;
*       unsigned char flags, version;
*
*       q16_setupStaticTable( pStaticTable );   // Once, can be reused.
*
*       if( q16_readHeader( (q16_fileheader*) pFile, &width, &height,
*                           &pixelBytes, &alphaBytes, &flags, &version ) == 0 )
*       {
*           unsigned long nbPixels = (unsigned long) width * height;
*           unsigned char * pPixelData = pFile + sizeof(q16_fileheader);
*           unsigned char * pAlphaData = pPixelData + pixelBytes;
*
*           q_decPix( pPixels, pPixelData, pPixelData + pixelBytes,
*                     nbPixels, pStaticTable );
*
*           if( alphaBytes > 0 )
*               q_decAlp( pAlpha, pAlphaData, pAlphaData + alphaBytes,
*                         nbPixels );
*       }
*
*   The caller should check that the file is at least
*   sizeof(q16_fileheader) + pixelBytes + alphaBytes bytes long.
*
*=========================================================================*/

#if defined(__PUREC__) || defined(__TURBOC__) || defined(__AHCC__)
#   define Q16CALL cdecl        /* Decoder takes its arguments on the stack. */
#else
#   define Q16CALL
#endif

enum Q16_FLAGS
{
	Q16_LINEAR_RGB = 1
};

typedef struct q16_fileheader_struct
{
	char			magic[4];		/* magic bytes "Q565" */
	unsigned char	version;		/* version of file format. */
	unsigned char	flags;			/* See Q16_FLAGS */
	unsigned short	width;			/* image width in pixels (little endian) */
	unsigned short	height;			/* image height in pixels (little endian) */
	unsigned short	dummy;			/* Padding for alignment. Always 0. */
	unsigned long	pixelBytes;		/* Bytes of pixel data. (little endian) */
	unsigned long	alphaBytes;		/* Bytes of alpha channel data, 0 if no alpha channel. (little endian) */
} q16_fileheader;


/* Returns version of the file format supported by the decoder. */

int Q16CALL		q16_version( void );

/* Fills in the 65536 byte table needed by q_decPix(). */

void Q16CALL	q16_setupStaticTable( unsigned char staticTable[65536] );

/* Reads the header, converting values from little endian.
*  Returns 0 if ok, -1 if not a Q16 file (all values set to 0) or -2 if
*  the version is unsupported (values are still filled in).
*/

int Q16CALL		q16_readHeader( const q16_fileheader * header,
								unsigned short * width, unsigned short * height,
								unsigned long * pixelBytes, unsigned long * alphaBytes,
								unsigned char * flags, unsigned char * version );

/* Decodes the complete pixel data between pBegin and pEnd into exactly
*  nbPixels big endian RGB565 pixels at pDest.
*  Returns 0 if ok, -1 if the data is corrupt or doesn't decode into exactly
*  nbPixels pixels. Never reads beyond pEnd nor writes beyond pDest + nbPixels.
*/

int Q16CALL		q_decPix( unsigned short * pDest,
						  const unsigned char * pBegin, const unsigned char * pEnd,
						  unsigned long nbPixels,
						  const unsigned char staticTable[65536] );

/* Same as q_decPix(), but calculates the palette index of each new pixel
*  with the hash formula instead of using the static table. In q16decf.s,
*  link with it to use this. Needs neither the table nor
*  q16_setupStaticTable(), but decodes slower; see ../bench/README.md.
*/

int Q16CALL		q_decPixF( unsigned short * pDest,
						   const unsigned char * pBegin, const unsigned char * pEnd,
						   unsigned long nbPixels );

/* Decodes the complete alpha data between pBegin and pEnd into exactly
*  nbPixels alpha values at pDest.
*  Returns 0 if ok, -1 if the data is corrupt or doesn't decode into exactly
*  nbPixels values. Never reads beyond pEnd nor writes beyond pDest + nbPixels.
*/

int Q16CALL		q_decAlp( unsigned char * pDest,
						  const unsigned char * pBegin, const unsigned char * pEnd,
						  unsigned long nbPixels );

#endif /* Q16DEC_DOT_H */
