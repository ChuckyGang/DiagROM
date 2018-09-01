;APS00000030000000300002B71E0002C0CF0002C0CF0002C0CF0002C0CF0002C0CF0002C0CF0002C0CF
;
; DiagROM by John "Chucky" Hertell
;

; A6 is ONLY to be used as a memorypointer to variables etc. so never SET a6 in the code.
; First some definitions.

; obscene words like "kuk" marks really bad code or temporary crap.. just look away.

	INCLUDE settings.i

	ifne rommode
	ifeq amiga
	;;  if we are spitting out a rom directly then we need to make sure
	;; vasm doesnt try to write out a section at the origin.
	;; this is a bit of a hack to make the 
	org rom_base
	endc
	endc

	
	PRINTT
	PRINTT "Diagrom Assembling... Statistics: "
	PRINTT
	PRINTT Romcodesize:
	PRINTV EndRom-TheStart	
	PRINTT
	PRINTT Variablespace:
	PRINTV C-V
	PRINTT
	PRINTT Workspace:
	PRINTV EndData-V	
	PRINTT
	PRINTT "Total Chipmem usage:"
	PRINTV EndData-Variables
	PRINTT
	PRINTT

	ifne	rommode
						; If we are in ROM Mode and start.
						; just save the file to disk.
	ifne	amiga

						; First lets fix some checksums
	move.l	#Checksums-rom_base,d0
	lea	a,a0
	move.l	a0,a1
	add.l	d0,a1				; a1 should now point to where checksums starts in memory
	move.l	a1,d1				; Store startaddress of checksums in d1
	move.l	d1,d2
	add.l	#EndChecksums-Checksums,d2	; Store endaddress of checksums in d2
	
	clr.l	d3
	
	move.l	#7,d6

.romcheckloop2:
	move.l	#0,d0				; Clear D0 that calculates the checksum
	move.l	#$3fff,d7
.romcheckloop:
	cmp.l	d1,a0
	bhi	.higher
	bra	.not
.higher:					; ok we are above checksums.
	cmp.l	d2,a0				; are we lower then end of checksums
	bhi	.not				; no. so we will do checksumcalculations
	add.l	#1,d3
	add.l	#4,a0
	bra	.nocalc
.not:

	add.l	(a0)+,d0
.nocalc:
	dbf	d7,.romcheckloop
.endromcheck:
	move.l	d0,(a1)+
	dbf	d6,.romcheckloop2
.slut:						; Checksums is calculated and put into code.
SaveFile:
	lea	.filnamn,a5
	move.l	$4,a6
	lea	Dos,a1
	jsr	-408(a6)
	move.l	d0,a6
	move.l	a5,d1
	jsr	-72(a6)				; Delete file
	move.l	a5,d1
	move.l	#1006,d2
	jsr	-30(a6)
	beq	.Error
	move.l	d0,.Peekare
	move.l	d0,d1
	move.l	#a,d2
	move.l	#b-a,d3
	jsr	-48(a6)

	move.l	.Peekare,d1
	jsr	-36(a6)
	clr.l	d0
	rts

.Error:
	move.l	#-1,d0
	rts

.Peekare:
	dc.l	0
.filnamn:
	ifeq	a1k
		dc.b	"DiagROM/DiagROM",0
	else
		dc.b	"DiagROM/DiagROMA1k",0
	endc
Dos:
	dc.b	"dos.library",0

a:	equ $45000000		; YES! this is as dirty as yesterdays underwear, but needed..  do not do this if you care about other running stuff.. OK?

		ifeq	a1k
b:	equ a+512*1024
		else
b:	equ a+64*1024
		endc

	endc			; end the amiga writer header.

	org rom_base		; Originate as if data is in ROM

	ifne	amiga           ; 
	load a			; PUT Data in where A points to, change this to a safe location for your machine.
	endc

START:

	PRINTT
	PRINTT "--------------------------------- ROMMMODE ENABLED ---------------------------------"
	PRINTT

	dc.w $1114		; this just have to be here for ROM. code starts at $2

	endc

	INCLUDE main.s
	
