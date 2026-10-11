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
	opt		d-,x-
	opt		p=68020
	section	text

;	Program start. Prints the title, loads the picture named on the command
;	line, saves the video mode and looks up the picture's extension in
;	format_table.

start:
	move.l	#title_text,-(a7)					; str - string pointer → title_text
	move.w	#9,-(a7)							; Cconws - write a NUL-terminated string to the console
	trap	#1									; GEMDOS #9 (Cconws)
	addq.l	#6,a7

	movea.l	4(a7),a0							; TOS basepage pointer from stack
	moveq	#0,d0
	move.b	$80(a0),d0							; basepage.p_cmdlin (command line length)
	lea		$81(a0),a0
	clr.b	(a0,d0.w)
.skip_spaces:
	cmpi.b	#32,(a0)
	bne.s	.cmdline_ok
	addq.l	#1,a0
	bra.s	.skip_spaces
.cmdline_ok:
	move.l	a0,(cmdline).l						; Picture file name
	movea.l	4(a7),a5							; TOS basepage pointer from stack
	move.l	$c(a5),d0							; basepage.p_tlen (text segment size)
	add.l	$14(a5),d0							; + basepage.p_dlen (data segment size)
	add.l	$1c(a5),d0							; + basepage.p_blen (bss segment size)
	addi.l	#$1100,d0							; + stack reservation (4352 bytes)
	move.l	a5,d1
	add.l	d0,d1
	andi.l	#-2,d1								; align stack to even address
	movea.l	d1,a7								; relocate stack pointer

	move.l	d0,-(a7)							; newsiz - new size in bytes
	move.l	a5,-(a7)							; block - start of the block to shrink
	move.w	d0,-(a7)							; zero - reserved, must be 0
	move.w	#74,-(a7)							; Mshrink - shrink a memory block
	trap	#1									; GEMDOS #74 (Mshrink)
	lea		$c(a7),a7							; restore stack frame

	move.l	#dta,-(a7)							; dta - DTA buffer pointer → dta
	move.w	#26,-(a7)							; Fsetdta - set the disk transfer address
	trap	#1									; GEMDOS #26 (Fsetdta)
	addq.l	#6,a7

	move.w	#7,-(a7)							; attr - attributes to match: read-only|hidden|system
	move.l	(cmdline).l,-(a7)					; fspec - search path pointer, wildcards allowed
	move.w	#78,-(a7)							; Fsfirst - find the first matching file
	trap	#1									; GEMDOS #78 (Fsfirst)
	addq.l	#8,a7
	tst.w	d0

	bne.w	exit
	lea		dta(pc),a0
	move.l	$1a(a0),(file_size).l				; File size from the DTA
	lea		$2c(a0),a0							; End of the file name in the DTA
.find_extension:
	subq.l	#1,a0
	cmpi.b	#46,(a0)
	bne.s	.find_extension
	move.l	(a0),(file_extension).l

	move.l	(file_size).l,-(a7)					; number - bytes to allocate
	move.w	#72,-(a7)							; Malloc - allocate memory
	trap	#1									; GEMDOS #72 (Malloc)
	addq.l	#6,a7

	beq.w	exit
	move.l	d0,(file_buffer).l

	move.w	#0,-(a7)							; mode - access mode: read-only
	move.l	(cmdline).l,-(a7)					; fname - file name pointer
	move.w	#61,-(a7)							; Fopen - open an existing file
	trap	#1									; GEMDOS #61 (Fopen)
	addq.l	#8,a7
	tst.w	d0

	bmi.w	exit
	move.w	d0,(file_handle).l					; store handle - file handle, or negative error code

	move.l	file_buffer(pc),-(a7)				; buf - transfer buffer pointer
	move.l	file_size(pc),-(a7)					; count - byte count
	move.w	file_handle(pc),-(a7)				; handle - file handle
	move.w	#63,-(a7)							; Fread - read from a file handle
	trap	#1									; GEMDOS #63 (Fread)
	lea		$c(a7),a7

	move.w	(file_handle).l,-(a7)				; handle - file handle
	move.w	#62,-(a7)							; Fclose - close a file handle
	trap	#1									; GEMDOS #62 (Fclose)
	addq.l	#4,a7
	tst.w	d0

	bmi.w	exit

	move.l	#0,-(a7)							; stack - 0 = use the user stack
	move.w	#32,-(a7)							; Super - enter or query supervisor mode
	trap	#1									; GEMDOS #32 (Super)
	addq.l	#6,a7

	move.w	($ffff8264).w,(old_hscroll).l		; store hscroll_noprefetch [STE/Falcon]
	move.w	($ffff820e).w,(old_line_offset).l	; store vid_lineoffset [Falcon]
	bsr.w	save_video

	move.w	#$ffff,-(a7)						; modecode - video mode code
	move.w	#88,-(a7)							; Vsetmode - select a Falcon video mode
	trap	#14									; XBIOS #88 (Vsetmode)
	addq.l	#4,a7
	btst.l	#7,d0

	beq.s	.not_st_compatible
	clr.w	(skip_shiftmode).l
.not_st_compatible:
	move.w	d0,d1
	andi.w	#7,d1
	cmp.w	#1,d1
	bne.s	.not_2_planes
	clr.w	(skip_shiftmode).l
.not_2_planes:
	move.w	d0,d1
	andi.w	#$87,d1
	cmp.w	#$80,d1
	bne.s	.check_monitor
	move.w	#1,(skip_shiftmode).l
.check_monitor:
	btst.l	#4,d0
	beq.s	.not_vga
	move.w	#$ffff,(monitor).l
	move.l	#video_vga,(video_table).l
	bra.s	.save_physbase
.not_vga:
	btst.l	#5,d0
	bne.s	.pal
	move.w	#1,(monitor).l
	move.l	#video_ntsc,(video_table).l
	bra.s	.save_physbase
.pal:
	move.l	#video_pal,(video_table).l

.save_physbase:
	move.w	#2,-(a7)							; Physbase - physical screen base address
	trap	#14									; XBIOS #2 (Physbase)
	addq.l	#2,a7
	move.l	d0,(old_physbase).l					; store physbase - physical screen base address

	lea		format_table-32(pc),a0				; The loop starts by adding 32.
	move.l	file_extension(pc),d0
	andi.l	#$ffdfdfdf,d0
.find_format:
	lea		$20(a0),a0
	move.l	(a0),d1
	beq.s	exit
	andi.l	#$ffdfdfdf,d1
	cmp.l	d0,d1
	bne.s	.find_format
	move.l	a0,(format).l
	tst.w	4(a0)
	beq.w	setup_screen

;	Frees the memory, restores the screen and the video mode and terminates.
;	Also the error exit: loaders jump here when a picture can't be shown.

exit:
	tst.l	(file_buffer).l
	beq.s	.free_screen

	move.l	(file_buffer).l,-(a7)				; block - address of the block to free
	move.w	#73,-(a7)							; Mfree - free memory
	trap	#1									; GEMDOS #73 (Mfree)
	addq.l	#6,a7

.free_screen:
	tst.l	(screen_block).l
	beq.s	.restore_screen

	move.l	(screen_block).l,-(a7)				; block - address of the block to free
	move.w	#73,-(a7)							; Mfree - free memory
	trap	#1									; GEMDOS #73 (Mfree)
	addq.l	#6,a7

.restore_screen:
	tst.l	(old_physbase).l
	beq.s	.restore_video
	move.b	(old_physbase+1).l,($ffff8201).w	; write vidbase_hi
	move.b	(old_physbase+2).l,($ffff8203).w	; write vidbase_mid
	move.b	(old_physbase+3).l,($ffff820d).w	; write vidbase_lo [STE+]
.restore_video:
	tst.w	(video_saved).l
	beq.s	.terminate
	lea		old_video(pc),a6
	bsr.w	restore_video
	move.w	old_hscroll(pc),($ffff8264).w		; write hscroll_noprefetch [STE/Falcon]
	move.w	old_line_offset(pc),($ffff820e).w	; write vid_lineoffset [Falcon]
	movea.l	kbdvecs(pc),a0
	move.l	old_mousevec(pc),$10(a0)

.terminate:
	clr.w	-(a7)								; Pterm0 - terminate with exit code 0
	trap	#1									; GEMDOS #0 (Pterm0)

;	Sets up a screen of at least 640 x 480 pixels for the picture (a0 = format
;	table entry), saves the palette, loads the picture, sets the video mode and
;	palette and runs the main loop, which reads the keyboard and mouse until
;	the user quits.

setup_screen:
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	move.w	6(a0),d0
	bmi.w	query_header
	move.w	8(a0),d1
	bmi.w	query_header
	move.w	$a(a0),d2
	bmi.w	query_header
	beq.w	exit
	cmp.w	#$280,d0
	bge.s	.width_ok
	move.w	#$280,d0
.width_ok:
	cmp.w	#$1e0,d1
	bge.s	.height_ok
	move.w	#$1e0,d1
.height_ok:
	move.w	d0,(screen_width).l
	move.w	d1,(screen_height).l
	move.w	d2,(screen_planes).l
	mulu.w	d1,d0
	mulu.l	d2,d0
	lsr.l	#3,d0
	addq.l	#4,d0
	move.l	d0,(screen_size).l

	move.l	d0,-(a7)							; number - bytes to allocate
	move.w	#72,-(a7)							; Malloc - allocate memory
	trap	#1									; GEMDOS #72 (Malloc)
	addq.l	#6,a7
	tst.l	d0

	beq.w	exit
	move.l	d0,(screen_block).l
	addq.l	#4,d0
	andi.l	#-4,d0
	move.l	d0,(screen).l
	movea.l	format(pc),a0
	cmpi.w	#2,$a(a0)
	beq.s	.save_st_palette
	cmpi.w	#16,$a(a0)
	beq.s	.load_picture

	move.w	#37,-(a7)							; Vsync - wait for the next vertical blank
	trap	#14									; XBIOS #37 (Vsync)
	addq.l	#2,a7

	lea		old_palette(pc),a0
	lea		($ffff9800).w,a1					; videl_palette[0] [Falcon]
	move.l	#$ff,d0
.save_falcon_palette:
	move.l	(a1)+,(a0)+
	dbra	d0,.save_falcon_palette
	bra.s	.load_picture
.save_st_palette:
	movem.l	($ffff8240).w,d0-d7					; read palette[0..15]
	movem.l	d0-d7,(old_palette).l
.load_picture:
	movea.l	format(pc),a0
	movea.l	$c(a0),a0
	jsr		(a0)
	bsr.w	find_border_colours
	move.w	darkest_colour(pc),(border_colour).l
	bsr.w	fill_border

	move.w	#37,-(a7)							; Vsync - wait for the next vertical blank
	trap	#14									; XBIOS #37 (Vsync)
	addq.l	#2,a7

	move.b	(screen+1).l,($ffff8201).w			; write vidbase_hi
	move.b	(screen+2).l,($ffff8203).w			; write vidbase_mid
	move.b	(screen+3).l,($ffff820d).w			; write vidbase_lo [STE+]
	bsr.w	zoom_out
	movea.l	format(pc),a0
	cmpi.w	#2,$a(a0)
	beq.s	.set_st_palette
	cmpi.w	#16,$a(a0)
	beq.s	.install_handlers
	lea		palette(pc),a0
	lea		($ffff9800).w,a1					; videl_palette[0] [Falcon]
	moveq	#1,d0
	move.w	screen_planes(pc),d1
	lsl.w	d1,d0
	subq.w	#1,d0
.set_falcon_palette:
	move.l	(a0)+,(a1)+
	dbra	d0,.set_falcon_palette
	bra.s	.install_handlers
.set_st_palette:
	lea		palette(pc),a0
	lea		($ffff8240).w,a1					; palette[0]
	moveq	#3,d0
.st_colour:
	moveq	#0,d3
	moveq	#0,d1
	move.b	(a0)+,d1
	move.l	d1,d2
	andi.b	#224,d2
	lsl.w	#3,d2
	or.w	d2,d3
	andi.b	#16,d1
	lsl.w	#7,d1
	or.w	d1,d3
	moveq	#0,d1
	move.b	(a0)+,d1
	move.l	d1,d2
	andi.b	#224,d2
	lsr.w	#1,d2
	or.w	d2,d3
	andi.b	#16,d1
	lsl.w	#3,d1
	or.w	d1,d3
	moveq	#0,d1
	addq.l	#1,a0
	move.b	(a0)+,d1
	move.l	d1,d2
	andi.b	#224,d2
	lsr.w	#5,d2
	or.w	d2,d3
	andi.b	#16,d1
	lsr.w	#1,d1
	or.w	d1,d3
	move.w	d3,(a1)+
	dbra	d0,.st_colour

.install_handlers:
	move.w	#34,-(a7)							; Kbdvbase - address of the IKBD vector table
	trap	#14									; XBIOS #34 (Kbdvbase)
	addq.l	#2,a7
	movea.l	d0,a0

	move.l	$10(a0),(old_mousevec).l
	move.l	a0,(kbdvecs).l
	move.l	#mouse_handler,$10(a0)
	move.l	($70).w,(old_vbl).l					; store vbl (vector)
	move.l	#vbl_handler,($70).w				; set vbl.handler
.main_loop:
	cmpi.b	#249,(mouse_buttons).l				; Right button
	beq.w	.quit
	cmpi.b	#250,(mouse_buttons).l				; Left button
	bne.s	.check_key
.wait_release:
	cmpi.b	#250,(mouse_buttons).l
	beq.s	.wait_release
	bsr.w	toggle_zoom

.check_key:
	move.w	#11,-(a7)							; Cconis - console input status
	trap	#1									; GEMDOS #11 (Cconis)
	addq.l	#2,a7
	tst.w	d0

	beq.s	.main_loop

	move.w	#7,-(a7)							; Crawcin - raw console input, no echo
	trap	#1									; GEMDOS #7 (Crawcin)
	addq.l	#2,a7

	swap	d0									; Scan code
	cmp.b	#78,d0								; Keypad +
	bne.s	.not_plus
	bsr.w	zoom_in
	bra.s	.main_loop
.not_plus:
	cmp.b	#74,d0								; Keypad -
	bne.s	.not_minus
	bsr.w	zoom_out
	bra.s	.main_loop
.not_minus:
	cmp.b	#72,d0								; Up
	bne.s	.not_up
	bsr.w	scroll_up
	bra.s	.main_loop
.not_up:
	cmp.b	#75,d0								; Left
	bne.s	.not_left
	bsr.w	scroll_left
	bra.s	.main_loop
.not_left:
	cmp.b	#77,d0								; Right
	bne.s	.not_right
	bsr.w	scroll_right
	bra.s	.main_loop
.not_right:
	cmp.b	#80,d0								; Down
	bne.s	.not_down
	bsr.w	scroll_down
	bra.w	.main_loop
.not_down:
	cmp.b	#59,d0								; F1
	bne.s	.not_f1
	bsr.w	toggle_greyscale
	bra.w	.main_loop
.not_f1:
	cmp.b	#68,d0								; F10
	bne.s	.not_f10

	move.w	#$ffff,-(a7)						; mode: query, do not set - new shift state, or -1 to que…
	move.w	#11,-(a7)							; Kbshift - read or set the keyboard shift state
	trap	#13									; BIOS #11 (Kbshift)
	addq.l	#4,a7
	btst.l	#2,d0								; Control

	beq.w	.main_loop
	btst.l	#3,d0								; Alternate
	beq.w	.main_loop
	bsr.w	save_picture
	bra.w	.main_loop
.not_f10:
	cmp.b	#60,d0								; F2
	bne.s	.not_f2
	bsr.w	toggle_border
	bra.w	.main_loop
.not_f2:
	cmp.b	#57,d0								; Space
	bne.s	.not_space
	bra.s	.quit
.not_space:
	cmp.b	#1,d0								; Esc
	bne.s	.not_esc
	bra.s	.quit
.not_esc:
	cmp.b	#114,d0								; Keypad Enter
	bne.s	.no_key
	bra.s	.quit
.no_key:
	bra.w	.main_loop
.quit:
	move.l	old_vbl(pc),($70).w					; write vbl (vector)
	movea.l	format(pc),a0
	cmpi.w	#2,$a(a0)
	beq.s	.restore_st_palette
	cmpi.w	#16,$a(a0)
	beq.w	exit
	lea		old_palette(pc),a0
	lea		($ffff9800).w,a1					; videl_palette[0] [Falcon]
	move.l	#$ff,d0
.restore_falcon_palette:
	move.l	(a0)+,(a1)+
	dbra	d0,.restore_falcon_palette
	bra.w	exit
