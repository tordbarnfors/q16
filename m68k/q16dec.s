;=========================================================================
;
;	q16dec.s - Q16 image decoder for 68020/68030 (Atari Falcon, TT etc.)
;
;	Decodes Q16 images (RGB565 pixels with optional 8-bit alpha) that
;	have been loaded into memory in their entirety. See q16dec.h for the
;	C interface and ../q16_lib.h for a description of the file format.
;
;	Devpac syntax. Uses 68020+ addressing modes and unaligned word reads,
;	so a 68000 is not supported.
;
;	Calling convention:
;
;	All functions take their arguments on the stack (cdecl) and return
;	their result in d0. All parameters are pointers or 32-bit values, so
;	the stack layout is the same regardless of the compiler's int size.
;	Registers d0-d1/a0-a1 are destroyed, all others are preserved.
;	q16dec.h declares the functions cdecl for Pure C and AHCC.
;
;	Every function is exported both with and without a leading
;	underscore to suit both a.out (GCC/MiNT) and ELF/DRI style linkers.
;
;	All functions are reentrant. No BSS or DATA is used.
;
;=========================================================================

	MC68030

	SECTION	TEXT

	XDEF	q16_version,_q16_version
	XDEF	q16_setupStaticTable,_q16_setupStaticTable
	XDEF	q16_readHeader,_q16_readHeader
	XDEF	q16_decompressPixels,_q16_decompressPixels
	XDEF	q16_decompressAlpha,_q16_decompressAlpha


;____ q16_version() ______________________________________________________
;
;	int q16_version( void );

q16_version:
_q16_version:
	moveq	#1,d0
	rts


;____ q16_setupStaticTable() _____________________________________________
;
;	void q16_setupStaticTable( unsigned char staticTable[65536] );
;
;	Generates the table deciding which of the 64 palette entries each
;	pixel goes into: (p + (p >> 3) + (p >> 4) + (p >> 10)) & 63

q16_setupStaticTable:
_q16_setupStaticTable:
	move.l	4(sp),a0
	move.l	d2,-(sp)
	moveq	#0,d0			; d0 = pixel value p, loops through 0-65535
sst_loop:
	move.w	d0,d1
	move.w	d0,d2
	lsr.w	#3,d2
	add.w	d2,d1			; p + (p >> 3)
	lsr.w	#1,d2
	add.w	d2,d1			;   + (p >> 4)
	lsr.w	#6,d2
	add.w	d2,d1			;   + (p >> 10)
	and.b	#63,d1
	move.b	d1,(a0)+
	addq.w	#1,d0
	bne.s	sst_loop
	move.l	(sp)+,d2
	rts


;____ q16_readHeader() ___________________________________________________
;
;	int q16_readHeader( const q16_fileheader * header,
;	                    unsigned short * width, unsigned short * height,
;	                    unsigned long * pixelBytes, unsigned long * alphaBytes,
;	                    unsigned char * flags, unsigned char * version );
;
;	Returns 0 if ok, -1 if not a Q16 file (all values set to 0) or -2 if
;	the version is unsupported (values are still filled in).

RH_HEADER	EQU	4
RH_WIDTH	EQU	8
RH_HEIGHT	EQU	12
RH_PIXELBYTES	EQU	16
RH_ALPHABYTES	EQU	20
RH_FLAGS	EQU	24
RH_VERSION	EQU	28

q16_readHeader:
_q16_readHeader:
	move.l	RH_HEADER(sp),a0
	cmp.l	#$51353635,(a0)		; "Q565"
	bne.s	rh_notq16

	move.l	RH_WIDTH(sp),a1
	move.w	6(a0),d0
	ror.w	#8,d0
	move.w	d0,(a1)

	move.l	RH_HEIGHT(sp),a1
	move.w	8(a0),d0
	ror.w	#8,d0
	move.w	d0,(a1)

	move.l	RH_PIXELBYTES(sp),a1
	move.l	12(a0),d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	move.l	d0,(a1)

	move.l	RH_ALPHABYTES(sp),a1
	move.l	16(a0),d0
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	move.l	d0,(a1)

	move.l	RH_FLAGS(sp),a1
	move.b	5(a0),(a1)

	move.l	RH_VERSION(sp),a1
	move.b	4(a0),(a1)

	moveq	#0,d0
	cmp.b	#1,4(a0)
	beq.s	rh_done
	moveq	#-2,d0			; Version unsupported by this decoder.
rh_done:
	rts

