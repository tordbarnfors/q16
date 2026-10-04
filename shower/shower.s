; Shower 1.2 - picture viewer for the Atari Falcon.
;
; Shower 1.1 by Blade of New Core (Tord Jansson), 1995, was disassembled
; from SHOWER.TTP with rg-dis 0.9.40 (Reservoir Gods) in Devpac 3 dialect,
; since its source code was lost. Version 1.2 (2026) adds Q16 support and
; fixes bugs in the Targa, GIF and BMP loaders, see SHOWER.TXT.
;
; The labels and comments were added after the disassembly. Labels starting
; with a dot are local to the function they're in. The disassembly gave
; 1.1 text: 9048 bytes, data: 3916 bytes, bss: 23768 bytes.
	OPT	D-,X-
	OPT	P=68020
	SECTION TEXT

;	Program start. Prints the title, loads the picture named on the command
;	line, saves the video mode and looks up the picture's extension in
;	format_table.

start:
	MOVE.L	#title_text,-(A7)	; str - string pointer → title_text
	MOVE.W	#9,-(A7)			; Cconws - write a NUL-terminated string to the console
	TRAP	#1				; GEMDOS #9 (Cconws)
	ADDQ.L	#6,A7

	MOVEA.L	4(A7),A0			; TOS basepage pointer from stack
	MOVEQ	#0,D0
	MOVE.B	$80(A0),D0			; basepage.p_cmdlin (command line length)
	LEA	$81(A0),A0
	CLR.B	(A0,D0.W)
.skip_spaces:
	CMPI.B	#32,(A0)
	BNE.S	.cmdline_ok
	ADDQ.L	#1,A0
	BRA.S	.skip_spaces
.cmdline_ok:
	MOVE.L	A0,(cmdline).L		; Picture file name
	MOVEA.L	4(A7),A5			; TOS basepage pointer from stack
	MOVE.L	$C(A5),D0			; basepage.p_tlen (text segment size)
	ADD.L	$14(A5),D0			; + basepage.p_dlen (data segment size)
	ADD.L	$1C(A5),D0			; + basepage.p_blen (bss segment size)
	ADDI.L	#$1100,D0			; + stack reservation (4352 bytes)
	MOVE.L	A5,D1
	ADD.L	D0,D1
	ANDI.L	#-2,D1				; align stack to even address
	MOVEA.L	D1,A7				; relocate stack pointer

	MOVE.L	D0,-(A7)			; newsiz - new size in bytes
	MOVE.L	A5,-(A7)			; block - start of the block to shrink
	MOVE.W	D0,-(A7)			; zero - reserved, must be 0
	MOVE.W	#74,-(A7)			; Mshrink - shrink a memory block
	TRAP	#1				; GEMDOS #74 (Mshrink)
	LEA	$C(A7),A7			; restore stack frame

	MOVE.L	#dta,-(A7)			; dta - DTA buffer pointer → dta
	MOVE.W	#26,-(A7)			; Fsetdta - set the disk transfer address
	TRAP	#1				; GEMDOS #26 (Fsetdta)
	ADDQ.L	#6,A7

	MOVE.W	#7,-(A7)			; attr - attributes to match: read-only|hidden|system
	MOVE.L	(cmdline).L,-(A7)	; fspec - search path pointer, wildcards allowed
	MOVE.W	#78,-(A7)			; Fsfirst - find the first matching file
	TRAP	#1				; GEMDOS #78 (Fsfirst)
	ADDQ.L	#8,A7
	TST.W	D0

	BNE.W	exit
	LEA	dta(PC),A0
	MOVE.L	$1A(A0),(file_size).L	; File size from the DTA
	LEA	$2C(A0),A0			; End of the file name in the DTA
.find_extension:
	SUBQ.L	#1,A0
	CMPI.B	#46,(A0)
	BNE.S	.find_extension
	MOVE.L	(A0),(file_extension).L

	MOVE.L	(file_size).L,-(A7)		; number - bytes to allocate
	MOVE.W	#72,-(A7)			; Malloc - allocate memory
	TRAP	#1				; GEMDOS #72 (Malloc)
	ADDQ.L	#6,A7

	BEQ.W	exit
	MOVE.L	D0,(file_buffer).L

	MOVE.W	#0,-(A7)			; mode - access mode: read-only
	MOVE.L	(cmdline).L,-(A7)	; fname - file name pointer
	MOVE.W	#61,-(A7)			; Fopen - open an existing file
	TRAP	#1				; GEMDOS #61 (Fopen)
	ADDQ.L	#8,A7
	TST.W	D0

	BMI.W	exit
	MOVE.W	D0,(file_handle).L			; store handle - file handle, or negative error code

	MOVE.L	file_buffer(PC),-(A7)		; buf - transfer buffer pointer
	MOVE.L	file_size(PC),-(A7)		; count - byte count
	MOVE.W	file_handle(PC),-(A7)		; handle - file handle
	MOVE.W	#63,-(A7)			; Fread - read from a file handle
	TRAP	#1				; GEMDOS #63 (Fread)
	LEA	$C(A7),A7

	MOVE.W	(file_handle).L,-(A7)		; handle - file handle
	MOVE.W	#62,-(A7)			; Fclose - close a file handle
	TRAP	#1				; GEMDOS #62 (Fclose)
	ADDQ.L	#4,A7
	TST.W	D0

	BMI.W	exit

	MOVE.L	#0,-(A7)			; stack - 0 = use the user stack
	MOVE.W	#32,-(A7)			; Super - enter or query supervisor mode
	TRAP	#1				; GEMDOS #32 (Super)
	ADDQ.L	#6,A7

	MOVE.W	($FFFF8264).W,(old_hscroll).L	; store hscroll_noprefetch [STE/Falcon]
	MOVE.W	($FFFF820E).W,(old_line_offset).L	; store vid_lineoffset [Falcon]
	BSR.W	save_video

	MOVE.W	#$FFFF,-(A7)			; modecode - video mode code
	MOVE.W	#88,-(A7)			; Vsetmode - select a Falcon video mode
	TRAP	#14				; XBIOS #88 (Vsetmode)
	ADDQ.L	#4,A7
	BTST.L	#7,D0

	BEQ.S	.not_st_compatible
	CLR.W	(skip_shiftmode).L
.not_st_compatible:
	MOVE.W	D0,D1
	ANDI.W	#7,D1
	CMP.W	#1,D1
	BNE.S	.not_2_planes
	CLR.W	(skip_shiftmode).L
.not_2_planes:
	MOVE.W	D0,D1
	ANDI.W	#$87,D1
	CMP.W	#$80,D1
	BNE.S	.check_monitor
	MOVE.W	#1,(skip_shiftmode).L
.check_monitor:
	BTST.L	#4,D0
	BEQ.S	.not_vga
	MOVE.W	#$FFFF,(monitor).L
	MOVE.L	#video_vga,(video_table).L
	BRA.S	.save_physbase
.not_vga:
	BTST.L	#5,D0
	BNE.S	.pal
	MOVE.W	#1,(monitor).L
	MOVE.L	#video_ntsc,(video_table).L
	BRA.S	.save_physbase
.pal:
	MOVE.L	#video_pal,(video_table).L

.save_physbase:
	MOVE.W	#2,-(A7)			; Physbase - physical screen base address
	TRAP	#14				; XBIOS #2 (Physbase)
	ADDQ.L	#2,A7
	MOVE.L	D0,(old_physbase).L		; store physbase - physical screen base address

	LEA	format_table-32(PC),A0		; The loop starts by adding 32.
	MOVE.L	file_extension(PC),D0
	ANDI.L	#$FFDFDFDF,D0
.find_format:
	LEA	$20(A0),A0
	MOVE.L	(A0),D1
	BEQ.S	exit
	ANDI.L	#$FFDFDFDF,D1
	CMP.L	D0,D1
	BNE.S	.find_format
	MOVE.L	A0,(format).L
	TST.W	4(A0)
	BEQ.W	setup_screen

;	Frees the memory, restores the screen and the video mode and terminates.
;	Also the error exit: loaders jump here when a picture can't be shown.

exit:
	TST.L	(file_buffer).L
	BEQ.S	.free_screen

	MOVE.L	(file_buffer).L,-(A7)		; block - address of the block to free
	MOVE.W	#73,-(A7)			; Mfree - free memory
	TRAP	#1				; GEMDOS #73 (Mfree)
	ADDQ.L	#6,A7

.free_screen:
	TST.L	(screen_block).L
	BEQ.S	.restore_screen

	MOVE.L	(screen_block).L,-(A7)		; block - address of the block to free
	MOVE.W	#73,-(A7)			; Mfree - free memory
	TRAP	#1				; GEMDOS #73 (Mfree)
	ADDQ.L	#6,A7

.restore_screen:
	TST.L	(old_physbase).L
	BEQ.S	.restore_video
	MOVE.B	(old_physbase+1).L,($FFFF8201).W	; write vidbase_hi
	MOVE.B	(old_physbase+2).L,($FFFF8203).W	; write vidbase_mid
	MOVE.B	(old_physbase+3).L,($FFFF820D).W	; write vidbase_lo [STE+]
.restore_video:
	TST.W	(video_saved).L
	BEQ.S	.terminate
	LEA	old_video(PC),A6
	BSR.W	restore_video
	MOVE.W	old_hscroll(PC),($FFFF8264).W	; write hscroll_noprefetch [STE/Falcon]
	MOVE.W	old_line_offset(PC),($FFFF820E).W	; write vid_lineoffset [Falcon]
	MOVEA.L	kbdvecs(PC),A0
	MOVE.L	old_mousevec(PC),$10(A0)

.terminate:
	CLR.W	-(A7)				; Pterm0 - terminate with exit code 0
	TRAP	#1				; GEMDOS #0 (Pterm0)

;	Sets up a screen of at least 640 x 480 pixels for the picture (A0 = format
;	table entry), saves the palette, loads the picture, sets the video mode and
;	palette and runs the main loop, which reads the keyboard and mouse until
;	the user quits.

setup_screen:
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVE.W	6(A0),D0
	BMI.W	query_header
	MOVE.W	8(A0),D1
	BMI.W	query_header
	MOVE.W	$A(A0),D2
	BMI.W	query_header
	BEQ.W	exit
	CMP.W	#$280,D0
	BGE.S	.width_ok
	MOVE.W	#$280,D0
.width_ok:
	CMP.W	#$1E0,D1
	BGE.S	.height_ok
	MOVE.W	#$1E0,D1
.height_ok:
	MOVE.W	D0,(screen_width).L
	MOVE.W	D1,(screen_height).L
	MOVE.W	D2,(screen_planes).L
	MULU.W	D1,D0
	MULU.L	D2,D0
	LSR.L	#3,D0
	ADDQ.L	#4,D0
	MOVE.L	D0,(screen_size).L

	MOVE.L	D0,-(A7)			; number - bytes to allocate
	MOVE.W	#72,-(A7)			; Malloc - allocate memory
	TRAP	#1				; GEMDOS #72 (Malloc)
	ADDQ.L	#6,A7
	TST.L	D0

	BEQ.W	exit
	MOVE.L	D0,(screen_block).L
	ADDQ.L	#4,D0
	ANDI.L	#-4,D0
	MOVE.L	D0,(screen).L
	MOVEA.L	format(PC),A0
	CMPI.W	#2,$A(A0)
	BEQ.S	.save_st_palette
	CMPI.W	#16,$A(A0)
	BEQ.S	.load_picture

	MOVE.W	#37,-(A7)			; Vsync - wait for the next vertical blank
	TRAP	#14				; XBIOS #37 (Vsync)
	ADDQ.L	#2,A7

	LEA	old_palette(PC),A0
	LEA	($FFFF9800).W,A1		; videl_palette[0] [Falcon]
	MOVE.L	#$FF,D0
.save_falcon_palette:
	MOVE.L	(A1)+,(A0)+
	DBRA	D0,.save_falcon_palette
	BRA.S	.load_picture
.save_st_palette:
	MOVEM.L	($FFFF8240).W,D0-D7		; read palette[0..15]
	MOVEM.L	D0-D7,(old_palette).L
.load_picture:
	MOVEA.L	format(PC),A0
	MOVEA.L	$C(A0),A0
	JSR	(A0)
	BSR.W	find_border_colours
	MOVE.W	darkest_colour(PC),(border_colour).L
	BSR.W	fill_border

	MOVE.W	#37,-(A7)			; Vsync - wait for the next vertical blank
	TRAP	#14				; XBIOS #37 (Vsync)
	ADDQ.L	#2,A7

	MOVE.B	(screen+1).L,($FFFF8201).W	; write vidbase_hi
	MOVE.B	(screen+2).L,($FFFF8203).W	; write vidbase_mid
	MOVE.B	(screen+3).L,($FFFF820D).W	; write vidbase_lo [STE+]
	BSR.W	zoom_out
	MOVEA.L	format(PC),A0
	CMPI.W	#2,$A(A0)
	BEQ.S	.set_st_palette
	CMPI.W	#16,$A(A0)
	BEQ.S	.install_handlers
	LEA	palette(PC),A0
	LEA	($FFFF9800).W,A1		; videl_palette[0] [Falcon]
	MOVEQ	#1,D0
	MOVE.W	screen_planes(PC),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
.set_falcon_palette:
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.set_falcon_palette
	BRA.S	.install_handlers
.set_st_palette:
	LEA	palette(PC),A0
	LEA	($FFFF8240).W,A1		; palette[0]
	MOVEQ	#3,D0
.st_colour:
	MOVEQ	#0,D3
	MOVEQ	#0,D1
	MOVE.B	(A0)+,D1
	MOVE.L	D1,D2
	ANDI.B	#224,D2
	LSL.W	#3,D2
	OR.W	D2,D3
	ANDI.B	#16,D1
	LSL.W	#7,D1
	OR.W	D1,D3
	MOVEQ	#0,D1
	MOVE.B	(A0)+,D1
	MOVE.L	D1,D2
	ANDI.B	#224,D2
	LSR.W	#1,D2
	OR.W	D2,D3
	ANDI.B	#16,D1
	LSL.W	#3,D1
	OR.W	D1,D3
	MOVEQ	#0,D1
	ADDQ.L	#1,A0
	MOVE.B	(A0)+,D1
	MOVE.L	D1,D2
	ANDI.B	#224,D2
	LSR.W	#5,D2
	OR.W	D2,D3
	ANDI.B	#16,D1
	LSR.W	#1,D1
	OR.W	D1,D3
	MOVE.W	D3,(A1)+
	DBRA	D0,.st_colour

.install_handlers:
	MOVE.W	#34,-(A7)			; Kbdvbase - address of the IKBD vector table
	TRAP	#14				; XBIOS #34 (Kbdvbase)
	ADDQ.L	#2,A7
	MOVEA.L	D0,A0

	MOVE.L	$10(A0),(old_mousevec).L
	MOVE.L	A0,(kbdvecs).L
	MOVE.L	#mouse_handler,$10(A0)
	MOVE.L	($70).W,(old_vbl).L		; store vbl (vector)
	MOVE.L	#vbl_handler,($70).W		; set vbl.handler
.main_loop:
	CMPI.B	#249,(mouse_buttons).L	; Right button
	BEQ.W	.quit
	CMPI.B	#250,(mouse_buttons).L	; Left button
	BNE.S	.check_key
.wait_release:
	CMPI.B	#250,(mouse_buttons).L
	BEQ.S	.wait_release
	BSR.W	toggle_zoom

.check_key:
	MOVE.W	#11,-(A7)			; Cconis - console input status
	TRAP	#1				; GEMDOS #11 (Cconis)
	ADDQ.L	#2,A7
	TST.W	D0

	BEQ.S	.main_loop

	MOVE.W	#7,-(A7)			; Crawcin - raw console input, no echo
	TRAP	#1				; GEMDOS #7 (Crawcin)
	ADDQ.L	#2,A7

	SWAP	D0				; Scan code
	CMP.B	#78,D0			; Keypad +
	BNE.S	.not_plus
	BSR.W	zoom_in
	BRA.S	.main_loop
.not_plus:
	CMP.B	#74,D0			; Keypad -
	BNE.S	.not_minus
	BSR.W	zoom_out
	BRA.S	.main_loop
.not_minus:
	CMP.B	#72,D0			; Up
	BNE.S	.not_up
	BSR.W	scroll_up
	BRA.S	.main_loop
.not_up:
	CMP.B	#75,D0			; Left
	BNE.S	.not_left
	BSR.W	scroll_left
	BRA.S	.main_loop
.not_left:
	CMP.B	#77,D0			; Right
	BNE.S	.not_right
	BSR.W	scroll_right
	BRA.S	.main_loop
.not_right:
	CMP.B	#80,D0			; Down
	BNE.S	.not_down
	BSR.W	scroll_down
	BRA.W	.main_loop
.not_down:
	CMP.B	#59,D0			; F1
	BNE.S	.not_f1
	BSR.W	toggle_greyscale
	BRA.W	.main_loop
.not_f1:
	CMP.B	#68,D0			; F10
	BNE.S	.not_f10

	MOVE.W	#$FFFF,-(A7)			; mode: query, do not set - new shift state, or -1 to que…
	MOVE.W	#11,-(A7)			; Kbshift - read or set the keyboard shift state
	TRAP	#13				; BIOS #11 (Kbshift)
	ADDQ.L	#4,A7
	BTST.L	#2,D0				; Control

	BEQ.W	.main_loop
	BTST.L	#3,D0				; Alternate
	BEQ.W	.main_loop
	BSR.W	save_picture
	BRA.W	.main_loop
.not_f10:
	CMP.B	#60,D0			; F2
	BNE.S	.not_f2
	BSR.W	toggle_border
	BRA.W	.main_loop
.not_f2:
	CMP.B	#57,D0			; Space
	BNE.S	.not_space
	BRA.S	.quit
.not_space:
	CMP.B	#1,D0			; Esc
	BNE.S	.not_esc
	BRA.S	.quit
.not_esc:
	CMP.B	#114,D0			; Keypad Enter
	BNE.S	.no_key
	BRA.S	.quit