.restore_st_palette:
	movem.l	old_palette(pc),d0-d7
	movem.l	d0-d7,($ffff8240).w					; write palette[0..15]
	bra.w	exit

;	Formats without a fixed size: calls the header parser, which fills in the
;	width, height and depth of the format table entry, and sets up the screen.

query_header:
	movea.l	$10(a0),a1
	tst.l	a1
	bmi.w	exit
	jsr		(a1)
	movea.l	format(pc),a0
	bra.w	setup_screen

;	F1: switches between the picture's colours and grey.

toggle_greyscale:
	cmpi.w	#16,(screen_planes).l
	beq.s	.done
	bchg.b	#0,(greyscale+1).l
	lea		palette(pc),a0
	lea		($ffff9800).w,a1					; videl_palette[0] [Falcon]
	moveq	#1,d0
	move.w	screen_planes(pc),d1
	lsl.w	d1,d0
	subq.w	#1,d0
	tst.w	(greyscale).l
	beq.s	.colour
	moveq	#0,d1
	moveq	#0,d2
.grey:
	moveq	#0,d3
	move.b	(a0)+,d1
	move.b	(a0)+,d2
	addq.l	#1,a0
	move.b	(a0)+,d3
	add.w	d1,d3
	add.w	d2,d3
	divu.w	#3,d3
	move.b	d3,(a1)+
	move.b	d3,(a1)+
	addq.l	#1,a1
	move.b	d3,(a1)+
	dbra	d0,.grey
	rts

.colour:
	move.l	(a0)+,(a1)+
	dbra	d0,.colour
.done:
	rts

;	F2: switches the border around small pictures between the darkest and the
;	brightest colour of the palette.

toggle_border:
	lea		border_colour(pc),a0
	move.w	(a0),d0
	cmp.w	darkest_colour(pc),d0
	beq.s	.brightest
	move.w	darkest_colour(pc),(a0)
	bra.s	.fill
.brightest:
	move.w	brightest_colour(pc),(a0)
.fill:
	bra.w	fill_border

;	Left mouse button: switches resolution.

toggle_zoom:
	tst.w	(high_res).l
	beq.w	zoom_out
	bra.w	zoom_in

;	Plus: low resolution (320 pixels wide), which shows the picture with
;	double sized pixels. Sets the scroll limits.

zoom_in:
	cmpi.w	#1,(screen_planes).l
	beq.w	zoom_out
	moveq	#0,d1
	movea.l	format(pc),a0
	move.w	6(a0),d0
	cmp.w	#$280,d0
	bge.s	.min_x
	cmp.w	#$140,d0
	bge.s	.width_320
	move.w	#$140,d0
.width_320:
	move.w	#$280,d1
	sub.w	d0,d1
	lsr.w	#1,d1
	andi.w	#$fff0,d1
.min_x:
	move.w	d1,(scroll_min_x).l
	move.w	#$c8,d2
	tst.w	(monitor).l
	bpl.s	.not_vga
	addi.w	#40,d2
.not_vga:
	moveq	#0,d1
	move.w	8(a0),d0
	cmp.w	#$1e0,d0
	bge.s	.min_y
	cmp.w	d2,d0
	bge.s	.height_ok
	move.w	d2,d0
.height_ok:
	move.w	#$1e0,d1
	sub.w	d0,d1
	lsr.w	#1,d1
.min_y:
	move.w	d1,(scroll_min_y).l
	move.w	6(a0),d0
	cmp.w	#$140,d0
	bge.s	.max_x
	move.w	#$140,d0
.max_x:
	subi.w	#$140,d0
	add.w	(scroll_min_x).l,d0
	move.w	d0,(scroll_max_x).l
	move.w	8(a0),d0
	cmp.w	d2,d0
	bge.s	.max_y
	move.w	d2,d0
.max_y:
	sub.w	d2,d0
	add.w	(scroll_min_y).l,d0
	move.w	d0,(scroll_max_y).l
	clr.w	(high_res).l
	movea.l	video_table(pc),a0
	move.w	screen_planes(pc),d1
	lea		mode_offsets(pc),a1
	move.w	(a1,d1.w*2),d1
	lea		-$30(a0,d1.w),a6
	bsr.w	set_video
	moveq	#0,d0
	move.w	screen_width(pc),d0
	lsr.w	#4,d0
	subi.w	#20,d0
	mulu.w	screen_planes(pc),d0
	move.w	d0,(line_offset).l
	move.w	d0,($ffff820e).w					; write vid_lineoffset [Falcon]
	rts

;	Minus: high resolution (640 pixels wide). Sets the scroll limits.

zoom_out:
	clr.w	(scroll_min_x).l
	clr.w	(scroll_min_y).l
	movea.l	format(pc),a0
	tst.w	(monitor).l
	bmi.s	.max_x
	cmpi.w	#$1e0,8(a0)
	bge.s	.max_x
	move.w	#$1e0,d0
	sub.w	8(a0),d0
	lsr.w	#1,d0
	cmp.w	#40,d0
	ble.s	.top_ok
	moveq	#40,d0
.top_ok:
	move.w	d0,(scroll_min_y).l
.max_x:
	move.w	screen_width(pc),d0
	subi.w	#$280,d0
	move.w	d0,(scroll_max_x).l
	move.w	#$190,d2
	tst.w	(monitor).l
	bpl.s	.not_vga
	addi.w	#80,d2
.not_vga:
	move.w	8(a0),d0
	cmp.w	d2,d0
	bge.s	.tall
	move.w	scroll_min_y(pc),(scroll_max_y).l
	bra.s	.set_mode
.tall:
	sub.w	d2,d0
	move.w	d0,(scroll_max_y).l
.set_mode:
	move.w	#1,(high_res).l
	movea.l	video_table(pc),a0
	move.w	screen_planes(pc),d1
	lea		mode_offsets(pc),a1
	move.w	(a1,d1.w*2),d1
	lea		(a0,d1.w),a6
	bsr.w	set_video
	cmpi.w	#16,(screen_planes).l
	bne.s	.line_offset
	tst.w	(monitor).l
	bmi.w	zoom_in
.line_offset:
	moveq	#0,d0
	move.w	screen_width(pc),d0
	lsr.w	#4,d0
	subi.w	#40,d0
	mulu.w	screen_planes(pc),d0
	move.w	d0,(line_offset).l
	move.w	d0,($ffff820e).w					; write vid_lineoffset [Falcon]
	rts

;	Cursor keys: scroll 4 pixels.

scroll_up:
	subi.w	#4,(scroll_dy).l
	rts

scroll_down:
	addi.w	#4,(scroll_dy).l
	rts

scroll_left:
	subi.w	#4,(scroll_dx).l
	rts

scroll_right:
	addi.w	#4,(scroll_dx).l
	rts

;	Saves the Videl registers and the ST shift mode in old_video.

save_video:
	move.l	($ffff820e).w,d0					; read vid_lineoffset [Falcon]
	move.l	($ffff8264).w,d1					; read hscroll_noprefetch [STE/Falcon]
	movem.l	($ffff8282).w,d2-d5					; read videl_hht [Falcon]
	movem.l	($ffff82a2).w,d6-d7/a0				; read videl_vft [Falcon]
	movea.l	($ffff82c0).w,a1					; read videl_vco [Falcon]
	movea.w	($ffff820a).w,a2					; read syncmode
	movem.l	d0-d7/a0-a2,(old_video).l
	move.l	($ffff8260).w,(old_shiftmode).l		; store shiftmode
	move.w	#1,(video_saved).l
	rts

;	Restores the video registers saved by save_video (a6 = old_video). The ST
;	shift mode is written too, unless skip_shiftmode is set.

restore_video:
	move.w	#37,-(a7)							; Vsync - wait for the next vertical blank
	trap	#14									; XBIOS #37 (Vsync)
	addq.l	#2,a7

	movem.l	(a6)+,d0-d7/a0-a2
	move.l	d0,($ffff820e).w					; write vid_lineoffset [Falcon]
	move.l	d1,($ffff8264).w					; write hscroll_noprefetch [STE/Falcon]
	movem.l	d2-d5,($ffff8282).w					; write videl_hht [Falcon]
	movem.l	d6-d7/a0,($ffff82a2).w				; write videl_vft [Falcon]
	move.l	a1,($ffff82c0).w					; write videl_vco [Falcon]
	move.w	a2,($ffff820a).w					; write syncmode
	move.w	(a6)+,d1
	tst.w	(skip_shiftmode).l
	beq.s	write_shiftmode
	rts

;	Sets a video mode from a 48-byte entry of a video table (a6): the Videl
;	registers, then the ST shift mode if the entry has one.

set_video:
	move.w	#37,-(a7)							; Vsync - wait for the next vertical blank
	trap	#14									; XBIOS #37 (Vsync)
	addq.l	#2,a7

	movem.l	(a6)+,d0-d7/a0-a2
	move.l	d0,($ffff820e).w					; write vid_lineoffset [Falcon]
	move.l	d1,($ffff8264).w					; write hscroll_noprefetch [STE/Falcon]
	movem.l	d2-d5,($ffff8282).w					; write videl_hht [Falcon]
	movem.l	d6-d7/a0,($ffff82a2).w				; write videl_vft [Falcon]
	move.l	a1,($ffff82c0).w					; write videl_vco [Falcon]
	move.w	a2,($ffff820a).w					; write syncmode
	move.w	(a6)+,d1
	bne.s	write_shiftmode
	rts

;	Writes the ST shift mode (d1), then the Videl registers again, as writing
;	the shift mode changes them.

write_shiftmode:
	move.w	d1,($ffff8260).w					; write shiftmode
	move.l	d0,($ffff820e).w					; write vid_lineoffset [Falcon]
	movem.l	d2-d5,($ffff8282).w					; write videl_hht [Falcon]
	movem.l	d6-d7/a0,($ffff82a2).w				; write videl_vft [Falcon]
	move.l	a1,($ffff82c0).w					; write videl_vco [Falcon]
	move.w	a2,($ffff820a).w					; write syncmode
	rts

;	Writes d0 as d1 decimal digits ending at a0 + d1.

format_number:
	lea		(a0,d1.w),a0
	subq.w	#1,d1
.digit:
	divu.w	#10,d0
	swap	d0
	addi.w	#48,d0
	move.b	d0,-(a0)
	clr.w	d0
	swap	d0
	dbra	d1,.digit
	rts

;	Ctrl+Alt+F10: saves the picture's size as text in SAVEDPIC.TXT, the
;	palette in SAVEDPIC.PAL and the screen data in SAVEDPIC.BIN.

save_picture:
	lea		info_text(pc),a0
	movea.l	format(pc),a1
	moveq	#0,d0
	move.w	6(a1),d0
	move.w	#4,d1
	bsr.s	format_number
	lea		info_height(pc),a0
	moveq	#0,d0
	move.w	8(a1),d0
	move.w	#4,d1
	bsr.s	format_number
	moveq	#1,d0
	move.w	$a(a1),d1
	lsl.l	d1,d0
	cmp.l	#$10000,d0
	beq.s	.true_color
	move.w	#3,d1
	lea		info_colours(pc),a0
	bsr.s	format_number
	bra.s	.write_info
.true_color:
	lea		info_colours(pc),a0
	move.l	#'True',(a0)
	move.w	#$2e20,9(a0)

.write_info:
	move.w	#0,-(a7)							; attr - file attributes (normal)
	move.l	#name_txt,-(a7)						; fname "SAVEDPIC.TXT"
	move.w	#60,-(a7)							; Fcreate - create and open a file
	trap	#1									; GEMDOS #60 (Fcreate)
	addq.l	#8,a7
	move.l	d0,d6

	move.l	#info_text,-(a7)					; buf "0000 X 0000 pixels, 000 colors."
	move.l	#31,-(a7)							; count - byte count
	move.w	d6,-(a7)							; handle - file handle
	move.w	#64,-(a7)							; Fwrite - write to a file handle
	trap	#1									; GEMDOS #64 (Fwrite)
	lea		$c(a7),a7

	move.w	d6,-(a7)							; handle - file handle
	move.w	#62,-(a7)							; Fclose - close a file handle
	trap	#1									; GEMDOS #62 (Fclose)
	addq.l	#4,a7

	moveq	#1,d7
	move.w	screen_planes(pc),d0
	cmp.w	#16,d0
	beq.s	.save_pixels
	lsl.w	d0,d7
	lsl.w	#2,d7

	move.w	#0,-(a7)							; attr - file attributes (normal)
	move.l	#name_pal,-(a7)						; fname "SAVEDPIC.PAL"
	move.w	#60,-(a7)							; Fcreate - create and open a file
	trap	#1									; GEMDOS #60 (Fcreate)
	addq.l	#8,a7
	move.l	d0,d6

	move.l	#palette,-(a7)						; buf - transfer buffer pointer → palette
	move.l	d7,-(a7)							; count - byte count
	move.w	d6,-(a7)							; handle - file handle
	move.w	#64,-(a7)							; Fwrite - write to a file handle
	trap	#1									; GEMDOS #64 (Fwrite)
	lea		$c(a7),a7

	move.w	d6,-(a7)							; handle - file handle
	move.w	#62,-(a7)							; Fclose - close a file handle
	trap	#1									; GEMDOS #62 (Fclose)
	addq.l	#4,a7

.save_pixels:
	movea.l	format(pc),a0
	move.w	6(a0),d7
	cmp.w	#$280,d7
	blt.s	.narrow
	lsr.w	#3,d7
	mulu.w	$a(a0),d7
	mulu.w	8(a0),d7
	bsr.w	picture_position

	move.w	#0,-(a7)							; attr - file attributes (normal)
	move.l	#name_bin,-(a7)						; fname "SAVEDPIC.BIN"
	move.w	#60,-(a7)							; Fcreate - create and open a file
	trap	#1									; GEMDOS #60 (Fcreate)
	addq.l	#8,a7
	move.l	d0,d6

	move.l	picture_start(pc),-(a7)				; buf - transfer buffer pointer
	move.l	d7,-(a7)							; count - byte count
	move.w	d6,-(a7)							; handle - file handle
	move.w	#64,-(a7)							; Fwrite - write to a file handle
	trap	#1									; GEMDOS #64 (Fwrite)
	lea		$c(a7),a7

	move.w	d6,-(a7)							; handle - file handle
	move.w	#62,-(a7)							; Fclose - close a file handle
	trap	#1									; GEMDOS #62 (Fclose)
	addq.l	#4,a7

	rts

.narrow:
	lsr.w	#3,d7
	mulu.w	$a(a0),d7
	mulu.w	8(a0),d7

	move.l	d7,-(a7)							; number - bytes to allocate
	move.w	#72,-(a7)							; Malloc - allocate memory
	trap	#1									; GEMDOS #72 (Malloc)
	addq.l	#6,a7
	tst.l	d0

	beq.s	.done
	movea.l	d0,a6
	movea.l	d0,a2
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	movea.l	format(pc),a0
	move.w	6(a0),d1
	lsr.w	#4,d1
	mulu.w	$a(a0),d1
	subq.w	#1,d1
	move.w	#$280,d3
	sub.w	6(a0),d3
	lsr.w	#3,d3
	mulu.w	screen_planes(pc),d3
	move.w	8(a0),d0
	subq.w	#1,d0
.line:
	move.l	d1,d2
.word:
	move.w	(a1)+,(a2)+
	dbra	d2,.word
	adda.l	d3,a1
	dbra	d0,.line

	move.w	#0,-(a7)							; attr - file attributes (normal)
	move.l	#name_bin,-(a7)						; fname "SAVEDPIC.BIN"
	move.w	#60,-(a7)							; Fcreate - create and open a file
	trap	#1									; GEMDOS #60 (Fcreate)
	addq.l	#8,a7
	move.l	d0,d6

	move.l	a6,-(a7)							; buf - transfer buffer pointer
	move.l	d7,-(a7)							; count - byte count
	move.w	d6,-(a7)							; handle - file handle
	move.w	#64,-(a7)							; Fwrite - write to a file handle
	trap	#1									; GEMDOS #64 (Fwrite)
	lea		$c(a7),a7

	move.w	d6,-(a7)							; handle - file handle
	move.w	#62,-(a7)							; Fclose - close a file handle
	trap	#1									; GEMDOS #62 (Fclose)
	addq.l	#4,a7

	move.l	a6,-(a7)							; block - address of the block to free
	move.w	#73,-(a7)							; Mfree - free memory
	trap	#1									; GEMDOS #73 (Mfree)
	addq.l	#6,a7

.done:
	rts

;	VBL interrupt. Sets the screen address, line offset and fine scroll
;	calculated in the previous frame, then moves the visible part of the
;	screen by the scroll speed (mouse and cursor keys) within the scroll limits
;	and calculates them for the next frame. Continues in the old VBL handler.