rh_notq16:
	move.l	RH_WIDTH(sp),a1
	clr.w	(a1)
	move.l	RH_HEIGHT(sp),a1
	clr.w	(a1)
	move.l	RH_PIXELBYTES(sp),a1
	clr.l	(a1)
	move.l	RH_ALPHABYTES(sp),a1
	clr.l	(a1)
	move.l	RH_FLAGS(sp),a1
	clr.b	(a1)
	move.l	RH_VERSION(sp),a1
	clr.b	(a1)
	moveq	#-1,d0
	rts


;____ q16_decompressPixels() _____________________________________________
;
;	int q16_decompressPixels( unsigned short * pDest,
;	                          const unsigned char * pBegin,
;	                          const unsigned char * pEnd,
;	                          unsigned long nbPixels,
;	                          const unsigned char staticTable[65536] );
;
;	Decodes the complete pixel stream between pBegin and pEnd into exactly
;	nbPixels big endian RGB565 pixels at pDest.
;
;	Returns 0 if ok, -1 if the stream is corrupt or doesn't decode into
;	exactly nbPixels pixels. Never reads beyond pEnd nor writes beyond
;	pDest + nbPixels, even for corrupt data.
;
;	Register usage:
;
;	d0 = opcode (bits 8-31 always 0)
;	d1 = literal pixel (bits 16-31 always 0)
;	d2 = palette index (bits 8-31 always 0)
;	d3 = temp
;	d4 = temp
;	d5 = end of output
;	d6 = opcodes left to decode in fast loop before next safety check
;	d7 = last pixel (bits 16-31 always 0)
;	a0 = read pointer
;	a1 = write pointer
;	a2 = static table (pixel to palette index)
;	a3 = palette (64 words on the stack)
;	a4 = delta table - $80*2, so it can be indexed by delta opcodes
;	a5 = palette - $40*2, so it can be indexed by index opcodes
;	a6 = end of input

DP_PALSIZE	EQU	128
DP_ARGS		EQU	4+11*4+DP_PALSIZE	; Return address, saved registers, palette.

q16_decompressPixels:
_q16_decompressPixels:
	movem.l	d2-d7/a2-a6,-(sp)
	lea	-DP_PALSIZE(sp),sp

	move.l	DP_ARGS(sp),a1		; pDest
	move.l	DP_ARGS+4(sp),a0	; pBegin
	move.l	DP_ARGS+8(sp),a6	; pEnd
	move.l	DP_ARGS+12(sp),d5	; nbPixels
	move.l	DP_ARGS+16(sp),a2	; staticTable

	cmpa.l	a0,a6
	blo	dp_error		; pEnd before pBegin.

	add.l	d5,d5
	add.l	a1,d5			; d5 = end of output

	move.l	sp,a3			; Clear the palette.
	moveq	#DP_PALSIZE/4-1,d0
dp_clear:
	clr.l	(a3)+
	dbra	d0,dp_clear

	move.l	sp,a3
	lea	-$40*2(a3),a5
	lea	dp_deltatable-$80*2(pc),a4

	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d7

	; Calculate how many opcodes we can decode before we need to check
	; for end of input or output. An opcode reads at most 65 bytes and
	; writes at most 32 pixels (64 bytes).

dp_refill:
	move.l	a6,d3
	sub.l	a0,d3
	lsr.l	#7,d3			; d3 = input bytes left / 128
	move.l	d5,d4
	sub.l	a1,d4
	lsr.l	#6,d4			; d4 = output bytes left / 64
	cmp.l	d4,d3
	bls.s	dp_refill2
	move.l	d4,d3
dp_refill2:
	tst.l	d3
	beq	dp_slow			; Close to the end, continue carefully.
	cmp.l	#$10000,d3
	bls.s	dp_refill3
	move.l	#$10000,d3
dp_refill3:
	subq.l	#1,d3
	move.w	d3,d6

	; Fast loop. No checks for end of input or output.

dp_loop:
	move.b	(a0)+,d0
	bmi.s	dp_delta
	btst	#6,d0
	bne.s	dp_index
	btst	#5,d0
	bne.s	dp_repeat

	; 000xxxxx - New pixels (1-32), little endian.

	move.w	d0,d3
dp_literal:
	move.w	(a0)+,d1
	ror.w	#8,d1
	move.w	d1,(a1)+
	move.b	(a2,d1.l),d2
	move.w	d1,(a3,d2.w*2)
	dbra	d3,dp_literal
	move.w	d1,d7
	dbra	d6,dp_loop
	bra.s	dp_refill

	; 1rrgggbb - Delta from previous pixel.