.no_key:
	BRA.W	.main_loop
.quit:
	MOVE.L	old_vbl(PC),($70).W		; write vbl (vector)
	MOVEA.L	format(PC),A0
	CMPI.W	#2,$A(A0)
	BEQ.S	.restore_st_palette
	CMPI.W	#16,$A(A0)
	BEQ.W	exit
	LEA	old_palette(PC),A0
	LEA	($FFFF9800).W,A1		; videl_palette[0] [Falcon]
	MOVE.L	#$FF,D0
.restore_falcon_palette:
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.restore_falcon_palette
	BRA.W	exit
.restore_st_palette:
	MOVEM.L	old_palette(PC),D0-D7
	MOVEM.L	D0-D7,($FFFF8240).W		; write palette[0..15]
	BRA.W	exit

;	Formats without a fixed size: calls the header parser, which fills in the
;	width, height and depth of the format table entry, and sets up the screen.

query_header:
	MOVEA.L	$10(A0),A1
	TST.L	A1
	BMI.W	exit
	JSR	(A1)
	MOVEA.L	format(PC),A0
	BRA.W	setup_screen

;	F1: switches between the picture's colours and grey.

toggle_greyscale:
	CMPI.W	#16,(screen_planes).L
	BEQ.S	.done
	BCHG.B	#0,(greyscale+1).L
	LEA	palette(PC),A0
	LEA	($FFFF9800).W,A1		; videl_palette[0] [Falcon]
	MOVEQ	#1,D0
	MOVE.W	screen_planes(PC),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
	TST.W	(greyscale).L
	BEQ.S	.colour
	MOVEQ	#0,D1
	MOVEQ	#0,D2
.grey:
	MOVEQ	#0,D3
	MOVE.B	(A0)+,D1
	MOVE.B	(A0)+,D2
	ADDQ.L	#1,A0
	MOVE.B	(A0)+,D3
	ADD.W	D1,D3
	ADD.W	D2,D3
	DIVU.W	#3,D3
	MOVE.B	D3,(A1)+
	MOVE.B	D3,(A1)+
	ADDQ.L	#1,A1
	MOVE.B	D3,(A1)+
	DBRA	D0,.grey
	RTS

.colour:
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.colour
.done:
	RTS

;	F2: switches the border around small pictures between the darkest and the
;	brightest colour of the palette.

toggle_border:
	LEA	border_colour(PC),A0
	MOVE.W	(A0),D0
	CMP.W	darkest_colour(PC),D0
	BEQ.S	.brightest
	MOVE.W	darkest_colour(PC),(A0)
	BRA.S	.fill
.brightest:
	MOVE.W	brightest_colour(PC),(A0)
.fill:
	BRA.W	fill_border

;	Left mouse button: switches resolution.

toggle_zoom:
	TST.W	(high_res).L
	BEQ.W	zoom_out
	BRA.W	zoom_in

;	Plus: low resolution (320 pixels wide), which shows the picture with
;	double sized pixels. Sets the scroll limits.

zoom_in:
	CMPI.W	#1,(screen_planes).L
	BEQ.W	zoom_out
	MOVEQ	#0,D1
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D0
	CMP.W	#$280,D0
	BGE.S	.min_x
	CMP.W	#$140,D0
	BGE.S	.width_320
	MOVE.W	#$140,D0
.width_320:
	MOVE.W	#$280,D1
	SUB.W	D0,D1
	LSR.W	#1,D1
	ANDI.W	#$FFF0,D1
.min_x:
	MOVE.W	D1,(scroll_min_x).L
	MOVE.W	#$C8,D2
	TST.W	(monitor).L
	BPL.S	.not_vga
	ADDI.W	#40,D2
.not_vga:
	MOVEQ	#0,D1
	MOVE.W	8(A0),D0
	CMP.W	#$1E0,D0
	BGE.S	.min_y
	CMP.W	D2,D0
	BGE.S	.height_ok
	MOVE.W	D2,D0
.height_ok:
	MOVE.W	#$1E0,D1
	SUB.W	D0,D1
	LSR.W	#1,D1
.min_y:
	MOVE.W	D1,(scroll_min_y).L
	MOVE.W	6(A0),D0
	CMP.W	#$140,D0
	BGE.S	.max_x
	MOVE.W	#$140,D0
.max_x:
	SUBI.W	#$140,D0
	ADD.W	(scroll_min_x).L,D0
	MOVE.W	D0,(scroll_max_x).L
	MOVE.W	8(A0),D0
	CMP.W	D2,D0
	BGE.S	.max_y
	MOVE.W	D2,D0
.max_y:
	SUB.W	D2,D0
	ADD.W	(scroll_min_y).L,D0
	MOVE.W	D0,(scroll_max_y).L
	CLR.W	(high_res).L
	MOVEA.L	video_table(PC),A0
	MOVE.W	screen_planes(PC),D1
	LEA	mode_offsets(PC),A1
	MOVE.W	(A1,D1.W*2),D1
	LEA	-$30(A0,D1.W),A6
	BSR.W	set_video
	MOVEQ	#0,D0
	MOVE.W	screen_width(PC),D0
	LSR.W	#4,D0
	SUBI.W	#20,D0
	MULU.W	screen_planes(PC),D0
	MOVE.W	D0,(line_offset).L
	MOVE.W	D0,($FFFF820E).W		; write vid_lineoffset [Falcon]
	RTS

;	Minus: high resolution (640 pixels wide). Sets the scroll limits.

zoom_out:
	CLR.W	(scroll_min_x).L
	CLR.W	(scroll_min_y).L
	MOVEA.L	format(PC),A0
	TST.W	(monitor).L
	BMI.S	.max_x
	CMPI.W	#$1E0,8(A0)
	BGE.S	.max_x
	MOVE.W	#$1E0,D0
	SUB.W	8(A0),D0
	LSR.W	#1,D0
	CMP.W	#40,D0
	BLE.S	.top_ok
	MOVEQ	#40,D0
.top_ok:
	MOVE.W	D0,(scroll_min_y).L
.max_x:
	MOVE.W	screen_width(PC),D0
	SUBI.W	#$280,D0
	MOVE.W	D0,(scroll_max_x).L
	MOVE.W	#$190,D2
	TST.W	(monitor).L
	BPL.S	.not_vga
	ADDI.W	#80,D2
.not_vga:
	MOVE.W	8(A0),D0
	CMP.W	D2,D0
	BGE.S	.tall
	MOVE.W	scroll_min_y(PC),(scroll_max_y).L
	BRA.S	.set_mode
.tall:
	SUB.W	D2,D0
	MOVE.W	D0,(scroll_max_y).L
.set_mode:
	MOVE.W	#1,(high_res).L
	MOVEA.L	video_table(PC),A0
	MOVE.W	screen_planes(PC),D1
	LEA	mode_offsets(PC),A1
	MOVE.W	(A1,D1.W*2),D1
	LEA	(A0,D1.W),A6
	BSR.W	set_video
	CMPI.W	#16,(screen_planes).L
	BNE.S	.line_offset
	TST.W	(monitor).L
	BMI.W	zoom_in
.line_offset:
	MOVEQ	#0,D0
	MOVE.W	screen_width(PC),D0
	LSR.W	#4,D0
	SUBI.W	#40,D0
	MULU.W	screen_planes(PC),D0
	MOVE.W	D0,(line_offset).L
	MOVE.W	D0,($FFFF820E).W		; write vid_lineoffset [Falcon]
	RTS

;	Cursor keys: scroll 4 pixels.

scroll_up:
	SUBI.W	#4,(scroll_dy).L
	RTS

scroll_down:
	ADDI.W	#4,(scroll_dy).L
	RTS

scroll_left:
	SUBI.W	#4,(scroll_dx).L
	RTS

scroll_right:
	ADDI.W	#4,(scroll_dx).L
	RTS

;	Saves the Videl registers and the ST shift mode in old_video.

save_video:
	MOVE.L	($FFFF820E).W,D0		; read vid_lineoffset [Falcon]
	MOVE.L	($FFFF8264).W,D1		; read hscroll_noprefetch [STE/Falcon]
	MOVEM.L	($FFFF8282).W,D2-D5		; read videl_hht [Falcon]
	MOVEM.L	($FFFF82A2).W,D6-D7/A0		; read videl_vft [Falcon]
	MOVEA.L	($FFFF82C0).W,A1		; read videl_vco [Falcon]
	MOVEA.W	($FFFF820A).W,A2		; read syncmode
	MOVEM.L	D0-D7/A0-A2,(old_video).L
	MOVE.L	($FFFF8260).W,(old_shiftmode).L	; store shiftmode
	MOVE.W	#1,(video_saved).L
	RTS

;	Restores the video registers saved by save_video (A6 = old_video). The ST
;	shift mode is written too, unless skip_shiftmode is set.

restore_video:
	MOVE.W	#37,-(A7)			; Vsync - wait for the next vertical blank
	TRAP	#14				; XBIOS #37 (Vsync)
	ADDQ.L	#2,A7

	MOVEM.L	(A6)+,D0-D7/A0-A2
	MOVE.L	D0,($FFFF820E).W		; write vid_lineoffset [Falcon]
	MOVE.L	D1,($FFFF8264).W		; write hscroll_noprefetch [STE/Falcon]
	MOVEM.L	D2-D5,($FFFF8282).W		; write videl_hht [Falcon]
	MOVEM.L	D6-D7/A0,($FFFF82A2).W		; write videl_vft [Falcon]
	MOVE.L	A1,($FFFF82C0).W		; write videl_vco [Falcon]
	MOVE.W	A2,($FFFF820A).W		; write syncmode
	MOVE.W	(A6)+,D1
	TST.W	(skip_shiftmode).L
	BEQ.S	write_shiftmode
	RTS

;	Sets a video mode from a 48-byte entry of a video table (A6): the Videl
;	registers, then the ST shift mode if the entry has one.

set_video:
	MOVE.W	#37,-(A7)			; Vsync - wait for the next vertical blank
	TRAP	#14				; XBIOS #37 (Vsync)
	ADDQ.L	#2,A7

	MOVEM.L	(A6)+,D0-D7/A0-A2
	MOVE.L	D0,($FFFF820E).W		; write vid_lineoffset [Falcon]
	MOVE.L	D1,($FFFF8264).W		; write hscroll_noprefetch [STE/Falcon]
	MOVEM.L	D2-D5,($FFFF8282).W		; write videl_hht [Falcon]
	MOVEM.L	D6-D7/A0,($FFFF82A2).W		; write videl_vft [Falcon]
	MOVE.L	A1,($FFFF82C0).W		; write videl_vco [Falcon]
	MOVE.W	A2,($FFFF820A).W		; write syncmode
	MOVE.W	(A6)+,D1
	BNE.S	write_shiftmode
	RTS

;	Writes the ST shift mode (D1), then the Videl registers again, as writing
;	the shift mode changes them.

write_shiftmode:
	MOVE.W	D1,($FFFF8260).W		; write shiftmode
	MOVE.L	D0,($FFFF820E).W		; write vid_lineoffset [Falcon]
	MOVEM.L	D2-D5,($FFFF8282).W		; write videl_hht [Falcon]
	MOVEM.L	D6-D7/A0,($FFFF82A2).W		; write videl_vft [Falcon]
	MOVE.L	A1,($FFFF82C0).W		; write videl_vco [Falcon]
	MOVE.W	A2,($FFFF820A).W		; write syncmode
	RTS

;	Writes D0 as D1 decimal digits ending at A0 + D1.

format_number:
	LEA	(A0,D1.W),A0
	SUBQ.W	#1,D1
.digit:
	DIVU.W	#10,D0
	SWAP	D0
	ADDI.W	#48,D0
	MOVE.B	D0,-(A0)
	CLR.W	D0
	SWAP	D0
	DBRA	D1,.digit
	RTS

;	Ctrl+Alt+F10: saves the picture's size as text in SAVEDPIC.TXT, the
;	palette in SAVEDPIC.PAL and the screen data in SAVEDPIC.BIN.

save_picture:
	LEA	info_text(PC),A0
	MOVEA.L	format(PC),A1
	MOVEQ	#0,D0
	MOVE.W	6(A1),D0
	MOVE.W	#4,D1
	BSR.S	format_number
	LEA	info_height(PC),A0
	MOVEQ	#0,D0
	MOVE.W	8(A1),D0
	MOVE.W	#4,D1
	BSR.S	format_number
	MOVEQ	#1,D0
	MOVE.W	$A(A1),D1
	LSL.L	D1,D0
	CMP.L	#$10000,D0
	BEQ.S	.true_color
	MOVE.W	#3,D1
	LEA	info_colours(PC),A0
	BSR.S	format_number
	BRA.S	.write_info
.true_color:
	LEA	info_colours(PC),A0
	MOVE.L	#'True',(A0)
	MOVE.W	#$2E20,9(A0)

.write_info:
	MOVE.W	#0,-(A7)			; attr - file attributes (normal)
	MOVE.L	#name_txt,-(A7)		; fname "SAVEDPIC.TXT"
	MOVE.W	#60,-(A7)			; Fcreate - create and open a file
	TRAP	#1				; GEMDOS #60 (Fcreate)
	ADDQ.L	#8,A7
	MOVE.L	D0,D6

	MOVE.L	#info_text,-(A7)		; buf "0000 X 0000 pixels, 000 colors."
	MOVE.L	#31,-(A7)			; count - byte count
	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#64,-(A7)			; Fwrite - write to a file handle
	TRAP	#1				; GEMDOS #64 (Fwrite)
	LEA	$C(A7),A7

	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#62,-(A7)			; Fclose - close a file handle
	TRAP	#1				; GEMDOS #62 (Fclose)
	ADDQ.L	#4,A7

	MOVEQ	#1,D7
	MOVE.W	screen_planes(PC),D0
	CMP.W	#16,D0
	BEQ.S	.save_pixels
	LSL.W	D0,D7
	LSL.W	#2,D7

	MOVE.W	#0,-(A7)			; attr - file attributes (normal)
	MOVE.L	#name_pal,-(A7)		; fname "SAVEDPIC.PAL"
	MOVE.W	#60,-(A7)			; Fcreate - create and open a file
	TRAP	#1				; GEMDOS #60 (Fcreate)
	ADDQ.L	#8,A7
	MOVE.L	D0,D6

	MOVE.L	#palette,-(A7)			; buf - transfer buffer pointer → palette
	MOVE.L	D7,-(A7)			; count - byte count
	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#64,-(A7)			; Fwrite - write to a file handle
	TRAP	#1				; GEMDOS #64 (Fwrite)
	LEA	$C(A7),A7

	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#62,-(A7)			; Fclose - close a file handle
	TRAP	#1				; GEMDOS #62 (Fclose)
	ADDQ.L	#4,A7

.save_pixels:
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D7
	CMP.W	#$280,D7
	BLT.S	.narrow
	LSR.W	#3,D7
	MULU.W	$A(A0),D7
	MULU.W	8(A0),D7
	BSR.W	picture_position

	MOVE.W	#0,-(A7)			; attr - file attributes (normal)
	MOVE.L	#name_bin,-(A7)		; fname "SAVEDPIC.BIN"
	MOVE.W	#60,-(A7)			; Fcreate - create and open a file
	TRAP	#1				; GEMDOS #60 (Fcreate)
	ADDQ.L	#8,A7
	MOVE.L	D0,D6

	MOVE.L	picture_start(PC),-(A7)		; buf - transfer buffer pointer
	MOVE.L	D7,-(A7)			; count - byte count
	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#64,-(A7)			; Fwrite - write to a file handle
	TRAP	#1				; GEMDOS #64 (Fwrite)
	LEA	$C(A7),A7

	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#62,-(A7)			; Fclose - close a file handle
	TRAP	#1				; GEMDOS #62 (Fclose)
	ADDQ.L	#4,A7

	RTS

.narrow:
	LSR.W	#3,D7
	MULU.W	$A(A0),D7
	MULU.W	8(A0),D7

	MOVE.L	D7,-(A7)			; number - bytes to allocate
	MOVE.W	#72,-(A7)			; Malloc - allocate memory
	TRAP	#1				; GEMDOS #72 (Malloc)
	ADDQ.L	#6,A7
	TST.L	D0

	BEQ.S	.done
	MOVEA.L	D0,A6
	MOVEA.L	D0,A2
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D1
	LSR.W	#4,D1
	MULU.W	$A(A0),D1
	SUBQ.W	#1,D1
	MOVE.W	#$280,D3
	SUB.W	6(A0),D3
	LSR.W	#3,D3
	MULU.W	screen_planes(PC),D3
	MOVE.W	8(A0),D0
	SUBQ.W	#1,D0
.line:
	MOVE.L	D1,D2
.word:
	MOVE.W	(A1)+,(A2)+
	DBRA	D2,.word
	ADDA.L	D3,A1
	DBRA	D0,.line

	MOVE.W	#0,-(A7)			; attr - file attributes (normal)
	MOVE.L	#name_bin,-(A7)		; fname "SAVEDPIC.BIN"
	MOVE.W	#60,-(A7)			; Fcreate - create and open a file
	TRAP	#1				; GEMDOS #60 (Fcreate)
	ADDQ.L	#8,A7
	MOVE.L	D0,D6

	MOVE.L	A6,-(A7)			; buf - transfer buffer pointer
	MOVE.L	D7,-(A7)			; count - byte count
	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#64,-(A7)			; Fwrite - write to a file handle
	TRAP	#1				; GEMDOS #64 (Fwrite)
	LEA	$C(A7),A7

	MOVE.W	D6,-(A7)			; handle - file handle
	MOVE.W	#62,-(A7)			; Fclose - close a file handle
	TRAP	#1				; GEMDOS #62 (Fclose)
	ADDQ.L	#4,A7

	MOVE.L	A6,-(A7)			; block - address of the block to free
	MOVE.W	#73,-(A7)			; Mfree - free memory
	TRAP	#1				; GEMDOS #73 (Mfree)
	ADDQ.L	#6,A7

.done:
	RTS

