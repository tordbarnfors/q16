; Startup code for Smurf export modules (.SXM).
;
; As for import modules, with the magic "SXMD" at +8, module_info at +12,
; module_ability at +16 and the interface version at +20.
;
; Assembled with PUREC_SMURF defined for Smurf built with Pure C, which
; passes the GARGAMEL pointer in A0 and expects the result in A0.

	SECTION	TEXT

	XREF	exp_module_main
	XREF	module_info
	XREF	module_ability
	XDEF	_errno

	clr.w	-(sp)			; Pterm0 if started as a program.
	trap	#1
	IFD	PUREC_SMURF
	bra.w	pc_entry
	ELSE
	bra.w	exp_module_main
	ENDC
	dc.l	'SXMD'
	dc.l	module_info
	dc.l	module_ability
	dc.l	$0101

	IFD	PUREC_SMURF

;	EXPORT_PIC *exp_module_main( GARGAMEL *smurf_struct /* A0 */ ), result in A0.

pc_entry:
	move.l	a0,-(sp)
	jsr	exp_module_main
	addq.l	#4,sp
	move.l	d0,a0
	rts

	ENDC

	SECTION	DATA

_errno:	dc.l	0