dp_delta:
	add.w	(a4,d0.w*2),d7
	move.w	d7,(a1)+
	move.b	(a2,d7.l),d2
	move.w	d7,(a3,d2.w*2)
	dbra	d6,dp_loop
	bra.s	dp_refill

	; 01xxxxxx - Pixel from palette.

dp_index:
	move.w	(a5,d0.w*2),d7
	move.w	d7,(a1)+
	dbra	d6,dp_loop
	bra.s	dp_refill

	; 001xxxxx - Repeat previous pixel (1-32).

dp_repeat:
	moveq	#$1f,d3
	and.w	d0,d3
	add.w	d3,d3
	neg.w	d3
	jmp	dp_replast(pc,d3.w)
	REPT	31
	move.w	d7,(a1)+
	ENDR
dp_replast:
	move.w	d7,(a1)+
	dbra	d6,dp_loop
	bra	dp_refill

	; Slow loop for the last opcodes. Checks every opcode against end of
	; input and output.

dp_slow:
	cmpa.l	a6,a0
	bhs.s	dp_inputend
	move.b	(a0)+,d0
	bmi.s	dp_slowdelta
	btst	#6,d0
	bne.s	dp_slowindex

	moveq	#$1f,d3
	and.w	d0,d3			; d3 = pixels - 1
	moveq	#0,d4
	move.w	d3,d4
	addq.w	#1,d4
	add.w	d4,d4			; d4 = bytes of output (and input if literal)
	move.l	d5,d1
	sub.l	a1,d1
	cmp.l	d4,d1
	blo.s	dp_error		; Writes beyond end of output.
	moveq	#0,d1

	btst	#5,d0
	bne.s	dp_slowrepeat

	move.l	a6,d1
	sub.l	a0,d1
	cmp.l	d4,d1
	blo.s	dp_error		; Reads beyond end of input.
	moveq	#0,d1
dp_slowliteral:
	move.w	(a0)+,d1
	ror.w	#8,d1
	move.w	d1,(a1)+
	move.b	(a2,d1.l),d2
	move.w	d1,(a3,d2.w*2)
	dbra	d3,dp_slowliteral
	move.w	d1,d7
	bra.s	dp_slow

dp_slowrepeat:
	move.w	d7,(a1)+
	dbra	d3,dp_slowrepeat
	bra.s	dp_slow

dp_slowdelta:
	cmp.l	a1,d5
	bls.s	dp_error
	add.w	(a4,d0.w*2),d7
	move.w	d7,(a1)+
	move.b	(a2,d7.l),d2
	move.w	d7,(a3,d2.w*2)
	bra.s	dp_slow

dp_slowindex:
	cmp.l	a1,d5
	bls.s	dp_error
	move.w	(a5,d0.w*2),d7
	move.w	d7,(a1)+
	bra.s	dp_slow

dp_inputend:
	cmp.l	a1,d5
	bne.s	dp_error		; Input ended before all pixels were decoded.
	moveq	#0,d0
	bra.s	dp_done
dp_error:
	moveq	#-1,d0
dp_done:
	lea	DP_PALSIZE(sp),sp
	movem.l	(sp)+,d2-d7/a2-a6
	rts

	; Value to add to previous pixel for each delta opcode ($80-$FF).
	; Opcode $D2 (zero delta) is reserved and never written by the encoder.

dp_deltatable:
	dc.w	$EF7E,$EF7F,$EF80,$EF81,$EF9E,$EF9F,$EFA0,$EFA1
	dc.w	$EFBE,$EFBF,$EFC0,$EFC1,$EFDE,$EFDF,$EFE0,$EFE1
	dc.w	$EFFE,$EFFF,$F000,$F001,$F01E,$F01F,$F020,$F021
	dc.w	$F03E,$F03F,$F040,$F041,$F05E,$F05F,$F060,$F061
	dc.w	$F77E,$F77F,$F780,$F781,$F79E,$F79F,$F7A0,$F7A1
	dc.w	$F7BE,$F7BF,$F7C0,$F7C1,$F7DE,$F7DF,$F7E0,$F7E1
	dc.w	$F7FE,$F7FF,$F800,$F801,$F81E,$F81F,$F820,$F821
	dc.w	$F83E,$F83F,$F840,$F841,$F85E,$F85F,$F860,$F861
	dc.w	$FF7E,$FF7F,$FF80,$FF81,$FF9E,$FF9F,$FFA0,$FFA1
	dc.w	$FFBE,$FFBF,$FFC0,$FFC1,$FFDE,$FFDF,$FFE0,$FFE1
	dc.w	$FFFE,$FFFF,$0000,$0001,$001E,$001F,$0020,$0021
	dc.w	$003E,$003F,$0040,$0041,$005E,$005F,$0060,$0061
	dc.w	$077E,$077F,$0780,$0781,$079E,$079F,$07A0,$07A1
	dc.w	$07BE,$07BF,$07C0,$07C1,$07DE,$07DF,$07E0,$07E1
	dc.w	$07FE,$07FF,$0800,$0801,$081E,$081F,$0820,$0821
	dc.w	$083E,$083F,$0840,$0841,$085E,$085F,$0860,$0861