;	VBL interrupt. Sets the screen address, line offset and fine scroll
;	calculated in the previous frame, then moves the visible part of the
;	screen by the scroll speed (mouse and cursor keys) within the scroll limits
;	and calculates them for the next frame. Continues in the old VBL handler.

vbl_handler:
	MOVE.W	#$2700,SR
	TST.W	(vbl_ready).L
	BEQ.W	.busy
	CLR.W	(vbl_ready).L
	MOVE.B	vbl_screen+1(PC),($FFFF8201).W	; write vidbase_hi
	MOVE.B	vbl_screen+2(PC),($FFFF8203).W	; write vidbase_mid
	MOVE.B	vbl_screen+3(PC),($FFFF820D).W	; write vidbase_lo [STE+]
	MOVE.B	vbl_screen+1(PC),($FFFF8205).W	; write vidcount_hi
	MOVE.B	vbl_screen+2(PC),($FFFF8207).W	; write vidcount_mid
	MOVE.B	vbl_screen+3(PC),($FFFF8209).W	; write vidcount_lo
	MOVE.W	vbl_hscroll(PC),($FFFF8264).W	; write hscroll_noprefetch [STE/Falcon]
	MOVE.W	vbl_line_offset(PC),($FFFF820E).W	; write vid_lineoffset [Falcon]
	MOVE.W	#$2300,SR
	MOVEM.L	D0-D7/A0-A6,-(A7)
	MOVE.W	scroll_x(PC),D0
	ADD.W	scroll_dx(PC),D0
	CMP.W	scroll_min_x(PC),D0
	BGE.S	.x_not_below
	MOVE.W	scroll_min_x(PC),D0
.x_not_below:
	CMP.W	scroll_max_x(PC),D0
	BLE.S	.x_ok
	MOVE.W	scroll_max_x(PC),D0
.x_ok:
	MOVE.W	D0,(scroll_x).L
	CLR.W	(scroll_dx).L
	MOVE.W	scroll_y(PC),D0
	ADD.W	scroll_dy(PC),D0
	CMP.W	scroll_min_y(PC),D0
	BGE.S	.y_not_below
	MOVE.W	scroll_min_y(PC),D0
.y_not_below:
	CMP.W	scroll_max_y(PC),D0
	BLE.S	.y_ok
	MOVE.W	scroll_max_y(PC),D0
.y_ok:
	MOVE.W	D0,(scroll_y).L
	CLR.W	(scroll_dy).L
	MOVE.W	screen_width(PC),D0
	LSR.W	#3,D0
	MULU.W	screen_planes(PC),D0
	MULU.W	scroll_y(PC),D0
	CMPI.W	#16,(screen_planes).L
	BNE.S	.bitplanes
	MOVE.W	line_offset(PC),(vbl_line_offset).L
	MOVEQ	#0,D1
	MOVE.W	scroll_x(PC),D1
	ADD.W	D1,D1
	BCLR.L	#1,D1
	ADD.L	D1,D0
	BRA.S	.set_screen
.bitplanes:
	MOVE.W	line_offset(PC),(vbl_line_offset).L
	MOVE.W	scroll_x(PC),D1
	LSR.W	#4,D1
	MULU.W	screen_planes(PC),D1
	ADD.L	D1,D1
	ADD.L	D1,D0
	MOVE.W	scroll_x(PC),D1
	ANDI.W	#15,D1
	BEQ.S	.no_fine_scroll
	MOVE.W	screen_planes(PC),D2
	SUB.W	D2,(vbl_line_offset).L
.no_fine_scroll:
	MOVE.W	D1,(vbl_hscroll).L
.set_screen:
	ADD.L	screen(PC),D0
	MOVE.L	D0,(vbl_screen).L
	MOVEM.L	(A7)+,D0-D7/A0-A6
	MOVE.L	old_vbl(PC),-(A7)
	MOVE.W	#$FFFF,(vbl_ready).L
	RTS

.busy:
	RTE

;	Cleared while vbl_handler runs, so it isn't entered twice.

vbl_ready:
	dc.w	$FFFF

;	IKBD mouse packet handler: saves the buttons and adds the movement to the
;	scroll speed.

mouse_handler:
	MOVE.W	D0,-(A7)
	MOVE.B	(A0)+,(mouse_buttons).L
	MOVE.B	(A0)+,D0
	EXT.W	D0
	ADD.W	D0,(scroll_dx).L
	MOVE.B	(A0)+,D0
	EXT.W	D0
	ADD.W	D0,(scroll_dy).L
	SUBQ.W	#3,A0
	MOVE.W	(A7)+,D0
	RTS

;	Finds the darkest and the brightest colour of the palette.

find_border_colours:
	LEA	palette(PC),A0
	MOVE.W	#$300,D2
	MOVEQ	#0,D1
	MOVEQ	#0,D3
	MOVEQ	#0,D6
	MOVEQ	#0,D7
	MOVEQ	#1,D5
	MOVE.W	screen_planes(PC),D1
	LSL.W	D1,D5
	SUBQ.W	#1,D5
.colour:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	MOVE.B	(A0)+,D1
	ADD.W	D1,D0
	ADDQ.L	#1,A0
	MOVE.B	(A0)+,D1
	ADD.W	D1,D0
	CMP.W	D0,D6
	BGE.S	.not_brighter
	MOVE.W	D0,D6
	MOVE.W	D3,D7
.not_brighter:
	CMP.W	D0,D2
	BLE.S	.not_darker
	MOVE.W	D0,D2
	MOVE.W	D3,D4
.not_darker:
	ADDQ.W	#1,D3
	DBRA	D5,.colour
	MOVE.W	D4,(darkest_colour).L
	MOVE.W	D7,(brightest_colour).L
	RTS

;	Fills the screen around the picture with the border colour, for 8, 4, 2
;	and 1 bitplanes (16-bit screens are filled with words of 0).

fill_border:
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D0
	CMP.W	#$280,D0
	BGE.S	.wide
	MOVE.W	#40,D1
	LSR.W	#4,D0
	SUB.W	D0,D1
	MOVE.W	D1,D0
	LSR.W	#1,D0
	SUB.W	D0,D1
	MULU.W	$A(A0),D0
	MULU.W	$A(A0),D1
	SUBQ.W	#1,D0
	SUBQ.W	#1,D1
	MOVE.W	D0,(border_left).L
	MOVE.W	D1,(border_right).L
	MOVE.W	8(A0),D0
	SUBQ.W	#1,D0
	MOVE.W	D0,(border_sides).L
	BRA.S	.vertical
.wide:
	MOVE.W	#$FFFF,(border_sides).L
.vertical:
	MOVE.W	8(A0),D0
	CMP.W	#$1E0,D0
	BGE.S	.tall
	MOVE.W	#$1E0,D1
	SUB.W	D0,D1
	MOVE.W	D1,D0
	LSR.W	#1,D0
	SUB.W	D0,D1
	SUBQ.W	#1,D0
	SUBQ.W	#1,D1
	MOVE.W	D0,(border_top).L
	MOVE.W	D1,(border_bottom).L
	BRA.S	.pattern
.tall:
	MOVE.W	#$FFFF,(border_top).L
	MOVE.W	#$FFFF,(border_bottom).L
.pattern:
	MOVE.W	screen_width(PC),D0
	LSR.W	#3,D0
	MULU.W	$A(A0),D0
	MOVE.W	D0,(screen_line_bytes).L
	MOVE.W	6(A0),D0
	LSR.W	#3,D0
	MULU.W	$A(A0),D0
	MOVE.W	D0,(picture_line_bytes).L
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVE.W	border_colour(PC),D4
	BTST.L	#0,D4
	BEQ.S	.plane1
	MOVE.L	#$FFFF0000,D0
.plane1:
	BTST.L	#1,D4
	BEQ.S	.plane2
	MOVE.W	#$FFFF,D0
.plane2:
	BTST.L	#2,D4
	BEQ.S	.plane3
	MOVE.L	#$FFFF0000,D1
.plane3:
	BTST.L	#3,D4
	BEQ.S	.plane4
	MOVE.W	#$FFFF,D1
.plane4:
	BTST.L	#4,D4
	BEQ.S	.plane5
	MOVE.L	#$FFFF0000,D2
.plane5:
	BTST.L	#5,D4
	BEQ.S	.plane6
	MOVE.W	#$FFFF,D2
.plane6:
	BTST.L	#6,D4
	BEQ.S	.plane7
	MOVE.L	#$FFFF0000,D3
.plane7:
	BTST.L	#7,D4
	BEQ.S	.pattern_done
	MOVE.W	#$FFFF,D3
.pattern_done:
	MOVEQ	#0,D7
	MOVE.W	picture_width(PC),D7
	ANDI.W	#15,D7
	LEA	edge_masks(PC),A0
	MOVE.L	(A0,D7.W*4),D7
	MOVEA.L	format(PC),A0
	MOVE.W	$A(A0),D4
	CMP.W	#2,D4
	BLT.W	.words
	BEQ.W	.planes2
	CMP.W	#8,D4
	BLT.W	.planes4
	BEQ.S	.planes8
	MOVEQ	#0,D0
	BRA.W	.words
.planes8:
	MOVEA.L	screen(PC),A0
	MOVE.W	border_top(PC),D5
	BMI.S	.sides8
.top_line8:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#4,D4
	SUBQ.W	#1,D4
.top8:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	MOVE.L	D2,(A0)+
	MOVE.L	D3,(A0)+
	DBRA	D4,.top8
	DBRA	D5,.top_line8
.sides8:
	MOVE.W	border_sides(PC),D5
	BMI.S	.bottom8
.side_line8:
	MOVE.W	border_left(PC),D4
	BMI.S	.edge8
	LSR.W	#3,D4
.left8:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	MOVE.L	D2,(A0)+
	MOVE.L	D3,(A0)+
	DBRA	D4,.left8