vbl_handler:
	move.w	#$2700,sr
	tst.w	(vbl_ready).l
	beq.w	.busy
	clr.w	(vbl_ready).l
	move.b	vbl_screen+1(pc),($ffff8201).w		; write vidbase_hi
	move.b	vbl_screen+2(pc),($ffff8203).w		; write vidbase_mid
	move.b	vbl_screen+3(pc),($ffff820d).w		; write vidbase_lo [STE+]
	move.b	vbl_screen+1(pc),($ffff8205).w		; write vidcount_hi
	move.b	vbl_screen+2(pc),($ffff8207).w		; write vidcount_mid
	move.b	vbl_screen+3(pc),($ffff8209).w		; write vidcount_lo
	move.w	vbl_hscroll(pc),($ffff8264).w		; write hscroll_noprefetch [STE/Falcon]
	move.w	vbl_line_offset(pc),($ffff820e).w	; write vid_lineoffset [Falcon]
	move.w	#$2300,sr
	movem.l	d0-d7/a0-a6,-(a7)
	move.w	scroll_x(pc),d0
	add.w	scroll_dx(pc),d0
	cmp.w	scroll_min_x(pc),d0
	bge.s	.x_not_below
	move.w	scroll_min_x(pc),d0
.x_not_below:
	cmp.w	scroll_max_x(pc),d0
	ble.s	.x_ok
	move.w	scroll_max_x(pc),d0
.x_ok:
	move.w	d0,(scroll_x).l
	clr.w	(scroll_dx).l
	move.w	scroll_y(pc),d0
	add.w	scroll_dy(pc),d0
	cmp.w	scroll_min_y(pc),d0
	bge.s	.y_not_below
	move.w	scroll_min_y(pc),d0
.y_not_below:
	cmp.w	scroll_max_y(pc),d0
	ble.s	.y_ok
	move.w	scroll_max_y(pc),d0
.y_ok:
	move.w	d0,(scroll_y).l
	clr.w	(scroll_dy).l
	move.w	screen_width(pc),d0
	lsr.w	#3,d0
	mulu.w	screen_planes(pc),d0
	mulu.w	scroll_y(pc),d0
	cmpi.w	#16,(screen_planes).l
	bne.s	.bitplanes
	move.w	line_offset(pc),(vbl_line_offset).l
	moveq	#0,d1
	move.w	scroll_x(pc),d1
	add.w	d1,d1
	bclr.l	#1,d1
	add.l	d1,d0
	bra.s	.set_screen
.bitplanes:
	move.w	line_offset(pc),(vbl_line_offset).l
	move.w	scroll_x(pc),d1
	lsr.w	#4,d1
	mulu.w	screen_planes(pc),d1
	add.l	d1,d1
	add.l	d1,d0
	move.w	scroll_x(pc),d1
	andi.w	#15,d1
	beq.s	.no_fine_scroll
	move.w	screen_planes(pc),d2
	sub.w	d2,(vbl_line_offset).l
.no_fine_scroll:
	move.w	d1,(vbl_hscroll).l
.set_screen:
	add.l	screen(pc),d0
	move.l	d0,(vbl_screen).l
	movem.l	(a7)+,d0-d7/a0-a6
	move.l	old_vbl(pc),-(a7)
	move.w	#$ffff,(vbl_ready).l
	rts

.busy:
	rte

;	Cleared while vbl_handler runs, so it isn't entered twice.

vbl_ready:
	dc.w	$ffff

;	IKBD mouse packet handler: saves the buttons and adds the movement to the
;	scroll speed.

mouse_handler:
	move.w	d0,-(a7)
	move.b	(a0)+,(mouse_buttons).l
	move.b	(a0)+,d0
	ext.w	d0
	add.w	d0,(scroll_dx).l
	move.b	(a0)+,d0
	ext.w	d0
	add.w	d0,(scroll_dy).l
	subq.w	#3,a0
	move.w	(a7)+,d0
	rts

;	Finds the darkest and the brightest colour of the palette.

find_border_colours:
	lea		palette(pc),a0
	move.w	#$300,d2
	moveq	#0,d1
	moveq	#0,d3
	moveq	#0,d6
	moveq	#0,d7
	moveq	#1,d5
	move.w	screen_planes(pc),d1
	lsl.w	d1,d5
	subq.w	#1,d5
.colour:
	moveq	#0,d0
	move.b	(a0)+,d0
	move.b	(a0)+,d1
	add.w	d1,d0
	addq.l	#1,a0
	move.b	(a0)+,d1
	add.w	d1,d0
	cmp.w	d0,d6
	bge.s	.not_brighter
	move.w	d0,d6
	move.w	d3,d7
.not_brighter:
	cmp.w	d0,d2
	ble.s	.not_darker
	move.w	d0,d2
	move.w	d3,d4
.not_darker:
	addq.w	#1,d3
	dbra	d5,.colour
	move.w	d4,(darkest_colour).l
	move.w	d7,(brightest_colour).l
	rts

;	Fills the screen around the picture with the border colour, for 8, 4, 2
;	and 1 bitplanes (16-bit screens are filled with words of 0).

fill_border:
	movea.l	format(pc),a0
	move.w	6(a0),d0
	cmp.w	#$280,d0
	bge.s	.wide
	move.w	#40,d1
	lsr.w	#4,d0
	sub.w	d0,d1
	move.w	d1,d0
	lsr.w	#1,d0
	sub.w	d0,d1
	mulu.w	$a(a0),d0
	mulu.w	$a(a0),d1
	subq.w	#1,d0
	subq.w	#1,d1
	move.w	d0,(border_left).l
	move.w	d1,(border_right).l
	move.w	8(a0),d0
	subq.w	#1,d0
	move.w	d0,(border_sides).l
	bra.s	.vertical
.wide:
	move.w	#$ffff,(border_sides).l
.vertical:
	move.w	8(a0),d0
	cmp.w	#$1e0,d0
	bge.s	.tall
	move.w	#$1e0,d1
	sub.w	d0,d1
	move.w	d1,d0
	lsr.w	#1,d0
	sub.w	d0,d1
	subq.w	#1,d0
	subq.w	#1,d1
	move.w	d0,(border_top).l
	move.w	d1,(border_bottom).l
	bra.s	.pattern
.tall:
	move.w	#$ffff,(border_top).l
	move.w	#$ffff,(border_bottom).l
.pattern:
	move.w	screen_width(pc),d0
	lsr.w	#3,d0
	mulu.w	$a(a0),d0
	move.w	d0,(screen_line_bytes).l
	move.w	6(a0),d0
	lsr.w	#3,d0
	mulu.w	$a(a0),d0
	move.w	d0,(picture_line_bytes).l
	moveq	#0,d0
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3
	move.w	border_colour(pc),d4
	btst.l	#0,d4
	beq.s	.plane1
	move.l	#$ffff0000,d0
.plane1:
	btst.l	#1,d4
	beq.s	.plane2
	move.w	#$ffff,d0
.plane2:
	btst.l	#2,d4
	beq.s	.plane3
	move.l	#$ffff0000,d1
.plane3:
	btst.l	#3,d4
	beq.s	.plane4
	move.w	#$ffff,d1
.plane4:
	btst.l	#4,d4
	beq.s	.plane5
	move.l	#$ffff0000,d2
.plane5:
	btst.l	#5,d4
	beq.s	.plane6
	move.w	#$ffff,d2
.plane6:
	btst.l	#6,d4
	beq.s	.plane7
	move.l	#$ffff0000,d3
.plane7:
	btst.l	#7,d4
	beq.s	.pattern_done
	move.w	#$ffff,d3
.pattern_done:
	moveq	#0,d7
	move.w	picture_width(pc),d7
	andi.w	#15,d7
	lea		edge_masks(pc),a0
	move.l	(a0,d7.w*4),d7
	movea.l	format(pc),a0
	move.w	$a(a0),d4
	cmp.w	#2,d4
	blt.w	.words
	beq.w	.planes2
	cmp.w	#8,d4
	blt.w	.planes4
	beq.s	.planes8
	moveq	#0,d0
	bra.w	.words
.planes8:
	movea.l	screen(pc),a0
	move.w	border_top(pc),d5
	bmi.s	.sides8
.top_line8:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#4,d4
	subq.w	#1,d4
.top8:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)+
	move.l	d3,(a0)+
	dbra	d4,.top8
	dbra	d5,.top_line8
.sides8:
	move.w	border_sides(pc),d5
	bmi.s	.bottom8
.side_line8:
	move.w	border_left(pc),d4
	bmi.s	.edge8
	lsr.w	#3,d4
.left8:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)+
	move.l	d3,(a0)+
	dbra	d4,.left8
