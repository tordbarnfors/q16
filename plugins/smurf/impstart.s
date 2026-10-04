; Startup code for Smurf import modules (.SIM), gcc version.
;
; Smurf loads the module with Pexec mode 3 and expects, from the start of
; the TEXT segment: an exit for when it's run directly, a branch to the
; main function at +4, the magic "SIMD" at +8, a pointer to module_info
; at +12 and the interface version at +16.

	SECTION	TEXT

	XREF	imp_module_main
	XREF	module_info
	XDEF	_errno

	clr.w	-(sp)			; Pterm0 if started as a program.
	trap	#1
	bra.w	imp_module_main
	dc.l	'SIMD'
	dc.l	module_info
	dc.l	$0101

	SECTION	DATA

_errno:	dc.l	0
