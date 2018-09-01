
VER:	MACRO
	dc.b "1"			; Versionnumber
	ENDM
REV:	MACRO
	dc.b "0"			; Revisionmumber
	ENDM

VERSION:	MACRO
	dc.b	"V"			; Generates versionstring.
	VER
	dc.b	"."
	REV
	ENDM

EDITION:	MACRO
;	dc.b	" - Revision Edition"
	ENDM

PUSH:	MACRO
	movem.l a0-a6/d0-d7,-(a7)	;Store all registers in the stack
	ENDM

POP:	MACRO
	movem.l (a7)+,a0-a6/d0-d7	;Restore the registers from the stack
	ENDM

TOGGLEPWRLED: MACRO
	bchg	#1,$bfe001
	ENDM
	
PAROUT: MACRO
	move.b	\1,$bfe101
	ENDM
	
VBLT:		MACRO
.vblt\@		btst	#14,$dff002
		bne.s	.vblt\@
		ENDM

rom_base:	equ $f80000		; Originate as if data is in ROM

LOWRESSize:	equ	40*256
HIRESSize:	equ	80*512

; Then some different modes for the assembler

rommode =	1				; Set to 1 if to assemble as being in ROM
a1k =		0				; Set to 1 if to assemble as for being used on A1000 (64k memrestriction)
debug = 	0				; Set to 1 to enable some debugshit in code
amiga = 	0 				; Set to 1 to create an amiga header to write the ROM to disk