.edge8:
	ADDA.W	picture_line_bytes(PC),A0
	MOVE.L	D0,D6
	AND.L	D7,D6
	MOVE.L	-$10(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-$10(A0)
	MOVE.L	D1,D6
	AND.L	D7,D6
	MOVE.L	-$C(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-$C(A0)
	MOVE.L	D2,D6
	AND.L	D7,D6
	MOVE.L	-8(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-8(A0)
	MOVE.L	D3,D6
	AND.L	D7,D6
	MOVE.L	-4(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-4(A0)
	MOVE.W	border_right(PC),D4
	LSR.W	#3,D4
.right8:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	MOVE.L	D2,(A0)+
	MOVE.L	D3,(A0)+
	DBRA	D4,.right8
	DBRA	D5,.side_line8
.bottom8:
	MOVE.W	border_bottom(PC),D5
	BMI.S	.done8
	MOVE.W	(border_top).L,D6
	MOVEA.L	format(PC),A0
	ADD.W	8(A0),D6
	ADDQ.L	#1,D6
	MULU.W	(screen_line_bytes).L,D6
	MOVEA.L	(screen).L,A0
	ADDA.L	D6,A0
.bottom_line8:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#4,D4
	SUBQ.W	#1,D4
.bottom_block8:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	MOVE.L	D2,(A0)+
	MOVE.L	D3,(A0)+
	DBRA	D4,.bottom_block8
	DBRA	D5,.bottom_line8
.done8:
	RTS

.planes4:
	MOVEA.L	screen(PC),A0
	MOVE.W	border_top(PC),D5
	BMI.S	.sides4
.top_line4:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#3,D4
	SUBQ.W	#1,D4
.top4:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	DBRA	D4,.top4
	DBRA	D5,.top_line4
.sides4:
	MOVE.W	border_sides(PC),D5
	BMI.S	.bottom4
.side_line4:
	MOVE.W	border_left(PC),D4
	BMI.S	.edge4
	LSR.W	#2,D4
.left4:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	DBRA	D4,.left4
.edge4:
	ADDA.W	picture_line_bytes(PC),A0
	MOVE.L	D0,D6
	AND.L	D7,D6
	MOVE.L	-8(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-8(A0)
	MOVE.L	D1,D6
	AND.L	D7,D6
	MOVE.L	-4(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-4(A0)
	MOVE.W	border_right(PC),D4
	LSR.W	#2,D4
.right4:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	DBRA	D4,.right4
	DBRA	D5,.side_line4
.bottom4:
	MOVE.W	border_bottom(PC),D5
	BMI.S	.done4
	MOVE.W	(border_top).L,D6
	MOVEA.L	format(PC),A0
	ADD.W	8(A0),D6
	ADDQ.L	#1,D6
	MULU.W	(screen_line_bytes).L,D6
	MOVEA.L	(screen).L,A0
	ADDA.L	D6,A0
.bottom_line4:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#3,D4
	SUBQ.W	#1,D4
.bottom_block4:
	MOVE.L	D0,(A0)+
	MOVE.L	D1,(A0)+
	DBRA	D4,.bottom_block4
	DBRA	D5,.bottom_line4
.done4:
	RTS

.planes2:
	MOVEA.L	screen(PC),A0
	MOVE.W	border_top(PC),D5
	BMI.S	.sides2
.top_line2:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#2,D4
	SUBQ.W	#1,D4
.top2:
	MOVE.L	D0,(A0)+
	DBRA	D4,.top2
	DBRA	D5,.top_line2
.sides2:
	MOVE.W	border_sides(PC),D5
	BMI.S	.bottom2
.side_line2:
	MOVE.W	border_left(PC),D4
	BMI.S	.edge2
	LSR.W	#1,D4
.left2:
	MOVE.L	D0,(A0)+
	DBRA	D4,.left2
.edge2:
	ADDA.W	picture_line_bytes(PC),A0
	MOVE.L	D0,D6
	AND.L	D7,D6
	MOVE.L	-4(A0),D4
	NOT.L	D7
	AND.L	D7,D4
	NOT.L	D7
	OR.L	D4,D6
	MOVE.L	D6,-4(A0)
	MOVE.W	border_right(PC),D4
	LSR.W	#1,D4
.right2:
	MOVE.L	D0,(A0)+
	DBRA	D4,.right2
	DBRA	D5,.side_line2
.bottom2:
	MOVE.W	border_bottom(PC),D5
	BMI.S	.done2
	MOVE.W	(border_top).L,D6
	MOVEA.L	format(PC),A0
	ADD.W	8(A0),D6
	ADDQ.L	#1,D6
	MULU.W	(screen_line_bytes).L,D6
	MOVEA.L	(screen).L,A0
	ADDA.L	D6,A0
.bottom_line2:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#2,D4
	SUBQ.W	#1,D4
.bottom_block2:
	MOVE.L	D0,(A0)+
	DBRA	D4,.bottom_block2
	DBRA	D5,.bottom_line2
.done2:
	RTS

.words:
	SWAP	D0
	MOVEA.L	screen(PC),A0
	MOVE.W	border_top(PC),D5
	BMI.S	.sides1
.top_line1:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#1,D4
	SUBQ.W	#1,D4
.top1:
	MOVE.W	D0,(A0)+
	DBRA	D4,.top1
	DBRA	D5,.top_line1
.sides1:
	MOVE.W	border_sides(PC),D5
	BMI.S	.bottom1
.side_line1:
	MOVE.W	border_left(PC),D4
	BMI.S	.edge1
.left1:
	MOVE.W	D0,(A0)+
	DBRA	D4,.left1
.edge1:
	ADDA.W	picture_line_bytes(PC),A0
	MOVE.W	D0,D6
	AND.W	D7,D6
	MOVE.W	-2(A0),D4
	NOT.W	D7
	AND.W	D7,D4
	NOT.W	D7
	OR.W	D4,D6
	MOVE.W	D6,-2(A0)
	MOVE.W	border_right(PC),D4
.right1:
	MOVE.W	D0,(A0)+
	DBRA	D4,.right1
	DBRA	D5,.side_line1
.bottom1:
	MOVE.W	border_bottom(PC),D5
	BMI.S	.done1
	MOVE.W	(border_top).L,D6
	MOVEA.L	format(PC),A0
	ADD.W	8(A0),D6
	ADDQ.L	#1,D6
	MULU.W	(screen_line_bytes).L,D6
	MOVEA.L	(screen).L,A0
	ADDA.L	D6,A0
.bottom_line1:
	MOVE.W	screen_line_bytes(PC),D4
	LSR.W	#1,D4
	SUBQ.W	#1,D4
.bottom_block1:
	MOVE.W	D0,(A0)+
	DBRA	D4,.bottom_block1
	DBRA	D5,.bottom_line1
.done1:
	RTS

;	Calculates picture_start, the screen address of the picture's top left
;	corner. Pictures smaller than the screen are centred.

picture_position:
	MOVEM.L	D0-D2/A0,-(A7)
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D0
	CMP.W	#$280,D0
	BGE.S	.wide
	NEG.W	D0
	ADDI.W	#$280,D0
	LSR.W	#1,D0
	LSR.W	#4,D0
	MULU.W	$A(A0),D0
	ADD.W	D0,D0
	BRA.S	.vertical
.wide:
	MOVEQ	#0,D0
.vertical:
	MOVE.W	8(A0),D1
	CMP.W	#$1E0,D1
	BGE.S	.done
	NEG.W	D1
	ADDI.W	#$1E0,D1
	LSR.W	#1,D1
	MOVE.W	screen_width(PC),D2
	MULU.W	D2,D1
	LSR.L	#3,D1
	MULU.W	$A(A0),D1
	ADD.L	D1,D0
.done:
	ADD.L	screen(PC),D0
	MOVE.L	D0,(picture_start).L
	MOVEM.L	(A7)+,D0-D2/A0
	RTS

;	Targa header parser. A0 = format table entry.
;
;	v1.2: rewritten together with the loader. Checks the file size, the
;	picture size and the bits per pixel, and accepts 32-bit pictures.

tga_header:
	MOVEA.L	file_buffer(PC),A1
	CMPI.L	#18,(file_size).L			; File size
	BLO.W	exit
	MOVE.B	2(A1),D0			; Image type: 2 = uncompressed,
	ANDI.B	#$F7,D0				; 10 = RLE, true color
	CMP.B	#2,D0
	BNE.W	exit
	MOVE.B	16(A1),D0			; Bits per pixel
	CMP.B	#16,D0
	BEQ.S	.size
	CMP.B	#24,D0
	BEQ.S	.size
	CMP.B	#32,D0
	BNE.W	exit
.size:
	MOVE.W	$C(A1),D0			; Width, little endian
	ROL.W	#8,D0
	BEQ.W	exit
	CMP.W	#$7FF0,D0
	BHI.W	exit
	MOVE.W	D0,(picture_width).L			; Real width
	ADDI.W	#15,D0
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)			; Width rounded up to 16 pixels
	MOVE.W	$E(A1),D0			; Height
	ROL.W	#8,D0
	BEQ.W	exit
	MOVE.W	D0,8(A0)
	MOVE.W	#16,$A(A0)			; True color
	RTS

;	Targa loader.
;
;	v1.2: rewritten. Version 1.1 read lines of the width rounded up to 16
;	pixels, which skewed pictures with other widths, ignored the origin
;	(most Targa pictures are stored bottom up and were shown upside down),
;	converted uncompressed 16-bit pixels wrongly and skipped color maps by
;	a wrong amount. RLE pictures are now unpacked into a buffer of their
;	own, with packets clipped to the picture, and then converted like
;	uncompressed ones. 32-bit pictures are shown without their alpha.

tga_load:
	BSR.W	picture_position				; Calculate screen position.
	MOVEM.L	D2-D7/A2-A6,-(A7)
	CLR.L	(tga_buffer).L
	MOVEA.L	file_buffer(PC),A1
	LEA	18(A1),A0
	MOVEQ	#0,D0
	MOVE.B	(A1),D0				; Skip the image ID.
	ADDA.L	D0,A0
	TST.B	1(A1)				; Skip the color map.
	BEQ.S	.no_colour_map
	MOVE.B	6(A1),D0			; Number of entries, little endian
	LSL.W	#8,D0
	MOVE.B	5(A1),D0
	MOVEQ	#0,D1
	MOVE.B	7(A1),D1			; Bits per entry
	ADDQ.W	#7,D1
	LSR.W	#3,D1
	MULU.W	D1,D0
	ADDA.L	D0,A0
.no_colour_map:
	MOVEQ	#0,D7
	MOVE.W	picture_width(PC),D7			; D7 = width
	MOVEA.L	format(PC),A2
	MOVEQ	#0,D6
	MOVE.W	8(A2),D6			; D6 = height
	MOVEQ	#0,D5
	MOVE.B	16(A1),D5
	LSR.W	#3,D5				; D5 = bytes per pixel
	CMPI.B	#10,2(A1)
	BNE.S	.convert

	MOVE.L	D7,D4				; Unpack RLE into a buffer.
	MULU.L	D6,D4
	MULU.L	D5,D4				; D4 = bytes
	MOVE.L	D4,-(A7)
	MOVE.W	#72,-(A7)			; Malloc
	TRAP	#1
	ADDQ.L	#6,A7
	TST.L	D0
	BEQ.W	.fail
	MOVE.L	D0,(tga_buffer).L
	MOVEA.L	D0,A3
	LEA	(A3,D4.L),A4			; A4 = end of buffer
	MOVEA.L	A1,A5
	ADDA.L	file_size(PC),A5			; A5 = end of file
	SUBQ.W	#1,D5
.packet:
	CMPA.L	A4,A3
	BHS.S	.unpacked
	CMPA.L	A5,A0
	BHS.S	.unpacked
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	BCLR	#7,D0
	BNE.S	.run
.raw:					; D0 + 1 pixels follow.
	MOVE.W	D5,D1
.raw_byte:
	MOVE.B	(A0)+,(A3)+
	DBRA	D1,.raw_byte
	CMPA.L	A4,A3
	DBHS	D0,.raw
	BRA.S	.packet
.run:					; Next pixel D0 + 1 times
	MOVEA.L	A0,A6
	MOVE.W	D5,D1
.run_byte:
	MOVE.B	(A6)+,(A3)+
	DBRA	D1,.run_byte
	CMPA.L	A4,A3
	DBHS	D0,.run
	MOVEA.L	A6,A0
	BRA.S	.packet
.unpacked:
	ADDQ.W	#1,D5
	MOVEA.L	(tga_buffer).L,A0

.convert:						; Convert and copy to the screen.
	MOVEA.L	picture_start(PC),A4			; A4 = screen line
	MOVEQ	#0,D3
	MOVE.W	screen_width(PC),D3
	ADD.L	D3,D3				; D3 = bytes per screen line
	BTST	#5,17(A1)			; Top-left origin?
	BNE.S	.top_down
	MOVE.L	D6,D0				; No, start with the last line.
	SUBQ.L	#1,D0
	MULU.L	D3,D0
	ADDA.L	D0,A4
	NEG.L	D3
.top_down:
	MOVE.W	6(A2),D4
	SUB.W	D7,D4				; D4 = padding up to 16 pixels
	LEA	tga_line16(PC),A5
	CMP.W	#2,D5
	BEQ.S	.lines
	LEA	tga_line24(PC),A5
	CMP.W	#3,D5
	BEQ.S	.lines
	LEA	tga_line32(PC),A5
.lines:
	SUBQ.W	#1,D6
.line:
	MOVEA.L	A4,A3
	MOVE.W	D7,D2
	SUBQ.W	#1,D2
	JSR	(A5)
	MOVE.W	D4,D2
	BRA.S	.pad_test
.pad:
	CLR.W	(A3)+
.pad_test:
	DBRA	D2,.pad
	ADDA.L	D3,A4
	DBRA	D6,.line

	BSR.S	tga_free
	MOVEM.L	(A7)+,D2-D7/A2-A6
	RTS

.fail:
	BSR.S	tga_free
	BRA.W	exit

;	Frees the RLE buffer.

tga_free:
	MOVE.L	(tga_buffer).L,D0
	BEQ.S	.done
	CLR.L	(tga_buffer).L
	MOVE.L	D0,-(A7)
	MOVE.W	#73,-(A7)			; Mfree
	TRAP	#1
	ADDQ.L	#6,A7
.done:
	RTS

;	Convert D2 + 1 pixels from A0 to RGB565 at A3.

tga_line16:					; 16 bits: ARRRRRGG GGGBBBBB, little endian
	MOVEQ	#0,D0
	MOVE.W	(A0)+,D0
	ROL.W	#8,D0
	ROR.L	#5,D0
	ADD.W	D0,D0
	ROL.L	#5,D0
	MOVE.W	D0,(A3)+
	DBRA	D2,tga_line16
	RTS

tga_line32:					; 32 bits: blue, green, red, alpha
	BSR.S	tga_pixel24
	ADDQ.L	#1,A0
	DBRA	D2,tga_line32
	RTS

tga_line24:					; 24 bits: blue, green, red
	BSR.S	tga_pixel24
	DBRA	D2,tga_line24
	RTS

tga_pixel24:
	MOVE.B	(A0)+,D0
	ROR.L	#8,D0
	MOVE.B	(A0)+,D0
	LSR.W	#2,D0
	ROR.L	#6,D0
	MOVE.B	(A0)+,D0
	LSR.W	#3,D0
	ROR.L	#5,D0
	SWAP	D0
	MOVE.W	D0,(A3)+
	RTS

;	IndyPaint (.TRU): checks the "Indy" header and reads the size.

tru_header:
	MOVEA.L	file_buffer(PC),A1
	CMPI.L	#'Indy',(A1)
	BNE.W	exit
	MOVE.W	4(A1),D0
	MOVE.W	D0,(picture_width).L		; v1.2: width rounded up to 16
	ADDI.W	#15,D0				; pixels, as fill_border needs it.
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)
	MOVE.W	6(A1),8(A0)
	RTS

;	IndyPaint loader: 16-bit pixels after a 256-byte header.

tru_load:
	BSR.W	picture_position
	MOVEM.L	D2-D6/A2-A3,-(A7)		; v1.2: lines of the real width,
	MOVEA.L	file_buffer(PC),A0		; padded to 16 pixels.
	LEA	$100(A0),A0
	BSR.W	tc_lines
.line:
	MOVEA.L	A1,A3
	MOVE.W	D4,D2
.pixel:
	MOVE.W	(A0)+,(A3)+
	DBRA	D2,.pixel
	BSR.W	tc_pad
	DBRA	D5,.line
	MOVEM.L	(A7)+,D2-D6/A2-A3
	RTS

;	For loaders of true colour pictures: A1 = picture_start, D3 = bytes per
;	screen line, D4 = width - 1, D5 = height - 1, D6 = padding up to 16
;	pixels.

tc_lines:
	MOVEA.L	picture_start(PC),A1
	MOVEA.L	format(PC),A2
	MOVE.W	8(A2),D5
	SUBQ.W	#1,D5
	MOVEQ	#0,D3
	MOVE.W	screen_width(PC),D3
	ADD.L	D3,D3
	MOVE.W	picture_width(PC),D4
	MOVE.W	6(A2),D6
	SUB.W	D4,D6
	SUBQ.W	#1,D4
	RTS

;	Clears the padding at A3 (D6 pixels) and moves A1 to the next line.

tc_pad:
	MOVE.W	D6,D2
	BRA.S	.test
.pad:
	CLR.W	(A3)+
.test:
	DBRA	D2,.pad
	ADDA.L	D3,A1
	RTS

;	GIF header parser: skips the global palette and any extension blocks and
;	reads the size from the image descriptor.

gif_header:
	MOVEA.L	file_buffer(PC),A1
	LEA	$D(A1),A1
	TST.B	-3(A1)
	BPL.S	.no_palette
	MOVE.B	-3(A1),D0
	ANDI.W	#7,D0
	ADDQ.L	#1,D0
	MOVEQ	#1,D1
	ROL.W	D0,D1
	MULU.W	#3,D1
	ADDA.W	D1,A1
.no_palette:						; v1.2: skip extension blocks,
	MOVEA.L	file_buffer(PC),A2			; GIF89a pictures often have them
	ADDA.L	file_size(PC),A2			; A2 = end of file
.block:
	CMPA.L	A2,A1
	BHS.W	exit
	CMPI.B	#$21,(A1)			; Extension
	BNE.S	.descriptor
	ADDQ.L	#2,A1
.subblock:
	CMPA.L	A2,A1
	BHS.W	exit
	MOVEQ	#0,D0
	MOVE.B	(A1)+,D0
	BEQ.S	.block
	ADDA.L	D0,A1
	BRA.S	.subblock
.descriptor:
	CMPI.B	#$2C,(A1)			; Image descriptor
	BNE.W	exit
	BTST	#6,9(A1)			; Interlaced
	SNE	(gif_interlaced).L
	MOVE.B	6(A1),D0
	LSL.W	#8,D0
	MOVE.B	5(A1),D0
	MOVE.W	D0,(picture_width).L
	ADDI.W	#15,D0
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)
	ADDQ.L	#7,A1
	MOVE.B	(A1)+,9(A0)
	MOVE.B	(A1)+,8(A0)
	RTS

;	GIF loader: unpacks the picture with gif_unpack and converts it to
;	bitplanes line by line.

gif_load:
	BSR.W	picture_position
	MOVEM.L	D2-D7/A2-A4,-(A7)		; v1.2
	MOVE.W	screen_width(PC),D0
	MULU.W	screen_height(PC),D0
	MOVE.W	picture_width(PC),D1
	MOVEA.L	format(PC),A0
	MULU.W	8(A0),D1
	SUB.L	D1,D0
	ADD.L	screen(PC),D0
	MOVE.L	D0,(gif_pixels).L
	CLR.L	(gif_buffer).L
	TST.B	(gif_interlaced).L		; v1.2: interlaced pictures are
	BEQ.S	.unpack			; unpacked into a buffer of their
	MOVE.L	D1,-(A7)			; own, as the lines are converted
	MOVE.W	#72,-(A7)			; out of order and could overwrite
	TRAP	#1				; lines not converted yet.
	ADDQ.L	#6,A7				; Malloc
	TST.L	D0
	BEQ.W	exit
	MOVE.L	D0,(gif_buffer).L
	MOVE.L	D0,(gif_pixels).L
.unpack:
	MOVE.L	#gif_info,(gif_info_ptr).L
	BSR.W	gif_unpack
	TST.W	D0
	BMI.W	.free
	BSR.W	make_c2p_tables
	LEA	line_buffer(PC),A0
	MOVEQ	#0,D0
	MOVE.W	#$5FF,D1
.clear_line:
	MOVE.L	D0,(A0)+
	DBRA	D1,.clear_line

;	v1.2: Version 1.1 converted as many lines as the screen has, reading
;	past the unpacked picture and writing past the screen for pictures
;	lower than the screen, converted whole screen lines (overwriting the
;	start of the next line), and ignored interlacing.

	MOVE.W	gif_info+10(PC),D0
	SUBQ.L	#1,D0				; D0 = width - 1
	MOVEA.L	gif_pixels(PC),A0
	MOVEA.L	picture_start(PC),A2			; A2 = first screen line
	MOVEQ	#0,D4
	MOVE.W	screen_width(PC),D4			; D4 = bytes per screen line
	MOVEA.L	format(PC),A3
	MOVE.W	6(A3),D3			; Width rounded up to 16 pixels
	LSR.W	#4,D3
	MOVE.W	D3,(c2p_blocks).L
	MOVEQ	#0,D7
	MOVE.W	8(A3),D7			; D7 = height
	MOVE.L	D7,D2
	SUBQ.W	#1,D2
	MOVE.L	#line_buffer,D3
	LEA	.passes(PC),A4		; Line order
	TST.B	(gif_info+15).L			; Interlaced?
	BEQ.S	.order
	ADDQ.L	#8,A4
.order:
	MOVE.W	(A4)+,D5			; D5 = screen line
	MOVE.W	(A4)+,D6			; D6 = step
.line:
	MOVE.W	D0,D1
	MOVEA.L	D3,A1
.copy:
	MOVE.B	(A0)+,(A1)+
	DBRA	D1,.copy
	MOVE.L	D3,(c2p_source).L
	MOVE.L	D5,D1
	MULU.L	D4,D1
	ADD.L	A2,D1
	MOVE.L	D1,(c2p_dest).L
	BSR.W	c2p_line
	ADD.W	D6,D5
.next_pass:
	CMP.W	D7,D5
	BLO.S	.next_line
	TST.W	(A4)				; Last pass done?
	BMI.S	.next_line
	MOVE.W	(A4)+,D5
	MOVE.W	(A4)+,D6
	BRA.S	.next_pass
.next_line:
	DBRA	D2,.line
.free:
	MOVE.L	(gif_buffer).L,D0
	BEQ.S	.done
	CLR.L	(gif_buffer).L
	MOVE.L	D0,-(A7)
	MOVE.W	#73,-(A7)			; Mfree
	TRAP	#1
	ADDQ.L	#6,A7
.done:
	MOVEM.L	(A7)+,D2-D7/A2-A4
	RTS

;	First line and step of each pass, ended by -1.

.passes:
	dc.w	0,1,-1,0			; Not interlaced
	dc.w	0,8,4,8,2,4,1,2,-1,0		; Interlaced

;	Unpacks the GIF in file_buffer to gif_pixels, one byte per pixel, and
;	copies the descriptors to gif_info. Returns D0 = -1 if it isn't a GIF.
;	The GIF depacker (gif_unpack to lzw_decode) is from TurboGIF by Sascha
;	Springer.

gif_unpack:
	MOVEM.L	D3-D7/A2-A6,-(A7)
	MOVEA.L	file_buffer(PC),A0
	LEA	gif_parsed(PC),A1
	BSR.S	gif_parse
	TST.W	D0
	BMI.S	.done
	MOVEA.L	file_buffer(PC),A1
	BSR.W	gif_join_blocks
	MOVEA.L	file_buffer(PC),A0
	MOVEA.L	gif_pixels(PC),A1
	BSR.W	lzw_decode
	LEA	gif_parsed(PC),A0
	MOVEA.L	gif_info_ptr(PC),A1
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	CLR.W	D0
.done:
	MOVEM.L	(A7)+,D3-D7/A2-A6
	RTS

;	Reads the screen and image descriptors of the GIF at A0 into A1 and the
;	palettes into palette. Returns D0 = -1 if it isn't a GIF, else A0 = the
;	image data.

gif_parse:
	MOVEQ	#-1,D0
	CMPI.L	#'GIF8',(A0)+
	BNE.W	.done
	CMPI.W	#$3761,(A0)+
	BEQ.S	.version_ok
	CMPI.W	#$3961,-2(A0)
	BNE.W	.done
.version_ok:
	MOVE.B	1(A0),D0
	LSL.W	#8,D0
	MOVE.B	(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	3(A0),D0
	LSL.W	#8,D0
	MOVE.B	2(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	4(A0),D0
	ANDI.B	#7,D0
	ADDQ.B	#1,D0
	MOVE.B	D0,(A1)+
	MOVE.B	4(A0),D0
	ANDI.B	#112,D0
	LSR.B	#4,D0
	ADDQ.B	#1,D0
	MOVE.B	D0,(A1)+
	ADDQ.W	#7,A0
	MOVE.B	-3(A0),D0
	ANDI.B	#128,D0
	BEQ.S	.no_global_palette
	LEA	palette(PC),A2
	MOVEQ	#1,D0
	MOVE.B	-2(A1),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
.global_colour:
	MOVE.B	(A0)+,(A2)+
	MOVE.B	(A0)+,(A2)+
	CLR.B	(A2)+
	MOVE.B	(A0)+,(A2)+
	DBRA	D0,.global_colour
.no_global_palette:
	CLR.W	D0
.skip_extension:
	CMPI.B	#33,(A0)
	BNE.S	.descriptor
	ADDQ.W	#2,A0
.skip_subblock:
	MOVE.B	(A0)+,D0
	BEQ.S	.skip_extension
	ADDA.W	D0,A0
	BRA.S	.skip_subblock
.descriptor:
	MOVEQ	#-1,D0
	CMPI.B	#44,(A0)
	BNE.W	.done
	MOVE.B	2(A0),D0
	LSL.W	#8,D0
	MOVE.B	1(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	4(A0),D0
	LSL.W	#8,D0
	MOVE.B	3(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	6(A0),D0
	LSL.W	#8,D0
	MOVE.B	5(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	8(A0),D0
	LSL.W	#8,D0
	MOVE.B	7(A0),D0
	MOVE.W	D0,(A1)+
	MOVE.B	9(A0),D0
	ANDI.B	#3,D0
	MOVE.B	D0,(A1)+
	MOVE.B	9(A0),D0
	ANDI.B	#64,D0
	SNE	(A1)+
	MOVE.B	9(A0),D0
	ANDI.B	#128,D0
	SNE	(A1)+
	LEA	$A(A0),A0
	TST.B	-1(A1)
	BEQ.S	.no_local_palette
	LEA	palette(PC),A2
	MOVEQ	#1,D0
	MOVE.B	-3(A1),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
.local_colour:
	MOVE.B	(A0)+,(A2)+
	MOVE.B	(A0)+,(A2)+
	CLR.B	(A2)+
	MOVE.B	(A0)+,(A2)+
	DBRA	D0,.local_colour
.no_local_palette:
	CLR.W	D0
.skip_extension2:
	CMPI.B	#33,(A0)
	BNE.S	.ok
	ADDQ.W	#2,A0
.skip_subblock2:
	MOVE.B	(A0)+,D0
	BEQ.S	.skip_extension2
	ADDA.W	D0,A0
	BRA.S	.skip_subblock2
.ok:
	MOVEQ	#0,D0
.done:
	RTS

;	Joins the data sub-blocks at A0 into one stream at A1.

gif_join_blocks:
	MOVE.B	(A0)+,(A1)+
.block:
	CLR.W	D0
	MOVE.B	(A0)+,D0
	BEQ.S	.done
	SUBQ.W	#1,D0
.copy:
	MOVE.B	(A0)+,(A1)+
	DBRA	D0,.copy
	BRA.S	.block
.done:
	RTS

;	LZW decoder. A0 = code size and data, A1 = output (one byte per pixel).
;	Uses work_tables for the string table and line_buffer as stack.

lzw_decode:
	CLR.W	D4
	MOVE.B	(A0)+,D4
	MOVEQ	#1,D1
	LSL.W	D4,D1
	MOVEA.W	D1,A3
	ADDQ.W	#1,D1
	MOVEA.W	D1,A4
	ADDQ.W	#1,D1
	ADDQ.W	#1,D4
	MOVEQ	#1,D2
	LSL.W	D4,D2
	MOVE.W	D2,D7
	SUBQ.W	#1,D2
	SWAP	D1
	MOVE.W	D4,D1
	SWAP	D1
	CLR.W	D3
	MOVEQ	#-1,D5
	LEA	work_tables(PC),A2
	LEA	line_buffer(PC),A5
	LEA	1(A5),A6
.code:
	MOVE.B	2(A0),D0
	SWAP	D0
	MOVE.B	1(A0),D0
	LSL.W	#8,D0
	MOVE.B	(A0),D0
	LSR.L	D3,D0
	AND.W	D2,D0
	ADD.W	D4,D3
	MOVE.W	D3,D6
	LSR.W	#3,D6
	ADDA.W	D6,A0
	ANDI.W	#7,D3
	CMP.W	A3,D0
	BNE.S	.not_clear
	SWAP	D1
	MOVE.W	D1,D4
	SWAP	D1
	MOVEQ	#1,D7
	LSL.W	D4,D7
	MOVE.W	D7,D2
	SUBQ.W	#1,D2
	MOVE.W	A4,D1
	ADDQ.W	#1,D1
	BRA.S	.code
.not_clear:
	CMP.W	A4,D0
	BEQ.S	.end
	BGT.S	.string
	MOVE.W	D0,(A2,D1.W*4)
	MOVE.W	D0,-2(A2,D1.W*4)
	MOVE.B	D0,(A1)+
	BRA.S	.next
.string:
	MOVE.W	D0,(A2,D1.W*4)
	MOVE.W	D0,D6
	ADDQ.W	#1,D6
.push:
	MOVE.B	3(A2,D0.W*4),(A5)+
	MOVE.W	(A2,D0.W*4),D0
	CMP.W	A4,D0
	BGT.S	.push
	MOVE.L	A5,D5
	SUB.L	A6,D5
	MOVE.W	D0,-2(A2,D1.W*4)
	MOVE.B	D0,(A1)+
.pop:
	MOVE.B	-(A5),(A1)+
	DBRA	D5,.pop
	CMP.W	D1,D6
	BNE.S	.next
	MOVE.B	D0,-1(A1)
.next:
	ADDQ.W	#1,D1
	CMP.W	D7,D1
	BLE.S	.code
	CMP.W	#12,D4
	BEQ.S	.code
	ADD.W	D7,D7
	ADDQ.W	#1,D4
	MOVE.W	D7,D2
	SUBQ.W	#1,D2
	BRA.W	.code
.end:
	RTS

;	MacPaint: 576 x 720 pixels, PackBits lines after a 512-byte header.

macpaint_load:
	MOVE.L	#-1,(palette).L
	CLR.L	(palette+4).L
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVEA.L	file_buffer(PC),A0
	LEA	$200(A0),A0
	MOVE.W	#$2CF,D6
.line:
	MOVE.L	A1,D7
	ADDI.L	#72,D7
	BSR.W	unpack_packbits
	ADDQ.L	#8,A1
	DBRA	D6,.line
	RTS

;	IFF ILBM header parser: size and depth from the BMHD chunk.

iff_header:
	MOVEA.L	file_buffer(PC),A1
	CMPI.L	#'ILBM',8(A1)
	BNE.S	.unsupported
	LEA	$C(A1),A1
.find_bmhd:
	CMPI.L	#'BMHD',(A1)
	BEQ.S	.bmhd
	ADDA.L	4(A1),A1
	ADDQ.L	#8,A1
	BRA.S	.find_bmhd
.bmhd:
	MOVE.L	A1,(iff_bmhd).L
	MOVE.W	8(A1),6(A0)
	MOVE.W	$A(A1),8(A0)
	MOVE.B	$10(A1),D0
	CMP.B	#2,D0
	BLE.S	.planes1
	BEQ.S	.planes2
	CMP.B	#4,D0
	BLE.S	.planes4
	CMP.B	#8,D0
	BLE.S	.planes8
.unsupported:
	CLR.W	$A(A0)
	RTS

.planes8:
	MOVE.W	#8,$A(A0)
	RTS

.planes4:
	MOVE.W	#4,$A(A0)
	RTS

.planes2:
	MOVE.W	#2,$A(A0)
	RTS

.planes1:
	MOVE.W	#1,$A(A0)
	RTS

;	IFF ILBM loader: palette from CMAP, then the lines of BODY (packed or not)
;	through the line routine for the number of planes.

iff_load:
	MOVEA.L	file_buffer(PC),A0
	LEA	$C(A0),A0
.find_cmap:
	CMPI.L	#'CMAP',(A0)
	BEQ.S	.cmap
	ADDA.L	4(A0),A0
	ADDQ.L	#8,A0
	BRA.S	.find_cmap
.cmap:
	ADDQ.L	#4,A0
	MOVE.L	(A0)+,D0
	DIVU.W	#3,D0
	SUBQ.L	#1,D0
	LEA	palette(PC),A1
.colour:
	MOVE.B	(A0)+,(A1)+
	MOVE.B	(A0)+,(A1)+
	ADDQ.L	#1,A1
	MOVE.B	(A0)+,(A1)+
	DBRA	D0,.colour
	MOVEA.L	file_buffer(PC),A0
	LEA	$C(A0),A0
.find_body:
	CMPI.L	#'BODY',(A0)
	BEQ.S	.body
	ADDA.L	4(A0),A0
	ADDQ.L	#8,A0
	BRA.S	.find_body
.body:
	ADDQ.L	#8,A0
	BSR.W	picture_position
	MOVE.L	picture_start(PC),(line_dest).L
	MOVEA.L	format(PC),A3
	MOVE.W	screen_width(PC),D3
	LSR.W	#3,D3
	MULU.W	screen_planes(PC),D3
	MOVE.L	D3,(line_step).L
	MOVE.W	8(A3),D4
	SUBQ.W	#1,D4
	MOVE.W	6(A3),D5
	LSR.W	#4,D5
	SUBQ.W	#1,D5
	MOVEQ	#0,D0
	MOVEA.L	(iff_bmhd).L,A2
	MOVE.B	$10(A2),D0
	LEA	line_routines(PC),A5
	MOVE.L	-4(A5,D0.W*4),D0
	BEQ.S	.done
	MOVEA.L	D0,A5
	MOVEQ	#0,D0
	MOVE.W	6(A3),D2
	LSR.W	#3,D2
	MOVE.L	D2,(plane_bytes).L
	MOVE.B	$10(A2),D0
	MULU.W	D0,D2
	TST.B	$12(A2)
	BEQ.S	.raw_line
.packed_line:
	LEA	line_buffer(PC),A1
	MOVE.L	A1,D7
	ADD.L	D2,D7
	BSR.W	unpack_packbits
	JSR	(A5)
	DBRA	D4,.packed_line
.done:
	RTS

.raw_line:
	MOVE.L	A0,(line_source).L
	JSR	(A5)
	ADDA.L	D2,A0
	DBRA	D4,.raw_line
	RTS

LELONG	MACRO					; Read little endian long \1 to \2.
	MOVE.L	\1,\2
	ROR.W	#8,\2
	SWAP	\2
	ROR.W	#8,\2
	ENDM

;	BMP header parser. A0 = format table entry.
;
;	v1.2: rewritten together with the loader. Checks that the picture is
;	an uncompressed 256-colour Windows BMP that fits in the file, reads
;	the 32-bit width and height and allows top-down pictures.

bmp_header:
	MOVEA.L	(file_buffer).L,A1
	CMPI.L	#54,(file_size).L			; File size
	BLO.W	exit
	CMPI.W	#'BM',(A1)
	BNE.W	exit
	LELONG	14(A1),D0			; Info header size
	CMP.L	#40,D0
	BLO.W	exit
	CMPI.W	#$0800,28(A1)			; 8 bits per pixel
	BNE.W	exit
	TST.L	30(A1)				; Not compressed
	BNE.W	exit
	LELONG	18(A1),D0			; Width
	TST.L	D0
	BEQ.W	exit
	CMP.L	#$7FF0,D0
	BHI.W	exit
	MOVE.W	D0,(picture_width).L			; Real width
	MOVE.L	D0,D2
	ADDI.W	#15,D0
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)			; Width rounded up to 16 pixels
	LELONG	22(A1),D1			; Height, negative if top-down
	SMI	(bmp_top_down).L
	BPL.S	.bottom_up
	NEG.L	D1
.bottom_up:
	TST.L	D1
	BEQ.W	exit
	CMP.L	#$7FFF,D1
	BHI.W	exit
	MOVE.W	D1,8(A0)
	MOVE.W	#8,$A(A0)
	ADDQ.L	#3,D2				; Lines are padded to 4 bytes.
	ANDI.W	#$FFFC,D2
	MULU.L	D1,D2
	LELONG	10(A1),D0			; Offset of the pixels
	ADD.L	D0,D2
	BCS.W	exit
	CMP.L	(file_size).L,D2			; Pixels must fit in the file.
	BHI.W	exit
	RTS

;	BMP loader.
;
;	v1.2: rewritten. Version 1.1 took the red component of each colour
;	from the previous palette entry, read lines of the width rounded down
;	to 16 pixels instead of the padded line length (skewing pictures with
;	other widths), assumed the palette right after a 40-byte info header
;	and read only the low word of the pixel offset.

bmp_load:
	BSR.W	make_c2p_tables
	MOVEM.L	D2-D7/A2-A3,-(A7)
	MOVEA.L	file_buffer(PC),A1
	LELONG	14(A1),D0			; Palette after the info header
	LEA	14(A1,D0.L),A0
	LELONG	46(A1),D1			; Colours used, 0 = all
	SUBQ.L	#1,D1
	CMP.L	#255,D1
	BLS.S	.colours
	MOVE.L	#255,D1
.colours:
	LEA	palette(PC),A2
.colour:						; Blue, green, red, 0
	MOVE.B	2(A0),(A2)+			; to red, green, 0, blue
	MOVE.B	1(A0),(A2)+
	CLR.B	(A2)+
	MOVE.B	(A0),(A2)+
	ADDQ.L	#4,A0
	DBRA	D1,.colour

	BSR.W	picture_position				; Calculate screen position.
	LEA	line_buffer(PC),A0			; Clear the line buffer, so the
	MOVE.W	#$5FF,D1			; padding up to 16 pixels is
.clear_line:						; colour 0.
	CLR.L	(A0)+
	DBRA	D1,.clear_line
	MOVEA.L	format(PC),A0
	MOVE.W	6(A0),D1
	LSR.W	#4,D1
	MOVE.W	D1,(c2p_blocks).L
	MOVEQ	#0,D6
	MOVE.W	8(A0),D6			; D6 = height
	MOVEQ	#0,D7
	MOVE.W	picture_width(PC),D7			; D7 = width
	MOVE.L	D7,D5
	ADDQ.L	#3,D5
	ANDI.W	#$FFFC,D5			; D5 = bytes per BMP line
	MOVEQ	#0,D2
	MOVE.W	screen_width(PC),D2
	LSR.W	#4,D2
	ADD.W	D2,D2
	MULU.W	screen_planes(PC),D2			; D2 = bytes per screen line
	LELONG	10(A1),D0
	LEA	(A1,D0.L),A2			; A2 = pixels
	MOVEA.L	picture_start(PC),A3			; A3 = screen line
	TST.B	(bmp_top_down).L
	BNE.S	.top_down
	MOVE.L	D6,D0				; Bottom-up: start with the
	SUBQ.L	#1,D0				; last screen line.
	MULU.L	D2,D0
	ADDA.L	D0,A3
	NEG.L	D2
.top_down:
	SUBQ.W	#1,D6
.line:
	MOVEA.L	A2,A0
	LEA	line_buffer(PC),A1
	MOVE.W	D7,D0
	SUBQ.W	#1,D0
.copy:
	MOVE.B	(A0)+,(A1)+
	DBRA	D0,.copy
	PEA	line_buffer(PC)
	MOVE.L	(A7)+,(c2p_source).L
	MOVE.L	A3,(c2p_dest).L
	BSR.W	c2p_line
	ADDA.L	D5,A2
	ADDA.L	D2,A3
	DBRA	D6,.line
	MOVEM.L	(A7)+,D2-D7/A2-A3
	RTS

;	Makes the tables for c2p_line in work_tables: for each of the 8 pixels of
;	a byte group and each colour, the colour's bits in 8 bitplanes.

make_c2p_tables:
	MOVEM.L	D0-D3/A0,-(A7)
	LEA	work_tables+2048(PC),A0
	MOVE.W	#$FF,D3
.entry:
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	BTST.L	#0,D3
	BEQ.S	.bit1
	BSET.L	#31,D1
.bit1:
	BTST.L	#1,D3
	BEQ.S	.bit2
	BSET.L	#23,D1
.bit2:
	BTST.L	#2,D3
	BEQ.S	.bit3
	BSET.L	#15,D1
.bit3:
	BTST.L	#3,D3
	BEQ.S	.bit4
	BSET.L	#7,D1
.bit4:
	BTST.L	#4,D3
	BEQ.S	.bit5
	BSET.L	#31,D2
.bit5:
	BTST.L	#5,D3
	BEQ.S	.bit6
	BSET.L	#23,D2
.bit6:
	BTST.L	#6,D3
	BEQ.S	.bit7
	BSET.L	#15,D2
.bit7:
	BTST.L	#7,D3
	BEQ.S	.store
	BSET.L	#7,D2
.store:
	MOVE.L	D2,-(A0)
	MOVE.L	D1,-(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$800(A0)
	MOVE.L	D2,$804(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$1000(A0)
	MOVE.L	D2,$1004(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$1800(A0)
	MOVE.L	D2,$1804(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$2000(A0)
	MOVE.L	D2,$2004(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$2800(A0)
	MOVE.L	D2,$2804(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$3000(A0)
	MOVE.L	D2,$3004(A0)
	LSR.L	#1,D1
	LSR.L	#1,D2
	MOVE.L	D1,$3800(A0)
	MOVE.L	D2,$3804(A0)
	DBRA	D3,.entry
	MOVEM.L	(A7)+,D0-D3/A0
	RTS

;	Converts c2p_blocks x 16 pixels (one byte each) from c2p_source to 8
;	interleaved bitplanes at c2p_dest.

c2p_line:
	MOVEM.L	D0-D4/A0-A5,-(A7)
	MOVEA.L	c2p_source(PC),A0
	LEA	work_tables(PC),A1
	MOVEA.L	c2p_dest(PC),A2
	LEA	$1000(A1),A3
	LEA	$1000(A3),A4
	LEA	$1000(A4),A5
	MOVE.W	c2p_blocks(PC),D4
	SUBQ.L	#1,D4
	MOVEQ	#0,D0
	MOVE.W	#$100,D3
.block:
	MOVE.B	(A0)+,D0
	MOVE.L	(A1,D0.W*8),D1
	MOVE.L	4(A1,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A1,D3.W*8),D1
	OR.L	4(A1,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A3,D0.W*8),D1
	OR.L	4(A3,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A3,D3.W*8),D1
	OR.L	4(A3,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A4,D0.W*8),D1
	OR.L	4(A4,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A4,D3.W*8),D1
	OR.L	4(A4,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A5,D0.W*8),D1
	OR.L	4(A5,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A5,D3.W*8),D1
	OR.L	4(A5,D3.W*8),D2
	MOVEP.L	D1,0(A2)
	MOVEP.L	D2,8(A2)
	MOVE.B	(A0)+,D0
	MOVE.L	(A1,D0.W*8),D1
	MOVE.L	4(A1,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A1,D3.W*8),D1
	OR.L	4(A1,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A3,D0.W*8),D1
	OR.L	4(A3,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A3,D3.W*8),D1
	OR.L	4(A3,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A4,D0.W*8),D1
	OR.L	4(A4,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A4,D3.W*8),D1
	OR.L	4(A4,D3.W*8),D2
	MOVE.B	(A0)+,D0
	OR.L	(A5,D0.W*8),D1
	OR.L	4(A5,D0.W*8),D2
	MOVE.B	(A0)+,D3
	OR.L	(A5,D3.W*8),D1
	OR.L	4(A5,D3.W*8),D2
	MOVEP.L	D1,1(A2)
	MOVEP.L	D2,9(A2)
	LEA	$10(A2),A2
	DBRA	D4,.block
	MOVE.L	A0,(c2p_source).L
	MOVE.L	A2,(c2p_dest).L
	MOVEM.L	(A7)+,D0-D4/A0-A5
	RTS

;	RAG-D! header parser: width, height and depth from the header.

rag_header:
	MOVEA.L	(file_buffer).L,A1
	MOVE.W	$C(A1),6(A0)
	MOVE.W	$E(A1),8(A0)
	MOVE.W	$10(A1),$A(A0)
	RTS

;	RAG-D! loader: a 32-byte ST palette or a 1024-byte Falcon palette, then
;	the screen data.

rag_load:
	MOVEA.L	file_buffer(PC),A0
	LEA	$1E(A0),A1
	CMPI.L	#32,$12(A0)
	BEQ.S	.st_palette
	LEA	palette(PC),A2
	MOVE.W	#$FF,D0
.falcon_palette:
	MOVE.L	(A1)+,(A2)+
	DBRA	D0,.falcon_palette
	BRA.S	.pixels
.st_palette:
	MOVE.L	A1,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.W	st_palette
.pixels:
	BSR.W	picture_position
	MOVEA.L	file_buffer(PC),A0
	MOVE.W	$E(A0),D0
	SUBQ.W	#1,D0
	MOVEA.L	picture_start(PC),A1
	MOVEQ	#0,D2
	MOVE.W	$C(A0),D1
	LSR.W	#4,D1
	CMP.W	#40,D1
	BGE.S	.wide
	MOVEQ	#40,D2
	SUB.W	D1,D2
	ADD.W	D2,D2
	MULU.W	screen_planes(PC),D2
.wide:
	MULU.W	screen_planes(PC),D1
	SUBQ.W	#1,D1
	ADDA.L	$12(A0),A0
	LEA	$1E(A0),A0
.line:
	MOVE.L	D1,D3
.word:
	MOVE.W	(A0)+,(A1)+
	DBRA	D3,.word
	ADDA.L	D2,A1
	DBRA	D0,.line
	RTS

;	POV raw header parser: width and height as decimal text. The 24-bit
;	pixels follow.

raw_header:
	MOVEA.L	(file_buffer).L,A1
	MOVEQ	#0,D0
	MOVEQ	#0,D1
.width:
	MOVE.B	(A1)+,D0
	SUBI.W	#48,D0
	BMI.S	.height
	MULU.W	#10,D1
	ADD.W	D0,D1
	BRA.S	.width
.height:
	MOVE.W	D1,(picture_width).L		; v1.2: width rounded up to 16
	ADDI.W	#15,D1				; pixels, as fill_border needs it.
	ANDI.W	#$FFF0,D1
	MOVE.W	D1,6(A0)
	MOVEQ	#0,D0
	MOVEQ	#0,D1
.height_digit:
	MOVE.B	(A1)+,D0
	SUBI.W	#48,D0
	BMI.S	.done
	MULU.W	#10,D1
	ADD.W	D0,D1
	BRA.S	.height_digit
.done:
	MOVE.W	D1,8(A0)
	MOVE.L	A1,(raw_pixels).L
	RTS

;	POV raw loader: converts the 24-bit pixels to RGB565.

raw_load:
	BSR.W	picture_position
	MOVEM.L	D2-D6/A2-A3,-(A7)		; v1.2: lines of the real width,
	MOVEA.L	raw_pixels(PC),A0		; padded to 16 pixels, and D1
	BSR.W	tc_lines			; cleared.
	MOVEQ	#0,D1
.line:
	MOVEA.L	A1,A3
	MOVE.W	D4,D2
.pixel:
	MOVE.B	(A0)+,D0			; Red
	LSL.W	#5,D0
	MOVE.B	(A0)+,D0			; Green
	ANDI.W	#$FFFC,D0
	LSL.W	#3,D0
	MOVE.B	(A0)+,D1			; Blue
	LSR.W	#3,D1
	OR.W	D1,D0
	MOVE.W	D0,(A3)+
	DBRA	D2,.pixel
	BSR.W	tc_pad
	DBRA	D5,.line
	MOVEM.L	(A7)+,D2-D6/A2-A3
	RTS

;	GEM (X)IMG header parser: size and depth. 24-bit pictures are shown on a
;	16-bit screen.

img_header:
	MOVEA.L	(file_buffer).L,A1
	MOVE.W	4(A1),D0
	CMP.W	#24,D0
	BNE.S	.depth
	MOVE.W	#16,D0
.depth:
	MOVE.W	D0,$A(A0)
	MOVE.W	$C(A1),D0
	MOVE.W	D0,(picture_width).L
	ADDI.W	#15,D0
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)
	MOVE.W	$E(A1),8(A0)
	RTS

;	GEM (X)IMG loader: monochrome or with several planes.

img_load:
	BSR.W	picture_position
	MOVEA.L	file_buffer(PC),A0
	MOVE.W	4(A0),D0
	CMP.W	#1,D0
	BEQ.W	img_load_mono
	BRA.W	img_load_planes

;	Sets the palette from an XIMG RGB palette. Pictures without one use the
;	system palette.

img_palette:
	MOVEA.L	file_buffer(PC),A0
	LEA	palette(PC),A1
	CMPI.W	#8,2(A0)
	BEQ.S	.system_palette
	CMPI.L	#'XIMG',$10(A0)
	BEQ.S	.ximg
	RTS

.system_palette:
	MOVEQ	#1,D0
	MOVE.W	screen_planes(PC),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
	LEA	($FFFF9800).W,A0		; videl_palette[0] [Falcon]
	LEA	palette(PC),A1
.copy:						; v1.2: was DBRA D1 (the number of
	MOVE.L	(A0)+,(A1)+			; planes), which copied only the
	DBRA	D0,.copy			; first few colours.
	RTS

.ximg:
	TST.W	$14(A0)
	BNE.S	.done
	MOVEQ	#1,D0
	MOVEQ	#0,D1
	MOVE.W	4(A0),D1
	LSL.W	D1,D0
	SUBQ.W	#1,D0
	LEA	$16(A0),A0
.ximg_colour:
	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	ADDQ.W	#8,D1
	MULU.W	#100,D1
	DIVU.W	#$18C,D1
	MOVE.B	D1,(A1)+
	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	ADDQ.W	#8,D1
	MULU.W	#100,D1
	DIVU.W	#$18C,D1
	MOVE.B	D1,(A1)+
	CLR.B	(A1)+
	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	ADDQ.W	#8,D1
	MULU.W	#100,D1
	DIVU.W	#$18C,D1
	MOVE.B	D1,(A1)+
	DBRA	D0,.ximg_colour
.done:
	RTS

;	IMG with several planes: unpacks each line with img_unpack_line and
;	converts it with the line routine for the number of planes.

img_load_planes:
	MOVEQ	#16,D0
	CMP.W	screen_planes(PC),D0
	BEQ.S	.palette_done
	BSR.W	img_palette
.palette_done:
	MOVEA.L	file_buffer(PC),A0
	MOVEQ	#0,D0
	MOVE.W	$C(A0),D0
	ADDQ.L	#7,D0
	LSR.W	#3,D0
	MOVE.L	D0,(plane_bytes).L
	MULU.W	4(A0),D0
	MOVE.L	D0,(img_line_bytes).L
	MOVE.L	picture_start(PC),(line_dest).L
	MOVEA.L	format(PC),A1
	MOVE.W	screen_width(PC),D0
	LSR.W	#3,D0
	MULU.W	$A(A1),D0
	MOVE.L	D0,(line_step).L
	MOVEQ	#0,D6
	MOVE.W	6(A0),D6
	SUBQ.W	#1,D6
	MOVE.W	$E(A0),D3
	SUBQ.W	#1,D3
	MOVE.W	4(A0),D0
	LEA	line_routines(PC),A6
	MOVE.L	-4(A6,D0.W*4),D0
	BEQ.S	.done
	MOVEA.L	D0,A6
	MOVE.W	2(A0),D0
	ADD.W	D0,D0
	ADDA.W	D0,A0
.line:
	LEA	line_buffer(PC),A1
	MOVE.L	img_line_bytes(PC),D7
	ADD.L	A1,D7
	BSR.W	img_unpack_line
	JSR	(A6)
	DBRA	D3,.line
.done:
	RTS

;	Line routines for IFF and IMG, see line_routines: copy one line from
;	line_source (separate planes of plane_bytes each, or chunky pixels) to the
;	screen at line_dest and advance line_dest by line_step.

line_16bit:
	MOVEM.L	D0/A0-A1,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	line_dest(PC),A1
	MOVE.W	picture_width(PC),D0
	SUBQ.W	#1,D0
.pixel:
	MOVE.W	(A0)+,(A1)+
	DBRA	D0,.pixel
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0/A0-A1
	RTS

line_24bit:
	MOVEM.L	D0-D1/A0-A1,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	line_dest(PC),A1
	MOVE.W	picture_width(PC),D0
	SUBQ.W	#1,D0
.pixel:
	MOVEQ	#0,D1
	MOVE.B	(A0)+,D1
	LSL.W	#5,D1
	MOVE.B	(A0)+,D1
	LSL.L	#6,D1
	MOVE.B	(A0)+,D1
	LSR.L	#3,D1
	MOVE.W	D1,(A1)+
	DBRA	D0,.pixel
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0-D1/A0-A1
	RTS

line_1plane:
	MOVEM.L	D0/A0/A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	line_dest(PC),A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
.byte:
	MOVE.B	(A0)+,(A6)+
	CMPA.L	D0,A0
	BNE.S	.byte
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0/A0/A6
	RTS

line_2planes:
	MOVEM.L	D0/A0-A1/A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	line_dest(PC),A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
.bytes:
	MOVE.B	(A0)+,(A6)+
	MOVE.B	(A1)+,1(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	ADDQ.L	#3,A6
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0/A0-A1/A6
	RTS

line_3planes:
	MOVEM.L	D0/A0-A2/A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	(line_dest).L,A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	ADDA.L	plane_bytes(PC),A2
.bytes:
	MOVE.B	(A0)+,(A6)+
	MOVE.B	(A1)+,1(A6)
	MOVE.B	(A2)+,3(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	ADDQ.L	#7,A6
	CLR.W	-2(A6)
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0/A0-A2/A6
	RTS

line_4planes:
	MOVEM.L	D0/A0-A3/A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	(line_dest).L,A6
	MOVE.L	A0,D0
	ADD.L	(plane_bytes).L,D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	ADDA.L	(plane_bytes).L,A2
	MOVEA.L	A2,A3
	ADDA.L	(plane_bytes).L,A3
.bytes:
	MOVE.B	(A0)+,(A6)+
	MOVE.B	(A1)+,1(A6)
	MOVE.B	(A2)+,3(A6)
	MOVE.B	(A3)+,5(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	MOVE.B	(A3)+,6(A6)
	ADDQ.L	#7,A6
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0/A0-A3/A6
	RTS

line_5planes:
	MOVEM.L	D0-D1/A0-A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	line_dest(PC),A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	MOVE.L	plane_bytes(PC),D1
	ADDA.L	D1,A2
	MOVEA.L	A2,A3
	ADDA.L	D1,A3
	MOVEA.L	A3,A4
	ADDA.L	D1,A4
.bytes:
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	MOVE.B	(A3)+,6(A6)
	MOVE.B	(A4)+,8(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,1(A6)
	MOVE.B	(A1)+,3(A6)
	MOVE.B	(A2)+,5(A6)
	MOVE.B	(A3)+,7(A6)
	MOVE.B	(A4)+,9(A6)
	CLR.W	$A(A6)
	CLR.L	$C(A6)
	LEA	$10(A6),A6
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0-D1/A0-A6
	RTS

line_6planes:
	MOVEM.L	D0-D1/A0-A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	(line_dest).L,A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	MOVE.L	plane_bytes(PC),D1
	ADDA.L	D1,A2
	MOVEA.L	A2,A3
	ADDA.L	D1,A3
	MOVEA.L	A3,A4
	ADDA.L	D1,A4
	ADDA.L	D1,A4
.bytes:
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	MOVE.B	(A3)+,6(A6)
	MOVE.B	-1(A3,D1.W),8(A6)
	MOVE.B	(A4)+,$A(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,1(A6)
	MOVE.B	(A1)+,3(A6)
	MOVE.B	(A2)+,5(A6)
	MOVE.B	(A3)+,7(A6)
	MOVE.B	-1(A3,D1.W),9(A6)
	MOVE.B	(A4)+,$B(A6)
	CLR.L	$C(A6)
	LEA	$10(A6),A6
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0-D1/A0-A6
	RTS

line_7planes:
	MOVEM.L	D0-D1/A0-A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	(line_dest).L,A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	MOVE.L	plane_bytes(PC),D1
	ADDA.L	D1,A2
	MOVEA.L	A2,A3
	ADDA.L	D1,A3
	MOVEA.L	A3,A4
	ADDA.L	D1,A4
	ADDA.L	D1,A4
.bytes:
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	MOVE.B	(A3)+,6(A6)
	MOVE.B	-1(A3,D1.W),8(A6)
	MOVE.B	(A4)+,$A(A6)
	MOVE.B	-1(A4,D1.W),$C(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,1(A6)
	MOVE.B	(A1)+,3(A6)
	MOVE.B	(A2)+,5(A6)
	MOVE.B	(A3)+,7(A6)
	MOVE.B	-1(A3,D1.W),9(A6)
	MOVE.B	(A4)+,$B(A6)
	MOVE.B	-1(A4,D1.W),$D(A6)
	LEA	$E(A6),A6
	CLR.W	(A6)+
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0-D1/A0-A6
	RTS

line_8planes:
	MOVEM.L	D0-D1/A0-A6,-(A7)
	MOVEA.L	line_source(PC),A0
	MOVEA.L	(line_dest).L,A6
	MOVE.L	A0,D0
	ADD.L	plane_bytes(PC),D0
	MOVEA.L	D0,A1
	MOVEA.L	D0,A2
	MOVE.L	plane_bytes(PC),D1
	ADDA.L	D1,A2
	MOVEA.L	A2,A3
	ADDA.L	D1,A3
	MOVEA.L	A3,A4
	ADDA.L	D1,A4
	ADDA.L	D1,A4
	MOVEA.L	A4,A5
	ADDA.L	D1,A5
	ADDA.L	D1,A5
.bytes:
	MOVE.B	(A0)+,(A6)
	MOVE.B	(A1)+,2(A6)
	MOVE.B	(A2)+,4(A6)
	MOVE.B	(A3)+,6(A6)
	MOVE.B	-1(A3,D1.W),8(A6)
	MOVE.B	(A4)+,$A(A6)
	MOVE.B	-1(A4,D1.W),$C(A6)
	MOVE.B	(A5)+,$E(A6)
	CMPA.L	D0,A0
	BEQ.S	.done
	MOVE.B	(A0)+,1(A6)
	MOVE.B	(A1)+,3(A6)
	MOVE.B	(A2)+,5(A6)
	MOVE.B	(A3)+,7(A6)
	MOVE.B	-1(A3,D1.W),9(A6)
	MOVE.B	(A4)+,$B(A6)
	MOVE.B	-1(A4,D1.W),$D(A6)
	MOVE.B	(A5)+,$F(A6)
	LEA	$10(A6),A6
	CMPA.L	D0,A0
	BNE.S	.bytes
.done:
	MOVE.L	line_step(PC),D0
	ADD.L	D0,(line_dest).L
	MOVEM.L	(A7)+,D0-D1/A0-A6
	RTS

;	Monochrome IMG: unpacks the lines straight to the screen.

img_load_mono:
	MOVE.L	#-1,(palette).L
	CLR.L	(palette+4).L
	MOVEA.L	file_buffer(PC),A0
	MOVE.W	$E(A0),D3
	SUBQ.W	#1,D3
	MOVEQ	#0,D5
	MOVE.W	screen_width(PC),D5
	LSR.W	#3,D5
	MOVEQ	#0,D7
	MOVE.W	$C(A0),D7
	ADDQ.L	#7,D7
	LSR.W	#3,D7
	MOVE.L	D5,D4
	SUB.L	D7,D4
	MOVE.W	6(A0),D6
	SUBQ.L	#1,D6
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	ADD.L	A1,D7
	MOVE.W	2(A0),D0
	ADD.W	D0,D0
	ADDA.W	D0,A0
.line:
	BSR.S	img_unpack_line
	ADD.L	D5,D7
	ADDA.L	D4,A1
	DBRA	D3,.line
	RTS

;	Unpacks IMG data from A0 to A1 up to D7: pattern runs, solid runs, bit
;	strings and vertical repeats (img_repeat). D6 = pattern length - 1.

img_unpack_line:
	TST.W	(img_repeat).L
	BEQ.S	.no_repeat
	SUBQ.W	#1,(img_repeat).L
	MOVEA.L	img_repeat_line(PC),A0
.no_repeat:
	TST.W	(A0)
	BNE.S	.code
	ADDQ.L	#3,A0
	MOVE.B	(A0)+,(img_repeat+1).L
	SUBQ.W	#1,(img_repeat).L
	MOVE.L	A0,(img_repeat_line).L
.code:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	BMI.S	.not_solid_white
	BNE.S	.white
	MOVE.B	(A0)+,D0
	SUBQ.W	#1,D0
.pattern:
	MOVE.W	D6,D1
	MOVEA.L	A0,A2
.pattern_byte:
	MOVE.B	(A2)+,(A1)+
	DBRA	D1,.pattern_byte
	DBRA	D0,.pattern
	MOVEA.L	A2,A0
.next:
	CMPA.L	D7,A1
	BLT.S	.code
	RTS

.white:
	MOVEQ	#0,D1
	SUBQ.W	#1,D0
.white_byte:
	MOVE.B	D1,(A1)+
	DBRA	D0,.white_byte
	BRA.S	.next
.not_solid_white:
	ANDI.W	#127,D0
	BNE.S	.black
	MOVE.B	(A0)+,D0
	SUBQ.L	#1,D0
.raw_byte:
	MOVE.B	(A0)+,(A1)+
	DBRA	D0,.raw_byte
	BRA.S	.next
.black:
	MOVEQ	#-1,D1
	SUBQ.W	#1,D0
.black_byte:
	MOVE.B	D1,(A1)+
	DBRA	D0,.black_byte
	BRA.S	.next

;	Unpacks PackBits data from A0 to A1 until A1 reaches D7.

unpack_packbits:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	BPL.S	.literal
	NEG.B	D0
	MOVE.B	(A0)+,D1
.repeat:
	MOVE.B	D1,(A1)+
	DBRA	D0,.repeat
.next:
	CMP.L	A1,D7
	BGT.S	unpack_packbits
	RTS

.literal:
	MOVE.B	(A0)+,(A1)+
	DBRA	D0,.literal
	BRA.S	.next

;	Degas compressed medium resolution (.PC2), lines doubled to 640 x 400.

pc2_load:
	MOVEA.L	file_buffer(PC),A0
	ADDQ.L	#2,A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#4,(pal_count).L
	BSR.W	st_palette
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A2
	MOVEA.L	file_buffer(PC),A0
	LEA	$22(A0),A0
	MOVE.W	#$C7,D2
.line:
	MOVEA.L	line_source(PC),A1
	MOVE.L	A1,D7
	ADDI.L	#$A0,D7
	BSR.S	unpack_packbits
	MOVEA.L	line_source(PC),A1
	MOVEQ	#39,D3
.word:
	MOVE.W	(A1)+,(A2)+
	MOVE.W	$4E(A1),(A2)+
	DBRA	D3,.word
	MOVE.W	#39,D3
.double:
	MOVE.L	-$A0(A2),(A2)+
	DBRA	D3,.double
	DBRA	D2,.line
	RTS

;	Degas compressed low resolution (.PC1).

pc1_load:
	MOVEA.L	file_buffer(PC),A0
	ADDQ.L	#2,A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.W	st_palette
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A2
	MOVEA.L	file_buffer(PC),A0
	LEA	$22(A0),A0
	MOVE.W	#$C7,D2
.line:
	MOVEA.L	line_source(PC),A1		; v1.2: was LEA, which unpacked
	MOVE.L	A1,D7
	ADDI.L	#$A0,D7
	BSR.W	unpack_packbits
	MOVEA.L	line_source(PC),A1		; over line_source and what follows.
	MOVEQ	#19,D3
.block:
	MOVE.W	(A1)+,(A2)+
	MOVE.W	$26(A1),(A2)+
	MOVE.W	$4E(A1),(A2)+
	MOVE.W	$76(A1),(A2)+
	DBRA	D3,.block
	LEA	$A0(A2),A2
	DBRA	D2,.line
	RTS

;	Degas compressed high resolution (.PC3).

pc3_load:
	MOVEA.L	file_buffer(PC),A0
	TST.W	2(A0)
	LEA	palette(PC),A1
	BEQ.S	.black_background
	MOVE.L	#$FFFF00FF,(A1)+
	CLR.L	(A1)+
	BRA.S	.unpack
.black_background:
	CLR.L	(A1)+
	MOVE.L	#$FFFF00FF,(A1)+
.unpack:
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVEA.L	file_buffer(PC),A0
	LEA	$22(A0),A0
	MOVE.W	#$18F,D2
.line:
	MOVE.L	A1,D7
	ADDI.L	#80,D7
	BSR.W	unpack_packbits
	DBRA	D2,.line
	RTS

;	Doodle and Object Editor Mural: 32000 bytes of low resolution data, shown
;	with a fixed palette.

doodle_load:
	MOVE.L	#doodle_palette,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.W	st_palette
	MOVE.L	file_buffer(PC),(put_source).L
	MOVE.L	screen(PC),(put_dest).L
	BSR.W	put_320x200
	RTS

;	Art Director: 32000 bytes of low resolution data, then the palette.

art_load:
	MOVEA.L	file_buffer(PC),A0
	LEA	$7D00(A0),A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.W	st_palette
	MOVE.L	file_buffer(PC),(put_source).L
	MOVE.L	screen(PC),(put_dest).L
	BSR.W	put_320x200
	RTS

;	Degas low resolution (.PI1).

pi1_load:
	MOVEA.L	file_buffer(PC),A0
	ADDQ.L	#2,A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.W	st_palette
	MOVE.L	file_buffer(PC),D0
	ADDI.L	#34,D0
	MOVE.L	D0,(put_source).L
	MOVE.L	screen(PC),(put_dest).L
	BSR.W	put_320x200
	RTS

;	Degas medium resolution (.PI2), lines doubled to 640 x 400.

pi2_load:
	MOVEA.L	file_buffer(PC),A0
	ADDQ.L	#2,A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#4,(pal_count).L
	BSR.W	st_palette
	MOVEA.L	file_buffer(PC),A0
	LEA	$22(A0),A0
	MOVEA.L	screen(PC),A1
	MOVE.W	#$C7,D2
.line:
	MOVEQ	#39,D0
.longword:
	MOVE.L	(A0)+,D1
	MOVE.L	D1,(A1)+
	MOVE.L	D1,$9C(A1)
	DBRA	D0,.longword
	LEA	$A0(A1),A1
	DBRA	D2,.line
	RTS

;	Degas high resolution (.PI3).

pi3_load:
	MOVEA.L	file_buffer(PC),A0
	TST.W	2(A0)
	BEQ.S	.black_background
	MOVE.L	#$FFFF00FF,(palette).L
	CLR.L	(palette+4).L
	BRA.S	.copy
.black_background:
	CLR.L	(palette).L
	MOVE.L	#$FFFF00FF,(palette+4).L
.copy:
	LEA	$22(A0),A0
	MOVEA.L	screen(PC),A1
	MOVE.W	#$1F3F,D0
.longword:
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.longword
	RTS

;	Extended Degas .PI4: 320 x 240 in 256 colours, Falcon palette first.

pi4_load:
	LEA	palette(PC),A1
	MOVEA.L	file_buffer(PC),A0
	MOVEQ	#127,D0
.palette:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.palette
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVE.W	#$EF,D0
.line:
	MOVEQ	#79,D1
.longword:
	MOVE.L	(A0)+,(A1)+
	DBRA	D1,.longword
	LEA	$140(A1),A1
	DBRA	D0,.line
	RTS

;	Extended Degas .PI5: 640 x 480 in 256 colours, Falcon palette first.

pi5_load:
	LEA	palette(PC),A1
	MOVEA.L	file_buffer(PC),A0
	MOVEQ	#127,D0
.palette:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.palette
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVE.L	#640*480/4-1,D0			; v1.2: was MOVE.W #$9600,D0 and
.longword:					; DBRA, which copied half of the
	MOVE.L	(A0)+,(A1)+			; picture.
	SUBQ.L	#1,D0
	BPL.S	.longword
	RTS

;	Extended Degas .PI9: 320 x 240 in 256 colours, Falcon palette first.

pi9_load:
	LEA	palette(PC),A1
	MOVEA.L	file_buffer(PC),A0
	MOVEQ	#127,D0
.palette:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBRA	D0,.palette
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVE.W	#$EF,D0
.line:
	MOVEQ	#79,D1
.longword:
	MOVE.L	(A0)+,(A1)+
	DBRA	D1,.longword
	LEA	$140(A1),A1
	DBRA	D0,.line
	RTS

;	Neochrome (.NEO).

neo_load:
	MOVEA.L	file_buffer(PC),A0
	ADDQ.L	#4,A0
	MOVE.L	A0,(pal_source).L
	MOVE.L	#palette,(pal_dest).L
	MOVE.W	#16,(pal_count).L
	BSR.S	st_palette
	MOVE.L	file_buffer(PC),D0
	ADDI.L	#$80,D0
	MOVE.L	D0,(put_source).L
	MOVE.L	screen(PC),(put_dest).L
	BSR.S	put_320x200
	RTS

;	Converts pal_count STE colours (4 bits per component) at pal_source to
;	Falcon palette entries at pal_dest.

st_palette:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	MOVE.W	pal_count(PC),D0
	SUBQ.L	#1,D0
	MOVEA.L	pal_source(PC),A0
	MOVEA.L	pal_dest(PC),A1
.colour:
	MOVEQ	#0,D1
	MOVEQ	#0,D2
	MOVE.W	(A0),D1
	ANDI.W	#7,D1
	LSL.W	#5,D1
	OR.W	D1,D2
	MOVE.W	(A0),D1
	ANDI.W	#8,D1
	ADD.W	D1,D1
	OR.W	D1,D2
	MOVE.W	(A0),D1
	ANDI.W	#112,D1
	MOVEQ	#17,D3
	LSL.L	D3,D1
	OR.L	D1,D2
	MOVE.W	(A0),D1
	ANDI.W	#$80,D1
	MOVEQ	#13,D3
	LSL.L	D3,D1
	OR.L	D1,D2
	MOVE.W	(A0),D1
	ANDI.W	#$700,D1
	MOVEQ	#21,D3
	LSL.L	D3,D1
	OR.L	D1,D2
	MOVEQ	#0,D1
	MOVE.W	(A0)+,D1
	ANDI.W	#$800,D1
	MOVEQ	#16,D3
	LSL.L	D3,D1
	ADD.L	D1,D1
	OR.L	D1,D2
	MOVE.L	D2,(A1)+
	DBRA	D0,.colour
	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS

;	Copies a 320 x 200 picture in the screen's format from put_source to the
;	screen.

put_320x200:
	MOVEM.L	D0-D3/A0-A1,-(A7)
	MOVEA.L	put_source(PC),A0
	MOVEA.L	put_dest(PC),A1
	BSR.W	picture_position
	MOVEA.L	picture_start(PC),A1
	MOVEQ	#40,D3
	MULU.W	screen_planes(PC),D3
	MOVEQ	#10,D0
	MULU.W	screen_planes(PC),D0
	SUBQ.L	#1,D0
	MOVE.W	#$C7,D1
.line:
	MOVE.L	D0,D2
.longword:
	MOVE.L	(A0)+,(A1)+
	DBRA	D2,.longword
	ADDA.L	D3,A1
	DBRA	D1,.line
	MOVEM.L	(A7)+,D0-D3/A0-A1
	RTS


;____ Q16 support, added in v1.2 ____________________________________________
;
;	Q16 is RGB565 with optional 8-bit alpha, see q16_lib.h. The picture is
;	decoded with q16dec.s into a temporary buffer and copied to the screen.
;	Alpha is blended against black.

;	Header parser. A0 = format table entry.

q16_header:
	MOVEA.L	file_buffer(PC),A1
	CMPI.L	#20,(file_size).L			; File size
	BLO.W	exit
	CMPI.L	#'Q565',(A1)
	BNE.W	exit
	CMPI.B	#1,4(A1)			; Version
	BNE.W	exit
	MOVE.W	6(A1),D0			; Width, little endian
	ROR.W	#8,D0
	BEQ.W	exit
	CMP.W	#$7FF0,D0
	BHI.W	exit
	MOVE.W	D0,(picture_width).L			; Real width
	ADDI.W	#15,D0
	ANDI.W	#$FFF0,D0
	MOVE.W	D0,6(A0)			; Width rounded up to 16 pixels
	MOVE.W	8(A1),D0			; Height
	ROR.W	#8,D0
	BEQ.W	exit
	MOVE.W	D0,8(A0)
	MOVE.W	#16,$A(A0)			; True color

	MOVE.L	12(A1),D0			; pixelBytes
	ROR.W	#8,D0
	SWAP	D0
	ROR.W	#8,D0
	MOVE.L	D0,(q16_pixel_bytes).L
	MOVE.L	16(A1),D1			; alphaBytes
	ROR.W	#8,D1
	SWAP	D1
	ROR.W	#8,D1
	MOVE.L	D1,(q16_alpha_bytes).L
	ADD.L	D1,D0
	BCS.W	exit
	ADDI.L	#20,D0
	BCS.W	exit
	CMP.L	(file_size).L,D0			; Header + data must fit in file.
	BHI.W	exit
	RTS

;	Loader. Decodes the picture and copies it to the screen.

q16_load:
	BSR.W	picture_position				; Calculate screen position.
	MOVEM.L	D2-D7/A2-A6,-(A7)

	MOVEQ	#0,D7
	MOVE.W	picture_width(PC),D7			; D7 = width
	MOVEA.L	format(PC),A2
	MOVEQ	#0,D6
	MOVE.W	8(A2),D6			; D6 = height
	MOVE.L	D7,D0
	MULU.L	D6,D0
	MOVE.L	D0,(q16_pixels_count).L

	MOVE.L	#65536,-(A7)			; Table for q_decPix
	MOVE.W	#72,-(A7)			; Malloc
	TRAP	#1
	ADDQ.L	#6,A7
	MOVE.L	D0,(q16_table).L
	BEQ.W	.fail

	MOVE.L	(q16_pixels_count).L,D0		; Pixels
	ADD.L	D0,D0
	MOVE.L	D0,-(A7)
	MOVE.W	#72,-(A7)			; Malloc
	TRAP	#1
	ADDQ.L	#6,A7
	MOVE.L	D0,(q16_pixels).L
	BEQ.W	.fail

	TST.L	(q16_alpha_bytes).L		; Alpha
	BEQ.S	.no_alpha
	MOVE.L	(q16_pixels_count).L,-(A7)
	MOVE.W	#72,-(A7)			; Malloc
	TRAP	#1
	ADDQ.L	#6,A7
	MOVE.L	D0,(q16_alpha).L
	BEQ.W	.fail
.no_alpha:

	MOVE.L	(q16_table).L,-(A7)
	BSR.W	q16_setupStaticTable
	ADDQ.L	#4,A7

	MOVE.L	(q16_table).L,-(A7)		; Decode pixels.
	MOVE.L	(q16_pixels_count).L,-(A7)
	MOVEA.L	file_buffer(PC),A3
	LEA	20(A3),A3
	MOVE.L	A3,D0
	ADD.L	(q16_pixel_bytes).L,D0
	MOVE.L	D0,-(A7)
	MOVE.L	A3,-(A7)
	MOVE.L	(q16_pixels).L,-(A7)
	BSR.W	q_decPix
	LEA	20(A7),A7
	TST.W	D0
	BNE.W	.fail

	TST.L	(q16_alpha_bytes).L		; Decode alpha and blend.
	BEQ.S	.copy
	MOVE.L	(q16_pixels_count).L,-(A7)
	ADDA.L	(q16_pixel_bytes).L,A3
	MOVE.L	A3,D0
	ADD.L	(q16_alpha_bytes).L,D0
	MOVE.L	D0,-(A7)
	MOVE.L	A3,-(A7)
	MOVE.L	(q16_alpha).L,-(A7)
	BSR.W	q_decAlp
	LEA	16(A7),A7
	TST.W	D0
	BNE.W	.fail
	BSR.W	q16_blend

.copy:
	MOVEA.L	(q16_pixels).L,A0
	MOVEA.L	picture_start(PC),A1
	MOVEA.L	format(PC),A2
	MOVEQ	#0,D1
	MOVE.W	screen_width(PC),D1			; Screen width
	ADD.L	D1,D1				; D1 = bytes per screen line
	MOVE.W	6(A2),D5
	SUB.W	D7,D5				; D5 = padding up to 16 pixels
	SUBQ.W	#1,D7
	MOVE.W	D6,D3
	SUBQ.W	#1,D3
.line:
	MOVEA.L	A1,A3
	MOVE.W	D7,D2
.pixel:
	MOVE.W	(A0)+,(A3)+
	DBRA	D2,.pixel
	MOVE.W	D5,D2
	BRA.S	.pad_test
.pad:
	CLR.W	(A3)+
.pad_test:
	DBRA	D2,.pad
	ADDA.L	D1,A1
	DBRA	D3,.line

	BSR.S	q16_free
	MOVEM.L	(A7)+,D2-D7/A2-A6
	RTS

.fail:
	BSR.S	q16_free
	BRA.W	exit

;	Frees the temporary buffers.

q16_free:
	LEA	(q16_table).L,A3
	MOVEQ	#2,D3
.loop:
	MOVE.L	(A3),D0
	BEQ.S	.next
	CLR.L	(A3)
	MOVE.L	D0,-(A7)
	MOVE.W	#73,-(A7)			; Mfree
	TRAP	#1
	ADDQ.L	#6,A7
.next:
	ADDQ.L	#4,A3
	DBRA	D3,.loop
	RTS

;	Blends the pixels against black using the alpha channel.

q16_blend:
	MOVEM.L	D2-D7,-(A7)
	MOVEA.L	(q16_pixels).L,A0
	MOVEA.L	(q16_alpha).L,A1
	MOVE.L	(q16_pixels_count).L,D7
	MOVEQ	#11,D6
.loop:
	MOVEQ	#0,D0
	MOVE.B	(A1)+,D0
	CMP.B	#255,D0
	BEQ.S	.opaque
	TST.B	D0
	BEQ.S	.clear
	ADDQ.W	#1,D0				; Multiply by (alpha + 1) / 256.
	MOVE.W	(A0),D1
	MOVE.W	D1,D2				; Red
	LSR.W	D6,D2
	MULU.W	D0,D2
	LSR.W	#8,D2
	LSL.W	D6,D2
	MOVE.W	D1,D3				; Green
	LSR.W	#5,D3
	ANDI.W	#63,D3
	MULU.W	D0,D3
	LSR.W	#8,D3
	LSL.W	#5,D3
	OR.W	D3,D2
	ANDI.W	#31,D1				; Blue
	MULU.W	D0,D1
	LSR.W	#8,D1
	OR.W	D1,D2
	MOVE.W	D2,(A0)+
	BRA.S	.next
.clear:
	CLR.W	(A0)+
	BRA.S	.next
.opaque:
	ADDQ.L	#2,A0
.next:
	SUBQ.L	#1,D7
	BNE.S	.loop
	MOVEM.L	(A7)+,D2-D7
	RTS

	INCLUDE	"../m68k/q16dec.s"

	SECTION DATA
skip_shiftmode:					; Restore the ST shift mode on exit if 0
	dc.b	$FF,$FF
edge_masks:					; Masks for the last word of a line, by width & 15
	dc.b	$00,$00,$00,$00,$7F,$FF,$7F,$FF,$3F,$FF,$3F,$FF,$3F,$FF,$3F,$FF
	dc.b	$0F,$FF,$0F,$FF,$07,$FF,$07,$FF,$03,$FF,$03,$FF,$01,$FF,$01,$FF
;	Picture formats, 32 bytes each:
;
;	 0	Extension, e.g. ".PI1"
;	 4	Output type, 0 = bitmap (the only one)
;	 6	Width in pixels, rounded up to 16 (-1 = from the header parser)
;	 8	Height in pixels (-1 = from the header parser)
;	10	Bits per pixel (-1 = from the header parser)
;	12	Loader
;	16	Header parser, or -1 for formats with a fixed size
;	20	Reserved

						; Unused
	dc.b	$00,$FF,$00,$FF,$00,$7F,$00,$7F,$00,$3F,$00,$3F,$00,$1F,$00,$1F
	dc.b	$00,$0F,$00,$0F,$00,$07,$00,$07,$00,$03,$00,$03,$00,$01,$00,$01
format_table:					; Picture formats, see the description above
	dc.b	$2E,$50,$49,$31,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	pi1_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$49,$32,$00,$00,$02,$80,$01,$90,$00,$02
	dc.l	pi2_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$49,$33,$00,$00,$02,$80,$01,$90,$00,$01
	dc.l	pi3_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$4E,$45,$4F,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	neo_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$44,$4F,$4F,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	doodle_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$4D,$55,$52,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	doodle_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$49,$4D,$47,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.l	img_load
	dc.l	img_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$52,$41,$57
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$00,$10
	dc.l	raw_load
	dc.l	raw_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$52,$41,$47
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.l	rag_load
	dc.l	rag_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$42,$4D,$50
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.l	bmp_load
	dc.l	bmp_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$50,$43,$33
	dc.b	$00,$00,$02,$80,$01,$90,$00,$01
	dc.l	pc3_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$43,$32,$00,$00,$02,$80,$01,$90,$00,$02
	dc.l	pc2_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$43,$31,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	pc1_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$41,$52,$54,$00,$00,$01,$40,$00,$C8,$00,$04
	dc.l	art_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$49,$46,$46,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.l	iff_load
	dc.l	iff_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$4D,$41,$43
	dc.b	$00,$00,$02,$40,$02,$D0,$00,$01
	dc.l	macpaint_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$4D,$50,$54,$00,$00,$02,$40,$02,$D0,$00,$01
	dc.l	macpaint_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$47,$49,$46,$00,$00,$FF,$FF,$FF,$FF,$00,$08
	dc.l	gif_load
	dc.l	gif_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$50,$49,$34
	dc.b	$00,$00,$01,$40,$00,$F0,$00,$08
	dc.l	pi4_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$49,$35,$00,$00,$02,$80,$01,$E0,$00,$08
	dc.l	pi5_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$50,$49,$39,$00,$00,$01,$40,$00,$F0,$00,$08
	dc.l	pi9_load
	dc.b	$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2E,$54,$52,$55,$00,$00,$FF,$FF,$FF,$FF,$00,$10
	dc.l	tru_load
	dc.l	tru_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2E,$54,$47,$41
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.l	tga_load
	dc.l	tga_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	".Q16",$00,$00,$FF,$FF,$FF,$FF,$FF,$FF	; Q16, added in v1.2
	dc.l	q16_load
	dc.l	q16_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00				; End of table
mode_offsets:					; Offset of the video mode for each depth in the video tables
	dc.b	$00,$00,$00,$00,$00,$60,$00,$00,$00,$C0,$00,$00,$00,$00,$00,$00
	dc.b	$01,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$01,$80
high_res:					; 1 = high resolution (640 wide), 0 = low
	dc.b	$00,$01
scroll_dx:					; Scroll speed (mouse and cursor keys), pixels
	dc.b	$00,$00
scroll_dy:
	dc.b	$00,$00
scroll_x:					; Top left of the visible part of the screen
	dc.b	$00,$00
scroll_y:
	dc.b	$00,$00
scroll_min_x:					; Scroll limits
	dc.b	$00,$00
scroll_min_y:
	dc.b	$00,$00
scroll_max_x:
	dc.b	$00,$00
scroll_max_y:
	dc.b	$00,$00
line_offset:					; Videl line offset for the screen width
	dc.b	$00,$00
vbl_line_offset:				; Line offset, fine scroll and screen address
	dc.b	$00,$00
vbl_hscroll:					; for the next VBL
	dc.b	$00,$00
vbl_screen:
	dc.b	$00
	dc.b	$00
	dc.b	$00
	dc.b	$00
video_saved:					; 1 when save_video has run
	dc.b	$00,$00
monitor:					; -1 = VGA, 1 = NTSC, 0 = PAL
	dc.b	$00,$00
greyscale:					; Bit 0 set: grey palette shown
	dc.b	$00
	dc.b	$00
name_bin:					; Files written by save_picture
	dc.b	"SAVEDPIC.BIN",$00
name_pal:
	dc.b	"SAVEDPIC.PAL",$00
name_txt:
	dc.b	"SAVEDPIC.TXT",$00
info_text:					; Text for SAVEDPIC.TXT
	dc.b	"0000 X "
info_height:
	dc.b	"0000 pixels, "
info_colours:
	dc.b	"000 colors."
picture_width:					; Real width of the picture in pixels
	dc.b	$00,$00
video_vga:					; Video modes, 48 bytes each, see set_video
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$00,$C6,$00,$8D,$00,$15,$02,$73
	dc.b	$00,$50,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$17,$00,$12,$00,$01,$02,$0A
	dc.b	$00,$09,$00,$11,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$17,$00,$12,$00,$01,$02,$0E
	dc.b	$00,$0D,$00,$11,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$C6,$00,$8D,$00,$15,$02,$8A
	dc.b	$00,$6B,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$00,$00,$C6,$00,$8D,$00,$15,$02,$A3
	dc.b	$00,$7C,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$10,$00,$C6,$00,$8D,$00,$15,$02,$9A
	dc.b	$00,$7B,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$00,$C6,$00,$8D,$00,$15,$02,$AB
	dc.b	$00,$84,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$C6,$00,$8D,$00,$15,$02,$AC
	dc.b	$00,$91,$00,$96,$00,$00,$00,$00,$04,$19,$03,$FF,$00,$3F,$00,$3F
	dc.b	$03,$FF,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
video_pal:					; and mode_offsets: 1 plane high resolution,
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$01,$FE,$01,$99,$00,$50,$03,$EF
	dc.b	$00,$A0,$01,$B2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2F,$00,$7E
	dc.b	$02,$0E,$02,$6B,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$3E,$00,$30,$00,$08,$02,$39
	dc.b	$00,$12,$00,$34,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2F,$00,$7F
	dc.b	$02,$0F,$02,$6B,$01,$81,$00,$00,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$3E,$00,$30,$00,$08,$00,$02
	dc.b	$00,$20,$00,$34,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2F,$00,$7E
	dc.b	$02,$0E,$02,$6B,$01,$81,$00,$06,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$FE,$00,$CB,$00,$27,$00,$0C
	dc.b	$00,$6D,$00,$D8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2F,$00,$7F
	dc.b	$02,$0F,$02,$6B,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$00,$01,$FE,$01,$99,$00,$50,$00,$4D
	dc.b	$00,$FE,$01,$B2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2F,$00,$7E
	dc.b	$02,$0E,$02,$6B,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$10,$00,$FE,$00,$CB,$00,$27,$00,$1C
	dc.b	$00,$7D,$00,$D8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2F,$00,$7F
	dc.b	$02,$0F,$02,$6B,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$01,$FE,$01,$99,$00,$50,$00,$5D
	dc.b	$01,$0E,$01,$B2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2F,$00,$7E
	dc.b	$02,$0E,$02,$6B,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$FE,$00,$CB,$00,$27,$00,$2E
	dc.b	$00,$8F,$00,$D8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2F,$00,$7F
	dc.b	$02,$0F,$02,$6B,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$02,$80,$00,$00,$01,$00,$01,$FE,$01,$99,$00,$50,$00,$71
	dc.b	$01,$22,$01,$B2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2F,$00,$7E
	dc.b	$02,$0E,$02,$6B,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
video_ntsc:					; then 2, 4, 8, 16 bits low and high (VGA: no 16 high)
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$01,$FF,$01,$97,$00,$50,$03,$F0
	dc.b	$00,$9F,$01,$B4,$00,$00,$00,$00,$02,$0C,$02,$01,$00,$16,$00,$4C
	dc.b	$01,$DC,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$3E,$00,$30,$00,$08,$02,$39
	dc.b	$00,$12,$00,$34,$00,$00,$00,$00,$02,$0D,$02,$01,$00,$16,$00,$4D
	dc.b	$01,$DD,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$3E,$00,$30,$00,$08,$00,$02
	dc.b	$00,$20,$00,$34,$00,$00,$00,$00,$02,$0C,$02,$01,$00,$16,$00,$4C
	dc.b	$01,$DC,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$FE,$00,$C9,$00,$27,$00,$0C
	dc.b	$00,$6D,$00,$D8,$00,$00,$00,$00,$02,$0D,$02,$01,$00,$16,$00,$4D
	dc.b	$01,$DD,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$00,$01,$FF,$01,$97,$00,$50,$00,$4D
	dc.b	$00,$FD,$01,$B4,$00,$00,$00,$00,$02,$0C,$02,$01,$00,$16,$00,$4C
	dc.b	$01,$DC,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$A0,$00,$00,$00,$10,$00,$FE,$00,$C9,$00,$27,$00,$1C
	dc.b	$00,$7D,$00,$D8,$00,$00,$00,$00,$02,$0D,$02,$01,$00,$16,$00,$4D
	dc.b	$01,$DD,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$01,$FF,$01,$97,$00,$50,$00,$5D
	dc.b	$01,$0D,$01,$B4,$00,$00,$00,$00,$02,$0C,$02,$01,$00,$16,$00,$4C
	dc.b	$01,$DC,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$FE,$00,$C9,$00,$27,$00,$2E
	dc.b	$00,$8F,$00,$D8,$00,$00,$00,$00,$02,$0D,$02,$01,$00,$16,$00,$4D
	dc.b	$01,$DD,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$02,$80,$00,$00,$01,$00,$01,$FF,$01,$97,$00,$50,$00,$71
	dc.b	$01,$21,$01,$B4,$00,$00,$00,$00,$02,$0C,$02,$01,$00,$16,$00,$4C
	dc.b	$01,$DC,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
file_buffer:					; The picture file
	dc.b	$00,$00,$00,$00
screen:						; The screen, aligned to a long word
	dc.b	$00
	dc.b	$00
	dc.b	$00
	dc.b	$00
palette:					; Picture palette, Falcon format: R, G, 0, B
	dc.b	$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
unused_tga_buffer:				; RLE Targa buffer in version 1.1, unused
	dc.b	$00,$00,$00,$00
	dc.l	palette
gif_pixels:					; Where gif_unpack writes the pixels
	dc.b	$00,$00,$00,$00
gif_info:					; Descriptors from gif_parse, +10 = image width
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00
line_routines:					; Line routine by number of planes - 1, see line_16bit
	dc.l	line_1plane
	dc.l	line_2planes
	dc.l	line_3planes
	dc.l	line_4planes
	dc.l	line_5planes
	dc.l	line_6planes
	dc.l	line_7planes
	dc.l	line_8planes
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.l	line_16bit
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.l	line_24bit
line_step:					; Bytes per screen line
	dc.b	$00,$00,$00,$00
line_dest:					; Screen line to write
	dc.b	$00,$00,$00,$00
line_source:					; Line to convert, the line buffer by default
	dc.l	line_buffer
plane_bytes:					; Bytes per line and plane
	dc.b	$00,$00,$00,$00
img_repeat:					; IMG vertical repeat count (byte at img_repeat+1)
	dc.b	$00
	dc.b	$00
img_repeat_line:				; IMG line to repeat
	dc.b	$00,$00,$00,$00
doodle_palette:					; Fixed palette for Doodle pictures, STE format
	dc.b	$0F,$FF,$0F,$00,$00,$F0,$0F,$F0,$00,$0F,$0F,$0F,$00,$FF,$0D,$DD
	dc.b	$04,$44,$05,$00,$00,$50,$05,$50,$00,$05,$05,$05,$00,$55,$00,$00
title_text:					; Printed at start
	dc.b	"The SHOWER picture-viewer v1.2.",$0A,$0D
	dc.b	"-------------------------------",$0A,$0D,$0A
	dc.b	"Functions & Controls",$0D,$0A,"--------------------",$0D,$0A
	dc.b	$0A,"Mouse &",$0D,$0A
	dc.b	"Cursor Keys          Scroll around large picture",$0D,$0A,$0A
	dc.b	"Space & Right",$0D,$0A,"Mousebutton          Quit",$0D,$0A,$0A
	dc.b	"Plus/minus & Left",$0D,$0A
	dc.b	"Mousebutton          Switch resolution",$0D,$0A,$0A
	dc.b	"F1                   Switch between Color/BW",$0D,$0A,$0A
	dc.b	"F2                   Switch between dark/bright frame",$0D,$0A
	dc.b	$0A,"Contr + Alt + F10    Save screen/color-dump",$0D,$0A,$0A
	dc.b	$0A,"Written by Blade of New Core in 100% assembler.",$0D,$0A
	dc.b	"GIF-Depacker by Sascha Springer.",$0D,$0A
	dc.b	"Q16 support added in 2026.",$0D,$0A,$00
	dc.b	$00

	SECTION BSS
border_colour:					; Colour around small pictures
	ds.b	2
darkest_colour:
	ds.b	2
brightest_colour:
	ds.b	2
screen_line_bytes:				; Bytes per screen line
	ds.b	2
picture_line_bytes:				; Bytes per picture line
	ds.b	2
border_top:					; Lines above the picture - 1, or -1
	ds.b	2
border_sides:					; Picture lines - 1, or -1 if no side borders
	ds.b	2
border_left:					; Words - 1 left of the picture
	ds.b	2
border_right:					; Words - 1 right of the picture
	ds.b	2
border_bottom:					; Lines below the picture - 1, or -1
	ds.b	2
video_table:					; video_vga, video_pal or video_ntsc (+1 unused byte)
	ds.b	5
mouse_buttons:					; Header byte of the last mouse packet
	ds.b	1
cmdline:					; Command line: the picture file name
	ds.b	4
file_handle:
	ds.b	2
file_size:
	ds.b	4
file_extension:					; For example ".GIF"
	ds.b	4
format:						; Format table entry of the picture
	ds.b	4
old_hscroll:					; Saved video state
	ds.b	2
old_line_offset:
	ds.b	2
old_mousevec:
	ds.b	4
kbdvecs:					; From Kbdvbase
	ds.b	4
old_physbase:
	ds.b	1
	ds.b	1
	ds.b	1
	ds.b	1
old_palette:
	ds.b	1024
screen_size:					; In bytes
	ds.b	4
screen_block:					; Screen memory block for Mfree
	ds.b	4
screen_width:					; Screen size: at least 640 x 480
	ds.b	2
screen_height:
	ds.b	2
screen_planes:					; 1, 2, 4, 8 or 16
	ds.b	2
old_vbl:
	ds.b	4
dta:						; For Fsfirst
	ds.b	44
old_video:					; Videl registers saved by save_video
	ds.b	44
old_shiftmode:					; Must follow old_video, see restore_video
	ds.b	4
line_buffer:					; One unpacked line, also the LZW stack
	ds.b	4096
gif_parsed:					; gif_parse's output
	ds.b	2048
picture_start:					; Screen address of the picture, see picture_position
	ds.b	4
gif_info_ptr:					; Where gif_unpack copies the descriptors
	ds.b	4
work_tables:					; LZW string table, then the c2p tables
	ds.b	2048
	ds.b	14336
iff_bmhd:					; Address of the BMHD chunk
	ds.b	4
c2p_source:					; c2p_line parameters
	ds.b	4
c2p_dest:
	ds.b	4
c2p_blocks:
	ds.b	2
raw_pixels:					; POV raw pixels (v1.2: was 2 bytes)
	ds.b	4
img_line_bytes:					; Bytes per IMG line, all planes
	ds.b	4
pal_source:					; st_palette parameters
	ds.b	4
pal_dest:
	ds.b	4
pal_count:
	ds.b	2
put_source:					; put_320x200 parameters
	ds.b	4
put_dest:
	ds.b	4
tga_buffer:					; v1.2: RLE Targa buffer
	ds.b	4
bmp_top_down:					; v1.2: BMP stored top-down
	ds.b	2
gif_interlaced:					; v1.2: GIF is interlaced
	ds.b	2
gif_buffer:					; v1.2: buffer for interlaced GIF
	ds.b	4
q16_pixel_bytes:
	ds.b	4
q16_alpha_bytes:
	ds.b	4
q16_pixels_count:
	ds.b	4
q16_table:					; q16_table, q16_pixels and q16_alpha
	ds.b	4				; must stay together, see q16_free.
q16_pixels:
	ds.b	4
q16_alpha:
	ds.b	4