;____ q16_decompressAlpha() ______________________________________________
;
;	int q16_decompressAlpha( unsigned char * pDest,
;	                         const unsigned char * pBegin,
;	                         const unsigned char * pEnd,
;	                         unsigned long nbPixels );
;
;	Decodes the complete alpha stream between pBegin and pEnd into exactly
;	nbPixels alpha values at pDest.
;
;	Returns 0 if ok, -1 if the stream is corrupt or doesn't decode into
;	exactly nbPixels values. Never reads beyond pEnd nor writes beyond
;	pDest + nbPixels, even for corrupt data.
;
;	Register usage:
;
;	d0 = opcode
;	d1 = temp
;	d3 = counter
;	d4 = last alpha value repeated in all four bytes
;	d6 = end of output
;	d7 = last alpha value
;	a0 = read pointer
;	a1 = write pointer
;	a2 = end of input

DA_ARGS		EQU	4+5*4			; Return address, saved registers.

q16_decompressAlpha:
_q16_decompressAlpha:
	movem.l	d3-d4/d6-d7/a2,-(sp)

	move.l	DA_ARGS(sp),a1		; pDest
	move.l	DA_ARGS+4(sp),a0	; pBegin
	move.l	DA_ARGS+8(sp),a2	; pEnd
	move.l	DA_ARGS+12(sp),d6	; nbPixels
	add.l	a1,d6			; d6 = end of output
	moveq	#0,d7

	cmpa.l	a0,a2
	blo.s	da_error		; pEnd before pBegin.

da_loop:
	cmpa.l	a2,a0
	bhs.s	da_inputend
	moveq	#0,d3
	move.b	(a0)+,d3
	bmi.s	da_repeat

	; 0-127 - Copy following 1-128 values verbatim. d3 = count - 1.

	move.l	a2,d1
	sub.l	a0,d1
	cmp.l	d3,d1
	bls.s	da_error		; Reads beyond end of input.
	move.l	d6,d1
	sub.l	a1,d1
	cmp.l	d3,d1
	bls.s	da_error		; Writes beyond end of output.
da_literal:
	move.b	(a0)+,(a1)+
	dbra	d3,da_literal
	move.b	-1(a1),d7
	bra.s	da_loop

	; -1 - -128 - Repeat previous value 1-128 times.

da_repeat:
	neg.b	d3			; d3 = count, 1-128
	move.l	d6,d1
	sub.l	a1,d1
	cmp.l	d3,d1
	blo.s	da_error		; Writes beyond end of output.

	cmp.w	#8,d3
	blo.s	da_short

	move.b	d7,d4			; Fill with longs for longer runs.
	lsl.w	#8,d4
	move.b	d7,d4
	move.w	d4,d1
	swap	d4
	move.w	d1,d4

	move.w	a1,d1
	btst	#0,d1
	beq.s	da_even
	move.b	d7,(a1)+
	subq.w	#1,d3
da_even:
	move.w	d3,d1
	lsr.w	#2,d1
	subq.w	#1,d1
da_long:
	move.l	d4,(a1)+
	dbra	d1,da_long
	and.w	#3,d3

da_short:
	subq.w	#1,d3
	bmi.s	da_loop
da_byte:
	move.b	d7,(a1)+
	dbra	d3,da_byte
	bra.s	da_loop

da_inputend:
	cmp.l	a1,d6
	bne.s	da_error		; Input ended before all values were decoded.
	moveq	#0,d0
	bra.s	da_done
da_error:
	moveq	#-1,d0
da_done:
	movem.l	(sp)+,d3-d4/d6-d7/a2
	rts

	END
