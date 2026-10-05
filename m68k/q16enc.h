#ifndef Q16ENC_DOT_H
#define Q16ENC_DOT_H

/*=========================================================================
*
*   q16enc.h - C interface to q16enc.s and q16enct.s, Q16 image encoders
*   for 68020/68030.
*
*   Encodes complete RGB565 images with optional 8-bit alpha into Q16. The
*   output is identical to that of q16_lib.c. Typical use:
*
*       unsigned long nbPixels = (unsigned long) width * height;
*       unsigned char * pFile = malloc( sizeof(q16_fileheader)
*                                       + Q16_MAX_PIXEL_BYTES(nbPixels)
*                                       + Q16_MAX_ALPHA_BYTES(nbPixels) );
*       unsigned char * pPixelData = pFile + sizeof(q16_fileheader);
*       unsigned char * pAlphaData, * pEnd;
*
*       pAlphaData = q_encPix( pPixelData, pPixels, pPixels + nbPixels );
*       pEnd = pAlpha ? q_encAlp( pAlphaData, pAlpha, pAlpha + nbPixels ) : pAlphaData;
*       q16_writeHeader( (q16_fileheader*) pFile, width, height,
*                        pAlphaData - pPixelData, pEnd - pAlphaData, 0 );
*
*       // Save pEnd - pFile bytes from pFile.
*
*   Link with one of the two, not both:
*
*   q16enc.s    q_encPix() calculates the palette index of each pixel with
*               the hash formula. This is the one to use normally.
*
*   q16enct.s   q_encPxT() looks the palette index up in a 64 KB table set
*               up by q16_setupStaticTable(), which is in q16dect.s. Faster
*               per pixel, so link with q16dect.s (not q16dec.s) and use
*               q_encPxT( ..., pStaticTable ) when the table is wanted.
*
*   Both contain q16_writeHeader() and q_encAlp().
*
*=========================================================================*/

#include "q16dec.h"

/* Maximum number of bytes compressed pixel and alpha data can take. */

#define Q16_MAX_PIXEL_BYTES(nbPixels)	((nbPixels) * 2 + (nbPixels) / 32 + 1)
#define Q16_MAX_ALPHA_BYTES(nbPixels)	((nbPixels) + (nbPixels) / 128 + 1)

/* Writes the header, converting values to little endian. */

void Q16CALL			q16_writeHeader( q16_fileheader * header,
										 unsigned long width, unsigned long height,
										 unsigned long pixelBytes, unsigned long alphaBytes,
										 unsigned long flags );

/* Compresses the big endian RGB565 pixels between pBegin and pEnd into pDest.
*  Returns the end of the compressed data. In q16enc.s.
*/

unsigned char * Q16CALL	q_encPix( unsigned char * pDest,
								  const unsigned short * pBegin, const unsigned short * pEnd );

/* Same as q_encPix(), but looks up the palette index of each pixel in the
*  static table. In q16enct.s.
*/

unsigned char * Q16CALL	q_encPxT( unsigned char * pDest,
								  const unsigned short * pBegin, const unsigned short * pEnd,
								  const unsigned char staticTable[65536] );

/* Compresses the alpha values between pBegin and pEnd into pDest.
*  Returns the end of the compressed data.
*/

unsigned char * Q16CALL	q_encAlp( unsigned char * pDest,
								  const unsigned char * pBegin, const unsigned char * pEnd );

#endif /* Q16ENC_DOT_H */