.edge8:
	adda.w	picture_line_bytes(pc),a0
	move.l	d0,d6
	and.l	d7,d6
	move.l	-$10(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-$10(a0)
	move.l	d1,d6
	and.l	d7,d6
	move.l	-$c(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-$c(a0)
	move.l	d2,d6
	and.l	d7,d6
	move.l	-8(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-8(a0)
	move.l	d3,d6
	and.l	d7,d6
	move.l	-4(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-4(a0)
	move.w	border_right(pc),d4
	lsr.w	#3,d4
.right8:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)+
	move.l	d3,(a0)+
	dbra	d4,.right8
	dbra	d5,.side_line8
.bottom8:
	move.w	border_bottom(pc),d5
	bmi.s	.done8
	move.w	(border_top).l,d6
	movea.l	format(pc),a0
	add.w	8(a0),d6
	addq.l	#1,d6
	mulu.w	(screen_line_bytes).l,d6
	movea.l	(screen).l,a0
	adda.l	d6,a0
.bottom_line8:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#4,d4
	subq.w	#1,d4
.bottom_block8:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	move.l	d2,(a0)+
	move.l	d3,(a0)+
	dbra	d4,.bottom_block8
	dbra	d5,.bottom_line8
.done8:
	rts

.planes4:
	movea.l	screen(pc),a0
	move.w	border_top(pc),d5
	bmi.s	.sides4
.top_line4:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#3,d4
	subq.w	#1,d4
.top4:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	dbra	d4,.top4
	dbra	d5,.top_line4
.sides4:
	move.w	border_sides(pc),d5
	bmi.s	.bottom4
.side_line4:
	move.w	border_left(pc),d4
	bmi.s	.edge4
	lsr.w	#2,d4
.left4:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	dbra	d4,.left4
.edge4:
	adda.w	picture_line_bytes(pc),a0
	move.l	d0,d6
	and.l	d7,d6
	move.l	-8(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-8(a0)
	move.l	d1,d6
	and.l	d7,d6
	move.l	-4(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-4(a0)
	move.w	border_right(pc),d4
	lsr.w	#2,d4
.right4:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	dbra	d4,.right4
	dbra	d5,.side_line4
.bottom4:
	move.w	border_bottom(pc),d5
	bmi.s	.done4
	move.w	(border_top).l,d6
	movea.l	format(pc),a0
	add.w	8(a0),d6
	addq.l	#1,d6
	mulu.w	(screen_line_bytes).l,d6
	movea.l	(screen).l,a0
	adda.l	d6,a0
.bottom_line4:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#3,d4
	subq.w	#1,d4
.bottom_block4:
	move.l	d0,(a0)+
	move.l	d1,(a0)+
	dbra	d4,.bottom_block4
	dbra	d5,.bottom_line4
.done4:
	rts

.planes2:
	movea.l	screen(pc),a0
	move.w	border_top(pc),d5
	bmi.s	.sides2
.top_line2:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#2,d4
	subq.w	#1,d4
.top2:
	move.l	d0,(a0)+
	dbra	d4,.top2
	dbra	d5,.top_line2
.sides2:
	move.w	border_sides(pc),d5
	bmi.s	.bottom2
.side_line2:
	move.w	border_left(pc),d4
	bmi.s	.edge2
	lsr.w	#1,d4
.left2:
	move.l	d0,(a0)+
	dbra	d4,.left2
.edge2:
	adda.w	picture_line_bytes(pc),a0
	move.l	d0,d6
	and.l	d7,d6
	move.l	-4(a0),d4
	not.l	d7
	and.l	d7,d4
	not.l	d7
	or.l	d4,d6
	move.l	d6,-4(a0)
	move.w	border_right(pc),d4
	lsr.w	#1,d4
.right2:
	move.l	d0,(a0)+
	dbra	d4,.right2
	dbra	d5,.side_line2
.bottom2:
	move.w	border_bottom(pc),d5
	bmi.s	.done2
	move.w	(border_top).l,d6
	movea.l	format(pc),a0
	add.w	8(a0),d6
	addq.l	#1,d6
	mulu.w	(screen_line_bytes).l,d6
	movea.l	(screen).l,a0
	adda.l	d6,a0
.bottom_line2:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#2,d4
	subq.w	#1,d4
.bottom_block2:
	move.l	d0,(a0)+
	dbra	d4,.bottom_block2
	dbra	d5,.bottom_line2
.done2:
	rts

.words:
	swap	d0
	movea.l	screen(pc),a0
	move.w	border_top(pc),d5
	bmi.s	.sides1
.top_line1:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#1,d4
	subq.w	#1,d4
.top1:
	move.w	d0,(a0)+
	dbra	d4,.top1
	dbra	d5,.top_line1
.sides1:
	move.w	border_sides(pc),d5
	bmi.s	.bottom1
.side_line1:
	move.w	border_left(pc),d4
	bmi.s	.edge1
.left1:
	move.w	d0,(a0)+
	dbra	d4,.left1
.edge1:
	adda.w	picture_line_bytes(pc),a0
	move.w	d0,d6
	and.w	d7,d6
	move.w	-2(a0),d4
	not.w	d7
	and.w	d7,d4
	not.w	d7
	or.w	d4,d6
	move.w	d6,-2(a0)
	move.w	border_right(pc),d4
.right1:
	move.w	d0,(a0)+
	dbra	d4,.right1
	dbra	d5,.side_line1
.bottom1:
	move.w	border_bottom(pc),d5
	bmi.s	.done1
	move.w	(border_top).l,d6
	movea.l	format(pc),a0
	add.w	8(a0),d6
	addq.l	#1,d6
	mulu.w	(screen_line_bytes).l,d6
	movea.l	(screen).l,a0
	adda.l	d6,a0
.bottom_line1:
	move.w	screen_line_bytes(pc),d4
	lsr.w	#1,d4
	subq.w	#1,d4
.bottom_block1:
	move.w	d0,(a0)+
	dbra	d4,.bottom_block1
	dbra	d5,.bottom_line1
.done1:
	rts

;	Calculates picture_start, the screen address of the picture's top left
;	corner. Pictures smaller than the screen are centred.

picture_position:
	movem.l	d0-d2/a0,-(a7)
	movea.l	format(pc),a0
	move.w	6(a0),d0
	cmp.w	#$280,d0
	bge.s	.wide
	neg.w	d0
	addi.w	#$280,d0
	lsr.w	#1,d0
	lsr.w	#4,d0
	mulu.w	$a(a0),d0
	add.w	d0,d0
	bra.s	.vertical
.wide:
	moveq	#0,d0
.vertical:
	move.w	8(a0),d1
	cmp.w	#$1e0,d1
	bge.s	.done
	neg.w	d1
	addi.w	#$1e0,d1
	lsr.w	#1,d1
	move.w	screen_width(pc),d2
	mulu.w	d2,d1
	lsr.l	#3,d1
	mulu.w	$a(a0),d1
	add.l	d1,d0
.done:
	add.l	screen(pc),d0
	move.l	d0,(picture_start).l
	movem.l	(a7)+,d0-d2/a0
	rts

;	Targa header parser. a0 = format table entry.
;
;	v1.2: rewritten together with the loader. Checks the file size, the
;	picture size and the bits per pixel, and accepts 32-bit pictures.

tga_header:
	movea.l	file_buffer(pc),a1
	cmpi.l	#18,(file_size).l					; File size
	blo.w	exit
	move.b	2(a1),d0							; Image type: 2 = uncompressed,
	andi.b	#$f7,d0								; 10 = RLE, true color
	cmp.b	#2,d0
	bne.w	exit
	move.b	16(a1),d0							; Bits per pixel
	cmp.b	#16,d0
	beq.s	.size
	cmp.b	#24,d0
	beq.s	.size
	cmp.b	#32,d0
	bne.w	exit
.size:
	move.w	$c(a1),d0							; Width, little endian
	rol.w	#8,d0
	beq.w	exit
	cmp.w	#$7ff0,d0
	bhi.w	exit
	move.w	d0,(picture_width).l				; Real width
	addi.w	#15,d0
	andi.w	#$fff0,d0
	move.w	d0,6(a0)							; Width rounded up to 16 pixels
	move.w	$e(a1),d0							; Height
	rol.w	#8,d0
	beq.w	exit
	move.w	d0,8(a0)
	move.w	#16,$a(a0)							; True color
	rts

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
	bsr.w	picture_position					; Calculate screen position.
	movem.l	d2-d7/a2-a6,-(a7)
	clr.l	(tga_buffer).l
	movea.l	file_buffer(pc),a1
	lea		18(a1),a0
	moveq	#0,d0
	move.b	(a1),d0								; Skip the image ID.
	adda.l	d0,a0
	tst.b	1(a1)								; Skip the color map.
	beq.s	.no_colour_map
	move.b	6(a1),d0							; Number of entries, little endian
	lsl.w	#8,d0
	move.b	5(a1),d0
	moveq	#0,d1
	move.b	7(a1),d1							; Bits per entry
	addq.w	#7,d1
	lsr.w	#3,d1
	mulu.w	d1,d0
	adda.l	d0,a0
.no_colour_map:
	moveq	#0,d7
	move.w	picture_width(pc),d7				; d7 = width
	movea.l	format(pc),a2
	moveq	#0,d6
	move.w	8(a2),d6							; d6 = height
	moveq	#0,d5
	move.b	16(a1),d5
	lsr.w	#3,d5								; d5 = bytes per pixel
	cmpi.b	#10,2(a1)
	bne.s	.convert

	move.l	d7,d4								; Unpack RLE into a buffer.
	mulu.l	d6,d4
	mulu.l	d5,d4								; d4 = bytes
	move.l	d4,-(a7)
	move.w	#72,-(a7)							; Malloc
	trap	#1
	addq.l	#6,a7
	tst.l	d0
	beq.w	.fail
	move.l	d0,(tga_buffer).l
	movea.l	d0,a3
	lea		(a3,d4.l),a4						; a4 = end of buffer
	movea.l	a1,a5
	adda.l	file_size(pc),a5					; a5 = end of file
	subq.w	#1,d5
.packet:
	cmpa.l	a4,a3
	bhs.s	.unpacked
	cmpa.l	a5,a0
	bhs.s	.unpacked
	moveq	#0,d0
	move.b	(a0)+,d0
	bclr	#7,d0
	bne.s	.run
.raw:											; d0 + 1 pixels follow.
	move.w	d5,d1
.raw_byte:
	move.b	(a0)+,(a3)+
	dbra	d1,.raw_byte
	cmpa.l	a4,a3
	dbhs	d0,.raw
	bra.s	.packet
.run:											; Next pixel d0 + 1 times
	movea.l	a0,a6
	move.w	d5,d1
.run_byte:
	move.b	(a6)+,(a3)+
	dbra	d1,.run_byte
	cmpa.l	a4,a3
	dbhs	d0,.run
	movea.l	a6,a0
	bra.s	.packet
.unpacked:
	addq.w	#1,d5
	movea.l	(tga_buffer).l,a0

.convert:										; Convert and copy to the screen.
	movea.l	picture_start(pc),a4				; a4 = screen line
	moveq	#0,d3
	move.w	screen_width(pc),d3
	add.l	d3,d3								; d3 = bytes per screen line
	btst	#5,17(a1)							; Top-left origin?
	bne.s	.top_down
	move.l	d6,d0								; No, start with the last line.
	subq.l	#1,d0
	mulu.l	d3,d0
	adda.l	d0,a4
	neg.l	d3
.top_down:
	move.w	6(a2),d4
	sub.w	d7,d4								; d4 = padding up to 16 pixels
	lea		tga_line16(pc),a5
	cmp.w	#2,d5
	beq.s	.lines
	lea		tga_line24(pc),a5
	cmp.w	#3,d5
	beq.s	.lines
	lea		tga_line32(pc),a5
.lines:
	subq.w	#1,d6
.line:
	movea.l	a4,a3
	move.w	d7,d2
	subq.w	#1,d2
	jsr		(a5)
	move.w	d4,d2
	bra.s	.pad_test
.pad:
	clr.w	(a3)+
.pad_test:
	dbra	d2,.pad
	adda.l	d3,a4
	dbra	d6,.line

	bsr.s	tga_free
	movem.l	(a7)+,d2-d7/a2-a6
	rts

.fail:
	bsr.s	tga_free
	bra.w	exit

;	Frees the RLE buffer.

tga_free:
	move.l	(tga_buffer).l,d0
	beq.s	.done
	clr.l	(tga_buffer).l
	move.l	d0,-(a7)
	move.w	#73,-(a7)							; Mfree
	trap	#1
	addq.l	#6,a7
.done:
	rts

;	Convert d2 + 1 pixels from a0 to RGB565 at a3.

tga_line16:										; 16 bits: ARRRRRGG GGGBBBBB, little endian
	moveq	#0,d0
	move.w	(a0)+,d0
	rol.w	#8,d0
	ror.l	#5,d0
	add.w	d0,d0
	rol.l	#5,d0
	move.w	d0,(a3)+
	dbra	d2,tga_line16
	rts

tga_line32:										; 32 bits: blue, green, red, alpha
	bsr.s	tga_pixel24
	addq.l	#1,a0
	dbra	d2,tga_line32
	rts

tga_line24:										; 24 bits: blue, green, red
	bsr.s	tga_pixel24
	dbra	d2,tga_line24
	rts

tga_pixel24:
	move.b	(a0)+,d0
	ror.l	#8,d0
	move.b	(a0)+,d0
	lsr.w	#2,d0
	ror.l	#6,d0
	move.b	(a0)+,d0
	lsr.w	#3,d0
	ror.l	#5,d0
	swap	d0
	move.w	d0,(a3)+
	rts

;	IndyPaint (.TRU): checks the "Indy" header and reads the size.

tru_header:
	movea.l	file_buffer(pc),a1
	cmpi.l	#'Indy',(a1)
	bne.w	exit
	move.w	4(a1),d0
	move.w	d0,(picture_width).l				; v1.2: width rounded up to 16
	addi.w	#15,d0								; pixels, as fill_border needs it.
	andi.w	#$fff0,d0
	move.w	d0,6(a0)
	move.w	6(a1),8(a0)
	rts

;	IndyPaint loader: 16-bit pixels after a 256-byte header.

tru_load:
	bsr.w	picture_position
	movem.l	d2-d6/a2-a3,-(a7)					; v1.2: lines of the real width,
	movea.l	file_buffer(pc),a0					; padded to 16 pixels.
	lea		$100(a0),a0
	bsr.w	tc_lines
.line:
	movea.l	a1,a3
	move.w	d4,d2
.pixel:
	move.w	(a0)+,(a3)+
	dbra	d2,.pixel
	bsr.w	tc_pad
	dbra	d5,.line
	movem.l	(a7)+,d2-d6/a2-a3
	rts

;	For loaders of true colour pictures: a1 = picture_start, d3 = bytes per
;	screen line, d4 = width - 1, d5 = height - 1, d6 = padding up to 16
;	pixels.

tc_lines:
	movea.l	picture_start(pc),a1
	movea.l	format(pc),a2
	move.w	8(a2),d5
	subq.w	#1,d5
	moveq	#0,d3
	move.w	screen_width(pc),d3
	add.l	d3,d3
	move.w	picture_width(pc),d4
	move.w	6(a2),d6
	sub.w	d4,d6
	subq.w	#1,d4
	rts

;	Clears the padding at a3 (d6 pixels) and moves a1 to the next line.

tc_pad:
	move.w	d6,d2
	bra.s	.test
.pad:
	clr.w	(a3)+
.test:
	dbra	d2,.pad
	adda.l	d3,a1
	rts

;	GIF header parser: skips the global palette and any extension blocks and
;	reads the size from the image descriptor.

gif_header:
	movea.l	file_buffer(pc),a1
	lea		$d(a1),a1
	tst.b	-3(a1)
	bpl.s	.no_palette
	move.b	-3(a1),d0
	andi.w	#7,d0
	addq.l	#1,d0
	moveq	#1,d1
	rol.w	d0,d1
	mulu.w	#3,d1
	adda.w	d1,a1
.no_palette:									; v1.2: skip extension blocks,
	movea.l	file_buffer(pc),a2					; GIF89a pictures often have them
	adda.l	file_size(pc),a2					; a2 = end of file
.block:
	cmpa.l	a2,a1
	bhs.w	exit
	cmpi.b	#$21,(a1)							; Extension
	bne.s	.descriptor
	addq.l	#2,a1
.subblock:
	cmpa.l	a2,a1
	bhs.w	exit
	moveq	#0,d0
	move.b	(a1)+,d0
	beq.s	.block
	adda.l	d0,a1
	bra.s	.subblock
.descriptor:
	cmpi.b	#$2c,(a1)							; Image descriptor
	bne.w	exit
	btst	#6,9(a1)							; Interlaced
	sne		(gif_interlaced).l
	move.b	6(a1),d0
	lsl.w	#8,d0
	move.b	5(a1),d0
	move.w	d0,(picture_width).l
	addi.w	#15,d0
	andi.w	#$fff0,d0
	move.w	d0,6(a0)
	addq.l	#7,a1
	move.b	(a1)+,9(a0)
	move.b	(a1)+,8(a0)
	rts

;	GIF loader: unpacks the picture with gif_unpack and converts it to
;	bitplanes line by line.

gif_load:
	bsr.w	picture_position
	movem.l	d2-d7/a2-a4,-(a7)					; v1.2
	move.w	screen_width(pc),d0
	mulu.w	screen_height(pc),d0
	move.w	picture_width(pc),d1
	movea.l	format(pc),a0
	mulu.w	8(a0),d1
	sub.l	d1,d0
	add.l	screen(pc),d0
	move.l	d0,(gif_pixels).l
	clr.l	(gif_buffer).l
	tst.b	(gif_interlaced).l					; v1.2: interlaced pictures are
	beq.s	.unpack								; unpacked into a buffer of their
	move.l	d1,-(a7)							; own, as the lines are converted
	move.w	#72,-(a7)							; out of order and could overwrite
	trap	#1									; lines not converted yet.
	addq.l	#6,a7								; Malloc
	tst.l	d0
	beq.w	exit
	move.l	d0,(gif_buffer).l
	move.l	d0,(gif_pixels).l
.unpack:
	move.l	#gif_info,(gif_info_ptr).l
	bsr.w	gif_unpack
	tst.w	d0
	bmi.w	.free
	bsr.w	make_c2p_tables
	lea		line_buffer(pc),a0
	moveq	#0,d0
	move.w	#$5ff,d1
.clear_line:
	move.l	d0,(a0)+
	dbra	d1,.clear_line

;	v1.2: Version 1.1 converted as many lines as the screen has, reading
;	past the unpacked picture and writing past the screen for pictures
;	lower than the screen, converted whole screen lines (overwriting the
;	start of the next line), and ignored interlacing.

	move.w	gif_info+10(pc),d0
	subq.l	#1,d0								; d0 = width - 1
	movea.l	gif_pixels(pc),a0
	movea.l	picture_start(pc),a2				; a2 = first screen line
	moveq	#0,d4
	move.w	screen_width(pc),d4					; d4 = bytes per screen line
	movea.l	format(pc),a3
	move.w	6(a3),d3							; Width rounded up to 16 pixels
	lsr.w	#4,d3
	move.w	d3,(c2p_blocks).l
	moveq	#0,d7
	move.w	8(a3),d7							; d7 = height
	move.l	d7,d2
	subq.w	#1,d2
	move.l	#line_buffer,d3
	lea		.passes(pc),a4						; Line order
	tst.b	(gif_info+15).l						; Interlaced?
	beq.s	.order
	addq.l	#8,a4
.order:
	move.w	(a4)+,d5							; d5 = screen line
	move.w	(a4)+,d6							; d6 = step
.line:
	move.w	d0,d1
	movea.l	d3,a1
.copy:
	move.b	(a0)+,(a1)+
	dbra	d1,.copy
	move.l	d3,(c2p_source).l
	move.l	d5,d1
	mulu.l	d4,d1
	add.l	a2,d1
	move.l	d1,(c2p_dest).l
	bsr.w	c2p_line
	add.w	d6,d5
.next_pass:
	cmp.w	d7,d5
	blo.s	.next_line
	tst.w	(a4)								; Last pass done?
	bmi.s	.next_line
	move.w	(a4)+,d5
	move.w	(a4)+,d6
	bra.s	.next_pass
.next_line:
	dbra	d2,.line
.free:
	move.l	(gif_buffer).l,d0
	beq.s	.done
	clr.l	(gif_buffer).l
	move.l	d0,-(a7)
	move.w	#73,-(a7)							; Mfree
	trap	#1
	addq.l	#6,a7
.done:
	movem.l	(a7)+,d2-d7/a2-a4
	rts

;	First line and step of each pass, ended by -1.

.passes:
	dc.w	0,1,-1,0							; Not interlaced
	dc.w	0,8,4,8,2,4,1,2,-1,0				; Interlaced

;	Unpacks the GIF in file_buffer to gif_pixels, one byte per pixel, and
;	copies the descriptors to gif_info. Returns d0 = -1 if it isn't a GIF.
;	The GIF depacker (gif_unpack to lzw_decode) is from TurboGIF by Sascha
;	Springer.

gif_unpack:
	movem.l	d3-d7/a2-a6,-(a7)
	movea.l	file_buffer(pc),a0
	lea		gif_parsed(pc),a1
	bsr.s	gif_parse
	tst.w	d0
	bmi.s	.done
	movea.l	file_buffer(pc),a1
	bsr.w	gif_join_blocks
	movea.l	file_buffer(pc),a0
	movea.l	gif_pixels(pc),a1
	bsr.w	lzw_decode
	lea		gif_parsed(pc),a0
	movea.l	gif_info_ptr(pc),a1
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	clr.w	d0
.done:
	movem.l	(a7)+,d3-d7/a2-a6
	rts

;	Reads the screen and image descriptors of the GIF at a0 into a1 and the
;	palettes into palette. Returns d0 = -1 if it isn't a GIF, else a0 = the
;	image data.

gif_parse:
	moveq	#-1,d0
	cmpi.l	#'GIF8',(a0)+
	bne.w	.done
	cmpi.w	#$3761,(a0)+
	beq.s	.version_ok
	cmpi.w	#$3961,-2(a0)
	bne.w	.done
.version_ok:
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0
	move.w	d0,(a1)+
	move.b	3(a0),d0
	lsl.w	#8,d0
	move.b	2(a0),d0
	move.w	d0,(a1)+
	move.b	4(a0),d0
	andi.b	#7,d0
	addq.b	#1,d0
	move.b	d0,(a1)+
	move.b	4(a0),d0
	andi.b	#112,d0
	lsr.b	#4,d0
	addq.b	#1,d0
	move.b	d0,(a1)+
	addq.w	#7,a0
	move.b	-3(a0),d0
	andi.b	#128,d0
	beq.s	.no_global_palette
	lea		palette(pc),a2
	moveq	#1,d0
	move.b	-2(a1),d1
	lsl.w	d1,d0
	subq.w	#1,d0
.global_colour:
	move.b	(a0)+,(a2)+
	move.b	(a0)+,(a2)+
	clr.b	(a2)+
	move.b	(a0)+,(a2)+
	dbra	d0,.global_colour
.no_global_palette:
	clr.w	d0
.skip_extension:
	cmpi.b	#33,(a0)
	bne.s	.descriptor
	addq.w	#2,a0
.skip_subblock:
	move.b	(a0)+,d0
	beq.s	.skip_extension
	adda.w	d0,a0
	bra.s	.skip_subblock
.descriptor:
	moveq	#-1,d0
	cmpi.b	#44,(a0)
	bne.w	.done
	move.b	2(a0),d0
	lsl.w	#8,d0
	move.b	1(a0),d0
	move.w	d0,(a1)+
	move.b	4(a0),d0
	lsl.w	#8,d0
	move.b	3(a0),d0
	move.w	d0,(a1)+
	move.b	6(a0),d0
	lsl.w	#8,d0
	move.b	5(a0),d0
	move.w	d0,(a1)+
	move.b	8(a0),d0
	lsl.w	#8,d0
	move.b	7(a0),d0
	move.w	d0,(a1)+
	move.b	9(a0),d0
	andi.b	#3,d0
	move.b	d0,(a1)+
	move.b	9(a0),d0
	andi.b	#64,d0
	sne		(a1)+
	move.b	9(a0),d0
	andi.b	#128,d0
	sne		(a1)+
	lea		$a(a0),a0
	tst.b	-1(a1)
	beq.s	.no_local_palette
	lea		palette(pc),a2
	moveq	#1,d0
	move.b	-3(a1),d1
	lsl.w	d1,d0
	subq.w	#1,d0
.local_colour:
	move.b	(a0)+,(a2)+
	move.b	(a0)+,(a2)+
	clr.b	(a2)+
	move.b	(a0)+,(a2)+
	dbra	d0,.local_colour
.no_local_palette:
	clr.w	d0
.skip_extension2:
	cmpi.b	#33,(a0)
	bne.s	.ok
	addq.w	#2,a0
.skip_subblock2:
	move.b	(a0)+,d0
	beq.s	.skip_extension2
	adda.w	d0,a0
	bra.s	.skip_subblock2
.ok:
	moveq	#0,d0
.done:
	rts

;	Joins the data sub-blocks at a0 into one stream at a1.

gif_join_blocks:
	move.b	(a0)+,(a1)+
.block:
	clr.w	d0
	move.b	(a0)+,d0
	beq.s	.done
	subq.w	#1,d0
.copy:
	move.b	(a0)+,(a1)+
	dbra	d0,.copy
	bra.s	.block
.done:
	rts

;	LZW decoder. a0 = code size and data, a1 = output (one byte per pixel).
;	Uses work_tables for the string table and line_buffer as stack.

lzw_decode:
	clr.w	d4
	move.b	(a0)+,d4
	moveq	#1,d1
	lsl.w	d4,d1
	movea.w	d1,a3
	addq.w	#1,d1
	movea.w	d1,a4
	addq.w	#1,d1
	addq.w	#1,d4
	moveq	#1,d2
	lsl.w	d4,d2
	move.w	d2,d7
	subq.w	#1,d2
	swap	d1
	move.w	d4,d1
	swap	d1
	clr.w	d3
	moveq	#-1,d5
	lea		work_tables(pc),a2
	lea		line_buffer(pc),a5
	lea		1(a5),a6
.code:
	move.b	2(a0),d0
	swap	d0
	move.b	1(a0),d0
	lsl.w	#8,d0
	move.b	(a0),d0
	lsr.l	d3,d0
	and.w	d2,d0
	add.w	d4,d3
	move.w	d3,d6
	lsr.w	#3,d6
	adda.w	d6,a0
	andi.w	#7,d3
	cmp.w	a3,d0
	bne.s	.not_clear
	swap	d1
	move.w	d1,d4
	swap	d1
	moveq	#1,d7
	lsl.w	d4,d7
	move.w	d7,d2
	subq.w	#1,d2
	move.w	a4,d1
	addq.w	#1,d1
	bra.s	.code
.not_clear:
	cmp.w	a4,d0
	beq.s	.end
	bgt.s	.string
	move.w	d0,(a2,d1.w*4)
	move.w	d0,-2(a2,d1.w*4)
	move.b	d0,(a1)+
	bra.s	.next
.string:
	move.w	d0,(a2,d1.w*4)
	move.w	d0,d6
	addq.w	#1,d6
.push:
	move.b	3(a2,d0.w*4),(a5)+
	move.w	(a2,d0.w*4),d0
	cmp.w	a4,d0
	bgt.s	.push
	move.l	a5,d5
	sub.l	a6,d5
	move.w	d0,-2(a2,d1.w*4)
	move.b	d0,(a1)+
.pop:
	move.b	-(a5),(a1)+
	dbra	d5,.pop
	cmp.w	d1,d6
	bne.s	.next
	move.b	d0,-1(a1)
.next:
	addq.w	#1,d1
	cmp.w	d7,d1
	ble.s	.code
	cmp.w	#12,d4
	beq.s	.code
	add.w	d7,d7
	addq.w	#1,d4
	move.w	d7,d2
	subq.w	#1,d2
	bra.w	.code
.end:
	rts

;	MacPaint: 576 x 720 pixels, PackBits lines after a 512-byte header.

macpaint_load:
	move.l	#-1,(palette).l
	clr.l	(palette+4).l
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	movea.l	file_buffer(pc),a0
	lea		$200(a0),a0
	move.w	#$2cf,d6
.line:
	move.l	a1,d7
	addi.l	#72,d7
	bsr.w	unpack_packbits
	addq.l	#8,a1
	dbra	d6,.line
	rts

;	IFF ILBM header parser: size and depth from the BMHD chunk.

iff_header:
	movea.l	file_buffer(pc),a1
	cmpi.l	#'ILBM',8(a1)
	bne.s	.unsupported
	lea		$c(a1),a1
.find_bmhd:
	cmpi.l	#'BMHD',(a1)
	beq.s	.bmhd
	adda.l	4(a1),a1
	addq.l	#8,a1
	bra.s	.find_bmhd
.bmhd:
	move.l	a1,(iff_bmhd).l
	move.w	8(a1),6(a0)
	move.w	$a(a1),8(a0)
	move.b	$10(a1),d0
	cmp.b	#2,d0
	ble.s	.planes1
	beq.s	.planes2
	cmp.b	#4,d0
	ble.s	.planes4
	cmp.b	#8,d0
	ble.s	.planes8
.unsupported:
	clr.w	$a(a0)
	rts

.planes8:
	move.w	#8,$a(a0)
	rts

.planes4:
	move.w	#4,$a(a0)
	rts

.planes2:
	move.w	#2,$a(a0)
	rts

.planes1:
	move.w	#1,$a(a0)
	rts

;	IFF ILBM loader: palette from CMAP, then the lines of BODY (packed or not)
;	through the line routine for the number of planes.

iff_load:
	movea.l	file_buffer(pc),a0
	lea		$c(a0),a0
.find_cmap:
	cmpi.l	#'CMAP',(a0)
	beq.s	.cmap
	adda.l	4(a0),a0
	addq.l	#8,a0
	bra.s	.find_cmap
.cmap:
	addq.l	#4,a0
	move.l	(a0)+,d0
	divu.w	#3,d0
	subq.l	#1,d0
	lea		palette(pc),a1
.colour:
	move.b	(a0)+,(a1)+
	move.b	(a0)+,(a1)+
	addq.l	#1,a1
	move.b	(a0)+,(a1)+
	dbra	d0,.colour
	movea.l	file_buffer(pc),a0
	lea		$c(a0),a0
.find_body:
	cmpi.l	#'BODY',(a0)
	beq.s	.body
	adda.l	4(a0),a0
	addq.l	#8,a0
	bra.s	.find_body
.body:
	addq.l	#8,a0
	bsr.w	picture_position
	move.l	picture_start(pc),(line_dest).l
	movea.l	format(pc),a3
	move.w	screen_width(pc),d3
	lsr.w	#3,d3
	mulu.w	screen_planes(pc),d3
	move.l	d3,(line_step).l
	move.w	8(a3),d4
	subq.w	#1,d4
	move.w	6(a3),d5
	lsr.w	#4,d5
	subq.w	#1,d5
	moveq	#0,d0
	movea.l	(iff_bmhd).l,a2
	move.b	$10(a2),d0
	lea		line_routines(pc),a5
	move.l	-4(a5,d0.w*4),d0
	beq.s	.done
	movea.l	d0,a5
	moveq	#0,d0
	move.w	6(a3),d2
	lsr.w	#3,d2
	move.l	d2,(plane_bytes).l
	move.b	$10(a2),d0
	mulu.w	d0,d2
	tst.b	$12(a2)
	beq.s	.raw_line
.packed_line:
	lea		line_buffer(pc),a1
	move.l	a1,d7
	add.l	d2,d7
	bsr.w	unpack_packbits
	jsr		(a5)
	dbra	d4,.packed_line
.done:
	rts

.raw_line:
	move.l	a0,(line_source).l
	jsr		(a5)
	adda.l	d2,a0
	dbra	d4,.raw_line
	rts

lelong				macro						; Read little endian long \1 to \2.
	move.l	\1,\2
	ror.w	#8,\2
	swap	\2
	ror.w	#8,\2
	endm

;	BMP header parser. a0 = format table entry.
;
;	v1.2: rewritten together with the loader. Checks that the picture is
;	an uncompressed 256-colour Windows BMP that fits in the file, reads
;	the 32-bit width and height and allows top-down pictures.

bmp_header:
	movea.l	(file_buffer).l,a1
	cmpi.l	#54,(file_size).l					; File size
	blo.w	exit
	cmpi.w	#'BM',(a1)
	bne.w	exit
	lelong	14(a1),d0							; Info header size
	cmp.l	#40,d0
	blo.w	exit
	cmpi.w	#$0800,28(a1)						; 8 bits per pixel
	bne.w	exit
	tst.l	30(a1)								; Not compressed
	bne.w	exit
	lelong	18(a1),d0							; Width
	tst.l	d0
	beq.w	exit
	cmp.l	#$7ff0,d0
	bhi.w	exit
	move.w	d0,(picture_width).l				; Real width
	move.l	d0,d2
	addi.w	#15,d0
	andi.w	#$fff0,d0
	move.w	d0,6(a0)							; Width rounded up to 16 pixels
	lelong	22(a1),d1							; Height, negative if top-down
	smi		(bmp_top_down).l
	bpl.s	.bottom_up
	neg.l	d1
.bottom_up:
	tst.l	d1
	beq.w	exit
	cmp.l	#$7fff,d1
	bhi.w	exit
	move.w	d1,8(a0)
	move.w	#8,$a(a0)
	addq.l	#3,d2								; Lines are padded to 4 bytes.
	andi.w	#$fffc,d2
	mulu.l	d1,d2
	lelong	10(a1),d0							; Offset of the pixels
	add.l	d0,d2
	bcs.w	exit
	cmp.l	(file_size).l,d2					; Pixels must fit in the file.
	bhi.w	exit
	rts

;	BMP loader.
;
;	v1.2: rewritten. Version 1.1 took the red component of each colour
;	from the previous palette entry, read lines of the width rounded down
;	to 16 pixels instead of the padded line length (skewing pictures with
;	other widths), assumed the palette right after a 40-byte info header
;	and read only the low word of the pixel offset.

bmp_load:
	bsr.w	make_c2p_tables
	movem.l	d2-d7/a2-a3,-(a7)
	movea.l	file_buffer(pc),a1
	lelong	14(a1),d0							; Palette after the info header
	lea		14(a1,d0.l),a0
	lelong	46(a1),d1							; Colours used, 0 = all
	subq.l	#1,d1
	cmp.l	#255,d1
	bls.s	.colours
	move.l	#255,d1
.colours:
	lea		palette(pc),a2
.colour:										; Blue, green, red, 0
	move.b	2(a0),(a2)+							; to red, green, 0, blue
	move.b	1(a0),(a2)+
	clr.b	(a2)+
	move.b	(a0),(a2)+
	addq.l	#4,a0
	dbra	d1,.colour

	bsr.w	picture_position					; Calculate screen position.
	lea		line_buffer(pc),a0					; Clear the line buffer, so the
	move.w	#$5ff,d1							; padding up to 16 pixels is
.clear_line:									; colour 0.
	clr.l	(a0)+
	dbra	d1,.clear_line
	movea.l	format(pc),a0
	move.w	6(a0),d1
	lsr.w	#4,d1
	move.w	d1,(c2p_blocks).l
	moveq	#0,d6
	move.w	8(a0),d6							; d6 = height
	moveq	#0,d7
	move.w	picture_width(pc),d7				; d7 = width
	move.l	d7,d5
	addq.l	#3,d5
	andi.w	#$fffc,d5							; d5 = bytes per BMP line
	moveq	#0,d2
	move.w	screen_width(pc),d2
	lsr.w	#4,d2
	add.w	d2,d2
	mulu.w	screen_planes(pc),d2				; d2 = bytes per screen line
	lelong	10(a1),d0
	lea		(a1,d0.l),a2						; a2 = pixels
	movea.l	picture_start(pc),a3				; a3 = screen line
	tst.b	(bmp_top_down).l
	bne.s	.top_down
	move.l	d6,d0								; Bottom-up: start with the
	subq.l	#1,d0								; last screen line.
	mulu.l	d2,d0
	adda.l	d0,a3
	neg.l	d2
.top_down:
	subq.w	#1,d6
.line:
	movea.l	a2,a0
	lea		line_buffer(pc),a1
	move.w	d7,d0
	subq.w	#1,d0
.copy:
	move.b	(a0)+,(a1)+
	dbra	d0,.copy
	pea		line_buffer(pc)
	move.l	(a7)+,(c2p_source).l
	move.l	a3,(c2p_dest).l
	bsr.w	c2p_line
	adda.l	d5,a2
	adda.l	d2,a3
	dbra	d6,.line
	movem.l	(a7)+,d2-d7/a2-a3
	rts

;	Makes the tables for c2p_line in work_tables: for each of the 8 pixels of
;	a byte group and each colour, the colour's bits in 8 bitplanes.

make_c2p_tables:
	movem.l	d0-d3/a0,-(a7)
	lea		work_tables+2048(pc),a0
	move.w	#$ff,d3
.entry:
	moveq	#0,d1
	moveq	#0,d2
	btst.l	#0,d3
	beq.s	.bit1
	bset.l	#31,d1
.bit1:
	btst.l	#1,d3
	beq.s	.bit2
	bset.l	#23,d1
.bit2:
	btst.l	#2,d3
	beq.s	.bit3
	bset.l	#15,d1
.bit3:
	btst.l	#3,d3
	beq.s	.bit4
	bset.l	#7,d1
.bit4:
	btst.l	#4,d3
	beq.s	.bit5
	bset.l	#31,d2
.bit5:
	btst.l	#5,d3
	beq.s	.bit6
	bset.l	#23,d2
.bit6:
	btst.l	#6,d3
	beq.s	.bit7
	bset.l	#15,d2
.bit7:
	btst.l	#7,d3
	beq.s	.store
	bset.l	#7,d2
.store:
	move.l	d2,-(a0)
	move.l	d1,-(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$800(a0)
	move.l	d2,$804(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$1000(a0)
	move.l	d2,$1004(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$1800(a0)
	move.l	d2,$1804(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$2000(a0)
	move.l	d2,$2004(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$2800(a0)
	move.l	d2,$2804(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$3000(a0)
	move.l	d2,$3004(a0)
	lsr.l	#1,d1
	lsr.l	#1,d2
	move.l	d1,$3800(a0)
	move.l	d2,$3804(a0)
	dbra	d3,.entry
	movem.l	(a7)+,d0-d3/a0
	rts

;	Converts c2p_blocks x 16 pixels (one byte each) from c2p_source to 8
;	interleaved bitplanes at c2p_dest.

c2p_line:
	movem.l	d0-d4/a0-a5,-(a7)
	movea.l	(c2p_source).l,a0
	lea		work_tables(pc),a1
	movea.l	(c2p_dest).l,a2
	lea		$1000(a1),a3
	lea		$1000(a3),a4
	lea		$1000(a4),a5
	move.w	(c2p_blocks).l,d4
	subq.l	#1,d4
	moveq	#0,d0
	move.w	#$100,d3
.block:
	move.b	(a0)+,d0
	move.l	(a1,d0.w*8),d1
	move.l	4(a1,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a1,d3.w*8),d1
	or.l	4(a1,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a3,d0.w*8),d1
	or.l	4(a3,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a3,d3.w*8),d1
	or.l	4(a3,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a4,d0.w*8),d1
	or.l	4(a4,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a4,d3.w*8),d1
	or.l	4(a4,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a5,d0.w*8),d1
	or.l	4(a5,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a5,d3.w*8),d1
	or.l	4(a5,d3.w*8),d2
	movep.l	d1,0(a2)
	movep.l	d2,8(a2)
	move.b	(a0)+,d0
	move.l	(a1,d0.w*8),d1
	move.l	4(a1,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a1,d3.w*8),d1
	or.l	4(a1,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a3,d0.w*8),d1
	or.l	4(a3,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a3,d3.w*8),d1
	or.l	4(a3,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a4,d0.w*8),d1
	or.l	4(a4,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a4,d3.w*8),d1
	or.l	4(a4,d3.w*8),d2
	move.b	(a0)+,d0
	or.l	(a5,d0.w*8),d1
	or.l	4(a5,d0.w*8),d2
	move.b	(a0)+,d3
	or.l	(a5,d3.w*8),d1
	or.l	4(a5,d3.w*8),d2
	movep.l	d1,1(a2)
	movep.l	d2,9(a2)
	lea		$10(a2),a2
	dbra	d4,.block
	move.l	a0,(c2p_source).l
	move.l	a2,(c2p_dest).l
	movem.l	(a7)+,d0-d4/a0-a5
	rts

;	RAG-D! header parser: width, height and depth from the header.

rag_header:
	movea.l	(file_buffer).l,a1
	move.w	$c(a1),6(a0)
	move.w	$e(a1),8(a0)
	move.w	$10(a1),$a(a0)
	rts

;	RAG-D! loader: a 32-byte ST palette or a 1024-byte Falcon palette, then
;	the screen data.

rag_load:
	movea.l	file_buffer(pc),a0
	lea		$1e(a0),a1
	cmpi.l	#32,$12(a0)
	beq.s	.st_palette
	lea		palette(pc),a2
	move.w	#$ff,d0
.falcon_palette:
	move.l	(a1)+,(a2)+
	dbra	d0,.falcon_palette
	bra.s	.pixels
.st_palette:
	move.l	a1,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.w	st_palette
.pixels:
	bsr.w	picture_position
	movea.l	file_buffer(pc),a0
	move.w	$e(a0),d0
	subq.w	#1,d0
	movea.l	picture_start(pc),a1
	moveq	#0,d2
	move.w	$c(a0),d1
	lsr.w	#4,d1
	cmp.w	#40,d1
	bge.s	.wide
	moveq	#40,d2
	sub.w	d1,d2
	add.w	d2,d2
	mulu.w	screen_planes(pc),d2
.wide:
	mulu.w	screen_planes(pc),d1
	subq.w	#1,d1
	adda.l	$12(a0),a0
	lea		$1e(a0),a0
.line:
	move.l	d1,d3
.word:
	move.w	(a0)+,(a1)+
	dbra	d3,.word
	adda.l	d2,a1
	dbra	d0,.line
	rts

;	POV raw header parser: width and height as decimal text. The 24-bit
;	pixels follow.

raw_header:
	movea.l	(file_buffer).l,a1
	moveq	#0,d0
	moveq	#0,d1
.width:
	move.b	(a1)+,d0
	subi.w	#48,d0
	bmi.s	.height
	mulu.w	#10,d1
	add.w	d0,d1
	bra.s	.width
.height:
	move.w	d1,(picture_width).l				; v1.2: width rounded up to 16
	addi.w	#15,d1								; pixels, as fill_border needs it.
	andi.w	#$fff0,d1
	move.w	d1,6(a0)
	moveq	#0,d0
	moveq	#0,d1
.height_digit:
	move.b	(a1)+,d0
	subi.w	#48,d0
	bmi.s	.done
	mulu.w	#10,d1
	add.w	d0,d1
	bra.s	.height_digit
.done:
	move.w	d1,8(a0)
	move.l	a1,(raw_pixels).l
	rts

;	POV raw loader: converts the 24-bit pixels to RGB565.

raw_load:
	bsr.w	picture_position
	movem.l	d2-d6/a2-a3,-(a7)					; v1.2: lines of the real width,
	movea.l	raw_pixels(pc),a0					; padded to 16 pixels, and d1
	bsr.w	tc_lines							; cleared.
	moveq	#0,d1
.line:
	movea.l	a1,a3
	move.w	d4,d2
.pixel:
	move.b	(a0)+,d0							; Red
	lsl.w	#5,d0
	move.b	(a0)+,d0							; Green
	andi.w	#$fffc,d0
	lsl.w	#3,d0
	move.b	(a0)+,d1							; Blue
	lsr.w	#3,d1
	or.w	d1,d0
	move.w	d0,(a3)+
	dbra	d2,.pixel
	bsr.w	tc_pad
	dbra	d5,.line
	movem.l	(a7)+,d2-d6/a2-a3
	rts

;	GEM (X)IMG header parser: size and depth. 24-bit pictures are shown on a
;	16-bit screen.

img_header:
	movea.l	(file_buffer).l,a1
	move.w	4(a1),d0
	cmp.w	#24,d0
	bne.s	.depth
	move.w	#16,d0
.depth:
	move.w	d0,$a(a0)
	move.w	$c(a1),d0
	move.w	d0,(picture_width).l
	addi.w	#15,d0
	andi.w	#$fff0,d0
	move.w	d0,6(a0)
	move.w	$e(a1),8(a0)
	rts

;	GEM (X)IMG loader: monochrome or with several planes.

img_load:
	bsr.w	picture_position
	movea.l	file_buffer(pc),a0
	move.w	4(a0),d0
	cmp.w	#1,d0
	beq.w	img_load_mono
	bra.w	img_load_planes

;	Sets the palette from an XIMG RGB palette. Pictures without one use the
;	system palette.

img_palette:
	movea.l	file_buffer(pc),a0
	lea		palette(pc),a1
	cmpi.w	#8,2(a0)
	beq.s	.system_palette
	cmpi.l	#'XIMG',$10(a0)
	beq.s	.ximg
	rts

.system_palette:
	moveq	#1,d0
	move.w	screen_planes(pc),d1
	lsl.w	d1,d0
	subq.w	#1,d0
	lea		($ffff9800).w,a0					; videl_palette[0] [Falcon]
	lea		palette(pc),a1
.copy:											; v1.2: was dbra d1 (the number of
	move.l	(a0)+,(a1)+							; planes), which copied only the
	dbra	d0,.copy							; first few colours.
	rts

.ximg:
	tst.w	$14(a0)
	bne.s	.done
	moveq	#1,d0
	moveq	#0,d1
	move.w	4(a0),d1
	lsl.w	d1,d0
	subq.w	#1,d0
	lea		$16(a0),a0
.ximg_colour:
	moveq	#0,d1
	move.w	(a0)+,d1
	addq.w	#8,d1
	mulu.w	#100,d1
	divu.w	#$18c,d1
	move.b	d1,(a1)+
	moveq	#0,d1
	move.w	(a0)+,d1
	addq.w	#8,d1
	mulu.w	#100,d1
	divu.w	#$18c,d1
	move.b	d1,(a1)+
	clr.b	(a1)+
	moveq	#0,d1
	move.w	(a0)+,d1
	addq.w	#8,d1
	mulu.w	#100,d1
	divu.w	#$18c,d1
	move.b	d1,(a1)+
	dbra	d0,.ximg_colour
.done:
	rts

;	IMG with several planes: unpacks each line with img_unpack_line and
;	converts it with the line routine for the number of planes.

img_load_planes:
	moveq	#16,d0
	cmp.w	screen_planes(pc),d0
	beq.s	.palette_done
	bsr.w	img_palette
.palette_done:
	movea.l	file_buffer(pc),a0
	moveq	#0,d0
	move.w	$c(a0),d0
	addq.l	#7,d0
	lsr.w	#3,d0
	move.l	d0,(plane_bytes).l
	mulu.w	4(a0),d0
	move.l	d0,(img_line_bytes).l
	move.l	picture_start(pc),(line_dest).l
	movea.l	format(pc),a1
	move.w	screen_width(pc),d0
	lsr.w	#3,d0
	mulu.w	$a(a1),d0
	move.l	d0,(line_step).l
	moveq	#0,d6
	move.w	6(a0),d6
	subq.w	#1,d6
	move.w	$e(a0),d3
	subq.w	#1,d3
	move.w	4(a0),d0
	lea		line_routines(pc),a6
	move.l	-4(a6,d0.w*4),d0
	beq.s	.done
	movea.l	d0,a6
	move.w	2(a0),d0
	add.w	d0,d0
	adda.w	d0,a0
.line:
	lea		line_buffer(pc),a1
	move.l	img_line_bytes(pc),d7
	add.l	a1,d7
	bsr.w	img_unpack_line
	jsr		(a6)
	dbra	d3,.line
.done:
	rts

;	Line routines for IFF and IMG, see line_routines: copy one line from
;	line_source (separate planes of plane_bytes each, or chunky pixels) to the
;	screen at line_dest and advance line_dest by line_step.

line_16bit:
	movem.l	d0/a0-a1,-(a7)
	movea.l	line_source(pc),a0
	movea.l	line_dest(pc),a1
	move.w	picture_width(pc),d0
	subq.w	#1,d0
.pixel:
	move.w	(a0)+,(a1)+
	dbra	d0,.pixel
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0/a0-a1
	rts

line_24bit:
	movem.l	d0-d1/a0-a1,-(a7)
	movea.l	line_source(pc),a0
	movea.l	line_dest(pc),a1
	move.w	picture_width(pc),d0
	subq.w	#1,d0
.pixel:
	moveq	#0,d1
	move.b	(a0)+,d1
	lsl.w	#5,d1
	move.b	(a0)+,d1
	lsl.l	#6,d1
	move.b	(a0)+,d1
	lsr.l	#3,d1
	move.w	d1,(a1)+
	dbra	d0,.pixel
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0-d1/a0-a1
	rts

line_1plane:
	movem.l	d0/a0/a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	line_dest(pc),a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
.byte:
	move.b	(a0)+,(a6)+
	cmpa.l	d0,a0
	bne.s	.byte
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0/a0/a6
	rts

line_2planes:
	movem.l	d0/a0-a1/a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	line_dest(pc),a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
.bytes:
	move.b	(a0)+,(a6)+
	move.b	(a1)+,1(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	addq.l	#3,a6
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0/a0-a1/a6
	rts

line_3planes:
	movem.l	d0/a0-a2/a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	(line_dest).l,a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
	movea.l	d0,a2
	adda.l	plane_bytes(pc),a2
.bytes:
	move.b	(a0)+,(a6)+
	move.b	(a1)+,1(a6)
	move.b	(a2)+,3(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	addq.l	#7,a6
	clr.w	-2(a6)
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0/a0-a2/a6
	rts

line_4planes:
	movem.l	d0/a0-a3/a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	(line_dest).l,a6
	move.l	a0,d0
	add.l	(plane_bytes).l,d0
	movea.l	d0,a1
	movea.l	d0,a2
	adda.l	(plane_bytes).l,a2
	movea.l	a2,a3
	adda.l	(plane_bytes).l,a3
.bytes:
	move.b	(a0)+,(a6)+
	move.b	(a1)+,1(a6)
	move.b	(a2)+,3(a6)
	move.b	(a3)+,5(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	move.b	(a3)+,6(a6)
	addq.l	#7,a6
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0/a0-a3/a6
	rts

line_5planes:
	movem.l	d0-d1/a0-a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	line_dest(pc),a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
	movea.l	d0,a2
	move.l	plane_bytes(pc),d1
	adda.l	d1,a2
	movea.l	a2,a3
	adda.l	d1,a3
	movea.l	a3,a4
	adda.l	d1,a4
.bytes:
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	move.b	(a3)+,6(a6)
	move.b	(a4)+,8(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,1(a6)
	move.b	(a1)+,3(a6)
	move.b	(a2)+,5(a6)
	move.b	(a3)+,7(a6)
	move.b	(a4)+,9(a6)
	clr.w	$a(a6)
	clr.l	$c(a6)
	lea		$10(a6),a6
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0-d1/a0-a6
	rts

line_6planes:
	movem.l	d0-d1/a0-a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	(line_dest).l,a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
	movea.l	d0,a2
	move.l	plane_bytes(pc),d1
	adda.l	d1,a2
	movea.l	a2,a3
	adda.l	d1,a3
	movea.l	a3,a4
	adda.l	d1,a4
	adda.l	d1,a4
.bytes:
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	move.b	(a3)+,6(a6)
	move.b	-1(a3,d1.w),8(a6)
	move.b	(a4)+,$a(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,1(a6)
	move.b	(a1)+,3(a6)
	move.b	(a2)+,5(a6)
	move.b	(a3)+,7(a6)
	move.b	-1(a3,d1.w),9(a6)
	move.b	(a4)+,$b(a6)
	clr.l	$c(a6)
	lea		$10(a6),a6
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0-d1/a0-a6
	rts

line_7planes:
	movem.l	d0-d1/a0-a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	(line_dest).l,a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
	movea.l	d0,a2
	move.l	plane_bytes(pc),d1
	adda.l	d1,a2
	movea.l	a2,a3
	adda.l	d1,a3
	movea.l	a3,a4
	adda.l	d1,a4
	adda.l	d1,a4
.bytes:
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	move.b	(a3)+,6(a6)
	move.b	-1(a3,d1.w),8(a6)
	move.b	(a4)+,$a(a6)
	move.b	-1(a4,d1.w),$c(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,1(a6)
	move.b	(a1)+,3(a6)
	move.b	(a2)+,5(a6)
	move.b	(a3)+,7(a6)
	move.b	-1(a3,d1.w),9(a6)
	move.b	(a4)+,$b(a6)
	move.b	-1(a4,d1.w),$d(a6)
	lea		$e(a6),a6
	clr.w	(a6)+
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0-d1/a0-a6
	rts

line_8planes:
	movem.l	d0-d1/a0-a6,-(a7)
	movea.l	line_source(pc),a0
	movea.l	(line_dest).l,a6
	move.l	a0,d0
	add.l	plane_bytes(pc),d0
	movea.l	d0,a1
	movea.l	d0,a2
	move.l	plane_bytes(pc),d1
	adda.l	d1,a2
	movea.l	a2,a3
	adda.l	d1,a3
	movea.l	a3,a4
	adda.l	d1,a4
	adda.l	d1,a4
	movea.l	a4,a5
	adda.l	d1,a5
	adda.l	d1,a5
.bytes:
	move.b	(a0)+,(a6)
	move.b	(a1)+,2(a6)
	move.b	(a2)+,4(a6)
	move.b	(a3)+,6(a6)
	move.b	-1(a3,d1.w),8(a6)
	move.b	(a4)+,$a(a6)
	move.b	-1(a4,d1.w),$c(a6)
	move.b	(a5)+,$e(a6)
	cmpa.l	d0,a0
	beq.s	.done
	move.b	(a0)+,1(a6)
	move.b	(a1)+,3(a6)
	move.b	(a2)+,5(a6)
	move.b	(a3)+,7(a6)
	move.b	-1(a3,d1.w),9(a6)
	move.b	(a4)+,$b(a6)
	move.b	-1(a4,d1.w),$d(a6)
	move.b	(a5)+,$f(a6)
	lea		$10(a6),a6
	cmpa.l	d0,a0
	bne.s	.bytes
.done:
	move.l	line_step(pc),d0
	add.l	d0,(line_dest).l
	movem.l	(a7)+,d0-d1/a0-a6
	rts

;	Monochrome IMG: unpacks the lines straight to the screen.

img_load_mono:
	move.l	#-1,(palette).l
	clr.l	(palette+4).l
	movea.l	file_buffer(pc),a0
	move.w	$e(a0),d3
	subq.w	#1,d3
	moveq	#0,d5
	move.w	screen_width(pc),d5
	lsr.w	#3,d5
	moveq	#0,d7
	move.w	$c(a0),d7
	addq.l	#7,d7
	lsr.w	#3,d7
	move.l	d5,d4
	sub.l	d7,d4
	move.w	6(a0),d6
	subq.l	#1,d6
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	add.l	a1,d7
	move.w	2(a0),d0
	add.w	d0,d0
	adda.w	d0,a0
.line:
	bsr.s	img_unpack_line
	add.l	d5,d7
	adda.l	d4,a1
	dbra	d3,.line
	rts

;	Unpacks IMG data from a0 to a1 up to d7: pattern runs, solid runs, bit
;	strings and vertical repeats (img_repeat). d6 = pattern length - 1.

img_unpack_line:
	tst.w	(img_repeat).l
	beq.s	.no_repeat
	subq.w	#1,(img_repeat).l
	movea.l	img_repeat_line(pc),a0
.no_repeat:
	tst.w	(a0)
	bne.s	.code
	addq.l	#3,a0
	move.b	(a0)+,(img_repeat+1).l
	subq.w	#1,(img_repeat).l
	move.l	a0,(img_repeat_line).l
.code:
	moveq	#0,d0
	move.b	(a0)+,d0
	bmi.s	.not_solid_white
	bne.s	.white
	move.b	(a0)+,d0
	subq.w	#1,d0
.pattern:
	move.w	d6,d1
	movea.l	a0,a2
.pattern_byte:
	move.b	(a2)+,(a1)+
	dbra	d1,.pattern_byte
	dbra	d0,.pattern
	movea.l	a2,a0
.next:
	cmpa.l	d7,a1
	blt.s	.code
	rts

.white:
	moveq	#0,d1
	subq.w	#1,d0
.white_byte:
	move.b	d1,(a1)+
	dbra	d0,.white_byte
	bra.s	.next
.not_solid_white:
	andi.w	#127,d0
	bne.s	.black
	move.b	(a0)+,d0
	subq.l	#1,d0
.raw_byte:
	move.b	(a0)+,(a1)+
	dbra	d0,.raw_byte
	bra.s	.next
.black:
	moveq	#-1,d1
	subq.w	#1,d0
.black_byte:
	move.b	d1,(a1)+
	dbra	d0,.black_byte
	bra.s	.next

;	Unpacks PackBits data from a0 to a1 until a1 reaches d7.

unpack_packbits:
	moveq	#0,d0
	move.b	(a0)+,d0
	bpl.s	.literal
	neg.b	d0
	move.b	(a0)+,d1
.repeat:
	move.b	d1,(a1)+
	dbra	d0,.repeat
.next:
	cmp.l	a1,d7
	bgt.s	unpack_packbits
	rts

.literal:
	move.b	(a0)+,(a1)+
	dbra	d0,.literal
	bra.s	.next

;	Degas compressed medium resolution (.PC2), lines doubled to 640 x 400.

pc2_load:
	movea.l	file_buffer(pc),a0
	addq.l	#2,a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#4,(pal_count).l
	bsr.w	st_palette
	bsr.w	picture_position
	movea.l	picture_start(pc),a2
	movea.l	file_buffer(pc),a0
	lea		$22(a0),a0
	move.w	#$c7,d2
.line:
	movea.l	line_source(pc),a1
	move.l	a1,d7
	addi.l	#$a0,d7
	bsr.s	unpack_packbits
	movea.l	line_source(pc),a1
	moveq	#39,d3
.word:
	move.w	(a1)+,(a2)+
	move.w	$4e(a1),(a2)+
	dbra	d3,.word
	move.w	#39,d3
.double:
	move.l	-$a0(a2),(a2)+
	dbra	d3,.double
	dbra	d2,.line
	rts

;	Degas compressed low resolution (.PC1).

pc1_load:
	movea.l	file_buffer(pc),a0
	addq.l	#2,a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.w	st_palette
	bsr.w	picture_position
	movea.l	picture_start(pc),a2
	movea.l	file_buffer(pc),a0
	lea		$22(a0),a0
	move.w	#$c7,d2
.line:
	movea.l	line_source(pc),a1					; v1.2: was lea, which unpacked
	move.l	a1,d7
	addi.l	#$a0,d7
	bsr.w	unpack_packbits
	movea.l	line_source(pc),a1					; over line_source and what follows.
	moveq	#19,d3
.block:
	move.w	(a1)+,(a2)+
	move.w	$26(a1),(a2)+
	move.w	$4e(a1),(a2)+
	move.w	$76(a1),(a2)+
	dbra	d3,.block
	lea		$a0(a2),a2
	dbra	d2,.line
	rts

;	Degas compressed high resolution (.PC3).

pc3_load:
	movea.l	file_buffer(pc),a0
	tst.w	2(a0)
	lea		palette(pc),a1
	beq.s	.black_background
	move.l	#$ffff00ff,(a1)+
	clr.l	(a1)+
	bra.s	.unpack
.black_background:
	clr.l	(a1)+
	move.l	#$ffff00ff,(a1)+
.unpack:
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	movea.l	file_buffer(pc),a0
	lea		$22(a0),a0
	move.w	#$18f,d2
.line:
	move.l	a1,d7
	addi.l	#80,d7
	bsr.w	unpack_packbits
	dbra	d2,.line
	rts

;	Doodle and Object Editor Mural: 32000 bytes of low resolution data, shown
;	with a fixed palette.

doodle_load:
	move.l	#doodle_palette,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.w	st_palette
	move.l	file_buffer(pc),(put_source).l
	move.l	screen(pc),(put_dest).l
	bsr.w	put_320x200
	rts

;	Art Director: 32000 bytes of low resolution data, then the palette.

art_load:
	movea.l	file_buffer(pc),a0
	lea		$7d00(a0),a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.w	st_palette
	move.l	file_buffer(pc),(put_source).l
	move.l	screen(pc),(put_dest).l
	bsr.w	put_320x200
	rts

;	Degas low resolution (.PI1).

pi1_load:
	movea.l	file_buffer(pc),a0
	addq.l	#2,a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.w	st_palette
	move.l	file_buffer(pc),d0
	addi.l	#34,d0
	move.l	d0,(put_source).l
	move.l	screen(pc),(put_dest).l
	bsr.w	put_320x200
	rts

;	Degas medium resolution (.PI2), lines doubled to 640 x 400.

pi2_load:
	movea.l	file_buffer(pc),a0
	addq.l	#2,a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#4,(pal_count).l
	bsr.w	st_palette
	movea.l	file_buffer(pc),a0
	lea		$22(a0),a0
	movea.l	screen(pc),a1
	move.w	#$c7,d2
.line:
	moveq	#39,d0
.longword:
	move.l	(a0)+,d1
	move.l	d1,(a1)+
	move.l	d1,$9c(a1)
	dbra	d0,.longword
	lea		$a0(a1),a1
	dbra	d2,.line
	rts

;	Degas high resolution (.PI3).

pi3_load:
	movea.l	file_buffer(pc),a0
	tst.w	2(a0)
	beq.s	.black_background
	move.l	#$ffff00ff,(palette).l
	clr.l	(palette+4).l
	bra.s	.copy
.black_background:
	clr.l	(palette).l
	move.l	#$ffff00ff,(palette+4).l
.copy:
	lea		$22(a0),a0
	movea.l	screen(pc),a1
	move.w	#$1f3f,d0
.longword:
	move.l	(a0)+,(a1)+
	dbra	d0,.longword
	rts

;	Extended Degas .PI4: 320 x 240 in 256 colours, Falcon palette first.

pi4_load:
	lea		palette(pc),a1
	movea.l	file_buffer(pc),a0
	moveq	#127,d0
.palette:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.palette
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	move.w	#$ef,d0
.line:
	moveq	#79,d1
.longword:
	move.l	(a0)+,(a1)+
	dbra	d1,.longword
	lea		$140(a1),a1
	dbra	d0,.line
	rts

;	Extended Degas .PI5: 640 x 480 in 256 colours, Falcon palette first.

pi5_load:
	lea		palette(pc),a1
	movea.l	file_buffer(pc),a0
	moveq	#127,d0
.palette:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.palette
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	move.l	#640*480/4-1,d0						; v1.2: was move.w #$9600,d0 and
.longword:										; dbra, which copied half of the
	move.l	(a0)+,(a1)+							; picture.
	subq.l	#1,d0
	bpl.s	.longword
	rts

;	Extended Degas .PI9: 320 x 240 in 256 colours, Falcon palette first.

pi9_load:
	lea		palette(pc),a1
	movea.l	file_buffer(pc),a0
	moveq	#127,d0
.palette:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	dbra	d0,.palette
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	move.w	#$ef,d0
.line:
	moveq	#79,d1
.longword:
	move.l	(a0)+,(a1)+
	dbra	d1,.longword
	lea		$140(a1),a1
	dbra	d0,.line
	rts

;	Neochrome (.NEO).

neo_load:
	movea.l	file_buffer(pc),a0
	addq.l	#4,a0
	move.l	a0,(pal_source).l
	move.l	#palette,(pal_dest).l
	move.w	#16,(pal_count).l
	bsr.s	st_palette
	move.l	file_buffer(pc),d0
	addi.l	#$80,d0
	move.l	d0,(put_source).l
	move.l	screen(pc),(put_dest).l
	bsr.s	put_320x200
	rts

;	Converts pal_count STE colours (4 bits per component) at pal_source to
;	Falcon palette entries at pal_dest.

st_palette:
	movem.l	d0-d3/a0-a1,-(a7)
	move.w	pal_count(pc),d0
	subq.l	#1,d0
	movea.l	pal_source(pc),a0
	movea.l	pal_dest(pc),a1
.colour:
	moveq	#0,d1
	moveq	#0,d2
	move.w	(a0),d1
	andi.w	#7,d1
	lsl.w	#5,d1
	or.w	d1,d2
	move.w	(a0),d1
	andi.w	#8,d1
	add.w	d1,d1
	or.w	d1,d2
	move.w	(a0),d1
	andi.w	#112,d1
	moveq	#17,d3
	lsl.l	d3,d1
	or.l	d1,d2
	move.w	(a0),d1
	andi.w	#$80,d1
	moveq	#13,d3
	lsl.l	d3,d1
	or.l	d1,d2
	move.w	(a0),d1
	andi.w	#$700,d1
	moveq	#21,d3
	lsl.l	d3,d1
	or.l	d1,d2
	moveq	#0,d1
	move.w	(a0)+,d1
	andi.w	#$800,d1
	moveq	#16,d3
	lsl.l	d3,d1
	add.l	d1,d1
	or.l	d1,d2
	move.l	d2,(a1)+
	dbra	d0,.colour
	movem.l	(a7)+,d0-d3/a0-a1
	rts

;	Copies a 320 x 200 picture in the screen's format from put_source to the
;	screen.

put_320x200:
	movem.l	d0-d3/a0-a1,-(a7)
	movea.l	put_source(pc),a0
	movea.l	put_dest(pc),a1
	bsr.w	picture_position
	movea.l	picture_start(pc),a1
	moveq	#40,d3
	mulu.w	screen_planes(pc),d3
	moveq	#10,d0
	mulu.w	screen_planes(pc),d0
	subq.l	#1,d0
	move.w	#$c7,d1
.line:
	move.l	d0,d2
.longword:
	move.l	(a0)+,(a1)+
	dbra	d2,.longword
	adda.l	d3,a1
	dbra	d1,.line
	movem.l	(a7)+,d0-d3/a0-a1
	rts


;____ Q16 support, added in v1.2 ____________________________________________
;
;	Q16 is RGB565 with optional 8-bit alpha, see q16_lib.h. The picture is
;	decoded with q_decPix and q_decAlp (q16dec.s) into temporary buffers
;	and copied to the screen.
;	Alpha is blended against black.

;	Header parser. a0 = format table entry.

q16_header:
	movea.l	file_buffer(pc),a1
	cmpi.l	#20,(file_size).l					; File size
	blo.w	exit
	cmpi.l	#'Q565',(a1)
	bne.w	exit
	cmpi.b	#1,4(a1)							; Version
	bne.w	exit
	move.w	6(a1),d0							; Width, little endian
	ror.w	#8,d0
	beq.w	exit
	cmp.w	#$7ff0,d0
	bhi.w	exit
	move.w	d0,(picture_width).l				; Real width
	addi.w	#15,d0
	andi.w	#$fff0,d0
	move.w	d0,6(a0)							; Width rounded up to 16 pixels
	move.w	8(a1),d0							; Height
	ror.w	#8,d0
	beq.w	exit
	move.w	d0,8(a0)
	move.w	#16,$a(a0)							; True color

	move.l	12(a1),d0							; pixelBytes
	ror.w	#8,d0
	swap	d0
	ror.w	#8,d0
	move.l	d0,(q16_pixel_bytes).l
	move.l	16(a1),d1							; alphaBytes
	ror.w	#8,d1
	swap	d1
	ror.w	#8,d1
	move.l	d1,(q16_alpha_bytes).l
	add.l	d1,d0
	bcs.w	exit
	addi.l	#20,d0
	bcs.w	exit
	cmp.l	(file_size).l,d0					; Header + data must fit in file.
	bhi.w	exit
	rts

;	Loader. Decodes the picture and copies it to the screen.

q16_load:
	bsr.w	picture_position					; Calculate screen position.
	movem.l	d2-d7/a2-a6,-(a7)

	moveq	#0,d7
	move.w	picture_width(pc),d7				; d7 = width
	movea.l	format(pc),a2
	moveq	#0,d6
	move.w	8(a2),d6							; d6 = height
	move.l	d7,d0
	mulu.l	d6,d0
	move.l	d0,(q16_pixels_count).l

	move.l	(q16_pixels_count).l,d0				; Pixels
	add.l	d0,d0
	move.l	d0,-(a7)
	move.w	#72,-(a7)							; Malloc
	trap	#1
	addq.l	#6,a7
	move.l	d0,(q16_pixels).l
	beq.w	.fail

	tst.l	(q16_alpha_bytes).l					; Alpha
	beq.s	.no_alpha
	move.l	(q16_pixels_count).l,-(a7)
	move.w	#72,-(a7)							; Malloc
	trap	#1
	addq.l	#6,a7
	move.l	d0,(q16_alpha).l
	beq.w	.fail
.no_alpha:

	move.l	(q16_pixels_count).l,-(a7)			; Decode pixels. q_decPix needs
	movea.l	file_buffer(pc),a3
	lea		20(a3),a3
	move.l	a3,d0
	add.l	(q16_pixel_bytes).l,d0
	move.l	d0,-(a7)
	move.l	a3,-(a7)							; no table, which would take
	move.l	(q16_pixels).l,-(a7)				; longer to set up than it saves
	bsr.w	q_decPix							; for one picture.
	lea		16(a7),a7
	tst.w	d0
	bne.w	.fail

	tst.l	(q16_alpha_bytes).l					; Decode alpha and blend.
	beq.s	.copy
	move.l	(q16_pixels_count).l,-(a7)
	adda.l	(q16_pixel_bytes).l,a3
	move.l	a3,d0
	add.l	(q16_alpha_bytes).l,d0
	move.l	d0,-(a7)
	move.l	a3,-(a7)
	move.l	(q16_alpha).l,-(a7)
	bsr.w	q_decAlp
	lea		16(a7),a7
	tst.w	d0
	bne.w	.fail
	bsr.w	q16_blend

.copy:
	movea.l	(q16_pixels).l,a0
	movea.l	picture_start(pc),a1
	movea.l	format(pc),a2
	moveq	#0,d1
	move.w	screen_width(pc),d1					; Screen width
	add.l	d1,d1								; d1 = bytes per screen line
	move.w	6(a2),d5
	sub.w	d7,d5								; d5 = padding up to 16 pixels
	subq.w	#1,d7
	move.w	d6,d3
	subq.w	#1,d3
.line:
	movea.l	a1,a3
	move.w	d7,d2
.pixel:
	move.w	(a0)+,(a3)+
	dbra	d2,.pixel
	move.w	d5,d2
	bra.s	.pad_test
.pad:
	clr.w	(a3)+
.pad_test:
	dbra	d2,.pad
	adda.l	d1,a1
	dbra	d3,.line

	bsr.s	q16_free
	movem.l	(a7)+,d2-d7/a2-a6
	rts

.fail:
	bsr.s	q16_free
	bra.w	exit

;	Frees the temporary buffers.

q16_free:
	lea		(q16_pixels).l,a3
	moveq	#1,d3
.loop:
	move.l	(a3),d0
	beq.s	.next
	clr.l	(a3)
	move.l	d0,-(a7)
	move.w	#73,-(a7)							; Mfree
	trap	#1
	addq.l	#6,a7
.next:
	addq.l	#4,a3
	dbra	d3,.loop
	rts

;	Blends the pixels against black using the alpha channel.

q16_blend:
	movem.l	d2-d7,-(a7)
	movea.l	(q16_pixels).l,a0
	movea.l	(q16_alpha).l,a1
	move.l	(q16_pixels_count).l,d7
	moveq	#11,d6
.loop:
	moveq	#0,d0
	move.b	(a1)+,d0
	cmp.b	#255,d0
	beq.s	.opaque
	tst.b	d0
	beq.s	.clear
	addq.w	#1,d0								; Multiply by (alpha + 1) / 256.
	move.w	(a0),d1
	move.w	d1,d2								; Red
	lsr.w	d6,d2
	mulu.w	d0,d2
	lsr.w	#8,d2
	lsl.w	d6,d2
	move.w	d1,d3								; Green
	lsr.w	#5,d3
	andi.w	#63,d3
	mulu.w	d0,d3
	lsr.w	#8,d3
	lsl.w	#5,d3
	or.w	d3,d2
	andi.w	#31,d1								; Blue
	mulu.w	d0,d1
	lsr.w	#8,d1
	or.w	d1,d2
	move.w	d2,(a0)+
	bra.s	.next
.clear:
	clr.w	(a0)+
	bra.s	.next
.opaque:
	addq.l	#2,a0
.next:
	subq.l	#1,d7
	bne.s	.loop
	movem.l	(a7)+,d2-d7
	rts

	include	"../m68k/q16dec.s"					; q_decPix, q_decAlp

	section	data
skip_shiftmode:									; Restore the ST shift mode on exit if 0
	dc.b	$ff,$ff
edge_masks:										; Masks for the last word of a line, by width & 15
	dc.b	$00,$00,$00,$00,$7f,$ff,$7f,$ff,$3f,$ff,$3f,$ff,$3f,$ff,$3f,$ff
	dc.b	$0f,$ff,$0f,$ff,$07,$ff,$07,$ff,$03,$ff,$03,$ff,$01,$ff,$01,$ff
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
	dc.b	$00,$ff,$00,$ff,$00,$7f,$00,$7f,$00,$3f,$00,$3f,$00,$1f,$00,$1f
	dc.b	$00,$0f,$00,$0f,$00,$07,$00,$07,$00,$03,$00,$03,$00,$01,$00,$01
format_table:									; Picture formats, see the description above
	dc.b	$2e,$50,$49,$31,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	pi1_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$49,$32,$00,$00,$02,$80,$01,$90,$00,$02
	dc.l	pi2_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$49,$33,$00,$00,$02,$80,$01,$90,$00,$01
	dc.l	pi3_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$4e,$45,$4f,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	neo_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$44,$4f,$4f,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	doodle_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$4d,$55,$52,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	doodle_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$49,$4d,$47,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.l	img_load
	dc.l	img_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$52,$41,$57
	dc.b	$00,$00,$ff,$ff,$ff,$ff,$00,$10
	dc.l	raw_load
	dc.l	raw_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$52,$41,$47
	dc.b	$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.l	rag_load
	dc.l	rag_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$42,$4d,$50
	dc.b	$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.l	bmp_load
	dc.l	bmp_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$50,$43,$33
	dc.b	$00,$00,$02,$80,$01,$90,$00,$01
	dc.l	pc3_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$43,$32,$00,$00,$02,$80,$01,$90,$00,$02
	dc.l	pc2_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$43,$31,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	pc1_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$41,$52,$54,$00,$00,$01,$40,$00,$c8,$00,$04
	dc.l	art_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$49,$46,$46,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.l	iff_load
	dc.l	iff_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$4d,$41,$43
	dc.b	$00,$00,$02,$40,$02,$d0,$00,$01
	dc.l	macpaint_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$4d,$50,$54,$00,$00,$02,$40,$02,$d0,$00,$01
	dc.l	macpaint_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$47,$49,$46,$00,$00,$ff,$ff,$ff,$ff,$00,$08
	dc.l	gif_load
	dc.l	gif_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$50,$49,$34
	dc.b	$00,$00,$01,$40,$00,$f0,$00,$08
	dc.l	pi4_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$49,$35,$00,$00,$02,$80,$01,$e0,$00,$08
	dc.l	pi5_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$50,$49,$39,$00,$00,$01,$40,$00,$f0,$00,$08
	dc.l	pi9_load
	dc.b	$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$2e,$54,$52,$55,$00,$00,$ff,$ff,$ff,$ff,$00,$10
	dc.l	tru_load
	dc.l	tru_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2e,$54,$47,$41
	dc.b	$00,$00,$ff,$ff,$ff,$ff,$ff,$ff
	dc.l	tga_load
	dc.l	tga_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	".Q16",$00,$00,$ff,$ff,$ff,$ff,$ff,$ff	; Q16, added in v1.2
	dc.l	q16_load
	dc.l	q16_header
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00						; End of table
mode_offsets:									; Offset of the video mode for each depth in the video tables
	dc.b	$00,$00,$00,$00,$00,$60,$00,$00,$00,$c0,$00,$00,$00,$00,$00,$00
	dc.b	$01,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$01,$80
high_res:										; 1 = high resolution (640 wide), 0 = low
	dc.b	$00,$01
scroll_dx:										; Scroll speed (mouse and cursor keys), pixels
	dc.b	$00,$00
scroll_dy:
	dc.b	$00,$00
scroll_x:										; Top left of the visible part of the screen
	dc.b	$00,$00
scroll_y:
	dc.b	$00,$00
scroll_min_x:									; Scroll limits
	dc.b	$00,$00
scroll_min_y:
	dc.b	$00,$00
scroll_max_x:
	dc.b	$00,$00
scroll_max_y:
	dc.b	$00,$00
line_offset:									; Videl line offset for the screen width
	dc.b	$00,$00
vbl_line_offset:								; Line offset, fine scroll and screen address
	dc.b	$00,$00
vbl_hscroll:									; for the next VBL
	dc.b	$00,$00
vbl_screen:
	dc.b	$00
	dc.b	$00
	dc.b	$00
	dc.b	$00
video_saved:									; 1 when save_video has run
	dc.b	$00,$00
monitor:										; -1 = VGA, 1 = NTSC, 0 = PAL
	dc.b	$00,$00
greyscale:										; Bit 0 set: grey palette shown
	dc.b	$00
	dc.b	$00
name_bin:										; Files written by save_picture
	dc.b	"SAVEDPIC.BIN",$00
name_pal:
	dc.b	"SAVEDPIC.PAL",$00
name_txt:
	dc.b	"SAVEDPIC.TXT",$00
info_text:										; Text for SAVEDPIC.TXT
	dc.b	"0000 X "
info_height:
	dc.b	"0000 pixels, "
info_colours:
	dc.b	"000 colors."
picture_width:									; Real width of the picture in pixels
	dc.b	$00,$00
video_vga:										; Video modes, 48 bytes each, see set_video
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$00,$c6,$00,$8d,$00,$15,$02,$73
	dc.b	$00,$50,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$17,$00,$12,$00,$01,$02,$0a
	dc.b	$00,$09,$00,$11,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$17,$00,$12,$00,$01,$02,$0e
	dc.b	$00,$0d,$00,$11,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$c6,$00,$8d,$00,$15,$02,$8a
	dc.b	$00,$6b,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$00,$00,$c6,$00,$8d,$00,$15,$02,$a3
	dc.b	$00,$7c,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$10,$00,$c6,$00,$8d,$00,$15,$02,$9a
	dc.b	$00,$7b,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$00,$c6,$00,$8d,$00,$15,$02,$ab
	dc.b	$00,$84,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$08,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$c6,$00,$8d,$00,$15,$02,$ac
	dc.b	$00,$91,$00,$96,$00,$00,$00,$00,$04,$19,$03,$ff,$00,$3f,$00,$3f
	dc.b	$03,$ff,$04,$15,$01,$86,$00,$05,$00,$00,$02,$00,$00,$00,$00,$00
video_pal:										; and mode_offsets: 1 plane high resolution,
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$01,$fe,$01,$99,$00,$50,$03,$ef
	dc.b	$00,$a0,$01,$b2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2f,$00,$7e
	dc.b	$02,$0e,$02,$6b,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$3e,$00,$30,$00,$08,$02,$39
	dc.b	$00,$12,$00,$34,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2f,$00,$7f
	dc.b	$02,$0f,$02,$6b,$01,$81,$00,$00,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$3e,$00,$30,$00,$08,$00,$02
	dc.b	$00,$20,$00,$34,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2f,$00,$7e
	dc.b	$02,$0e,$02,$6b,$01,$81,$00,$06,$00,$00,$02,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$fe,$00,$cb,$00,$27,$00,$0c
	dc.b	$00,$6d,$00,$d8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2f,$00,$7f
	dc.b	$02,$0f,$02,$6b,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$00,$01,$fe,$01,$99,$00,$50,$00,$4d
	dc.b	$00,$fe,$01,$b2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2f,$00,$7e
	dc.b	$02,$0e,$02,$6b,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$10,$00,$fe,$00,$cb,$00,$27,$00,$1c
	dc.b	$00,$7d,$00,$d8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2f,$00,$7f
	dc.b	$02,$0f,$02,$6b,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$01,$fe,$01,$99,$00,$50,$00,$5d
	dc.b	$01,$0e,$01,$b2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2f,$00,$7e
	dc.b	$02,$0e,$02,$6b,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$fe,$00,$cb,$00,$27,$00,$2e
	dc.b	$00,$8f,$00,$d8,$00,$00,$00,$00,$02,$71,$02,$65,$00,$2f,$00,$7f
	dc.b	$02,$0f,$02,$6b,$01,$81,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
	dc.b	$00,$00,$02,$80,$00,$00,$01,$00,$01,$fe,$01,$99,$00,$50,$00,$71
	dc.b	$01,$22,$01,$b2,$00,$00,$00,$00,$02,$70,$02,$65,$00,$2f,$00,$7e
	dc.b	$02,$0e,$02,$6b,$01,$81,$00,$06,$00,$00,$02,$00,$00,$00,$00,$00
video_ntsc:										; then 2, 4, 8, 16 bits low and high (VGA: no 16 high)
	dc.b	$00,$00,$00,$28,$00,$00,$04,$00,$01,$ff,$01,$97,$00,$50,$03,$f0
	dc.b	$00,$9f,$01,$b4,$00,$00,$00,$00,$02,$0c,$02,$01,$00,$16,$00,$4c
	dc.b	$01,$dc,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$28,$00,$00,$00,$00,$00,$3e,$00,$30,$00,$08,$02,$39
	dc.b	$00,$12,$00,$34,$00,$00,$00,$00,$02,$0d,$02,$01,$00,$16,$00,$4d
	dc.b	$01,$dd,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$3e,$00,$30,$00,$08,$00,$02
	dc.b	$00,$20,$00,$34,$00,$00,$00,$00,$02,$0c,$02,$01,$00,$16,$00,$4c
	dc.b	$01,$dc,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$01,$00,$00,$00
	dc.b	$00,$00,$00,$50,$00,$00,$00,$00,$00,$fe,$00,$c9,$00,$27,$00,$0c
	dc.b	$00,$6d,$00,$d8,$00,$00,$00,$00,$02,$0d,$02,$01,$00,$16,$00,$4d
	dc.b	$01,$dd,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$00,$01,$ff,$01,$97,$00,$50,$00,$4d
	dc.b	$00,$fd,$01,$b4,$00,$00,$00,$00,$02,$0c,$02,$01,$00,$16,$00,$4c
	dc.b	$01,$dc,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$a0,$00,$00,$00,$10,$00,$fe,$00,$c9,$00,$27,$00,$1c
	dc.b	$00,$7d,$00,$d8,$00,$00,$00,$00,$02,$0d,$02,$01,$00,$16,$00,$4d
	dc.b	$01,$dd,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$00,$10,$01,$ff,$01,$97,$00,$50,$00,$5d
	dc.b	$01,$0d,$01,$b4,$00,$00,$00,$00,$02,$0c,$02,$01,$00,$16,$00,$4c
	dc.b	$01,$dc,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$01,$40,$00,$00,$01,$00,$00,$fe,$00,$c9,$00,$27,$00,$2e
	dc.b	$00,$8f,$00,$d8,$00,$00,$00,$00,$02,$0d,$02,$01,$00,$16,$00,$4d
	dc.b	$01,$dd,$02,$07,$01,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$02,$80,$00,$00,$01,$00,$01,$ff,$01,$97,$00,$50,$00,$71
	dc.b	$01,$21,$01,$b4,$00,$00,$00,$00,$02,$0c,$02,$01,$00,$16,$00,$4c
	dc.b	$01,$dc,$02,$07,$01,$81,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00
file_buffer:									; The picture file
	dc.b	$00,$00,$00,$00
screen:											; The screen, aligned to a long word
	dc.b	$00
	dc.b	$00
	dc.b	$00
	dc.b	$00
palette:										; Picture palette, Falcon format: R, G, 0, B
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
unused_tga_buffer:								; RLE Targa buffer in version 1.1, unused
	dc.b	$00,$00,$00,$00
	dc.l	palette
gif_pixels:										; Where gif_unpack writes the pixels
	dc.b	$00,$00,$00,$00
gif_info:										; Descriptors from gif_parse, +10 = image width
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00
line_routines:									; Line routine by number of planes - 1, see line_16bit
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
line_step:										; Bytes per screen line
	dc.b	$00,$00,$00,$00
line_dest:										; Screen line to write
	dc.b	$00,$00,$00,$00
line_source:									; Line to convert, the line buffer by default
	dc.l	line_buffer
plane_bytes:									; Bytes per line and plane
	dc.b	$00,$00,$00,$00
img_repeat:										; IMG vertical repeat count (byte at img_repeat+1)
	dc.b	$00
	dc.b	$00
img_repeat_line:								; IMG line to repeat
	dc.b	$00,$00,$00,$00
doodle_palette:									; Fixed palette for Doodle pictures, STE format
	dc.b	$0f,$ff,$0f,$00,$00,$f0,$0f,$f0,$00,$0f,$0f,$0f,$00,$ff,$0d,$dd
	dc.b	$04,$44,$05,$00,$00,$50,$05,$50,$00,$05,$05,$05,$00,$55,$00,$00
title_text:										; Printed at start
	dc.b	"The SHOWER picture-viewer v1.2.",$0a,$0d
	dc.b	"-------------------------------",$0a,$0d,$0a
	dc.b	"Functions & Controls",$0d,$0a,"--------------------",$0d,$0a
	dc.b	$0a,"Mouse &",$0d,$0a
	dc.b	"Cursor Keys          Scroll around large picture",$0d,$0a,$0a
	dc.b	"Space & Right",$0d,$0a,"Mousebutton          Quit",$0d,$0a,$0a
	dc.b	"Plus/minus & Left",$0d,$0a
	dc.b	"Mousebutton          Switch resolution",$0d,$0a,$0a
	dc.b	"F1                   Switch between Color/BW",$0d,$0a,$0a
	dc.b	"F2                   Switch between dark/bright frame",$0d,$0a
	dc.b	$0a,"Contr + Alt + F10    Save screen/color-dump",$0d,$0a,$0a
	dc.b	$0a,"Written by Blade of New Core in 100% assembler.",$0d,$0a
	dc.b	"GIF-Depacker by Sascha Springer.",$0d,$0a
	dc.b	"Q16 support added in 2026.",$0d,$0a,$00
	dc.b	$00

	section	bss
border_colour:									; Colour around small pictures
	ds.b	2
darkest_colour:
	ds.b	2
brightest_colour:
	ds.b	2
screen_line_bytes:								; Bytes per screen line
	ds.b	2
picture_line_bytes:								; Bytes per picture line
	ds.b	2
border_top:										; Lines above the picture - 1, or -1
	ds.b	2
border_sides:									; Picture lines - 1, or -1 if no side borders
	ds.b	2
border_left:									; Words - 1 left of the picture
	ds.b	2
border_right:									; Words - 1 right of the picture
	ds.b	2
border_bottom:									; Lines below the picture - 1, or -1
	ds.b	2
video_table:									; video_vga, video_pal or video_ntsc (+1 unused byte)
	ds.b	5
mouse_buttons:									; Header byte of the last mouse packet
	ds.b	1
cmdline:										; Command line: the picture file name
	ds.b	4
file_handle:
	ds.b	2
file_size:
	ds.b	4
file_extension:									; For example ".GIF"
	ds.b	4
format:											; Format table entry of the picture
	ds.b	4
old_hscroll:									; Saved video state
	ds.b	2
old_line_offset:
	ds.b	2
old_mousevec:
	ds.b	4
kbdvecs:										; From Kbdvbase
	ds.b	4
old_physbase:
	ds.b	1
	ds.b	1
	ds.b	1
	ds.b	1
old_palette:
	ds.b	1024
screen_size:									; In bytes
	ds.b	4
screen_block:									; Screen memory block for Mfree
	ds.b	4
screen_width:									; Screen size: at least 640 x 480
	ds.b	2
screen_height:
	ds.b	2
screen_planes:									; 1, 2, 4, 8 or 16
	ds.b	2
old_vbl:
	ds.b	4
dta:											; For Fsfirst
	ds.b	44
old_video:										; Videl registers saved by save_video
	ds.b	44
old_shiftmode:									; Must follow old_video, see restore_video
	ds.b	4
line_buffer:									; One unpacked line, also the LZW stack
	ds.b	4096
gif_parsed:										; gif_parse's output
	ds.b	2048
picture_start:									; Screen address of the picture, see picture_position
	ds.b	4
gif_info_ptr:									; Where gif_unpack copies the descriptors
	ds.b	4
work_tables:									; LZW string table, then the c2p tables
	ds.b	2048
	ds.b	14336
iff_bmhd:										; Address of the BMHD chunk
	ds.b	4
c2p_source:										; c2p_line parameters
	ds.b	4
c2p_dest:
	ds.b	4
c2p_blocks:
	ds.b	2
raw_pixels:										; POV raw pixels (v1.2: was 2 bytes)
	ds.b	4
img_line_bytes:									; Bytes per IMG line, all planes
	ds.b	4
pal_source:										; st_palette parameters
	ds.b	4
pal_dest:
	ds.b	4
pal_count:
	ds.b	2
put_source:										; put_320x200 parameters
	ds.b	4
put_dest:
	ds.b	4
tga_buffer:										; v1.2: RLE Targa buffer
	ds.b	4
bmp_top_down:									; v1.2: BMP stored top-down
	ds.b	2
gif_interlaced:									; v1.2: GIF is interlaced
	ds.b	2
gif_buffer:										; v1.2: buffer for interlaced GIF
	ds.b	4
q16_pixel_bytes:
	ds.b	4
q16_alpha_bytes:
	ds.b	4
q16_pixels_count:
	ds.b	4
q16_pixels:										; q16_pixels and q16_alpha must
	ds.b	4									; stay together, see q16_free.
q16_alpha:
	ds.b	4
