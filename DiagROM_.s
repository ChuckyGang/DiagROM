;APS00000036000000360002BCCB00000036000000360000003600000036000000360000003600000036
;
;
; DiagROM by John "Chucky" Hertell
;

; A6 is ONLY to be used as a memorypointer to variables etc. so never SET a6 in the code.
; First some definitions.

; Segment type:	Pure code
; segment "ROM"
_custom         	EQU     $dff000
intenar     		EQU   	$01C
intena			EQU    	$09A


	;; IDE interface 
IDE_Slow	EQU	$da0000
AT_Data		EQU	$00		; 16 bit wide port
AT_Error	EQU	$04		; error register
AT_SectorCnt	EQU	$08		; # of sectors, 0 = 256
AT_SectorNum	EQU	$0c		; sector to start (1-based!)
AT_CylLow	EQU	$10		; low byte of Cylinder number
AT_CylHigh	EQU	$14		; high byte
AT_DriveHead	EQU	$18		; Drive and head number | $A0
AT_Status	EQU	$1c		; (read) status reg, clears interrupt
AT_Command	EQU	$1c		; (write) command value, starts it
AT_AltStatus	EQU	$1018		; (read) alt status, doesn't clear int
AT_DeviceCtrl	EQU	$1018		; (write) device control - int/reset
AT_DriveAddress	EQU	$101c		; not used (pc-ish)
AT_IntStatus	EQU	$1000		; interrupt status bit, active low

; Gayle address and offsets
GAYLE_ADDR	EQU	$da8000
GAYLE_ID_ADDR	EQU	$de1000
GAYLE_VERSION	EQU	%00001101	; version 1101 (first)
GAYLE_IntStatus	EQU	0
GAYLE_IntChange	EQU	$1000
GAYLE_IntEnable	EQU	$2000
GAYLE_Control	EQU	$3000


FPCR    	EQU     $1000
FPSR    	EQU     $0800
FPIAR   	EQU     $0400

PRINT		macro
		lea	(\1).l,a0
		lea	(.r_\@).l,a1
		jmp	DumpSerial
.r_\@
		endm

SPRINT		macro
		movem.l d0-d7/a0-a4,-(sp)
		PRINT  \1
		movem.l (sp)+,d0-d7/a0-a4
		endm

	
CONVHEX        macro
	       lea	(.r_\@).l,a1
	       jmp	bin2hex
.r_\@
	       endm

PRINTHEX       macro
	       move.w  d0,d1
	       lea	(.r1_\@).l,a1
	       jmp	bin2hex
.r1_\@
	       lea	(.r2_\@).l,a1
	       jmp	charout
.r2_\@
	       lsr     #8,d1
	       lea	(.r3_\@).l,a1
	       jmp	charout
.r3_\@
	       endm

SPRINTHEX      macro
	       movem.l d0-d7/a0-a4,-(sp)
	       move.w  d0,d1

	       lea	(.r1_\@).l,a1
	       jmp	bin2hex
.r1_\@
	       lea	(.r2_\@).l,a1
	       jmp	charout
.r2_\@
	       lsr     #8,d1
	       lea	(.r3_\@).l,a1
	       jmp	charout
.r3_\@
	       movem.l (sp)+,d0-d7/a0-a4
	       endm

	
CHAROUT        macro
	       move    #\1,d1
	       lea	(.r_\@).l,a1
	       jmp	charout
.r_\@
	       endm


SCHAROUT        macro
	       movem.l d0-d7/a0-a4,-(sp)
	       move    #\1,d1
	       lea	(.r_\@).l,a1
	       jmp	charout
.r_\@
	       movem.l (sp)+,d0-d7/a0-a4
	       endm


CHAROUTD       macro
	       move    d0,d1
	       lea	(.r_\@).l,a1
	       jmp	charout
.r_\@
	       endm



	
	;; This will write out the contents of D0 to serial as hex 
	;;  
PRINTHEX16     macro
	
	       move.w  d0,d1
	       lsr     #8,d1
	       lea	(.r1_\@).l,a1
	       jmp	bin2hex
.r1_\@
	       lea	(.r2_\@).l,a1
	       jmp	charout
.r2_\@
	       lsr     #8,d1
	       lea	(.r3_\@).l,a1
	       jmp	charout
.r3_\@
	       move.w  d0,d1
	       lea	(.r4_\@).l,a1
	       jmp	bin2hex
.r4_\@
	       lea	(.r5_\@).l,a1
	       jmp	charout
.r5_\@
	       lsr     #8,d1
	       lea	(.r6_\@).l,a1
	       jmp	charout
.r6_\@
	       endm

SPRINTHEX32	macro
		movem.l d0-d7/a0-a4,-(sp)
	        swap d0
                SPRINTHEX16
		swap d0
                SPRINTHEX16
		movem.l (sp)+,d0-d7/a0-a4
		endm

	

SPRINTHEX16	macro
		movem.l d0-d7/a0-a4,-(sp)
		PRINTHEX16
		movem.l (sp)+,d0-d7/a0-a4
		endm
	
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

	org rom_base
; Then some different modes for the assembler


rommode =	1				; Set to 1 if to assemble as being in ROM
a1k =		0				; Set to 1 if to assemble as for being used on A1000 (64k memrestriction)
debug = 	0				; Set to 1 to enable some debugshit in code
amiga = 	0 				; Set to 1 to create an amiga header to write the ROM to disk

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
	

LOWRESSize:	equ	40*256
HIRESSize:	equ	80*512


	org rom_base		; Originate as if data is in ROM

	ifne	amiga           ; 
	;; load a			; PUT Data in where A points to, change this to a safe location for your machine.
	endc

START:

	PRINTT
	PRINTT "--------------------------------- ROMMMODE ENABLED ---------------------------------"
	PRINTT

	dc.w $1114		; this just have to be here for ROM. code starts at $2




; Lets start the code..  with a jump
TheStart:
	jmp	Begin

	dc.l	POSTBusError				; Hardcoded pointers
	dc.l	POSTAddressError			; if something is wrong rom starts at $0
	dc.l	POSTIllegalError			; so this will actually be pointers to
	dc.l	POSTDivByZero				; traps.
	dc.l	POSTChkInst
	dc.l	POSTTrapV
	dc.l	POSTPrivViol
	dc.l	POSTTrace
	dc.l	POSTUnimplInst

strstart:
	DC.B	"IHOL : :6U6U,A,B1U1U5767U,U,8181 1 0    "	; This string will make a readable text on each 32 bit
	DC.B	"HILO: : U6U6A,B,U1U17576,U,U18181 0     "	; rom what socket to use. (SOME programmingsoftware does byteshift so both orders)

	dc.b	"$VER: DiagROM Amiga Diagnostic by John Hertell. "
	dc.b	"www.diagrom.com "
	incbin	"BuildDate.txt"
	dc.b	"- "
	VERSION
strstop:

	blk.b	166-(strstop-strstart),0		; Crapdata that needs to be here

	EVEN

Begin:	


	ifne	rommode
; Code in ROM mode


	lea	$400,SP			; Set the stack. BUT!!! do not use it yet. we need to check chipmem first!

	move.b	#$ff,$bfe200
	move.b	#$ff,$bfe300



	move.b	#0,$bfe001			; Clear register.
	move.b	#$ff,$bfe301
	move.b	#$0,$bfe101
	move.b	#3,$bfe201	
	move.b	#0,$bfe001		; Powerled will go ON! so user can see that CPU works
	move.b	#$40,$bfed01

					; Lets check status of mousebuttons at start.  AAAND we have ONE register not used in
	move.l	#POSTBusError,$8
	move.l	#POSTAddressError,$c
	move.l	#POSTIllegalError,$10
	move.l	#POSTDivByZero,$14
	move.l	#POSTChkInst,$18
	move.l	#POSTTrapV,$1c
	move.l	#POSTPrivViol,$20
	move.l	#POSTTrace,$24
	move.l	#POSTUnimplInst,$28
	move.l	#POSTUnimplInst,$2c

					; all code.  A4.. so lets store the result therea
			
	move.b	#$88,$bfed01
	or.b	#$40,$bfee01		; For keyboard
					; We will print the result on the serialport later.
					
	move.l	#0,d0			; Make sure D0 is cleared.
	

	btst	#6,$bfe001		; Check LMB port 1
	bne	.NOP1LMB		; NOT pressed.. Skip to next
	bset	#0,d0
.NOP1LMB:
	btst	#7,$bfe001		; Check LMB port 2
	bne	.NOP2LMB
	bset	#1,d0
.NOP2LMB:
	btst	#10,$dff016		; Check RMB port 1
	bne	.NOP1RMB
	bset	#2,d0
.NOP1RMB:
	btst	#14,$dff016		; Check RMB port 2
	bne	.NOP2RMB
	bset	#3,d0
.NOP2RMB:

	move.l	d0,a4			; OK Store the result in a4 (YEAH I know it is not used for data.. but  no mem.. and only register not used)

	lea	AnsiNull,a0		; Clear screen, clear ansi attributes, set default color
	lea	.jmp0,a1
	jmp	DumpSerial		; Dump to serial, after it jump to where a1 points at.
.jmp0:


	lea	InitSerial,a0
	lea	.jmp1,a1
	jmp	DumpSerial		; Dump to serial, after it jump to where a1 points at.
.jmp1:

	move.w	#$aaa,$dff180		; Set screen to light grey

	lea	.cleardone,a0
	jmp	DumpClearSerial
.cleardone:



	lea	LoopSerTest,a0
	lea	.loopdone,a1
	jmp	DumpSerial
.loopdone:
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	TOGGLEPWRLED

	clr.l	d6			; Clear D6, if this is anything else than 0 efter loopbacktest, we had an echo (adapter)
	
	move.l	#"<",d2
	lea	.looptst1,a0
	jmp	Loopbacktest
.looptst1:
	move.w	#$777,$dff180		; Set screen to light grey
	TOGGLEPWRLED
	move.l	#">",d2
	lea	.looptst2,a0
	jmp	Loopbacktest
.looptst2:
	move.w	#$555,$dff180		; Set screen to light grey
	TOGGLEPWRLED
	cmp.b	#0,d6
	beq	.noadapter


	lea	DDETECTED,a0
	lea	.loopdetect,a1
	jmp	DumpSerial
.loopdetect:

					; ok we had detected a loopback, lets mark it in our "secret" register (in A4 now) by setting bit 4
	move.l	a4,d0
	bset	#4,d0
	move.l	d0,a4			; ok we have restored it in A4 now.

	bra	.goon

.noadapter:
	lea	NoLoopback,a0
	lea	.nodetect,a1
	jmp	DumpSerial
.nodetect:


.goon:
	move.l	a4,$4


	PAROUT #$ff			; Send #$ff to Paralellport.
	lea	parfftxt,a0		; And explaining simliar text to serialport.
	lea	.jmp2,a1
	jmp	DumpSerial
.jmp2:
	lea	Initmousetxt,a0
	lea	.jmp3,a1
	jmp	DumpSerial
.jmp3:
	move.l	a4,d0
	btst	#0,d0
	beq	.noP1LMB
	lea	InitP1LMBtxt,a0
	lea	.noP1LMB,a1
	jmp	DumpSerial
.noP1LMB:
	btst	#1,d0
	beq	.noP2LMB
	lea	InitP2LMBtxt,a0
	lea	.noP2LMB,a1
	jmp	DumpSerial
.noP2LMB:
	btst	#2,d0
	beq	.noP1RMB
	lea	InitP1RMBtxt,a0
	lea	.noP1RMB,a1
	jmp	DumpSerial
.noP1RMB:
	btst	#3,d0
	beq	.noP2RMB
	lea	InitP2RMBtxt,a0
	lea	.noP2RMB,a1
	jmp	DumpSerial
.noP2RMB:
	lea	NewLineTxt,a0
	lea	.mousedone,a1
	jmp	DumpSerial
		
.mousedone:
	lea	InitINTENAtxt,a0
	lea	.jmp4,a1
	jmp	DumpSerial
.jmp4:	
	move.w	#$7fff,$dff09a		; Disable all INTENA

	lea	InitDONEtxt,a0
	lea	.jmp5,a1
	jmp	DumpSerial
.jmp5:
	lea	InitINTREQtxt,a0
	lea	.jmp6,a1
	jmp	DumpSerial
.jmp6:
	move.w	#$7fff,$dff09c		; Disable all INTREQ

	lea	InitDONEtxt,a0
	lea	.jmp7,a1
	jmp	DumpSerial
.jmp7:

	lea	InitDMACONtxt,a0
	lea	.jmp8,a1
	jmp	DumpSerial
.jmp8:
	move.w	#$7fff,$dff096		; Disable all DMACON

	lea	InitDONEtxt,a0
	lea	.jmp9,a1
	jmp	DumpSerial
.jmp9:



	move.w	#$200,$dff100
	move.w	#0,$dff110

.RMB:						; We had RMB pressed so we skipped DMA stuff..
						; next part will hopefully go so fast so the user will not release the button
						; so we can force data to fastmem if any.

;	Now lets check for some memory, the only thing we KNOW exists on all machines is Chipmem.
;	so this will only really rely on Chipmem.  but does it work?  anyway. NO stack is allowed at this
;	point, meaning NO Stack, no subroutines only registers A0-A6 and D0-D7 and no memory.


	PAROUT	#$fe			; Send #$fe to Paralellport.
	lea	parfetxt,a0			; And explaining simliar text to serialport.
	lea	.ldsuds1,a1
	jmp	DumpSerial

.ldsuds1:
						; Time to detect some chipmem

	lea	writeffff,a0
	lea	.ldsuds2,a1
	jmp	DumpSerial
.ldsuds2:
	move.w	#$ffff,d1
	move.w	d1,$400
	move.w	$400,d0
	cmp.w	d0,d1
	bne.s	.ldsuds2fail
	lea	OK,a0
	lea	.ldsuds3,a1
	jmp	DumpSerial
.ldsuds2fail:
	lea	FAILED,a0
	lea	.ldsuds3,a1
	jmp	DumpSerial
.ldsuds3:
	lea	NewLineTxt,a0
	lea	.ldsuds3nl,a1
	jmp	DumpSerial
.ldsuds3nl:
	
	lea	write00ff,a0
	lea	.ldsuds4,a1
	jmp	DumpSerial
.ldsuds4:
	move.w	#$00ff,d1
	move.w	d1,$400
	move.w	$400,d0
	cmp.w	d0,d1
	bne.s	.ldsuds4fail
	lea	OK,a0
	lea	.ldsuds5,a1
	jmp	DumpSerial
.ldsuds4fail:
	lea	FAILED,a0
	lea	.ldsuds5,a1
	jmp	DumpSerial
.ldsuds5:
	lea	NewLineTxt,a0
	lea	.ldsuds5nl,a1
	jmp	DumpSerial
.ldsuds5nl:
	

	lea	writeff00,a0
	lea	.ldsuds6,a1
	jmp	DumpSerial
.ldsuds6:
	move.w	#$ff00,d1
	move.w	d1,$400
	move.w	$400,d0
	cmp.w	d0,d1
	bne.s	.ldsuds6fail
	lea	OK,a0
	lea	.ldsuds7,a1
	jmp	DumpSerial
.ldsuds6fail:
	lea	FAILED,a0
	lea	.ldsuds7,a1
	jmp	DumpSerial
.ldsuds7:
	lea	NewLineTxt,a0
	lea	.ldsuds7nl,a1
	jmp	DumpSerial
.ldsuds7nl:

	lea	write0000,a0
	lea	.ldsuds8,a1
	jmp	DumpSerial
.ldsuds8:
	move.w	#$0000,d1
	move.w	d1,$400
	move.w	$400,d0
	cmp.w	d0,d1
	bne.s	.ldsuds8fail
	lea	OK,a0
	lea	.ldsuds9,a1
	jmp	DumpSerial
.ldsuds8fail:
	lea	FAILED,a0
	lea	.ldsuds9,a1
	jmp	DumpSerial
.ldsuds9:
	lea	NewLineTxt,a0
	lea	.ldsuds9nl,a1
	jmp	DumpSerial
.ldsuds9nl:
	lea	writebeven,a0
	lea	.ldsuds10,a1
	jmp	DumpSerial
.ldsuds10:
	move.w	#$0,d0
	move.w	d0,$400
	move.b	#$ff,d1
	move.b	d1,$400
	move.w	#$ff00,d1
	cmp.b	d0,d1
	bne	.ldsuds10fail
	lea	OK,a0
	lea	.ldsuds11,a1
	jmp	DumpSerial
.ldsuds10fail:
	lea	FAILED,a0
	lea	.ldsuds11,a1
	jmp	DumpSerial
.ldsuds11:
	lea	NewLineTxt,a0
	lea	.ldsuds11nl,a1
	jmp	DumpSerial
.ldsuds11nl:
	lea	writebodd,a0
	lea	.ldsuds12,a1
	jmp	DumpSerial
.ldsuds12:
	move.w	#$0,d0
	move.w	d0,$400
	move.b	#$ff,d1
	move.b	d1,$401
	move.w	#$00ff,d1
	move.w	$400,d0
	cmp.b	d0,d1
	bne	.ldsuds12fail
	lea	OK,a0
	lea	.ldsuds13,a1
	jmp	DumpSerial
.ldsuds12fail:
	lea	FAILED,a0
	lea	.ldsuds13,a1
	jmp	DumpSerial
.ldsuds13:

	lea	NewLineTxt,a0
	lea	.ldsuds13nl,a1
	jmp	DumpSerial
.ldsuds13nl:


	PAROUT	#$fd				; Send #$fe to Paralellport.
	lea	parfdtxt,a0			; And explaining simliar text to serialport.
	lea	.jmp10,a1
	jmp	DumpSerial


.jmp10:


POSTDetectChipmem:
	lea	$400,a6				; Lets scan memory, start at $400
	move.l	#$33333333,(a6)			; Write a number that is NOT in the memcheck table. for shadowcheck
	clr.l	d0			
	clr.l	d3				; if d3 is not null, it contains first memaddr found
	
	lea	NewLineTxt,a0
	lea	.nldone,a1
	jmp	DumpSerial
		
.nldone:

.detectloop:
	move.l	(a6),d5				; Do a backup of content
	lea	MEMCheckPatternFast,a5		; Load list of data to test
	bclr	#31,d0
.memloop:
	lea	AddrTxt,a0			; Prints text "Addr $"
	lea	.addrdone,a1
	jmp	DumpSerial
.addrdone:

	move.l	a6,d1
	lea	.addrout,a3
	jmp	DumpHexLong
.addrout:



	move.l	(a5),(a6)			; Write data to memory
	move.l	(a5),d1
	asl.l	#4,d1
	and.w	#$0f0,d1
	move.w	d1,$dff180			; Write data to screen as green only.

	move.l	(a6),d4				; Read data from memory
	cmp.l	(a5),d4				; Check if written data is the same as the read data.
	beq	.ok				; YES it is OK

	cmp.l	#0,d3				; Check if d3 is 0, in that case we havent found any memory
						; and user might want to see whats wrong. if we had. we are simply out of mem
	bne	.faildone

	lea	WTxt,a0				; Prints text "Write:"
	lea	.wtxtdone,a1
	jmp	DumpSerial
.wtxtdone:
	move.l	a6,d1				; Print address to check


	move.l	(a5),d1
	lea	.wbindone,a3
	jmp	DumpHexLong
.wbindone:

	lea	RTxt,a0				; Prints text "Read:"
	lea	.rtxtdone,a1
	jmp	DumpSerial
	.rtxtdone:

	move.l	d4,d1
	lea	.rbindone,a3
	jmp	DumpHexLong
.rbindone:

	lea	SPACEFAIL,a0			; Prints "FAILED"
	lea	.faildone,a1
	jmp	DumpSerial
.faildone:
	bset	#31,d0				; set bit 31 in d0 to tell we had an error
	move.w	#$f00,$dff180
.ok:
	cmp.l	#$400,a6
	beq	.yes400				; if we are checking address 400, skip this
	move.l	$400,d4
	beq	.shadow				; ok, we are not checking address 400, BUT we had same data there. meaning
						; we have a shadow. so exit

.yes400:
	TOGGLEPWRLED

	cmp.l	#0,(a5)+			; Was last longword tested null? if not, repeat
	bne	.memloop



	btst	#31,d0
	bne	.fail				; did we have failed memory


	cmp.l	#0,d3				; check if this is the first block of good memory
	bne	.notfirst
	move.l	a6,d3				; Store that this was the first sucessful memory

.notfirst:
	add.w	#1,d0				; Add 1 to mark a sucessful block
	lea	SPACEOK,a0			; Print "OK"
	lea	.okdone,a1
	jmp	DumpSerial
.okdone:
	lea	Txt32KBlock,a0			; Print string of number of blocks
	lea	.blkdone,a1
	jmp	DumpSerial
.blkdone:
	move.l	d0,d1
	lea	.longdone,a2
	jmp	DumpHexByte			; Print out number of OK blocks.

.fail:						; We had a failure


	cmp.l	#0,d3				; Check if d3 is 0, in that case we havent found any memory yet
	beq	.longdone
						; ok we had memory, so this is the endblock.
	bra	.finished			; lets stop all check. we have found it all.

.longdone:
	move.l	d5,(a6)				; Restore backupped data

	add.l	#32768,a6			; Add 32k to a6
	cmp.l	#$200000,a6			; have we scanned more then 2MB of data, exit
	bhi	.finished
	bra	.detectloop			; Do one more turn.

.shadow:
	move.l	#"SHDW",(a6)			; to test that we REALLY have a shadowram. write a string
	cmp.l	#"SHDW",$400			; and check it at $400,  if it is there aswell SHADOW
	bne	.yes400				; go on checking ram. we did not have shadow

	lea	ShadowChiptxt,a0
	lea	.finished,a1
	jmp	DumpSerial

.finished:
	bclr	#31,d0				; Clear "the errorbit"
	cmp.l	#0,d0				; check if we had no chipmem
	beq	.nochipatall


	lea	StartAddrTxt,a0
	lea	.startaddrdone,a1
	jmp	DumpSerial
.startaddrdone:

	move.l	d3,d1
	lea	.startdone,a3
	jmp	DumpHexLong
.startdone:

	lea	EndAddrTxt,a0
	lea	.endaddrdone,a1
	jmp	DumpSerial
.endaddrdone:
	sub.l	#$400,a6
	move.l	a6,d1
	lea	.enddone,a3
	jmp	DumpHexLong
.enddone:
					; At EXIT registers that are interesting:
					; D0 = Number of usable 32Kb blocks
					; D3 = First usable address
					; A6 = Last usable address

	
	sub.l	#EndData-Variables,a6	; Subtract total chipmemsize, putting workspace at end of memory
	sub.l	#2048,a6		; Subtract 2Kb more, "just to be sure"
					; A6 from now on points to where diagroms workspace begins. do NOT change A6
					; A6 is from now on STATIC

	lea	Base1Txt,a0
	lea	.base1,a1
	jmp	DumpSerial
.base1:
	move.l	a6,d1
	lea	.base2,a3
	jmp	DumpHexLong
.base2:
	lea	Base2Txt,a0
	lea	.base3,a1
	jmp	DumpSerial

.nochipatall:
	lea	NoChiptxt,a0
	lea	.base3,a1
	jmp	DumpSerial


.base3:

;----------- Chipmemtest done

; ---------- Terrible Fire Tests

	lea	E_EXPANSIONBASE,a0
	
zorro_tests:

		MOVE.B	#$DE,($BFE101).l
		PRINT   aParallelCodeDE
	
zorro_next_board:
	        PRINT   aZorroTest
	;; read out the expansion rom
		lea	$4000,a2
		lea	E_EXPANSIONBASE,a0
		move.l	a0,a5
		jsr	ReadRom

		lea	$4000,a2
		tst.b	er_Reserved03(a2)
		beq	.gotboard

		lea	$4000,a2
		lea	EZ3_EXPANSIONBASE,a0
		move.l  a0,a5
		jsr	ReadRom
	
.gotboard
		lea	$4000,a2
		tst.b	er_Reserved03(a2)
		bne	NoMoreBoards

		move.w	er_Manufacturer(a2),d0
		beq	NoMoreBoards
		cmp.w	#-1,d0
		beq	NoMoreBoards
	
		lea	$4000,a2	
		move.l	#0,d6
.loop	
	        CHAROUT 48
	        CHAROUT 120
		clr.l	d0	
		move.b	(a2)+,d0
	        PRINTHEX 
	        CHAROUT 32

		addq.l	#1,d6
		cmp.w	#ExpansionRom_SIZEOF,d6
		blt	.loop

		CHAROUT $a
		CHAROUT $d
zorro_test_again:	
	;; read out the expansion rom again
 		lea	$4010,a2
		move.l	a5,a0

		jsr	ReadRom

		lea	$4010,a2	
		move.l	#0,d6
.loop	
		clr.l	d0	
		move.b	(a2)+,d0

		addq.l	#1,d6
		cmp.w	#ExpansionRom_SIZEOF,d6
		blt	.loop

check_equal_test:
		PRINT 	aZorroTestEqual
		moveq.l	#0,d6
		lea	$4000,a0
		lea	$4010,a1
check_loop:	
		move.b	(a1),d1
		move.b	(a0),d0
		move.b	#0,(a0)+
		move.b	#0,(a1)+
	
		cmp.b	d0,d1
		beq	.pass

		PRINT	aTestFailed

	        PRINT   aZorroTest
	
		lea	$4010,a2	
		move.l	#0,d6
.loop	
	        CHAROUT 48
	        CHAROUT 120
		clr.l	d0	
		move.b	(a2)+,d0
	        PRINTHEX 
	        CHAROUT 32

		addq.l	#1,d6
		cmp.w	#ExpansionRom_SIZEOF,d6
		blt	.loop

	        CHAROUT $a
		CHAROUT $d

	
	;; try again
		bra 	zorro_next_board
	
.pass
		addq.l	#1,d6
		cmp.w	#ExpansionRom_SIZEOF,d6
		blt	check_loop

		PRINT	aTestPassed		
.end

complete_config:
		PRINT	aZorroDoConfig
		move.l	a5,a0

		jsr	DumbConfigBoard

		cmp.l	#0,d0
		blt	.error1

		cmp.l	#0,d0	
		beq	.ramboard
		PRINT   aZorroIINonRAMDone
		bra	zorro_next_board
.ramboard

		PRINT   aZorroIIDone
		bra	zorro_next_board
.error1
		cmp.l	#-1,d0
		bne	.error2
		PRINT   aZorroIIISkipped
		bra	zorro_next_board
.error2
		cmp.l	#1,d0	
		bne	.errorUnknown
		PRINT   aZorroIINonRAMDone
		bra	zorro_next_board
.errorUnknown
		PRINT   aTestFailed

NoMoreBoards:

	PRINT   aZorroDone


access_tests:
	
	SPRINT aAccessTests
	
	lea	GAYLE_ID_ADDR,a1
	move.b	#$FF,(a1)

	REPT  8

	SPRINT aAccessGary
	lea	GAYLE_ID_ADDR,a1
	move.b	(a1),d0	
	SPRINTHEX
	SPRINT	aCrLf

	ENDR

	lea	GAYLE_ID_ADDR,a1
	move.b	#$FF,(a1)
	REPT  8

	SPRINT aAccessGary
	lea	GAYLE_ID_ADDR,a1
	move.w	(a1),d0	
	SPRINTHEX16
	SPRINT	aCrLf

	ENDR

; checking the IDE interrupt status

        ; status
	REPT  8

	SPRINT aAccessGStatus
	lea	$dA8000,a1
	move.w	(a1),d0	
	SPRINTHEX16
	SPRINT	aCrLf

	ENDR

        ; status
	REPT  8

	SPRINT aAccessGChange
	lea	$DA9000,a1
	move.w	(a1),d0	
	SPRINTHEX16
	SPRINT	aCrLf

	ENDR



	lea	$E90000,a1
	move.b	#$FF,(a1)
	
	REPT  8

	SPRINT aAccessConf
	lea	$E90000,a1
	move.b	(a1),d0	
	SPRINTHEX
	SPRINT	aCrLf

	ENDR

	lea	$E90000,a1
	move.b	#$FF,(a1)
	
	REPT  8

	SPRINT aAccessConf
	lea	$E90000,a1
	move.w	(a1),d0	
	SPRINTHEX16
	SPRINT	aCrLf

	ENDR

	REPT  8

	SPRINT aAccessFastRAMW
		
	lea	$200000,a1

	move.l  #$01234567,d0
	move.l	d0,(a1)
	
	SPRINTHEX32
	SPRINT	aCrLf

	SPRINT aAccessFastRAMR

	lea	$200000,a1
	move.l	(a1),d0

	SPRINTHEX32
	SPRINT	aCrLf

	SPRINT aAccessFastRAMW
		
	lea	$200000,a1

	move.l  #$89ABCDEF,d0
	move.l	d0,(a1)
	
	SPRINTHEX32
	SPRINT	aCrLf

	SPRINT aAccessFastRAMR

	lea	$200000,a1
	move.l	(a1),d0

	SPRINTHEX32
	SPRINT	aCrLf
	
	
	ENDR


ide_tests:
	
	    SPRINT aIDETests
sjlGaryVersion:
		SPRINT aChipsetMirror

		lea	_custom,a0
		lea	GAYLE_ID_ADDR,a1	GAYLE id address

		move.w	intenar(a0),-(sp)	save old value
		move.w	#$bfff,intena(a1)	set all ables
		move.w	#$3fff,d1		also flag for no mirror
		cmp.w	intenar(a0),d1
		bne.s	.no_mirror
		move.w	d1,intena(a1)		clear all ables
		tst.w	intenar(a0)
		bne.s	.no_mirror
		moveq	#0,d1			mirrored
		SPRINT	aMirrorDetected
.no_mirror					

		move.w	#$3fff,intena(a0)	clear bits
		ori.w	#$8000,(sp)		add set bit
		move.w	(sp)+,intena(a0)	reset values

		tst.w	d1			did we find mirroring?
		beq	.no_hw			yes, exit

		SPRINT	aMirrorNotDetected

	;; dont have a mirror
	
		moveq	#0,d1
		move.b	d1,(a1)			value doesn't matter
		
		bsr	get_gid_bit		get 4 bits
		bsr	get_gid_bit
		bsr	get_gid_bit
		bsr	get_gid_bit

		SPRINT  aReadGayleVersion
		move.w	d1,d0
		SPRINTHEX
		SPRINT	aCrLf
		
		cmp.b	#GAYLE_VERSION,d1
		beq.s	sjlGayleFound
	
.no_hw
		SPRINT	aIDEInterfaceNotFound
		jmp	endIDETests
sjlGayleFound
		; Ok we have an ide interface at this point
		SPRINT	aIDEInterfaceFound

		
		jsr	IDEWaitRDY

		SPRINT	Donetxt
		
		cmp.b	#0,d2
		beq	nointexit

		move.b	#$EC,d0 ; read the drive ID.
		jsr	IDECommand

BoardServer
		SPRINT	aIDEInterruptCheck
		moveq.l	#0,d0			assume it's not our interrupt
		lea	GAYLE_ADDR,a0	point to the board
		move.b	GAYLE_IntChange(a0),d1	check for int!
		bpl	nointexit			not ours
	
		SPRINT	aIDEInterruptDetected

		bsr	IDECheckStatus
	
		; our interrupt, clear it
		; must clear drive first, then gayle
		move.l	IDE_Slow,a2
		move.b	AT_Status(a2),d1		clears interrupt (IDE)

		SPRINT	aIDEInterruptClearedDrive

		bsr	IDECheckStatus
	
		move.w	SR,d2			save current SR
		ori.w	#$0700,SR		raise int priority to level 7
		move.b	GAYLE_IntChange(a0),d1

		SPRINT	aIDEInterruptIntChangedReading
		move.w 	d1,d0
		SPRINTHEX
		SPRINT aCrLf
intwrite:	
		
		and.b	#$03,d1			leave low two bits alone
		or.b	#$7c,d1			clear IDE int, leave the rest

		SPRINT	aIDEInterruptIntChangedWriting
		move.w 	d1,d0
		SPRINTHEX
		SPRINT aCrLf
	
		move.b	d1,GAYLE_IntChange(a0)	clear latch in Gayle
		move.w	d2,SR			re-enable normal int level

		lea	IDE_Slow,a2
		jsr	IDEReadData

		bsr	IDECheckStatus	
	
		bra	endIDETests
	
nointexit:
		SPRINT	aIDEInterruptNotDetected

		moveq.l #0,d0
		move.b	d1,d0
		SPRINTHEX
		SPRINT aCrLf

endIDETests:
		jmp 	zorro_tests
; ---------- Terrible Fire Tests Done.
	
	PAROUT	#$fc			; Send $fd to parallelport
	lea	parfctxt,a0		; And explaining simliar text to serialport.
	lea	.jmp12,a1
	jmp	DumpSerial
.jmp12:
					; Lets detect fastmem, do NOT touch D0, A6 or A4
					; As we have several blocks to search. we do it in a subroutine instead of in-code as we did with chipmem
					

	move.l	d3,a7			; Store start of chipmem

	clr.l	d1
	clr.l	d2
	move.l	#0,a0

	move.l	#"24BT",$4000700	; Write "TEST" to highmem
	cmp.l	#"24BT",$700		; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect in next routines
	beq	.a1200done

	move.l	#$4000000,a1		; Detect motherboardmem on A3000/4000
	move.l	#$7ffffff,a2
	lea	.a3k4kdone,a3
	bra	DetectMBFastmem
.a3k4kdone:
	move.l	#$70000000,a1		; Detect memory on A1200/4000 accelerators
	move.l	#$7affffff,a2
	lea	.a1200done,a3
	bra	DetectMBFastmem
.a1200done:
	move.l	#$200000,a1		; Detect memory on 24 bit range
	move.l	#$9fffff,a2
	lea	.24bitdone,a3
	bra	DetectMBFastmem
.24bitdone:

	move.l	#$c00000,a1		; Detect memory on 24 bit range
	move.l	#$c80000,a2
	lea	.fakefastdone,a3
	bra	DetectMBFastmem
.fakefastdone:



	move.l	d1,d6			; Store size in d6 as Dumpserial uses d1
	move.l	a0,a5			; Store detected mem to a5
	PAROUT	#$fb			; Send $fd to parallelport
	lea	parfbtxt,a0		; And explaining simliar text to serialport.
	lea	.jmp16,a1
	jmp	DumpSerial
.jmp16:
	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection


	cmp.l	#(EndData-Variables)/32768+1,d0
	bgt	.enoughchip		; ok we had enough chipmem
					; so we are not happy with the amount of found chipmem

	cmp.l	#(EndData-Variables)/16384+1,d1		; but was there enough FASTMEM??
	bgt	.enoughfast		; if so, jump there  (should be enoughfast..)

					; OK we are is trouble.. not enough memory
	cmp.l	#2,d0			; do we have extremly little chipmem
	ble	.nochip
	
					; ok we did not have enough chipmem, or fastmem, but SOME chipmem
 	PAROUT	#$81			; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	lea	par81txt,a0		; And explaining simliar text to serialport.
	lea	.jmp14,a1
	jmp	DumpSerial
.jmp14:
	move.l	#$0080,d6		; set D6 to darker green
	bra	ERRORHALT	
.nochip:				; we had NO chipmem
 	PAROUT	#$80			; Set code to $80 to paralellport, NO chipmem avaible
	lea	par80txt,a0		; And explaining simliar text to serialport.
	lea	.jmp15,a1
	jmp	DumpSerial
.jmp15:
	move.l	#$00f0,d6		; set D0 to darker green
	bra	ERRORHALT	

.enoughfast:

	move.l	a5,a6			; We had enough fastmem, so lets set fastmem adress as base memory.
	move.l	#1,a4			; Set do NODRAW mode.
	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection
	bra	code

	
.enoughchip:
					; OK we had enough chipmem avaible.
	move.l	a4,d7

	btst	#0,d7			; Check if LMB was pressed during boot
	bne	.LMB

	cmp.l	#$20000,a6		; check if a6 is in chipmem
	ble	.wearechip		; if we are do not set to nodraw mode
	move.l	#1,d7			; Set d7 to non 0 mode to force "nodraw" mode.
.wearechip:
	bra	startcode		; Start ROM for real, now with memory.
	
.LMB:					; LMB Pressed so we force chipmem if avaible, and if not just turn off screenstuff etc.
	move.l	#1,d7			; OK we are in a nodraw mode..
	
	cmp.l	#0,a5			; Was there any useful fastmem
	beq	.nofast

	move.l	a5,a6			; OK we had fastmem, set it as baseadress
.nofast:				; we didnt have any fastmem, lets use chipmem but skip screenstuff.
startcode:
	move.l	d1,d6			; Store size in d6 as Dumpserial uses d1
	move.l	a0,a5			; Store detected mem to a1

 	PAROUT	#$fa			; Set code to $fb to paralellport, NO chipmem avaible
	lea	parfatxt,a0		; And explaining simliar text to serialport.
	lea	.jmp,a1
	jmp	DumpSerial
.jmp:


	move.l	d6,d1
	move.l	a5,a0			; Restore important data from fastmemdetection
	bra	code

	
ERRORHALT:				; This is a critical Error. stop everything. we are fucked.
	move.l	d6,d4			; as d4 isnt used in motherboardcheck, store color

ERRORHALT2:

	lea	HALTTXT,a0		; Tell user on serialport that we are totally halted.
	lea	.endless,a1
	bra	DumpSerial


.endless:
	move.w	#$0f0,d5			; color to flash with
	clr.l	d3
						; speed of "flash"
	lea	$400,a1				; Start to test at $400
.endlessloop:	
	move.l	#$ffffffff,d0
	move.l	d0,(a1)
	move.l	(a1),d1
	clr.l	d2				; result. 0 = ok, 1 = error
						; check only SETS error.
	lea	.check1,a0
	bra	bitcheck			; So lets check what we got from it
.check1:

	move.l	#$0,d0
	move.l	d0,(a1)
	move.l	(a1),d1
	lea	.check2,a0
	bra	bitcheck
.check2:

	move.l	#$aaaaaaaa,d0
	move.l	d0,(a1)
	move.l	(a1),d1
	lea	.check3,a0
	bra	bitcheck
.check3:
	move.l	#$55555555,d0
	move.l	d0,(a1)
	move.l	(a1),d1
	lea	.check4,a0
	bra	bitcheck
.check4:



	move.l	d2,d1				; Transfer biterorlongword to d1
.bottomloopa:
	move.l	#32,d7				; number of "bits"
	move.l	#31,d6
	move.l	#$24,d0				; Startrow
;.bottomloop:
;	move.w	d5,$dff180			; Start with Black screen
;	cmp.b	#$f0,$dff006			; Wait to bottom $ff line
;	bne	.bottomloop
.bottomloop2:
	cmp.b	#$25,$dff006			; wait for rasterline below that even more
	bne	.bottomloop2				; to make sure, we will be waiting for the top later
						; OK this is the real deal. so now we can start the business
								
.redloop:
	cmp.b	$dff006,d0
	bne	.redloop
	move.w	#$f00,$dff180
	add.l	#2,d0
.endredloop:
	cmp.b	$dff006,d0
	bne	.endredloop
	btst	d6,d1
	beq	.on
	move.w	#$070,$dff180
	bra	.off
.on:
	move.w	#$0f0,$dff180
.off:
	sub.l	#1,d6
	add.l	#4,d0
	dbf	d7,.redloop
	move.w	d5,$dff180

	add.b	#1,d3
	cmp.b	#15,d3
	bne	.notnow
	eor.w	#$0c0,d5
	TOGGLEPWRLED				; Change value of Powerled.
	add.l	#4,a1				; so at every flash, lets text next longword
						; no "endtest" is done, if you want to wait for
						; 2 MB of data YOU ARE FUCKING WELCOME!
	clr.b	d3	
.notnow:
	bra	.endlessloop

code:

	move.l	a7,d3			; Copy start of chipmem (temporary stored in a7) do d3

	move.l	a6,a7			; ok.  we have found memory. so put stack there. BUT first put a6 to a7 (SP)
	move.l	#Endstack-Variables,d6	; set d7 to the stacksize	
	add.l	d6,a7			; and add stacksize so we have a stack
	move.l	a7,a6			
	add.l	#4,a6			; make a6 first usable address AFTER stack. for variables.

	asl.l	#4,d1			; Multiply  d1 with 16 to get correct number of kilobytes of fastmem.;

	clr.l	d2

	move.l	#RTEcode,$64
	move.l	#RTEcode,$68
	move.l	#RTEcode,$6c
	move.l	#RTEcode,$70
	move.l	#RTEcode,$74
	move.l	#RTEcode,$78
	move.l	#RTEcode,$7c

	move.l	#SSPError,0		; Set different traps of faults that can happen
	move.l	#BusError,$8		; This time to a routine that can present more data.
	move.l	#AddressError,$c
	move.l	#IllegalError,$10
	move.l	#DivByZero,$14
	move.l	#ChkInst,$18
	move.l	#TrapV,$1c
	move.l	#PrivViol,$20
	move.l	#Trace,$24
	move.l	#UnimplInst,$28
	move.l	#UnimplInst,$2c
	move.l	#Trap,$80
	move.l	#Trap,$84
	move.l	#Trap,$88
	move.l	#Trap,$8c
	move.l	#Trap,$90
	move.l	#Trap,$94
	move.l	#Trap,$98
	move.l	#Trap,$9c
	move.l	#Trap,$a0
	move.l	#Trap,$a4
	move.l	#Trap,$a8
	move.l	#Trap,$ac
	move.l	#Trap,$b0
	move.l	#Trap,$b4
	move.l	#Trap,$b8
	move.l	#Trap,$bc
	TOGGLEPWRLED


		else
; Code in NON-ROM mode
code:

	clr.b	$bfe001
	clr.b	$bfe201
	clr.b	$bfe001
	move.b	#$ff,$bfe301
	move.b	#3,$bfe201	
	bclr	#1,$bfe001

	lea	$0,a4			; if this is not set. bugs can happen as it can think we are in nondrawmode
	lea	V,a6			; Set V as startaddress in non-rom mode.. the stackblock is more "nonsense"
					; do not set any stack in this mode. it is already set.
	move.l	#BeforeUsed,d3
	move.l	#$40,d0			; Assume 2MB of chipem when running in non ROM mode
	move.b	#1,RASTER-V(a6)		; Set that we DO have raster


	move.l	$64,irq1
	move.l	$68,irq2
	move.l	$6c,irq3
	move.l	$70,irq4
	move.l	$74,irq5
	move.l	$78,irq6
	move.l	$7c,irq7


			endc
		
; Normal code

;	Put initstuff here that consumes time, so user have time to read text on console


					; Before we actually do start, lets clear all used memory



	move.l	a6,a0
	move.l	a6,d2
	add.l	#EndData-V,d2
.loop:
	move.b	#0,(a0)+
	cmp.l	d2,a0
	blo	.loop

	move.l	a4,d7


;	bset	#4,d7			; Set LOOPBACK	KUK

	btst	#0,d7			; is d7 set? then we should not draw anything onscreen
	beq	.notset
	move.b	#1,NoDraw-V(a6)

.notset:
	move.b	#0,NoSerial-V(a6)
	btst	#1,d7			; Check if noserial is to be set
	beq	.notset2

	move.b	#1,NoSerial-V(a6)	; set it
.notset2:
	move.b	#0,LoopB-V(a6)

	btst	#4,d7			; Check if loopbackadapter was attached at boot (buggy code, so will test again)
	beq	.notset3
	
	move.b	#1,LoopB-V(a6)
.notset3:

	move.l	d1,TotalFast-V(a6)	; Store total fastmem detected
	move.l	d1,BootMBFastmem-V(a6)
	asl.l	#5,d0			; Multiply d0 with 32 as it contains number of blocks of 32K
	move.l	d3,ChipStart-V(a6)	; Write where detected chipmem starts
	move.l	d0,TotalChip-V(a6)	; Write totalchipvalue so we know how much chipmem is detected


	move.l	a6,d0			; Subtract startaddress with lowest value of detected ram
	sub.l	#V-Variables,d0

	move.l	d0,ChipUnreservedAddr-V(a6)
	sub.l	d3,d0			; also subtract stacksize, now we got all usable NONUSED chipmem
	move.l	d0,ChipUnreserved-V(a6)	; Store amount of NONRESERVED chipmem

	bsr	GetHWReg		; Store HW Registers

	move.l	ChipStart-V(a6),d1	; Get startaddress of chipmem
	move.l	TotalChip-V(a6),d0	; Get total of chipmemblocks detected
	mulu	#1024,d0
	sub.l	#$400,d0		; Subtract first 1Kb
	add.l	d1,d0			; add Startaddess of chipmem, so d0 now contains last memaddress

	move.l	d0,ChipEnd-V(a6)	; Write lastchipmemaddress into EndChip



;---------------------------------- This is more or less where it all starts and a system is up and running

;	ifeq	rommode			; if we are in rommode, then do a loopbacktest here aswell... removed due to initbug.

	lea	LoopSerTest,a0
	lea	.dirtyjump,a1		; TECHNICALLY we do not need to do this dirty thing anymore, but just to
	bra	DumpSerial		; reuse the code
.dirtyjump
	bsr	ClearSerial
	bsr	ClearSerial
	clr.l	d6			; Clear d6 as it a counter for how many similiar chars we got back as echo
	move.b	#"<",d2			; Char to test
	bsr	RealLoopbacktest

	move.b	#">",d2			; Char to test
	bsr	RealLoopbacktest

	cmp.b	#0,d6			; Check if we had any return, if so we have a loopbackadapter installed.
	beq	.noloopback

	move.b	d6,shit
	move.w	#5,SerialSpeed-V(a6)	; Set serialspeed to 5 ,(same as 0 but mark loopbackadapter)
	move.b	#1,LoopB-V(a6)

	lea	DDETECTED,a0
	lea	.loopbackdone,a1
	bra	DumpSerial

.noloopback:
	lea	NoLoopback,a0
	lea	.loopbackdone,a1
	bra	DumpSerial

.loopbackdone:

;	endc

	cmp.b	#1,NoSerial-V(a6)	; Check if noserial is set
	beq	.noser
	cmp.b	#1,LoopB-V(a6)		; Check if loopbackadapter was attacjhed
	beq	.noserloop		; in that case, no serial output
	move.w	#2,SerialSpeed-V(a6)	; KUKEN
	bsr	Init_Serial


	lea	DetectRasterTxt,a0
	bsr	SendSerial
	bra	.ser
.noserloop:
	move.w	#5,SerialSpeed-V(a6)	; Set serialspeed to 5 ,(same as 0 but mark loopbackadapter)
	move.b	#1,NoSerial-V(a6)
	bra	.ser
.noser:
	move.w	#0,SerialSpeed-V(a6)	; Set Serialspeed to 0
.ser:

	move.b	$dff006,d0		; Load value of raster
	bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort
	move.b	$dff006,d1		; Load value of raster again
	cmp.b	d0,d1
	beq	.noraster		; if raster was the same, We assume we have no working raster
	move.b	#1,RASTER-V(a6)		; it was different so we assume we have working raster.
	lea	DETECTED,a0
	bsr	SendSerial
	beq	.rastercheckdone

.noraster:
	move.b	#0,RASTER-V(a6)
	lea	FAILED,a0
	bsr	SendSerial
.rastercheckdone:

	lea	NewLineTxt,a0
	bsr	SendSerial

	move.l	#EnglishKey,keymap-V(a6)	; Set english keymap as default

	lea	DetChipTxt,a0
	bsr	SendSerial


	move.l	TotalChip-V(a6),d0
	bsr	bindec
	bsr	SendSerial
	lea	KB,a0
	bsr	SendSerial		; Put out detected chipmem on serialport..
	lea	NewLineTxt,a0
	bsr	SendSerial

	lea	DetMBFastTxt,a0
	bsr	SendSerial
	
	nop
	move.l	BootMBFastmem-V(a6),d0
	bsr	bindec
	bsr	SendSerial
	lea	KB,a0
	bsr	SendSerial
	lea	NewLineTxt,a0
	bsr	SendSerial

	lea	BaseAdrTxt,a0
	bsr	SendSerial
	move.l	a6,d0
		ifne	rommode
	sub.l	#Endstack-Variables+4,d0
		endc
	bsr	binhex
	bsr	SendSerial
	lea	NewLineTxt,a0
	bsr	SendSerial


 	PAROUT	#$f9		; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	lea	parf9txt,a0		; And explaining simliar text to serialport.
	bsr	SendSerial

	move.l	#"DATA",Endstack-Variables(a6)	; Write "DATA" to first usable longword after stack


	move.l	#Endstack-Variables,StackSize-V(a6)		; write stacksize to varible for stacksize.
	move.l	a6,StartAddress-V(a6)


	move.l	a6,a5
	add.l	#Bpl1str-V,a5		; we do this way as this are in the end and big segments above 64k...
	move.l	#"BPL1",(a5)+		; Put the BPL1 string, just to be able to identify BPL1
	move.l	a5,Bpl1Ptr-V(a6)	; and store the pointer to bitplane

	move.l	a6,a5
	add.l	#Bpl2str-V,a5
	move.l	#"BPL2",(a5)+
	move.l	a5,Bpl2Ptr-V(a6)

	move.l	a6,a5
	add.l	#Bpl3str-V,a5
	move.l	#"BPL3",(a5)+
	move.l	a5,Bpl3Ptr-V(a6)
	clr.l	BplEnd-V(a6)		; make it 0, so we have a bitplanelist

	move.l	a6,a5
	add.l	#EndData-V,a5
	move.l	#"END!",(a5)

	bsr	CopyToChip

	bsr	InitStuff
					
; Initialize the screen.

	ifeq	rommode

						; Code to handle stuff when NOT using rom mode. when coding/testing
		move.l	SP,STACKPOINTER		; Store stackpointer
	        move.l  4.w,a6
	        lea     graph,a1          
	        moveq   #33,d0
	        jsr     -552(a6)        	;open gfxlib    
	        move.l  d0,-(a7)        	;gfxbase!!
	        move.l  d0,a6
		jsr	-456(a6)		;OwnBlitter
		jsr	-228(a6)		;WaitBlit
	        move.l  34(a6),ActiveView	;Store activeview for a clean exit
	        sub.l   a1,a1
	        jsr     -222(a6)        	;loadview(NULL) hell..this only works w. a6
		jsr	-270(a6)		;WaitTOF()
		jsr	-270(a6)		;WaitTOF()
	        move.l  4.w,a6
		jsr     -132(a6)        	;forbid
		move.l	$4,a6			;exec.library
		jsr	-150(a6)		;Switches the processor to supervisor mode. Keeps the user stack, witch contains all
						;interrupt data.

		lea	V,a6
		move.l	d0,sysstack
	endc

	cmp.b	#0,NoDraw-V(a6)
	bne	.NoChip

	bsr	SetMenuCopper


	lea	InitPOTGO,a0
	bsr	SendSerial
	move.w	#$ff00,$dff034
	lea	InitDONEtxt,a0
	bsr	SendSerial

 	PAROUT	#$f8			; Set code to $81 to paralellport, NOT ENOUGH chipmem avaible
	lea	parf8txt,a0			; And explaining simliar text to serialport.
	bsr	SendSerial



	bsr	ClearScreenNoSerial

	lea	InitTxt,a0
	move.l	#7,d1
	bsr	Print
	bra	.Chip

.NoChip:
	lea	NoDrawTxt,a0
	bsr	SendSerial
.Chip:

	lea	InitSerial2,a0
	move.l	#7,d1
	bsr	Print

	cmp.b	#1,NoDraw-V(a6)			; Check if we are in NoDraw Mode. if so. do not disable serialport
	beq	.nodraw

	cmp.b	#1,NoSerial-V(a6)
	beq	.serialon			; IF Noserial was set, skip this part

	cmp.b	#1,LoopB-V(a6)			; Same if loopbackadapter was attached
	beq	.serialon


	move.l	#1200,d7			; read data for a while.. Giving user a possability of try to press a key on serialport
	clr.l	d6
.waitloop:
	move.b	d7,$dff181			; Just flash some colors. so local user can see that something is happening
	bsr	GetInput
	cmp.b	#1,RMB-V(a6)			; RMB pressed? then turn serial on
	beq	.serialon
	btst	#2,d0
	bne	.serialon			; if any key was pressed turn serial on
	btst	#3,d0
	bne	.serialon
	add.l	#1,d6
	cmp	#16,d6
	bne	.nodot
	lea	DotTxt,a0
	move.l	#7,d1
	bsr	Print
	clr.l	d6
.nodot:
	dbf	d7,.waitloop
	lea	EndSerial,a0			; Send text about "no key pressed"
	move.l	#7,d1
	bsr	SendSerial
	move.w	#0,SerialSpeed-V(a6)
	bra	.serialon

.nodraw:
	TOGGLEPWRLED
	move.w	#2,SerialSpeed-V(a6)
	lea	NoDrawTxt,a0
	bsr	SendSerial
	
.serialon:

; Clears screen and lets go on

;	clr.w	SerialSpeed-V(a6)	; Disable Serialport

	clr.l	d7


	bsr	DefaultVars

	move.l	#Menus,Menu-V(a6)
	bra	MainMenu			; Print the mainmenu



MainLoop:

	move.l	#0,a0
	bsr	PrintMenu			; Print or update the menu

	bsr	GetInput			; Scan keyboard, mouse, buttons, serialport etc..


	clr.l	d0
	move.l	#27,d1
	bsr	SetPos
	clr.l	d0

	ifne	debug				; Print and do debugshit
		move.l	#0,d0
		move.l	#28,d1
		bsr	SetPos
		clr.l	d0
		move.b	GetCharData-V(a6),d0
		bsr	bindec
		move.l	#2,d1
		bsr	Print

		move.l	#5,d0
		move.l	#28,d1
		bsr	SetPos
		clr.l	d0
		move.w	shit-V(a6),d0
		bsr	binhexword
		move.l	#4,d1
		bsr	Print


		move.l	#15,d0
		move.l	#28,d1
		bsr	SetPos
		move.l	SerBuf-V(a6),d0
		bsr	binhex
		move.l	#2,d1
		bsr	Print
	endc


.no:
		ifeq	rommode

	cmp.b	#1,RMB
	beq.w	Exit
		endc

	bsr	HandleMenu			; ok, LMB pressed, do menuhandling

.notpressed:
	clr.l	d0
	move.l	InputRegister-V(a6),d0
	btst	#0,d0
	bra	MainLoop

Exit:
		ifeq	rommode

	move.l	irq1,$64
	move.l	irq2,$68
	move.l	irq3,$6c
	move.l	irq4,$70
	move.l	irq5,$74
	move.l	irq6,$78
	move.l	irq7,$7c

	move.b	#$40,$bfe601
	move.b	#$a0,$bfe701



	move.l	$4,a6				; Exec.library
	move.l	sysstack,d0
	jsr	-156(a6)			; Restore from supervisor mode
	jsr	-138(a6)			; Permit
	lea	graph,a1
	jsr	-408(a6)			; open graphics.library
	move.l	d0,a6
	move.l	ActiveView,a1
	move.l	38(a6),$dff080
	jsr	-222(a6)			; Restore ActiveView (original gfx mode)
	jsr	-462(a6)			;Disown Blitter

	move.l	a6,a1
	move.l	$4,a6
	jsr	-414(a6)			; Close library (graphics.library)

	move.l	STACKPOINTER,SP			; Restore Stackpointer
	rts
		endc
	rts

SetMenuCopper:
	lea	InitCOP1LCH,a0
	bsr	SendSerial
	move.l	a6,d0
	add.l	#MenuCopper-V,d0
	move.l	d0,$dff080			;Load new copperlist
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitCOPJMP1,a0
	bsr	SendSerial
	move.w	$dff088,d0
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitDMACON,a0
	bsr	SendSerial
	move.w	#$8380,$dff096
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitBEAMCON0,a0
	bsr	SendSerial
	move.w	#32,$dff1dc			;Hmmm
	lea	InitDONEtxt,a0
	bsr	SendSerial
	rts

InitStuff:
	move.l	a6,a1
	add.l	#Bpl1Ptr-V,a1
	move.l	a6,a0
	add.l	#MenuCopper-V,a0
	add.l	#MenuBplPnt-RomMenuCopper,a0
	bsr	FixBitplane
	rts

ClearScreen:
	PUSH
	cmp.b	#0,NoDraw-V(a6)
	bne	.no
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	Bpl2Ptr-V(a6),a1		; load A1 with address of BPL2
	move.l	Bpl3Ptr-V(a6),a2		; load A2 with address of BPL3

	move.l	#20*256,d0
.loop:
	clr.l	(a0)+
	clr.l	(a1)+
	clr.l	(a2)+
	dbf	d0,.loop
.no:
	lea	AnsiNull,a0
	bsr	SendSerial

	move.l	#12,d0
	bsr	rs232_out
	lea	AnsiNull,a0
	bsr	SendSerial

	clr.l	d0
	clr.l	d1
	bsr	SetPos
	POP
	rts

ClearScreenNoSerial:				; Clear screen but does not dump to serialport.
	cmp.b	#0,NoDraw-V(a6)
	bne	.no
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	Bpl2Ptr-V(a6),a1		; load A1 with address of BPL2
	move.l	Bpl3Ptr-V(a6),a2		; load A2 with address of BPL3

	move.l	#20*256,d0
.loop:
	clr.l	(a0)+
	clr.l	(a1)+
	clr.l	(a2)+
	dbf	d0,.loop
.no:
	clr.l	d0
	clr.l	d1
	bsr	SetPosNoSerial
	rts



GetMouse:
	PUSH
	clr.l	d0				; Clear d0..
	move.b	#0,BUTTON-V(a6)			; Clear the generic "Button" variable
	move.b	#0,LMB-V(a6)			; I use move as clr actually does a read first
	move.b	#0,P1LMB-V(a6)
	move.b	#0,P2LMB-V(a6)
	move.b	#0,RMB-V(a6)
	move.b	#0,P1RMB-V(a6)
	move.b	#0,P2RMB-V(a6)
	move.b	#0,MBUTTON-V(a6)		; Clear the generic "Mbutton" variable
	clr.l	d1
	bsr	GetMouseData
	move.l	d0,InputRegister-V(a6)
	POP
	move.l	InputRegister-V(a6),d0
	rts



GetInput:
						; Check inputsignals and return actions.
						; in: none
						; out: d0 - messageflags.
						;	bits:
						;		0 = Mouse moved
						;		1 = Mouse button
						;		2 = Keyboard action happened
						;		3 = Serial action happened

	PUSH

	clr.l	d0				; Clear d0..
	move.w	#0,CurAddX-V(a6)
	move.w	#0,CurSubX-V(a6)
	move.w	#0,CurAddY-V(a6)
	move.w	#0,CurSubY-V(a6)
	move.b	#0,MOUSE-V(a6)
	move.b	#0,BUTTON-V(a6)			; Clear the generic "Button" variable
	move.b	#0,LMB-V(a6)			; I use move as clr actually does a read first
	move.b	#0,P1LMB-V(a6)
	move.b	#0,P2LMB-V(a6)
	move.b	#0,RMB-V(a6)
	move.b	#0,P1RMB-V(a6)
	move.b	#0,P2RMB-V(a6)
	move.b	#0,key-V(a6)
	move.b	#0,Serial-V(a6)
	move.b	#0,GetCharData-V(a6)
	move.b	#0,MBUTTON-V(a6)

	clr.l	d1

	clr.l	d0

	bsr	GetMouseData

	move.l	d0,d1
	bsr	GetCharSerial
	cmp.b	#0,d0
	beq	.noserial
	move.b	d0,GetCharData-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.l	d1,d0
	bset	#3,d1

.noserial:

	move.l	d1,d0


.getkey:
	move.l	d0,d1
	bsr	GetCharKey
	cmp	#0,d0
	beq	.nokey

	move.b	#1,BUTTON-V(a6)

	move.b	d0,GetCharData-V(a6)
	move.l	d1,d0
	bset	#2,d0
	bra	.exit

.nokey:
	move.l	d1,d0	


	
.exit:
	move.l	d0,InputRegister-V(a6)
	POP
	move.l	InputRegister-V(a6),d0
	rts

GetSerial:					; Reads serialport and returns first char in buffer.
	cmp.w	#0,SerialSpeed-V(a6)		; if serialport is disabled.  skip all serial stuff
	beq	.exit
	cmp.w	#5,SerialSpeed-V(a6)
	beq	.exit
	move.b	#0,SerData-V(a6)
	bsr	ReadSerial
	cmp.b	#0,SerBufLen-V(a6)		; Check if we have a serialbuffer, if not, just exit
	beq	.exit
						; OK, we do have a serialbuffer, so return first char in buffer
	clr.l	d6
	move.b	SerBufLen-V(a6),d6
	lea	SerBuf-V(a6),a5
	move.b	(a5),Serial-V(a6)		; Read char in the buffer and put it to "Serial" that is the output variable
	PUSH
	move.l	#$fe,d6
.loop:
	move.b	1(a5),(a5)+
	dbf	d6,.loop
	sub.b	#1,SerBufLen-V(a6)
	move.b	#0,(a5)				; Clear the last byte in the buffer
	POP
	bset	#3,d0				; Mark that we had a serialevent
	rts
.exit:
	rts

ReadSerial:					; Read serialport, and if anything there store it in the buffer
	cmp.w	#0,SerialSpeed-V(a6)		; is serialport is disabled.  skip all serial stuff
	beq	.exit
	cmp.w	#5,SerialSpeed-V(a6)
	beq	.exit

	move.w	$dff018,d5
		ifeq	debug
		endc
	move.b	OldSerial-V(a6),d6
	cmp.b	d5,d6				; is there a change from last scan?
	bne	.serial				; yes. so. well handle it as a new char.
	btst	#14,d5				; Buffer full, we have a new char
	beq	.exit

.serial:
	move.b	#1,SerData-V(a6)
	move.b	d5,OldSerial-V(a6)
	move.w	#$0800,$dff09c			; Turn off RBF bit
	move.w	#$0800,$dff09c
	move.b	#1,BUTTON-V(a6)

	clr.l	d6
	move.b	SerBufLen-V(a6),d6
	add.b	#1,SerBufLen-V(a6)
	lea	SerBuf-V(a6),a5
	move.b	d5,(a5,d6)
.exit:
	rts


GetMouseData:
						; Get data from mouse.. ANY port.

	;First handle Y position
	bsr	.CheckButton
	move.l	d0,d4				; Store d0 in d4 temporary

	move.b	$dff00a,d2
	move.b	OldMouse1Y-V(a6),d1
	cmp.b	d1,d2				; Check to old Y pos at mouse 1. if differs, mouse is moved.
	bne	.Mouse1YMove
.Check2Y:
	move.b	$dff00c,d2
	move.b	OldMouse2Y-V(a6),d1
	cmp.b	d1,d2
	bne	.Mouse2YMove
.CheckX:
	move.b	$dff00b,d2
	move.b	OldMouse1X-V(a6),d1
	cmp.b	d1,d2
	bne.w	.Mouse1XMove
.Check2X:
	move.b	$dff00d,d2
	move.b	OldMouse2X-V(a6),d1
	cmp.b	d1,d2
	bne.w	.Mouse2XMove


						; ok now we have a raw "mouse" data from either port.
						; but maybe time to convert it to a real X, Y cursor instead.
						; that goes between 0 and 640 on X, and 0 and 512 on Y.

	clr.l	d0
	clr.l	d1
	move.b	MouseX-V(a6),d0			; Store X pos in d0
	move.b	OldMouseX-V(a6),d1		; Store old X pos value in d1
	cmp.b	d1,d0				; Compare them to check if we have mousemovement
	bne	.XMove				; We have mousemovements in the X Axis

.CheckY:
	clr.l	d0
	clr.l	d1
	move.b	MouseY-V(a6),d0			; Store Y pos in d0
	move.b	OldMouseY-V(a6),d1		; Store old Y pos value in d1
	cmp.b	d1,d0				; Compare them to check if we have mousemovement
	bne	.YMove				; We have mousemovements in the Y Axis
.DoneM:
	move.l	d4,d0				; Restore d0 to keep flags
	rts

.XMove:
	bset	#0,d4				; Set flag that we have mousemovements, d4 is temporary
	move.b	#1,MOUSE-V(a6)
	move.b	d0,OldMouseX-V(a6)		; Store current to old.
						; OK , we have a movement, but what direction?
	bsr	.GetMouseDir
	cmp.b	#1,d1				; Check what direction
	beq	.backX
	add.w	d0,CurX-V(a6)
	move.w	d0,CurAddX-V(a6)
	cmp.w	#640,CurX-V(a6)
	bge	.highX
	bra	.DoneX
.highX:
	move	#640,CurX-V(a6)
	bra	.DoneX

.backX:
	sub.w	d0,CurX-V(a6)
	move.w	d0,CurSubX-V(a6)
	cmp.w	#0,CurX-V(a6)
	blt	.MaxX
	bra	.DoneX
.MaxX:
	move.w	#0,CurX-V(a6)
	bra	.DoneX
.DoneX:
	bra	.CheckY


.YMove:
	bset	#0,d4				; Set flag that we have mousemovements, d4 is temporary
	move.b	#1,MOUSE-V(a6)
	move.b	d0,OldMouseY-V(a6)		; Store current to old.
						; OK , we have a movement, but what direction?
	bsr	.GetMouseDir
	cmp.b	#1,d1				; Check what direction
	beq	.backY
	add.w	d0,CurY-V(a6)
	move.w	d0,CurAddY-V(a6)
	cmp.w	#512,CurY-V(a6)
	bge	.highY
	bra	.DoneY
.highY:
	move	#512,CurY-V(a6)
	bra	.DoneY

.backY:
	move.w	d0,CurSubY-V(a6)
	sub.w	d0,CurY-V(a6)
	cmp.w	#0,CurY-V(a6)
	blt	.MaxY
	bra	.DoneY
.MaxY:
	move.w	#0,CurY-V(a6)
	bra	.DoneY
.DoneY:
	bra	.DoneM



.GetMouseDir:
						; INDATA:
						;	D0 = Old pos
						;	D1 = New pos
						; OUTDATA:
						;	D0 = Number of steps
						;	D1 = if 0 = "backwards"

	move.l	d0,d2
	move.l	d1,d3				; Store values

	cmp.b	d0,d1				; Check what direction mousemovement is
	blt	.Lower				; ok we have a lower value
	sub.b	d0,d1				; Calculate how big the movement was.
	move.l	d1,d0				; put it in d0
	move.b	#1,d1				; Mark as "forward" movement

	cmp.w	#128,d0				; Check if we had a BIG movement.
	bge	.highadd			; yes.  so it must be the OPPOSITE direction instead
	rts

.highadd:
	move.b	#255,d1
	sub.b	d1,d0
	clr.b	d1
	rts	

.Lower:
	sub.b	d1,d0
	clr.l	d1				; Mark as "backward"
	cmp.w	#128,d0
	bge	.highsub
	rts	
.highsub:
	move.b	#255,d1
	sub.b	d1,d0
	move.b	#1,d1
	rts




.Mouse2XMove:
	move.b	d2,OldMouse2X-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseX-V(a6)
	bset	#0,d0
	bra	.CheckButton
	
.Mouse1XMove:
	move.b	d2,OldMouse1X-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseX-V(a6)
	bset	#0,d0
	bra	.Check2X
.Mouse1YMove:
	move.b	d2,OldMouse1Y-V(a6)
	sub.b	d2,d1				; Get delta from old value
	sub.b	d1,MouseY-V(a6)
	bset	#0,d0
	bra	.Check2Y
.Mouse2YMove:
	move.b	d2,OldMouse2Y-V(a6)
	sub.b	d2,d1
	sub.b	d1,MouseY-V(a6)
	bset	#0,d0
	bra	.CheckX	


.CheckButton:					; X and Y are now checked, lets check the buttons.
	cmp.b	#0,STUCKP1LMB-V(a6)		; Check if button was marked as stuck, if so. skip it
	bne	.nolmb1
	btst	#6,$bfe001			; Check LMB
	beq	.P1LMB
.nolmb1:
	cmp.b	#0,STUCKP2LMB-V(a6)
	bne	.CheckRight
	btst	#7,$bfe001
	beq	.P2LMB
.CheckRight:
	cmp.b	#0,STUCKP1RMB-V(a6)
	bne	.normb1
	btst	#10,$dff016			; Check RMB port 1
	beq	.P1RMB
.normb1:
	cmp.b	#0,STUCKP2RMB-V(a6)
	bne	.CheckMiddle
	btst	#14,$dff016			; Check RMB port 2
	beq	.P2RMB

.CheckMiddle
	cmp.b	#0,STUCKP1MMB-V(a6)
	bne	.nommb1
	btst	#8,$dff016			; Check MMB
	beq	.MMB
.nommb1:
	cmp.b	#0,STUCKP2MMB-V(a6)
	bne	.Done
	btst	#12,$dff016
	beq	.MMB
.Done:
	rts	

.P1LMB:
	move.b	#1,P1LMB-V(a6)
	bra	.LMB
.P2LMB:
	move.b	#1,P2LMB-V(a6)
.LMB:
	move.b	#1,BUTTON-V(a6)
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,LMB-V(a6)			; Mark LMB as pressed
	bset	#1,d0
	bra	.CheckRight
.P1RMB:
	move.b	#1,P1RMB-V(a6)
	bra	.RMB
.P2RMB:
	move.b	#1,P2RMB-V(a6)
.RMB:
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.b	#1,RMB-V(a6)
	bset	#1,d0
	rts
.MMB:
	move.b	#1,MBUTTON-V(a6)
	move.b	#1,BUTTON-V(a6)
	move.b	#1,MMB-V(a6)
	bset	#1,d0
	rts

GetChar:					; Reads keyboard and serialport and returns the value in D0
	bsr	GetCharKey
	cmp.b	#0,d0
	bne	.noserial
	bsr	GetCharSerial
.noserial:
	move.b	d0,GetCharData-V(a6)
	rts

GetCharKey:
						; Keyboard have priority

	PUSH
	move.b	#0,keyresult-V(a6)
	bsr	GetKey				; Read keyboard
	cmp.b	#1,keynew-V(a6)			; Did we have a new keypress on the keyboard?
	bne	.no				; no, do serialstuff instead

	lea	keymap-V(a6),a0
	move.l	(a0),a0				; Set wanted keymap.
	bsr	ConvertKey			; Convert keyscan to actual ASCII

.no:
	POP
	clr.l	d0
	move.b	keyresult-V(a6),d0
	rts


GetCharSerial:
	PUSH
	clr.b	Serial-V(a6)
	bsr	GetSerial			; Read Serialport
	
	cmp.b	#1,SerAnsiFlag-V(a6)		; Are we in ANSI mode?
	beq	.ansimode

	POP
	clr.l	d0
	move.b	Serial-V(a6),d0			; Return what was in serial, if nothing it will be 0 (nothing happend)
	cmp.b	#$1b,d0				; is it ESC? if so. we might be in ANSI mode.
	beq	.ansion
	cmp.b	#$d,d0				; is it a linefeed?
	bne	.nolf
	move.b	#$a,d0				; convert it to CR
.nolf:
	rts
.ansion:
	move.b	#1,SerAnsiFlag-V(a6)		; Set flag that we are in ANSImode
	move.w	#0,SerAnsiChecks-V(a6)		; Clear ansicheck variable

	move.b	#0,d0				; return that nothing was recieved
	move.b	d0,Serial-V(a6)
	rts

.ansimode:
	
	move.b	Serial-V(a6),d0			; Load the serialdata to d0
	clr.l	d1				; clear d1 to make sure we do not get crapdata
	cmp.b	#0,d0				; did we get a 0 from serialport?
	beq	.sernull			; if so.. handle it
	cmp.b	#$1b,d0
	beq	.sernull

	cmp.b	#32,d0				; Strip away all nonascii chars
	blt	.noascii


	cmp.b	#$41,d0				;UP
	beq	.up
	cmp.b	#$42,d0				;DOWN
	beq	.down
	cmp.b	#$43,d0				;RIGHT
	beq	.right
	cmp.b	#$44,d0				;LEFT
	beq	.left
.noascii:
	clr.b	d0
	bra	.ansiexit
.ansichar
	move.b	#0,SerAnsiFlag-V(a6)
	bra	.ansiexit

.up:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#30,d0
	bra	.ansiexit
.down:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#31,d0
	bra	.ansiexit
.right:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#28,d0
	bra	.ansiexit
.left:
	clr.b	SerAnsiFlag-V(a6)
	move.l	#29,d0
	bra	.ansiexit
.exitchar:
	POP
	clr.l	d0
	rts
	
.nochar:
	move.b	#$1b,d0
	move.b	#0,SerAnsiFlag-V(a6)

.ansiexit:
	move.b 	d0,Serial-V(a6)
.ansidone:
	POP
	clr.l	d0
	move.b	Serial-V(a6),d0			; Return what was in serial, if nothing it will be 0 (nothing happend)
	rts

.sernull:
	clr.b	d0				; OK we had a binary 0 as result
	add.w	#1,SerAnsiChecks-V(a6)		; add number of times we run through this
	cmp.w	#$f,SerAnsiChecks-V(a6)		; is it max?
	bne	.ansiexit			; if not. just exit with 0
	TOGGLEPWRLED
	move.w	#0,SerAnsiChecks-V(a6)		; ok we had too many checks. guess nothing happened. so exit with an ESC.
	bra	.nochar		
	

ConvertKey:					; Converts keystroke to char.
							; INDATA:
						; a0=pointer to keymap
	move.b	(a0,d0),d1
	move.b	d1,keypressed-V(a6)
	move.b	d1,keyresult-V(a6)
	move.b	EnglishKeyShifted-EnglishKey(a0,d0),d1
	move.b	d1,keypressedshifted-V(a6)
	cmp.b	#0,keyshift-V(a6)
	beq	.notshift
	move.b	d1,keyresult-V(a6)
.notshift:
	rts	

GetKey:			
	PUSH					; Read keyboard
	move.b	#$88,$bfed01
	bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort
	clr.b	keynew-V(a6)			; Clear keynew variable, will be set if we have a new keypress
	clr.b	keyup-V(a6)
	clr.b	keydown-V(a6)
	move.b	$bfec01,d0			; Read keyboard
	move.b	d0,scancode-V(a6)		; Store the original scancode
	ror.b	#1,d0
	not.b	d0
	
	move.b	d0,key-V(a6)			; after rotates etc, store the keycode
	btst	#7,d0				; Test if key is up or down
	beq	.down
	move.b	#1,keyup-V(a6)			; Set that a key was released
	clr.b	keystatus-V(a6)
	bra	.nokey				; Somewhat wrong label.. :)
.down:	
	move.b	#1,keydown-V(a6)		; Set that a key was pressed
	move.b	#1,keystatus-V(a6)
	move.b	#1,keynew-V(a6)

.nokey:
	bset	#6,$bfee01			; Set handshakebit
	sf.b	$bfec01				; Clear keyboardbuffer
	bsr	WaitShort			; Wait a short while
	Bsr	WaitShort
	bsr	WaitShort
	bsr	WaitShort
	bclr	#6,$bfee01			; Clear the handshakebit

						; OK.  we have read the buffer and also cleared it. Lets handle it.

	bclr	#7,d0				; We clear the up/down bit, so we know what key we handled

	cmp.b	#$60,d0
	beq	.shift
	cmp.b	#$61,d0
	beq	.shift
	cmp.b	#$62,d0
	beq	.capsshift			; Now we have handled shift


	cmp.b	#$64,d0
	beq	.alt
	cmp.b	#$65,d0
	beq	.alt				; Now we have handled alt

	cmp.b	#$63,d0
	beq	.ctrl
	cmp.b	#$67,d0
	beq	.ctrl				; Now we have handled ctrl

.keydone:
	POP
	move.b	key-V(a6),d0
	rts

.alt:
	move.b	keystatus-V(a6),keyalt-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone

.ctrl:
	move.b	keystatus-V(a6),keyctrl-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone

.shift:						; we have a happening on the SHIFT key
	cmp.b	#0,keycaps-V(a6)		; Check if caps is pressed
	bne	.caps
	move.b	#0,key-V(a6)
	move.b	keystatus-V(a6),keyshift-V(a6)
.caps:
	bra	.keydone
.capsshift:
	move.b	keystatus-V(a6),keycaps-V(a6)
	move.b	keystatus-V(a6),keyshift-V(a6)
	move.b	#0,key-V(a6)
	bra	.keydone


GetHex:						; Takes an ASCII and returns only valid chars for hex. (and backspace/enter)

						; Input:
						;	D0 = Char

						; Output:
						; 	D0 = Char
	cmp.b	#"0",d0
	blt	.nonumber
	cmp.b	#"9",d0
	bgt	.nonumber
	rts

.nonumber:
	bclr	#5,d0				; Make it uppercase
	cmp.b	#"A",d0
	blt	.nochar
	cmp.b	#"F",d0
	bgt	.nochar
	rts
.nochar:
	cmp.b	#8,d0
	bne	.nobackspace
	rts
.nobackspace:
	cmp.b	#$d,d0
	bne	.checkenter
						; we had linefeed? convert to an enter :)
	move.b	#$a,d0
.checkenter:
	cmp.b	#$a,d0
	bne	.noenter
	rts
.noenter:
	cmp.b	#27,d0
	bne	.noesc
	rts
.noesc:
	move.b	#0,d0
	rts
	

FixBitplane:
; Set bitplanes in copperlist
;
; Indata
;
;	A0 = bitplanespointers in copper
;	A1 = List to bitplane pointers, 0 = End of list
;

	move.l	(a1)+,d0
	cmp.l	#0,d0
	beq.s	.Slut

	move.w	d0,6(a0)
	swap	d0
	move.w	d0,2(a0)
	add.l	#8,a0
	bra.s	FixBitplane
.Slut:
	rts


CopyToChip:					; Copy data that needs to be in Chipmem from ROM for menusystem etc.

	move.l	#0,DummySprite-V(a6)		; Just make sure sprite i empty

	lea	RomMenuCopper,a0
	move.l	a6,a1
	add.l	#MenuCopper-V,a1
	move.l	#EndRomMenuCopper-RomMenuCopper,d0
	bsr	CopyMem				; Copy the font to chipmem

	lea	RomEcsCopper,a0
	move.l	a6,a1
	add.l	#ECSCopper-V,a1
	move.l	#EndRomEcsCopper-RomEcsCopper,d0
	bsr	CopyMem

	lea	RomEcsCopper2,a0
	move.l	a6,a1
	add.l	#ECSCopper2-V,a1
	move.l	#EndRomEcsCopper2-RomEcsCopper2,d0
	bsr	CopyMem


	lea.l	MenuCopper-V(a6),a0
ClearSprite:
	move.w	#7,d0
	move.l	a6,d1
	add.l	#DummySprite-V,d1
.ClearS:
	swap	d1
	move.w	d1,2(a0)

	swap	d1
	move.w	d1,6(a0)

	add.l	#8,a0
	dbf	d0,.ClearS			; A empty dummysprite is now defined
	

	lea	ROMAudioWaves,a0
	move.l	a6,a1
	add.l	#AudioWaves-V,a1
	move.l	#EndROMAudioWaves-ROMAudioWaves,d0
	bsr	CopyMem				; Copy the font to chipmem



	lea	MT_Init,a0
	move.l	a6,a1
	add.l	#ptplay-V,a1
	move.l	#mt_END-MT_Init,d0
	bsr	CopyMem				; Copy the protracker replayroutine to mem

	move.l	a6,d0
	add.l	#ptplay-V,d0			; d0 now contains first address of where replayroutine is in memory
	move.l	d0,AudioModInit-V(a6)
	move.l	d0,d2				; Make a backup of it

	add.l	#MT_End-MT_Init,d0		; Add where MR_End is to a1 so we can store it aswell
	move.l	d0,AudioModEnd-V(a6)		; Store it for future use
	move.l	d2,d0				; Restore a1
	
	add.l	#MT_Music-MT_Init,d0		; Add where MR_Music is to a1 so we can store it aswell
	move.l	d0,AudioModMusic-V(a6)		; Store it

	move.l	d2,d0
	add.l	#mt_MasterVol-MT_Init,d0
	move.l	d0,AudioModMVol-V(a6)

	rts
	

CopyMem:
						; Copy one block memory to another
						; INDATA:
						;	A0 = Source
						;	D0 = Bytes to copy. (YES. being lazy, we do this bytestyle)
						;	A1 = Destination
	clr.l	d7
.loop:
	move.b	(a0)+,(a1)+
	add.l	#1,d7
	cmp.l	d7,d0
	bgt	.loop				; YES a DBF would do just fine. but i want to support more then 64k
	rts


Init_Serial:
	cmp.b	#1,NoSerial-V(a6)
	beq	.noser
	move.w	#$4000,$dff09a
	clr.l	d0
	move.w	SerialSpeed-V(a6),d0		; Get serialspeed
	mulu	#4,d0				; Multiply with 4 to get correct address
	lea	SerSpeeds,a0
	move.l	(a0,d0),d0			; Load d0 with the value to write to the register for the correct speed.
	move.w	d0,$dff032			; Set the speed of the serialport
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c
.noser:
	rts
	

Clean_Serial:
	move.w	#$c000,$dff09a

rs232_out:	
	cmp.w	#0,SerialSpeed-V(a6)
	beq	.noserial
	cmp.w	#5,SerialSpeed-V(a6)
	beq	.noserial
	cmp.b	#1,NoSerial-V(a6)
	beq	.noserial
	PUSH
	bsr	ReadSerial
	move.l	#$90000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
.loop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d2				; count down timeout value
	cmp.l	#0,d2				; if 0, timeout.
	beq	.endloop

	move.w	$dff018,d1
	btst	#13,d1				; Check TBE bit
	beq.s	.loop
.endloop:
	move.w	#$0100,d1
	move.b	d0,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit
	POP
.noserial:
	rts


PutChar:

	PUSH					; Puts a char on the screen.
						; INDATA: (expects longwords)
						; D0 = Char (IF color above 8, it gets reversed in that color - 8)
						; D1 = Color
						; D2 = XPos
						; D3 = YPos

	cmp.b	#1,d0				; Nonprinted char?
	beq	.noprint					

	cmp.b	#0,NoDraw-V(a6)			; Check if we should draw
	bne	.exit

	move.l	d0,d5
	sub.b	#32,d0				; Subtract 32 from the char as " " is the first char in the Font.
	clr.l	d4				; if d4 if 0. no invert of char
	cmp.b	#8,d1
	blt	.Normal				; Normal color. do not invert
	move.b	#1,d4
	sub.b	#8,d1
.Normal:

	mulu	#640,d3				; Multiply Y with 640 to get a correct Y pos on screen
	add.w	d2,d3				; Add�X pos to the d3. D3 now contains how much to add to bitplane to print

	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	Bpl2Ptr-V(a6),a1		; load A1 with address of BPL2
	move.l	Bpl3Ptr-V(a6),a2		; load A2 with address of BPL3
	lea	RomFont,a3

	add.l	d3,a0
	add.l	d3,a1
	add.l	d3,a2				; Add the value to the screen bitplane addresses

	mulu	#8,d0
	add.l	d0,a3
	
	cmp.b	#0,NoChar-V(a6)			; Check if we should print
	bne	.no				; nonzero. do not print


	move.l	#7,d0
.loop:
	move.b	(a3)+,d2

	cmp.b	#1,d4				; IF D4 is 1, invert char
	bne.s	.noinvert
	eor	#$ff,d2
.noinvert:
	clr.b	(a0)
	clr.b	(a1)
	clr.b	(a2)				; To be sure. delete anything
	btst	#0,d1				; Check what bitplane to print on
	beq.w	.nopl1
	move.b	d2,(a0)
.nopl1:
	btst	#1,d1
	beq.s	.nopl2
	move.b	d2,(a1)
.nopl2:
	btst	#2,d1
	beq.s	.nopl3
	move.b	d2,(a2)
.nopl3:
	add.l	#80,a0
	add.l	#80,a1
	add.l	#80,a2
	dbf	d0,.loop			; put char on the screen
.no:
	move.l	d5,d0
.exitwithserial:
	bsr	rs232_out
	POP
	rts


.noprint:
	move.l	#" ",d0
	bsr	rs232_out
	POP
	rts
.exit:
	TOGGLEPWRLED				; As we cannot put any chars on screen. flicker the powerled so user MIGHT
						; notice something is happening. as DMA etc are out. we cannot rely on colors etc.
	move.b	d3,$dff180			; but. just for the "fun" of it. push some random crap on background colotr
	move.b	d0,$dff181
	bra	.exitwithserial

PrintChar:					; Puts a char on screen and add X, Y variables depending on char etc.
						; INDATA: (Longwords expected)
						;	D0 = Char
						;	D1 = Color
	PUSH
	cmp.b	#1,d0				; check if char is $1
	beq	.Noprint			; then it is a nonprinted char
	cmp.b	#$d,d0
	beq	.ignore

	move.l	d0,d7
	move.l	d1,d6
	move.l	d1,d0
	cmp.b	Color-V(a6),d0




	beq	.samecol			; if it is the same color as last time.. do nothing special
	move.b	d0,Color-V(a6)

						; ok we have a new color, change it to serialport
	cmp.b	#8,d0
	blt	.noinvert



	move.b	#1,Inverted-V(a6)		; set the inverted-flag

	lea	Black,a0
	bsr	SendSerial
	sub.l	#8,d1

	lea	Ansi,a0
	bsr	SendSerial			; Send ANSI esc code.
	move.b	#"4",d0
	bsr	rs232_out
	move.b	d1,d0
	bsr	oldbindec
	bsr	SendSerial
	move.l	#"m",d0
	bsr	rs232_out
	bra	.samecol

.noinvert:

	cmp.b	#0,Inverted-V(a6)		; Check if the invertedflag is 0
	beq	.notinverted			; it was 0, last char printed was not inverted

						; last char WAS inverted. we must clear it on the serialport.
	lea	AnsiNull,a0
	bsr	SendSerial			; Send the string to serialport that clears inverted.
	clr.b	Inverted-V(a6)			; clear the invertedflag aswell


.notinverted:

	lea	Ansi,a0
	bsr	SendSerial			; Send ANSI esc code.
	move.b	#"3",d0

	bsr	rs232_out
	move.b	d1,d0
	bsr	oldbindec


	bsr	SendSerial
	move.l	#"m",d0
	bsr	rs232_out
	
.samecol:
	move.l	d6,d1
	move.l	d7,d0
	move.l	#0,d2
	move.l	#0,d3

	cmp.b	#$a,d0				; IF char is $a, new line
	beq.s	.NewLine
	cmp.b	#$d,d0				; IF Char is $d, put cursor to the left
	bne.s	.No
	clr.b	Xpos-V(a6)


	PUSH
	move.b	#"A",d0
	bsr	rs232_out
	POP
.No:
	clr.l	d2
	clr.l	d3				; Clear d2 and d3 so it is all clear before printing the char
.Noprint:
	move.b	Xpos-V(a6),d2
	move.b	Ypos-V(a6),d3			; Take current X and Y positions to d2 and d3 as argument to PutChar
	bsr	PutChar				; Print the char on screen
	add.b	#1,Xpos-V(a6)			; Add one to the Xpos
	cmp.b	#79,Xpos-V(a6)			; check if we have hit the border
	bgt	.NewLine			; we have hit the border. put it on a new line instead.
.ignore:
	POP
	rts

.NewLine:
	clr.b	Xpos-V(a6)			; Put X pos to the left
	add.b	#1,Ypos-V(a6)			; Add Y pos
	PUSH
	move.l	#$a,d0
	bsr	rs232_out
	move.l	#$d,d0
	bsr	rs232_out
	POP
	cmp.b	#31,Ypos-V(a6)			; Hit the border?
	bgt	.EndOfPage			; ohyes.
	POP
	rts
.EndOfPage:
	bsr	ScrollScreen
	clr.b	Xpos-V(a6)
	sub.b	#1,Ypos-V(a6)
	POP
	rts

MakePrintable:
						; Makes the char in D0 printable. remove controlchars etc.
	cmp.b	#" ",d0
	ble	.lessthenspace			; is less then space.. make it space.
	rts
.lessthenspace:
	move.b	#" ",d0
	rts

StrLen:
						; Returns length of string
						; IN:
						;	A0 = Pointer to nullterminated string
						; OUT:
						;	D0 = Length of string
	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d7			; Load d7 with char
	cmp.b	#0,d7
	beq	.exit				; Exit if we found a null
	cmp.b	#2,d7				; if centercommand, skip char
	beq	.skip
	add.l	#1,d0				; add 1 to stringlength
.skip:
	bra	.loop
.exit:
	move.l	d0,temp-V(a6)			; Store length in temp. as we will restore all registers
	POP
	move.l	temp-V(a6),d0			; So back to D0 again
	rts
	

Print:						; Prints a string
	PUSH					; INDATA:
	clr.l	d7				; Clear d7
	cmp.b	#2,(a0)				; Check if first byte in string is a 2, then we will center it.
	beq	.center
.print:						; A0 = string to print, nullterminated
						; D1 = Color
	clr.l	d0
	move.b	(a0)+,d0
	cmp.b	#0,d0				; is the char 0?
	beq	.exit				; exit printing, we are done

	bsr	PrintChar

	add.l	#1,d7				; add one to d7
	cmp.l	#3000,d7			; to avoid "foreverprinting" bug, if string is too long, just stop
	beq	.exit
	
	bra.s	.print
.exit:
	POP
	rts


.center:
	move.l	d1,d5				; backup colordata
	add.l	#1,a0				; First skip this first char.
	move.l	a0,a1				; Store stringaddress for future use.
	clr.l	d7				; Clear d7
.loop:
	move.b	(a0)+,d6			; Read char into d6

	cmp.b	#0,d6				; End of string?
	beq	.end

	cmp.b	#31,d6
	ble	.loop				; is less then space? then it is not printable and should be ignored

	add.l	#1,d7				; Add 1 to length of string
	bra	.loop
.end:						; OK we are done, d7 now contains length of string
	cmp.b	#80,d7				; Check if string is larger then one row, then skip centerstuff
	bge	.zero

	move.l	#80,d1
	sub.b	d7,d1				; d7 now contains number of chars to fill row.
	asr	#1,d1				; Divide by 2, d7 now contains number of spaces to fill out to center

	cmp.b	#0,d1				; Check if zero, then no spaces to be printed
	beq	.zero
	move.l	d1,d7
	sub.b	#1,d7				; Subtract with 1 so loop gets correct number of spaces.

.spaceloop:
	move.b	#" ",d0				; make sure a space is printed
	move.l	d5,d1
	bsr	PrintChar			; Print it
	dbf	d7,.spaceloop			; loop it.

.zero:
	move.l	a1,a0				; We are done, restore string to print (minus first char) and print it
	move.l	d5,d1				; Restore d1 (color)
	bra	.print


ScrollScreen:
	cmp.b	#0,NoDraw-V(a6)			; Check if we should draw
	bne	.exit

	PUSH
	move.l	Bpl1Ptr-V(a6),a0		; load A0 with address of BPL1
	move.l	Bpl2Ptr-V(a6),a1		; load A1 with address of BPL2
	move.l	Bpl3Ptr-V(a6),a2		; load A2 with address of BPL3
	move.l	#EndBpl1-Bpl1,d0		; How much data is one screen
	sub.l	#640,d0				; Subtract 8 pixels
	divu	#4,d0				; Divide by 4 to get longwords.
.loop:
	move.l	640(a0),(a0)+
	move.l	640(a1),(a1)+
	move.l	640(a2),(a2)+	
	dbf	d0,.loop

	move.w	#140,d0
.loop2:
	clr.l	(a0)+
	clr.l	(a1)+
	clr.l	(a2)+				; Clear last row
	dbf	d0,.loop2

	POP
.exit:	rts

SendSerial:
						; Indata a0=string to send to serialport
						; nullterminated

	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d0
	cmp.b	#0,d0				; end of string?
	beq	.nomore				; yes
	bsr	rs232_out
	bra.s	.loop
.nomore:
	POP
	rts

SetPos:						; Set cursor at wanted position on screen
						; Indata:
						; d0 = xpos
						; d1 = ypos

	PUSH
	move.b	d0,Xpos-V(a6)
	move.b	d1,Ypos-V(a6)
	move.l	d0,d2
	move.l	d1,d0
	add.l	#1,d0
	lea	Ansi,a0
	bsr	SendSerial
	bsr	oldbindec			;convert d0 to decimal string (x pos)
	bsr	SendSerial			;and send result to serialport
	move.l	#";",d0				;load d0 with ;
	bsr	rs232_out
	move.l	d2,d0
	add.l	#1,d0
	bsr	oldbindec			;convert d0 (from d1. Ypos) to decimal
	bsr	SendSerial
	move.l	#"H",d0
	bsr	rs232_out
	POP
	rts


SetPosNoSerial:					; Set cursor at wanted position on screen but not on serialport
						; Indata:
						; d0 = xpos
						; d1 = ypos

	move.b	d0,Xpos-V(a6)
	move.b	d1,Ypos-V(a6)
	rts




	; *********************************************
	;
	; $VER:	Binary2Decimal.s 0.2b (22.12.15)
	;
	; Author: 	Highpuff
	; Orginal code: Ludis Langens
	;
	; In:	D0.L = Hex / Binary
	;
	; Out:	A0.L = Ptr to null-terminated String
	;	D0.L = String Length (Zero if null on input)
	;
	; *********************************************


b2dNegative	equ	0			; 0 = Only Positive numbers
						; 1 = Both Positive / Negative numbers

	; *********************************************


bindec:		movem.l	d1-d5/a1,-(sp)

		moveq	#0,d1			; Clear D1/2/3/4/5
		moveq	#0,d2
		moveq	#0,d3
		moveq	#0,d4
		moveq	#0,d5

		lea.l	b2dString+12-V(a6),a0
		movem.l	d1-d3,-(a0)		; Clear String buffer

		neg.l	d0			; D0.L ! D0.L = 0?
		bne	.notZero		; If NOT True, Move on...
		move.b	#$30,(a0)		; Put a ASCII Zero in buffer
		moveq	#1,d0			; Set Length to 1
		bra	.b2dExit		; Exit	
		
.notZero:	neg.l	d0			; Restore D0.L

	IF b2dNegative				; Is b2dNegative True?

		move.l	d0,d1			; D1.L = D0.L
		swap	d1			; Swap Upper Word with Lower Word
		rol.w	#1,d1			; MSB  = First byte
		btst	#0,d1			; Negative?
		beq	.notNegative		; If not, jump to .notNegative
		move.b	#$2d,(a0)+		; Add a '-' to the String
		neg.l	d0			; Make D0.L positive
.notNegative:	moveq	#0,d1			; Clear D1 after use

	endc

.lftAlign:	addx.l	d0,d0			; D0.L = D0.L << 1
		bcc.s	.lftAlign		; Until CC is set (all trailing zeros are gone)

.b2dLoop:	abcd.b	d1,d1			; xy00000000
		abcd.b	d2,d2			; 00xy000000
		abcd.b	d3,d3			; 0000xy0000
		abcd.b	d4,d4			; 000000xy00
		abcd.b	d5,d5			; 00000000xy
		add.l	d0,d0			; D0.L = D0.L << 1
		bne.s	.b2dLoop		; Loop until D0.L = 0
	
		; Line up the 5x Bytes

		lea.l	b2dTemp-V(a6),a1	; A1.L = b2dTemp Ptr
		move.b	d5,(a1)			; b2dTemp = d5.xx.xx.xx.xx
		move.b	d4,1(a1)		; b2dTemp = d5.d4.xx.xx.xx
		move.b	d3,2(a1)		; b2dTemp = d5.d4.d3.xx.xx
		move.b	d2,3(a1)		; b2dTemp = d5.d4.d3.d2.xx
		move.b	d1,4(a1)		; b2dTemp = d5.d4.d3.d2.d1


		; Convert Nibble to Byte
		
		moveq	#5-1,d5			; 5 bytes (10 Bibbles) to check
.dec2ASCII:	move.b	(a1)+,d1		; D1.W = 00xy
		ror.w	#4,d1			; D1.W = y00x
		move.b	d1,(a0)+		; Save ASCII
		sub.b	d1,d1			; D1.B = 00
		rol.w	#4,d1			; D1.W = 000y
		move.b	d1,(a0)+		; Save ASCII
		dbf	d5,.dec2ASCII		; Loop until done...

		sub.l	#10,a0			; Point to first byte (keep "-" if it exists)
		move.l	a0,a1

		; Find where the numbers start and trim it...

		moveq	#10-1,d5		; 10 Bytes total to check
.trimZeros:	move.b	(a0),d0			; Move byte to D0.B
		bne.s	.trimSkip		; Not Zero? Exit loop
		add.l	#1,a0			; Next Character Byte
		dbf	d5,.trimZeros		; Loop
.trimSkip:	move.b	(a0)+,d0		; Move Number to D0.B
		add.b	#$30,d0			; Add ASCII Offset to D0.B
		move.b	d0,(a1)+		; Move to buffer
		dbf	d5,.trimSkip		; Loop

		; Get string length

		move.l	a1,d0			; D0.L = EOF b2dString
		lea.l	b2dString-V(a6),a0	; A0.L = SOF b2dString
		sub.l	a0,d0			; D0.L = b2dString.Length
		move.b	#0,(a0,d0)
.b2dExit:	movem.l	(sp)+,d1-d5/a1
		rts





oldbindec:					; Converts a binary number to decimal textstring
						; this is my old bin->dec code. it is still here as I need a bin-dec
						; convertion done for ANSI stuff in my print routine. and that can
						; overwrite other data when printing. so to separate the different things
						; why not have this left.  this only handles word and no longwords...
						;
						; INDATA:
						;	D0 = binary number (word)
						; OUTDATA:
						;	A0 = Pointer to "bindecoutput" contining the string

	PUSH
	lea	bindecoutput-V(a6),a0
	move.b	#$20,d1
	tst.w	d0
	bpl	.notneg
	move.b	#$2d,d1
	neg.w	d0
	clr.l	d3
.notneg:
	move.b	d1,(a0)
	add.l	#5,a0
	move.w	#4,d1
.loop:
	ext.l	d0
	divs	#10,d0
	swap	d0
	move.b	d0,-(a0)
	add.b	#$30,(a0)
	swap	d0
	dbra	d1,.loop
	clr.l	d0
.scroll:
	move.w	#6,d2
	lea	bindecoutput-V(a6),a0
	lea	bindecoutput+1-V(a6),a1
	move.b	(a0),d1
	cmp.b	#"0",d1
	bne.s	.stop
	add.b	#1,d0
	cmp.b	#5,d0
	beq.s	.stop
.scroll1:
	move.b	(a1)+,(a0)+
	dbf	d2,.scroll1
	bra.s	.scroll
.stop:
	POP
	lea	bindecoutput-V(a6),a0
	rts


hexbin:						; Converts a longword to binary.
						; NO ERRORCHECk WHATSOEVER!
						; Input:
						;	A0 = String to convert (8 bytes)
						; Output:
						;	D0 = binary number
						;
	PUSH
	clr.l	d0				; Clear D0 that will contain the binary number
	move.l	#3,d7				; Loop this 3 times.
.loop:

	bsr	hexbytetobin

	asl.l	#8,d0				; Rotate d0 8 bits to make room for the next byte
	add.l	d2,d0				; Add the content of d2 to d0
	dbf	d7,.loop			; Repeat 3 times to complete one longword
	move.l	d0,HexBinBin-V(a6)
	POP
	move.l	HexBinBin-V(a6),d0
	rts



hexbytetobin:
	clr.l	d2				; Clear D2 that holds the ASCII code
	move.b	(a0)+,d2			; Read one byte of the string
	bsr	.tobin				; Convert to binary
	move.l	d2,d1				; Store the value in D1
	move.b	(a0)+,d2			; Read next char to complete this byte
	bsr	.tobin				; Convert to binary
	asl.l	#4,d1				; Rotate the first char 4 bits
	add.l	d1,d2				; add d1 to d2, d2 will now contain this byte in binary
	rts
.tobin:
	cmp.b	#"A",d2				; Check if it is "A"
	blt	.nochar				; Lower then A, this is not a char
	sub.l	#7,d2				; ok we have a char, subtract 7
.nochar:
	sub.l	#$30,d2				; Subtract $30, converting it to binary.
	rts

binhexbyte:
						; Same as binhex but only for one byte.
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	add.l	#9,a0
	move.l	#1,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput+7-V(a6),a0
	rts



binhexword:
						; Same as binhex but only for one word.
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	add.l	#9,a0
	move.l	#3,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput+4-V(a6),a0
	move.b	#"$",(a0)
	rts
						; Same as binhex but only for one byte.


binstringbyte:
						; Converts a binary number (byte) to binary string
						; INDATA:
						;	D0 = binary number
						; OUTDATA:
						;	A0 = Poiner to outputstring
	PUSH
	move.l	#7,d7
	lea	binstringoutput-V(a6),a0
.loop:
	btst	d7,d0
	beq	.notset
	move.b	#"1",(a0)+
	bra	.done
.notset:
	move.b	#"0",(a0)+
.done:
	dbf	d7,.loop
	move.b	#0,(a0)
	
	POP
	lea	binstringoutput-V(a6),a0
	rts


binstring:
						; Converts a binary number (longword) to binary string
						; INDATA:
						;	D0 = binary number
						; OUTDATA:
						;	A0 = Poiner to outputstring
	PUSH
	move.l	#31,d7
	lea	binstringoutput-V(a6),a0
.loop:
	btst	d7,d0
	beq	.notset
	move.b	#"1",(a0)+
	bra	.done
.notset:
	move.b	#"0",(a0)+
.done:
	dbf	d7,.loop
	move.b	#0,(a0)
	
	POP
	lea	binstringoutput-V(a6),a0
	rts

		

binhex:						; Converts a binary number to hex
						; INDATA:
						;	D0 = binary nymber
						; OUTDATA:
						;	A0 = Pointer to "binhexoutput" contiaing the string
	PUSH
	lea	hextab,a1			; location of hexstring source
	lea	binhexoutput-V(a6),a0
	clr.l	(a0)
	clr.l	4(a0)
	clr.w	8(a0)				; Clear the area first.
	move.b	#"$",(a0)			; put a leading "$" char in the beginning
	add.l	#9,a0
	move.l	#7,d1
.loop:
	move.l	d0,d2
	and.l	#15,d2
	move.b	(a1,d2),-(a0)
	lsr.l	#4,d0
	dbra	d1,.loop
	POP
	lea	binhexoutput-V(a6),a0
	rts

HandleMenu:					; Routine that handles menus.
	cmp.b	#0,MenuChoose-V(a6)		; If this item chosen with keyboard etc?
	bne	.released			; if so.  go to "releaaed" (after LMB is released again..)
	cmp.b	#1,MBUTTON-V(a6)
	bne	.nobutton			; no mousebutton pressed

.CheckButton:
	bsr	GetInput
	bsr	WaitShort
	cmp.b	#0,MBUTTON-V(a6)
	bne	.CheckButton
.released:
	clr.b	MenuChoose-V(a6)		; Clear value of choosen item
	clr.l	d0
	move.w	MenuNumber-V(a6),d0
	lea	MenuCode,a0			; Get list of pointers to list for the menu
	mulu	#4,d0				; Multiply menunumber with 4
	add.l	d0,a0				; read pointer to the correct menu
	move.l	(a0),a0				; a0 now contains address of menu routines

	clr.l	d0
	move.b	MarkItem-V(a6),d0		; Get the marked item
	mulu	#4,d0
	
	add.l	d0,a0				; a0 now contains the address of the pointer to the routing
	move.l	(a0),a0				; a0 now contains the address of the routine.

	jmp	(a0)				; go there
.nobutton:

	clr.l	d0
	move.w	MenuNumber-V(a6),d0
	lea	MenuKeys,a0
	mulu	#4,d0
	add.l	d0,a0
	move.l	(a0),a0				; A0 now contains pointer to where list of interesting keys are.
	clr.l	d0				; Clear d0
.loop:
	cmp.b	#0,(a0)				; does A0 point to 0? in that case, out of list
	beq	.nokey

	move.b	GetCharData-V(a6),d7		; d7 is now what the last keycode was.
	cmp.b	(a0),d7				; check if value in list is the same as pressed keycode
	beq	.Pressed
.nokeyboard:
	add.l	#1,a0
	add.l	#1,d0
	bra	.loop
.nokey:	
	rts

.Pressed:					; ok we have a match of key or serial.
	move.b	d0,MarkItem-V(a6)		; store it to marked item
	bra	.released			; so jump to the part of the code that actually executes the routine

PrintMenu:
						; Prints out menu.
						; INDATA = D0 - MenuNumber
	PUSH
	clr.l	d1
	clr.l	d2
	clr.l	d3
	clr.l	d4
	clr.l	d5
	clr.l	d6
	clr.l	d7
	move.w	MenuNumber-V(a6),d0
	cmp.w	OldMenuNumber-V(a6),d0		; Check if menu is changed since last call
	beq	.nochange
	clr.b	MarkItem-V(a6)			; Clear variables for marked item etc
	clr.b	OldMarkItem-V(a6)	
	move.w	d0,OldMenuNumber-V(a6)
.nochange:
	cmp.b	#0,PrintMenuFlag-V(a6)
	beq	.noprint			; if flag is 0, menu is already printed.
	cmp.b	#2,PrintMenuFlag-V(a6)		; Check if we just want to update
	beq	.noupdatemenu
	move.b	#0,MenuPos-V(a6)		; Clear menuposition. always start at the top as we didnt want to update
.noupdatemenu:	
	clr.l	d0
	move.w	MenuNumber-V(a6),d0		; Load what menunumber to print
	move.l	MenuVariable-V(a6),a2		; A2 now contains pointer to pointerlist of variables. if 0 = no variables ignore

	move.l	Menu-V(a6),a0			; Load a0 with pointer to list of menus.
.nozero:
	mulu	#4,d0				; multiply d0 with 4 to point on the correct item on list.
	add.l	d0,a0				; A0 now points on the correct item in the menulist
	move.l	(a0),a1				; A1 now contains the menuinfo.

	clr.l	d0
	clr.l	d1
	bsr	SetPos
	move.l	(a1),a0				; Print first line (label) of the menu
	move.l	#7,d1
	
	cmp.b	#0,UpdateMenuNumber-V(a6)	; Check if we will only update one line.
	bne	.nolabel			; if so, skip printing label
	bsr	Print				; Print label of the menu
.nolabel:
	add.l	#4,a1				; Skip first row of itemlist as it was the label
	move.l	a1,a0				; Copy a1 to a0


	clr.l	d1				; Clear D1
	move.l	a0,a1


.loop:
	add.l	#1,d1				; Add 1 to D1 for number of entrys in list
	cmp.l	#0,(a1)+			; is A1 pointing to a 0?
	bne.s	.loop				; no, we are not at end of list if items in the menu.
	sub.l	#2,d1				; we ARE at end of itmes, and as we counted the last 0 aswell.. subtract with 2
						; d1 now contrains number of items in this menu.

	move.b	d1,MenuEntrys-V(a6)


	move.l	d1,d5				; Copy d1 to d5

	move.l	#20,d6				; Set d6 to X pos of text in menu
	move.l	#5,d7				; Set d7 to 5, where to start text on the meny on the Y pos

	move.l	a0,a1				; a1 is now list of items in menu
	clr.l	d4


.loop2:
	add.l	#1,d4
	move.l	(a1)+,a0

	cmp.b	#0,UpdateMenuNumber-V(a6)
	beq	.prnt
	cmp.b	UpdateMenuNumber-V(a6),d4	; Check if we just should update one line
	bne	.noprnt	
.prnt:
	move.l	d6,d0
	move.l	d7,d1
	bsr	SetPos				; Set position on screen for next item to be printed.
	move.l	#6,d1
	bsr	Print

.noprnt:
	cmp.l	#0,a2				; Check if A2 is 0.  if so, do not do anything with variables
	beq	.novar
						; OK, we have variables to be printed after the normal menuitem
						; A2 is a pointer to where a list of variables are located.
						; it is actually just a list if pointers to strings to be printed.
						; first word is color to print, next longword is pointer to string to be
						; printed.

	cmp.b	#0,UpdateMenuNumber-V(a6)
	beq	.prntvar
	cmp.b	UpdateMenuNumber-V(a6),d4	; Check if we just should update one line
	bne	.noprntvar
.prntvar:
	lea	SPACE,a0
	bsr	Print

	move.w	(a2),d1				; Set color
	move.l	2(a2),a0			; Set string
	cmp.l	#0,a0				; is A0 0? then skip printing
	beq	.novar
		
	bsr	Print				; Print it
.noprntvar:
	add.l	#6,a2				; add 6 to a2 for next varaibledata to print

.novar:
	add.l	#2,d7				; Add 2 to next row to print.
	dbf	d5,.loop2			; Print all items on the menu
	move.b	#1,UpdateMenuFlag-V(a6)
	move.b	#0,UpdateMenuNumber-V(a6)
.noprint:
						; ok we have printed the menu (or skipped it, depending on flag)
						; now lets see if it needs to be updated.
	clr.l	d7
	move.b	MenuEntrys-V(a6),d7
						; but to be sure, we add 1 to the result.
					
	clr.l	d0
	move.b	GetCharData-V(a6),d0

	cmp.b	#30,d0
	bne	.NoUp

	bsr	.Up
	bra	.NoKeyMove
	
.NoUp:
	cmp.b	#31,d0
	bne	.NoDown
	bsr	.Down
	bra	.NoKeyMove

.NoDown:
	cmp.b	#$a,d0
	bne	.NoEnter
	move.b	#1,MenuChoose-V(a6)

.NoEnter:


.NoKeyMove:


	move.w	CurAddY-V(a6),d7		; Load d7 with any value of added (lower) mousemovement
	cmp.w	#0,d7
	beq	.noadd				; no movements down...


	clr.w	MenuMouseSub-V(a6)		; ok we add, then clear any sub variable
	add.w	d7,MenuMouseAdd-V(a6)		; add it to mouseadd variable
	cmp	#40,MenuMouseAdd-V(a6)		; Check if we moved enough to bump menu one step
	blt	.noadd	

	clr.w	MenuMouseAdd-V(a6)
	bsr	.Down
	
.noadd:
	move.w	CurSubY-V(a6),d7
	cmp.w	#0,d7
	beq	.nosub

	clr.w	MenuMouseAdd-V(a6)
	add.w	d7,MenuMouseSub-V(a6)
	cmp.w	#40,MenuMouseSub-V(a6)
	blt	.nosub

	clr.w	MenuMouseSub-V(a6)
	bsr	.Up

.nosub:

	clr.l	d7
	move.b	MenuPos-V(a6),d7		; Load d7 with menupostin to highlight

	move.b	d7,MarkItem-V(a6)

	cmp.b	#0,PrintMenuFlag-V(a6)		; check if menu is printed
	bne	.forceupdate			; if so, also force update of the marked line etc

	cmp.b	OldMarkItem-V(a6),d7		; Compare the value with the old marked item
	beq	.noupdate			; no changes done, no updates needed.
.forceupdate:

	clr.l	d7
	move.b	OldMarkItem-V(a6),d7		; d7 now contains the number of the FORMERLY marked item.
	move.b	#6,d6				; Set Color
	bsr	.PrintItem			; print it.
	

	clr.l	d7
	move.b	MarkItem-V(a6),d7
	move.b	d7,OldMarkItem-V(a6)

	move.l	#13,d6
	bsr	.PrintItem


.noupdate:				
	clr.b	PrintMenuFlag-V(a6)		; ok, clear the print menu flag..  we do not want this to be printed again;
	
	POP
	rts


.Up:
	cmp.b	#0,MenuPos-V(a6)		; check if we already are at the top
	beq	.No
	sub.b	#1,MenuPos-V(a6)		; Move up one step
.No:	rts

.Down:
	clr.l	d7
	move.b	MenuEntrys-V(a6),d7
	cmp.b	MenuPos-V(a6),d7
	beq	.No
	add.b	#1,MenuPos-V(a6)
	rts


.PrintItem:					; Prints item on menu.
						; d7 = item to print
						; d6 = color to use when printing

	PUSH					
	move.w	MenuNumber-V(a6),d0		; Load what menunumber to print

	move.l	Menu-V(a6),a0			; Load a0 with pointer to list of menus.
	mulu	#4,d0				; multiply d0 with 4 to point on the correct item on list.
	add.l	d0,a0				; A0 now points on the correct item in the menulist
	move.l	(a0),a1				; A1 now contains the menuinfo.
	add.l	#4,a1				; Skip first item as it is the label anyway.

	move.l	d7,d2				; copy d1 to d2 so d2 also contains the item to highlight.
	mulu	#2,d2				; Multiply d2 with 2 to get the row to print the text on.

	move.l	#20,d0				; Load d0 with X Postition of menu
	move.l	#5,d1				; Load d1 with beginning of Y position
	add.l	d2,d1				; add number of lines for the item to update
	bsr	SetPos				; Set screenposition
	move.l	d7,d2				; copy d7 to d2
	mulu	#4,d2				; Multiply with 4, so we know what item in list to point to
	add.l	d2,a1				; add it to a1, a1 now points to pointer of string to update
	move.l	(a1),a0				; load A0 with actual string
	move.l	d6,d1				; Set color
	bsr	Print				; Print it.
	POP
	rts


PrintStatus:
	move.l	#0,d0
	move.l	#31,d1
	bsr	SetPos
	lea	StatusLine,a0
	move.l	#3,d1
	bsr	Print
	rts

UpdateStatus:
	move.l	#8,d0				; Print Serialspeed
	move.l	#31,d1
	bsr	SetPos
	clr.l	d0
	move.w	SerialSpeed-V(a6),d0		; Get SerialSpeed value
	mulu	#4,d0				; Multiply with 4
	lea	SerText,a0			; Load table of pointers to different texts
	move.l	(a0,d0.l),a0			; load a0 with the value that a0+d0 points to (text of speed)
	move.l	#7,d1
	bsr	Print

	move.l	#25,d0				; Print CPU type
	move.l	#31,d1
	bsr	SetPos
	lea	CPU,a0
	move.l	#7,d1
	bsr	Print

	move.l	#39,d0				; Print Chipmem
	move.l	#31,d1
	bsr	SetPos
	move.l	TotalChip-V(a6),d0
	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print
	move.l	#56,d0
	move.l	#31,d1
	bsr	SetPos
	move.l	#7,d1
	move.l	TotalFast-V(a6),d0
	bsr	bindec
	bsr	Print
	move.l	#69,d0
	move.l	#31,d1
	bsr	SetPos
	move.l	a6,d0
		ifne	rommode
	sub.l	#Endstack-Variables+4,d0
		endc
	bsr	binhex
	move.l	#7,d1
	bsr	Print

	rts


MainMenu:
	bsr	FilterON
	bsr	ClearScreen			; Clear the screen
	bsr	PrintStatus			; Print the statusline
	bsr	UpdateStatus			; Update "static" data of statusline
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	move.l	#Menus,Menu-V(a6)		; Set Menus as default menu. if different set another manually
	move.l	#0,MenuVariable-V(a6)
	move.w	#0,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)


	bra	MainLoop


InitScreen:
	bsr	ClearScreen
	bsr	PrintStatus
	bsr	UpdateStatus
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	rts

CheckMemory:
						; Checks memory
						; IN:
						;	D0 = Startaddress
						;	D1 = Endaddress
						;	D2 = 0=NORMAL 1=FAST Check (no bitchecks etc and no counting/errors)
						;	     2=NORMAL but no clear of detected memory etc, to be used to check another block.
						;
						; OUT:
						;	D0 = Number of errors


	cmp.l	d0,d1				; Check if we actually have memory to scan
	bls	.nomem
	
	move.l	#"BEEF",$0			; make sure address 0 is something we never check for.  for shadowramtests

	move.b	d2,CheckMemFast-V(a6)
	lea	CheckMemBitErrors-V(a6),a0
	move.l	#31,d6				; ok lets do this for all bits
.clearloop:
	clr.b	(a0)+
	dbf	d6,.clearloop
	lea	CheckMemByteErrors-V(a6),a0
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+

	cmp.b	#2,CheckMemFast-V(a6)		; Check if mode is 2=normal check but no clearing of some resultdata.
	beq	.continue			; if so. skip some clearing here

	lea	CheckMemErrors-V(a6),a0
	clr.l	(a0)				; now all data is cleared so old results doesnt show
	lea	CheckMemRow-V(a6),a0
	move.b	#13,(a0)
.continue:

	lea	CheckMemFrom-V(a6),a0

	move.l	d0,(a0)+			; Set startaddress
	move.l	d1,(a0)+			; Set endaddress
	clr.l	(a0)+				; clear current address
	cmp.b	#2,CheckMemFast-V(a6)
	beq	.continue2
	clr.l	(a0)+				; clear checked mem
	clr.l	(a0)+				; clear usable mem
	clr.l	(a0)+				; clear nonusable mem
	bra	.nocontinue			; ok this is the last part of "skippable" stuff if in continue mode.
.continue2:
	move.b	#0,CheckMemFast-V(a6)		; so now set the flag to 0 as in Normal mode.
	bsr	CheckMemNewRow			; Get next row for status
.nocontinue:
	lea	CheckMemType-V(a6),a0
	clr.b	(a0)
	lea	CheckMemOldType-V(a6),a0
	move.b	#$87,(a0)			; writing a crapnumber there.. so there will be a change first time
	

	clr.l	d0
	move.l	#3,d1
	bsr	SetPos
	lea	CheckMemRangeTxt,a0
	move.l	#7,d1
	bsr	Print				; Print checking memory from...


	clr.l	d0
	move.l	#5,d1
	bsr	SetPos
	lea	CheckMemCheckAdrTxt,a0
	move.l	#7,d1
	bsr	Print				; Print Checking address..


	cmp.b	#0,CheckMemFast-V(a6)		; Check if in fastmode
	bne	.fastmode			; if so.. skip som texts here

	lea	CheckMemBitErrTxt,a0
	move.l	#7,d1
	bsr	Print				; Print Bit error shows max....


	lea	CheckMemBitErrorsTxt,a0
	move.l	#3,d1				; Print Biterros and byte errors
	bsr	Print


	move.l	#53,d0
	move.l	#9,d1
	bsr	SetPos
	lea	CheckMemNumErrTxt,a0
	move.l	#3,d1
	bsr	Print				; Print "Number of errors"
	bra	.nofast
.fastmode:
	lea	CheckMemFastModeTxt,a0
	move.l	#2,d1
	bsr	Print


.nofast:
	move.l	#0,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemCheckedTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#26,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemUsableTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#52,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemNonUsableTxt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#3,d1
	move.l	#21,d0
	bsr	SetPos
	lea	CheckMemFrom-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d7
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print startaddress of test

	move.l	#3,d1
	move.l	#34,d0
	bsr	SetPos
	lea	CheckMemTo-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d6
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print endaddress of test


	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	lea	DividerTxt,a0
	move.l	#4,d1
	bsr	Print

	move.l	d7,a0				; set A0 to startaddress
	move.l	d6,a1				; set A1 to endaddress
	sub.l	#8,a1

						; Lets do actual memorytesting
.checkloop:	

	cmp.b	#0,CheckMemNoShadow-V(a6)	; check if we should skip shadowmemtests
	bne	.notchip			; so go to "not chip" so we skip shadowtests on chipmem
	

	cmp.l	#$200000,a0
	bhi	.notchip			; check if scanned memory is within chipmem
						; ok we are in chipmem
						; so lets check if we have "shadow" memory. meaning we write at one address
						; is it readable on another. meaning we actually do not have any memory there



	cmp.l	#1024*1024,a0			; have we checked more then 1024kb of chipmem?
	blo	.nomorethen1024
						; ok we have checked more then 1024k
	move.l	a0,a2
	sub.l	#1024*1024,a2			; subtract 1MB to current address

	bsr	.checkshadow
	bra	.notchip
.nomorethen1024:

	cmp.l	#512*1024,a0			; have we checked more then 512kb of chipmem?
	blo	.nomorethen512
						; ok we have checked more then 512k
	move.l	a0,a2
	sub.l	#512*1024,a2			; subtract 512k to current address

	bsr	.checkshadow
	bra	.notchip
.nomorethen512:

	cmp.l	#256*1024,a0			; have we checked more then 256kb of chipmem?
	blo	.nomorethen256
						; ok we have checked more then 256k
	move.l	a0,a2
	sub.l	#256*1024,a2			; subtract 256k to current address

	bsr	.checkshadow

.nomorethen256:					; ok those tests could be "nicer" done...

.notchip:

	TOGGLEPWRLED

	lea	MEMCheckPattern,a2		; Load list of data to test.
	clr.l	d7				; Clear d7, as it will contain set bits of faliing bits

	lea	CheckMemChecked-V(a6),a3
	cmp.b	#0,CheckMemFast-V(a6)
	bne	.fastmode3
	add.l	#4,(a3)
	bra	.nofastmode3
.fastmode3:
	add.l	#1024,(a3)
.nofastmode3:

.checkpattern:
	move.l	(a0),d2				; Take a backup of what is in the memory for the moment
	move.l	(a2)+,d0

	move.l	d0,(a0)				; Write d0 to memoryaddress
	nop					; 040 will need this to write data to memory
	move.l	(a0),d1				; Read from memory and put into d1. (this will work in ROM mode, as cache is off)

.noerr:

	cmp.b	#0,CheckMemNoShadow-V(a6)	; check if we should skip shadowmemtests
	bne	.noshdw				; so we skip shadowtest


	cmp.l	$0,d0				; IF the data we are looking for is also on $0, then we are dealing
	bne	.noshdw				; with shadowram and should stop
	move.l	#"SHDW",d7
	bra	.finished
.noshdw:

	move.l	d2,(a0)				; Write back old data to the memory so we do not corrupt anything
	cmp.l	d0,d1				; Compare what we wrote with what we read..
	bne	.error				; If there was an error jump to .error

.aftererror:					; we are safe

	cmp.l	#0,d0				; was d0 = 0 then we are at the end of the memorytest-list
	bne	.checkpattern

						; Now d7 will contain 0 if memory was OK, if not. the bit with problem will
						; be set in d7

	lea	CheckMemCurrent-V(a6),a5
	move.l	a0,(a5)				; Write a0 to current address being checked.



	cmp.l	#0,d7				; Did we have an error on last run?
	beq	.noerror			; Nope, jump to noerror

						; OK we are in an errorcondition. (gahh! not good :))

						; so lets present type of error to the user. First bitwise.
						; and as we can only see up to $ff on screen we will only see max 255 errors
						; on bits. but hey.. then you atleast knows there are a problem.
					



	lea	CheckMemNonUsable-V(a6),a3
	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.fastmode2
	add.l	#4,(a3)
	bra	.nofastmode2
	
.fastmode2:
	add.l	#1024,(a3)

.nofastmode2:
	cmp.b	#$ffffffff,d7			; did we have error on ALL bits? meaing a DEAD memory???
	bne.w	.nodead				;nope

	lea	CheckMemType-V(a6),a2
	move.b	#0,(a2)				; Write that we had an error
	bra	.wehaddead
.nodead:


	lea	CheckMemType-V(a6),a2
	move.b	#1,(a2)				; Write that we had an error

.wehaddead:

	lea	CheckMemErrors-V(a6),a2
	add.l	#1,(a2)

	lea	CheckMemBitErrors-V(a6),a2
	move.l	#31,d6				; ok lets do this for all bits
.loop:
	btst	d6,d7				; check if this bit had an error
	beq	.nobiterror
						; OK, we had an error.  lets step up the bitcounter
	clr.l	d0
	move.b	(a2),d0
	cmp.b	#255,d0				; is this already 255? then do not add any more
	beq	.nobiterror			; this name is wrong.. but anyway.. :)
	add.b	#1,(a2)				; add 1 to biterror
.nobiterror
	add.l	#1,a2				; use next address to store next biterror
	dbf	d6,.loop			; loop through all bits

	lea	CheckMemByteErrors-V(a6),a2
	move.l	d7,d1
	and.l	#$ff000000,d1
	cmp.l	#0,d1
	beq	.noerr1
	add.l	#1,(a2)
.noerr1:
	move.l	d7,d1
	and.l	#$00ff0000,d1
	cmp.l	#0,d1
	beq	.noerr2
	add.l	#1,4(a2)
.noerr2:
	move.l	d7,d1
	and.l	#$0000ff00,d1
	cmp.l	#0,d1
	beq	.noerr3
	add.l	#1,8(a2)
.noerr3:
	move.l	d7,d1
	and.l	#$000000ff,d1
	cmp.l	#0,d1
	beq	.noerr4
	add.l	#1,12(a2)
.noerr4:

	bra	.notusable			; Just to skip adding of usable memory
.noerror:

	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.infast1


	lea	CheckMemUsable-V(a6),a3
	add.l	#4,(a3)

	lea	CheckMemType-V(a6),a2
	move.b	#2,(a2)				; Write that we had an usable block of memory
	bra	.notinfast1
.infast1:					; We are in fastmode, we actually only test every longword every 1KB.
	lea	CheckMemUsable-V(a6),a3		; not much as memorytest, more like a scan where there is memory..
	add.l	#1024,(a3)

	lea	CheckMemType-V(a6),a2
	move.b	#2,(a2)				; Write that we had an usable block of memory
	bra	.notinfast1

.notinfast1:
.notusable:
	
	cmp.l	a1,a0				; Checked all memory?
	bhi	.finished			; Yes


	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.infast2

	add.l	#4,a0				; Add 4 to a0 so we check the next longword later
	bra	.notinfast2
.infast2:
	add.l	#1024,a0			; Add 1024 to a0 so we check the "next" longword later, being in fastmode

.notinfast2:

	bsr	GetMouse
	cmp.b	#1,BUTTON-V(a6)			; Check mouse during check, if pressed cancel.  but we do NOT check
	beq	.break				; keyboard and mouse so it doesnt affect speed

	move.l	a0,d0
	divu	#32768,d0			; divide with 32768, if answer is even we have a new 32k block. update status
	swap	d0
	cmp.w	#0,d0
	beq	.update
						; Check if type of memory has been changed, if so force a screenupdate
	lea	CheckMemType-V(a6),a4
	move.b	(a4),d0				; d0 now contains what the type of memory was
	lea	CheckMemOldType-V(a6),a5
	move.b	(a5),d1				; d1 now contains what the former type of memory was. (type=good or not)

	cmp.b	d0,d1				; compare.. do we have a change?
	beq	.noupdate			; if no change.. go to nochange

.update:

	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)			; Check mouse AND keyboard/serial if anything pressed if so cancel
	beq	.break
	bsr	CheckMemoryUpdate		; Update text with memorylocation etc

.noupdate:
	bra	.checkloop

.break:
	bsr	WaitReleased
	
.finished:

	lea	CheckMemType-V(a6),a5
	move.b	#255,(a5)			; write anything that is not in the type. forcing it to update.

	lea	CheckMemCurrent-V(a6),a5
	sub.l	#1,(a5)				; Subtract current address with 1 to show the end.. for a "nicer" look

	bsr	CheckMemoryUpdate		; Update final status of memorycheck
	cmp.l	#"SHDW",d7			; did we exit due to shadow??
	bne	.noshadowmem			; nahhh

	bsr	CheckMemNewRow

	lea	CheckMemRow-V(a6),a0		; Get row.
	clr.l	d1
	move.b	(a0),d1
	clr.l	d0
	move.l	#28,d1
	bsr	SetPos

	lea	MemtestShadowTxt,a0
	move.l	#3,d1
	bsr	Print

.noshadowmem:
.nomem:
	bclr	#1,$bfe001			; Set Powerled ON again
	rts

.error:						; OK, we have a memoryerror. lets break it down and analyze the error.
						; d0 contains what was written
						; d1 contains what was read

	move.l	#31,d6				; We will check 31+1 bits (longword)
.bitloop:
	btst	d6,d0				; Check bit at d6 with d0
	bne	.setread
	clr.l	d2				; we clear d2 as in bit is 0
	bra	.notsetread
.setread:
	move.l	#1,d2				; set it as set.
.notsetread:
						; d2 now contains 0 if bit was not set, 1 if it was set
	btst	d6,d1
	bne	.setwrite
	clr.l	d3
	bra	.notsetwrite
.setwrite:
	move.l	#1,d3
.notsetwrite:	
	cmp.l	d2,d3
	bne	.notsame
	dbf	d6,.bitloop
	bra	.errordone
.notsame:
	bset	d6,d7
	dbf	d6,.bitloop
.errordone:
	bra	.aftererror

.checkshadow:
	move.l	(a0),d7				; make a backup of what is in address now
	move.l	#"SHD!",(a0)			; write TEST to current testaddress
	cmp.l	#"SHD!",(a2)			; is it readable on "shadow"
	beq	.shadow				; YES! we DO have a shadow!
	move.l	d7,(a0)
	bra	.noshadow
	
.shadow:					; We have Shadowmemory.. lets stop the test afterall.
	move.l	d7,(a0)
	move.l	#"SHDW",d7			; Write a nonsensestring to d7..
	bra	.finished
.noshadow:
	rts


CheckMemoryUpdate:				; Update text on screen while checking memory

	PUSH


	move.l	#18,d0
	move.l	#5,d1
	bsr	SetPos
	lea	CheckMemCurrent-V(a6),a0	; Print current address to test
	move.l	(a0),d0
	move.l	d0,d7				; Store current address to D7 aswell
	add.l	#4,d0				; Add 4 just to show a more "even" address
	bsr	binhex
	move.l	#7,d1
	bsr	Print				; Print current position of test

	lea	CheckMemTypeChange-V(a6),a1
	clr.b	(a1)				; Just to be sure. clear that we had a change of type

	lea	CheckMemType-V(a6),a0
	move.b	(a0),d0				; d0 now contains what the type of memory was
	lea	CheckMemOldType-V(a6),a1
	move.b	(a1),d1				; d1 now contains what the former type of memory was. (type=good or not)

	move.l	#$fe,d5				; set d5 to $fe telling stuff that we did not have a change..


	cmp.b	d0,d1				; compare.. do we have a change?
	beq	.nochange			; if no change.. go to nochange
						; ok there was a change of blocktype.. (good, bad etc)

	move.b	d0,(a1)				; store the current type to oldtype

	
	lea	CheckMemTypeChange-V(a6),a2
	move.b	#1,(a2)				; Write 1 to tell that there was a change of type.

.scanagain:
	lea	CheckMemTypeStart-V(a6),a0
	cmp.l	#0,(a0)				; if start is 0 we have a new block. if not we are at the end of that block
	beq	.notatend

	move.l	#1,d5				; if d5 is 1.. we are at the end of the block

	bra	.startendsorted	
						; ok we are at the start of the block.
						; d0 still contains type of block.


.notatend:

	lea	CheckMemCurrent-V(a6),a1
	move.l	(a1),d7				; as we can be looped, we are not sure that d7 actually contains the start anymore
						; so better reload it
						; ok we are at the beginning of the block....
	move.l	d7,(a0)				; store the beginning
	clr.l	d5				; d5 is cleared. we are at the beginning of the block


						; As we are in the beginning if the block. lets find out what type of block
						; and set the correct color

	lea	CheckMemType-V(a6),a1
	move.b	(a1),d0				; d0 now contains what the type of memory was


	lea	CheckMemCol-V(a6),a1

	cmp.b	#2,d0				; check if we are type 2 (good)
	bne	.nogood				; nope
.notend:
	move.b	#2,(a1)				; write 2 as color to print
	bra	.gooddone

.nogood:
	cmp.b	#0,d0
	bne.s	.bad				; well not dead either
						; so it is not good or bad. so it is dead....
	move.b	#5,(a1)
	bra	.gooddone
.bad:	
	move.b	#1,(a1)				; write 1 as color to print
	bra	.gooddone			; well. label is somewhat wrong
	
.gooddone:

.startendsorted:

	cmp.b	#255,d0				; are we at the end?
	bne	.notendofscan

	move.b	#255,d5				; we was at the end.. so set d5 to 255

.notendofscan:

	lea	CheckMemCol-V(a6),a1

	clr.l	d6
	move.b	(a1),d6				; color to actually print on


	clr.l	d0				; Clear d0 so it is clear before setpos
	clr.l	d1				; clear d1 aswell

	lea	CheckMemRow-V(a6),a0		; Get what row to print string on
	move.b	(a0),d1				; Set Y pos to that row
	bsr	SetPos				; Set pos of screen

	cmp.b	#5,d6				; check if we print with "dead" color
	bne	.notdead

	lea	CheckMemDeadTxt,a0
	move.l	d6,d1
	bsr	Print
	bra	.notbad

.notdead:
	cmp.b	#2,d6				; check if we print with red color"
	bne	.badblk

	lea	CheckMemGoodTxt,a0
	move.l	d6,d1
	bsr	Print				; Print "Good block.."
	bra	.notbad
.badblk:
	lea	CheckMemBadTxt,a0
	move.l	d6,d1
	bsr	Print				; Print "Bad block.."
	bra	.notbad
	
.notbad:
	lea	CheckMemTypeStart-V(a6),a0
	move.l	(a0),d0
	move.l	d0,d4				; store current position to d4 for later use..
	bsr	binhex
	move.l	d6,d1
	bsr	Print				; Print address

	cmp	#0,d5				; is d5 clear?
	beq	.nochange			; yes. we are at the begining of the block.. no more update to do..
						; no..  we are at the end

	lea	CheckMemEndAtTxt,a0		; print "and ends at"
	move.l	d6,d1
	bsr	Print



	cmp.b	#$ff,d5				; end?
	bne	.nottheend
	add.l	#5,d7

.nottheend:
	move.l	d7,d0				; copy current pos to d0
	sub.l	#1,d0				; Subtract with 1 to show address of last working byte.
	bsr	binhex
	move.l	d6,d1
	bsr	Print				; Print endaddress


	lea	CheckMemSizeOfTxt,a0		; print "with a size of"
	move.l	d6,d1
	bsr	Print


	lea	CheckMemTypeStart-V(a6),a0
	move.l	(a0),d0				; Get startaddress of this block

	sub.l	d0,d7				; d7 now contains total size of this block
	move.l	d7,d0

	asr.l	#8,d0
	asr.l	#2,d0				; Divide d0 with 1024 so we know how much memory in kb we got

	bsr	bindec
	move.l	d6,d1
	bsr	Print				; Print out number of KB
	

	move.l	d6,d1
	lea	KB,a0
	bsr	Print				; Print "KB" text


	lea	CheckMemTypeStart-V(a6),a2
	clr.l	(a2)				; clear the startaddress. as we had a change


.nochange:


	cmp.b	#0,CheckMemFast-V(a6)		; check if we are in fastmode
	bne	.fastmode

	move.l	#12,d0				; Set cursor at beginning of biterror
	move.l	#8,d1
	bsr	SetPos

	lea	CheckMemBitErrors-V(a6),a5


	move.l	#3,d6
.bitloop2:
	move.l	#7,d7
.bitloop:
	clr.l	d0
	move.b	(a5)+,d0
	move.l	#2,d1				; Set for Green color
	cmp.b	#0,d0
	beq	.noerr
	move.l	#1,d1				; we had an error, set for red color
.noerr:	
	bsr	binhexbyte
	bsr	Print
	dbf	d7,.bitloop
	move.b	#" ",d0
	bsr	PrintChar
	dbf	d6,.bitloop2			; Loop so we print 4 chunks of bitdata

	lea	CheckMemByteErrors-V(a6),a5
	move.l	#3,d2
	move.l	#13,d6				; set X pos of text
.byteloop:
	move.l	d6,d0				; Set X pos
	move.l	#9,d1				; Set Y pos
	bsr	SetPos

	move.l	(a5)+,d0
	move.l	#2,d1				; Set for green color
	cmp.l	#0,d0
	beq	.noerr2
	move.l	#1,d1				; We had an error, set color to red
.noerr2:
	bsr	bindec
	bsr	Print
	move.b	#" ",d0
	bsr	PrintChar
	add.l	#10,d6
	dbf	d2,.byteloop			; Loop and print 4 longwords of errordata


	move.l	#71,d0
	move.l	#9,d1
	bsr	SetPos
	move.l	#1,d1
	lea	CheckMemErrors-V(a6),a0
	move.l	(a0),d0
	move.l	#2,d1
	cmp.l	#0,d0
	beq	.noerr3
	move.l	#1,d1
.noerr3:
	bsr	bindec
	bsr	Print
.fastmode:
	move.l	#16,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemChecked-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print how much memory is tested

	move.l	#41,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemUsable-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#7,d1
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print how mush memory is usable

	move.l	#70,d0
	move.l	#11,d1
	bsr	SetPos
	lea	CheckMemNonUsable-V(a6),a0
	move.l	(a0),d0
	asr.l	#8,d0
	asr.l	#2,d0


	bsr	bindec
	move.l	#7,d1
.nonousableprint:
	bsr	Print
	lea	KB,a0
	bsr	Print				; Print hos much memory is not usable


	cmp.b	#0,d5				; check if we was at the end of the scan
	beq	.endofscan
						; ok we is not at the end of the scan. and we had a typedifference.
						; so we have to do this all again on a new row.

	cmp.b	#$fe,d5				; check if we didnt have a change of type
	beq	.endofscan

	cmp.b	#$ff,d5				; check if we was at the end of memoryscan
	beq	.endofscan

	lea	CheckMemTypeStart-V(a6),a0

	clr.l	(a0)				; first clear the startaddress. so the routine handles it as a new happening

	bsr	CheckMemNewRow

	lea	CheckMemTypeChange-V(a6),a1
	cmp.b	#1,(a1)				; did we have a change of type? if so we have to do this all over again.
	bne	.endofscan			; no. we did not have a change of type
						; yes we had
	clr.b	(a1)				; to avoid an eternal loop. clear the changeflag
	bra	.scanagain			; do it all again
.endofscan:

	POP
	rts

CheckMemNewRow:
	lea	CheckMemRow-V(a6),a0		; Get row.
	clr.l	d0
	move.b	(a0),d0
	cmp.b	#30,d0
	bne	.notlastrow
	move.b	#13,(a0)			; we reaced last row. .so start from the beginning again
	bra	.rowdone
.notlastrow:
	add.b	#1,(a0)				; write the stuff on the next row
.rowdone:	
	rts


DetectMBFastmem:				; A very fast detection of fastmem made for startup before stackusage etc.
						; INdata:
						; d1 = total block of known working 16Kb fastmem blocks. (CLEAR before first usage)
						; d2 = size of memory found at a0 (CLEAR before fist usage) (in number of 16k blocks)
						; a0 = First usable address (CLEAR before first usage)
						; a1 = First address to scan
						; a2 = Address to end scan
						; a3 = adress to jump to after we are done with this routine
						;
						; Detection is done that it checks one longword every 16k and assumes a working 16k block if successful)

	clr.l	d3				; total size of memory found in this scan
	clr.l	d4
	clr.l	d5				; Will contain first memoryadress found
.loop1:
	lea	MEMCheckPattern,a5		; list of memcheck pattern
	add.b	#4,d4				; just add a number, d4 is only for screenflash when a good longword is found
.loop:
	move.l	(a5)+,d7			; load next pattern to d7
	move.l	d7,(a1)				; write d7 to memoryaddress to check
	move.b	d7,$dff180
	nop					; needed for 040
	move.l	(a1),d6				; read the same address to d6
	cmp.l	d6,d7				; compare if they are the same
	bne	.checknext			; if not. go to check next block
	cmp.l	#0,d7				; Check if d7 was 0, meaning we are done with out check of this longword
	bne	.loop

	move.b	d4,$dff181			; just to make somewhat coloreffect onscreen so user can see that something is happening

	cmp.l	#0,d5				; check if this is the first memoryblock we found that are working
	bne	.notfirst			; nope, not first block
	move.l	a1,d5				; store the current address to a5 as it is the first working address
.notfirst:
	add.l	#1,d3				; Add 1 to d3 for a working block
.checknext:
	add.l	#16384,a1			; add 16k to a1 for next memoryblock to scan
	cmp.l	a1,a2				; check if we are finished
	bgt	.loop1				; OK, we are not finished. lets check next block

						; OK  we are done with checking everyting
	cmp.l	#0,a0				; check if a0 is 0, if not we already have memory that are usable
	bne	.nomemneeded
						; ok we had no working memory, lets tell what memory we have
	cmp.l	#0,d5				; check if we actually did find any memory atall?
	beq	.nomemneeded			; ok fuck it, we did not find any memory anyway

	move.l	d5,a0				; we found memory and no memory detected before that. so make this detected
						; memory as found block
	move.l	d3,d2				; also store size of this block

.nomemneeded:
	add.l	d3,d1				; add this detected blocksize of total size of fastmem
	jmp	(a3)				; we are done.  jump to what a3 points to.


DetectMem:
						; Detects memory
						; Indata:
						; a0 = Startadress.. or actually END of block as it scans backwards.
						; a1 = Endadress (or.. startadress)
						; Outdata:
						; d0 = Total amoumt of memory found (caluclated from 16Kb blocks)
						; d1 = if anything then 0, total memory was found in several blocks.
						; (like: you have  bad simm, placed wrong or so...)
						; a0 = first memoryaddress
						; a1 = last memoryaddress

			
						; (as the Amiga assigns memory that way)

	PUSH
	clr.l	d0				; Clear total amount of memory
	clr.l	d1				; Clear the "several block" flag
	clr.l	d3				; if 0, no memory found yet
	clr.l	d4				; Tempvariable holding the last working memaddress
	clr.l	d5				; Tempvariable holding the first working memaddress (last. scanning backwards)
	

	move.l	a0,a3				; Make a backup of the lowest memoryaddress

	cmp.l	#$ffffff,a1			; Check if testadress is above the 24bit limit
	ble	.check				; no, jump to check

	move.l	$700,d2				; Make a backup of $700
	clr.l	$700				; Clear $700 to be sure
	move.l	#"24BT",$4000700		; Write "24BT" to highmem
	cmp.l	#"24BT",$700			; IF memory is readable at $700 instead. we are using a cpu with 24 bit adress. no memory to detect this time
	beq	.24bitcpu
	move.l	d2,$700				; Restore $700 again

.check:
	sub.l	#$4000,a1			; Check next block of 16K of memory
	move.l	(a1),d2				; Backup data in position to test

	clr.l	d7				; should return 0 if there was no errors.
	lea	MEMCheckPattern,a4
.loop:
	move.l	(a4)+,d6
	move.l	d6,(a1)
	nop
	cmp.l	(a1),d6
	beq	.noerror
	move.b	#1,d7				; Mark that we had an error
.noerror:
	cmp.l	#0,d6				; Was last value a 0? if so, this longword is fully checked
	bne.s	.loop				; no, test some more
	move.l	d2,(a1)				; Restore backup of data to address

	cmp.b	#1,d7
	beq	.error				; If we had an error, handle it


	move.l	a1,d4				; OK, we had no error, meaning this is working memory
						; So store this address in d4
						
	cmp.b	#1,d3				; Check if we had working memory before
	beq	.yesmem				; yes we had
	move.b	#1,d3				; Mark that we now have memory
	move.l	a1,d5				; And store at what memory this segments ends. (yes we scan backwards)
	
.yesmem:

	add.l	#1,d0				; ok, no error, so we had memory. add one to block
.nomem:
	cmp.l	a0,a1				; Check if we scanned the whole block
	bge	.check				; no, scan more
.done:
	
	move.l	d0,temp-V(a6)			; Store size
	move.l	d4,temp+4-V(a6)			; Store firstmemaddress
	move.l	d5,temp+8-V(a6)			; Store last memaddress
	move.l	a3,temp+12-V(a6)		; Store the first WANTED memaddress to scan

						; lets change it to the lowest address we wanted to test

	POP					; Restore all registers
	move.l	temp-V(a6),d0
	asl.l	#6,d0
	asl.l	#8,d0
	move.l	temp+4-V(a6),a0
	move.l	temp+8-V(a6),a1

	cmp.l	temp+12-V(a6),a0		; Check is first memoryaddress is in a lower address than wanted
						; meaning that the 16K chunk was too big
	bgt	.notlower

	PUSH

	move.l	temp+12-V(a6),d1
	move.l	a0,d2
	sub.l	d2,d1				; D1 is now the difference between address we got and the real one
	move.l	d1,temp+8-V(a6)			; Lets store it as temp
	
	bchg	#1,$bfe001			; So lets correct it
;	move.w	#$fff,$dff180
	POP
	move.l	temp+12-V(a6),a0		; Lets put the lowest address to check as address of detected mem
	sub.l	temp+8-V(a6),d0			; Lets subtract sizedifference to size found

.notlower:

	rts

.error:						; OK we had an error in check
	cmp.b	#1,d3				; did we have memory detected before?
	bne	.nomem				; no, so scan for some
	beq	.done				; ok we had memory, this is the end (or beginning of it)
						; so stop.
						

.24bitcpu:					; OK we had a 24bit cpu and wanted to check memory above 24bit.
						; give null as answer
	POP
	clr.l	d0
	lea	$0,a0
	lea	$0,a1
	rts


WaitButton:					; Waits until a button is pressed AND released
	bsr	WaitPressed
	bsr	WaitReleased
	rts


WaitPressed:					; Waits until some "button" is pressed
	clr.l	d7				; Clear d7 that is used for a timeout counter
.loop:
		ifne	rommode			; if we are in rommode, do timeout code..
	add.l	#1,d7				; Add 1 to the timout counter
	cmp.l	#$ffff,d7			; did we count for a lot of times? well then there is a timeout
	beq	.timeout
		endc
	bsr	GetInput			; get inputdata
	cmp.b	#1,BUTTON-V(a6)			; check if any button was pressed.
	bne	.loop				; nope. lets loop
	rts
.timeout:
	rts
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; ok we had a timeout. so we GUESS a port is stuck.
	move.b	P2LMB-V(a6),STUCKP2LMB-V(a6)	; if we just simply copy the status of all keys
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; to the STUCK version. we will disable all stuck ports
	move.b	P2RMB-V(a6),STUCKP2RMB-V(a6)
	move.b	P1MMB-V(a6),STUCKP1MMB-V(a6)
	move.b	P2MMB-V(a6),STUCKP2MMB-V(a6)
	rts

WaitReleased:					; Waits until some "button" is unreleased

	clr.l	d7				; Clear d7 that is used for a timeout counter
.loop:
		ifne	rommode
	move.b	$dff006,$dff180
	add.l	#1,d7				; Add 1 to the timout counter
	cmp.l	#$ffff,d7			; did we count for a lot of times? well then there is a timeout
	beq	.timeout
		endc
	bsr	GetInput			; get inputdata
	cmp.b	#0,BUTTON-V(a6)			; check if any button was pressed.
	bne	.loop				; nope. lets loop
	rts
.timeout:
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; ok we had a timeout. so we GUESS a port is stuck.
	move.b	P2LMB-V(a6),STUCKP2LMB-V(a6)	; if we just simply copy the status of all keys
	move.b	P1LMB-V(a6),STUCKP1LMB-V(a6)	; to the STUCK version. we will disable all stuck ports
	move.b	P2RMB-V(a6),STUCKP2RMB-V(a6)
	move.b	P1MMB-V(a6),STUCKP1MMB-V(a6)
	move.b	P2MMB-V(a6),STUCKP2MMB-V(a6)
	rts


;------------------------------------------------------------------------------------------


AudioMenu:
	bsr	InitScreen
	move.w	#2,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

AudioSimple:

	bsr	ClearScreen
	move.w	#0,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	move.l	#AudioSimpleMenu,Menu-V(a6)	; Set different menu

						;	OK we have variables to handle here
	move.l	a6,d0
	lea	AudSimpChan1-V(a6),a0

	add.l	#AudSimpVar-V,d0
	move.l	d0,MenuVariable-V(a6)

						; ok lets populate this with default values.
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#0,(a0)+
	move.b	#64,(a0)+
	move.b	#12,(a0)+
	move.b	#1,(a0)+
	move.b	#0,(a0)+
 
	bsr	.setvar
.loop:
	bsr	.Playaudio

	bsr	PrintMenu
	bsr	GetInput
	bsr	WaitLong
	cmp.b	#0,d0
	beq	.no


	move.b	keyresult-V(a6),d1		; Read value from last keyboardread
	cmp.b	#$a,d1				; if it was enter, select this item
	beq	.action
	move.b	Serial-V(a6),d2			; Read value from last serialread
	cmp.b	#$a,d2
	beq	.action
	cmp.b	#1,LMB-V(a6)
	beq	.action

	lea	AudioSimpleWaveKeys,a5		; Load list of keys in menu
	clr.l	d0				; Clear d0, this is selected item in list

.keyloop:
	move.b	(a5)+,d3				; Read item
	cmp.b	#0,d3				; Check if end of list
	beq	.nokey
	cmp.b	d1,d3				; fits with keyboardread?
	beq	.goaction
	cmp.b	d2,d3				; fits with serialread?
	beq	.goaction				; if so..  do it
	add.l	#1,d0				; Add one to d0, selecting next item
	bra	.keyloop
.goaction:
	move.b	d0,MenuPos-V(a6)
	bra	.action

.nokey:	
	cmp.b	#1,RMB
	beq	Exit
	btst	#1,d0
	beq	.no

.action:
	clr.l	d0
	move.b	MenuPos-V(a6),d0
	cmp.b	#0,d0
	beq	.chan1
	cmp.b	#1,d0
	beq	.chan2
	cmp.b	#2,d0
	beq	.chan3
	cmp.b	#3,d0
	beq	.chan4
	cmp.b	#4,d0
	beq	.vol
	cmp.b	#5,d0
	beq	.wave
	cmp.b	#6,d0
	beq	.filter
	cmp.b	#7,d0
	beq	.exit

	


.no:
	bra	.loop

.setvar:
	move.l	a6,a0
	move.l	a6,a1
	add.l	#AudSimpChan1-V,a0	
	add.l	#AudSimpVar-V,a1

	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer

	clr.l	d0
	move.b	(a0)+,d0			; Get Volume

	lea	AudSimpVolStr-V(a6),a2
	move.w	#3,(a1)+
	move.l	a2,(a1)+	
	PUSH	
	bsr	bindec
	move.l	#7,d0				; Lets copy output to a safe location
.setvarloop:
	move.b	(a0)+,(a2)+
	dbf	d0,.setvarloop
	POP
	add.l	#1,a0	
	move.w	#2,(a1)+			; Write color
	lea	AudSimpWave-V(a6),a2
	clr.l	d1
	move.b	(a2),d1
	asl.l	#2,d1
	lea.l	AudioName,a2
	move.l	(a2,d1.w),(a1)+			; Write Stringpointer


	bsr	CheckOnOff
	move.w	d0,(a1)+			; Write color
	move.l	d1,(a1)+			; Write Stringpointer
	rts

.Playaudio:
	clr.l	d0
	move.b	AudSimpWave-V(a6),d0
	move.l	d0,d1
	mulu	#2,d1
	mulu	#4,d0
	
	lea	AudioPointers,a2
	move.l	a6,a0
	add.l	#AudioWaves-V,a0
	add.l	(a2,d0.l),a0

	lea	AudSimpChan1-V(a6),a1
	move.l	a0,$dff0a0			;Wave
	move.l	a0,$dff0b0			;Wave
	move.l	a0,$dff0c0			;Wave
	move.l	a0,$dff0d0			;Wave


	cmp.b	#0,(a1)+
	beq	.noch1

	move.w	#64,$dff0a8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0a4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0a6
	move.w	#$8201,$dff096
	bra	.checkch2
.noch1:
	move.w	#$1,$dff096
	
.checkch2:

	cmp.b	#0,(a1)+
	beq	.noch2

	move.w	#64,$dff0b8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0b4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0b6			;frequency
	move.w	#$8202,$dff096
	bra	.checkch3
.noch2:
	move.w	#$2,$dff096
	
.checkch3:
	cmp.b	#0,(a1)+
	beq	.noch3

	move.w	#64,$dff0c8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0c4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0c6			;frequency
	move.w	#$8204,$dff096
	bra	.checkch4
.noch3:
	move.w	#$4,$dff096
	
.checkch4:

	cmp.b	#0,(a1)+
	beq	.noch4

	move.w	#64,$dff0d8			;volume
	lea	AudioLen,a2
	move.w	(a2,d1),$dff0d4			;number of words
	lea	AudioPer,a2
	move.w	(a2,d1),$dff0d6			;frequency
	move.w	#$8208,$dff096
	bra	.checkdone
.noch4:
	move.w	#$8,$dff096
	
.checkdone:

	rts


.chan1:
	bchg	#0,AudSimpChan1-V(a6)
	move.b	#1,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop



.chan2:
	bchg	#0,AudSimpChan2-V(a6)
	move.b	#2,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop



.chan3:
	bchg	#0,AudSimpChan3-V(a6)
	move.b	#3,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop




.chan4:
	bchg	#0,AudSimpChan4-V(a6)
	move.b	#4,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.vol:
	move.l	a6,a0
;	add.l	#AudSimpVol-V,a0
	move.w	#4,(a0)+
	move.l	#OFF,(a0)+
	move.b	#5,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.wave:
	TOGGLEPWRLED
	clr.l	d7
	move.b	AudSimpWave-V(a6),d7

	cmp.b	#17,d7
	beq	.notmax
	add.b	#1,d7
	bra	.wave2
.notmax:
	clr.l	d7
.wave2:
	move.b	d7,AudSimpWave-V(a6)

	move.b	#6,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop

.filter:
	bchg	#0,AudSimpFilter-V(a6)
	btst	#0,AudSimpFilter-V(a6)
	beq	.off
	bclr	#1,$bfe001
	bra	.on
.off:
	bset	#1,$bfe001
.on:
	move.b	#7,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)
	bsr	CheckKeyReleased
	bsr	.setvar
	bra	.loop


.exit:
	move.w	#15,$dff096
	bsr	WaitReleased

	move.l	#Menus,Menu-V(a6)		; Set Menus as default menu. if different set another manually
	move.l	#0,MenuVariable-V(a6)
	bra	AudioMenu

CheckKeyReleased:
	bsr	GetInput
	btst	#1,d0
	bne.s	CheckKeyReleased
	rts

CheckOnOff:					; Checks if a0 is pointing to a variable that is on or off
						; OUTPUT =   D0 = Color
						;	     D1 = Address of String
			
	cmp.b	#0,(a0)+
	bne	.on
	move.l	#1,d0
	move.l	#OFF,d1
	rts
.on:
	move.l	#2,d0
	move.l	#ON,d1
	rts
	

AudioMod:
	ifeq a1k

	bsr	FilterOFF

	bsr	ClearScreen
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	clr.l	(a1)+

	bset	#1,(a1)+			; Set Default filter off
	move.b	#64,(a1)+			; Set Default MasterVolume
	clr.w	(a1)+
	move.l	#-1,(a1)+
	move.l	#-1,(a1)			; and the "former" values aswell
						; but to something that never can happen
						; forcing an update first run
	lea	AudioModTxt,a0
	move.l	#2,d1
	bsr	Print


	move.l	#EndMusic-Music,d0
	bsr	GetChip				; Get memory for module

	cmp.l	#0,d0				; if it is 0, no chipmem avaible
	bne	.chip

	move.l	#1,d1
	lea	NoChiptxt,a0
	bsr	Print				; We did not have enough chipmem
	bra	.exit

.chip:

	cmp	#1,d0
	bne	.enough

	move.l	#1,d1
	lea	NotEnoughChipTxt,a0
	bsr	Print
	bra	.exit

.enough:

	move.l	d0,AudioModAddr-V(a6)		; Store address of module
	move.l	d0,AudioModData-V(a6)

	lea	AudioModCopyTxt,a0
	move.l	#3,d1
	bsr	Print


	move.l	AudioModAddr-V(a6),a0
	move.l	#EndMusic-Music,d0		; get size of module
	asr.l	#2,d0				; Divide by 4 to get number of longwords
	lea	Music,a1			; Get address where module is in ROM
.loop:
	move.l	(a1)+,(a0)+
	dbf	d0,.loop			; Copy module into chipmem



	move.l	#2,d1
	lea	Donetxt,a0
	bsr	Print

	lea	AudioModInitTxt,a0
	move.l	#3,d1
	bsr	Print


	move.l	AudioModAddr-V(a6),a0
	
	move.l	AudioModInit-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_Init

	lea	Donetxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	AudioModMVol-V(a6),a0
	move.b	#4,(a0)				; Set Mastervolume

	lea	AudioModName,a0
	move.l	#3,d1
	bsr	Print

	move.l	AudioModAddr-V(a6),a0
	move.l	#5,d1
	bsr	Print

	lea	AudioModInst,a0
	move.l	#3,d1
	bsr	Print

	move.l	AudioModAddr-V(a6),a1
	add.l	#20,a1
	move.l	#1,d7
	move.l	#15,d6
	move.l	#7,d5
.instloop:
	clr.l	d0
	move.l	d5,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print

	lea	SpaceTxt,a0
	bsr	Print

	move.l	a1,a0
	move.l	#5,d1
	bsr	Print
	add.l	#30,a1
	add.l	#1,d7

.noprint:
	lea	NewLineTxt,a0
	bsr	Print
	add.l	#1,d5
	dbf	d6,.instloop

	move.l	#15,d6
	move.l	#7,d5
.instloop2:
	move.l	#40,d0
	move.l	d5,d1
	bsr	SetPos
	move.l	d7,d0
	cmp.l	#$20,d0
	beq	.noprint2
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print
	lea	SpaceTxt,a0
	bsr	Print

	move.l	a1,a0
	move.l	#5,d1
	bsr	Print

	add.l	#30,a1
	add.l	#1,d7
.noprint2:
	lea	NewLineTxt,a0
	bsr	Print
	add.l	#1,d5
	dbf	d6,.instloop2


	lea	NewLineTxt,a0
	bsr	Print

	lea	AudioModPlayTxt,a0
	move.l	#3,d1
	bsr	Print

	lea	AudioModOptionTxt,a0
	move.l	#3,d1
	bsr	Print

	lea	AudioModEndTxt,a0
	move.l	#3,d1
	bsr	Print

	bsr	AudioModStatus

.loopa:
	cmp.b	#$e0,$dff006
	bne.s	.loopa

	move.l	AudioModMusic-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_Music

	bsr	GetInput
	
	lea	AudioModStatData-V(a6),a1	; Get statusvariable

	cmp.b	#"1",GetCharData-V(a6)
	beq	.chan1
	cmp.b	#"2",GetCharData-V(a6)
	beq	.chan2
	cmp.b	#"3",GetCharData-V(a6)
	beq	.chan3
	cmp.b	#"4",GetCharData-V(a6)
	beq	.chan4
	cmp.b	#"f",GetCharData-V(a6)
	beq	.filter
	cmp.b	#"+",GetCharData-V(a6)
	beq	.volup
	cmp.b	#"-",GetCharData-V(a6)
	beq	.voldown
	cmp.b	#"l",GetCharData-V(a6)
	beq	.left
	cmp.b	#"r",GetCharData-V(a6)
	beq	.right
	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exitit

.keydone:

	bsr	AudioModStatus
	cmp.b	#1,LMB-V(a6)
	bne.w	.loopa
.exitit:


	move.l	AudioModEnd-V(a6),a1
	lea	$dff000,a5
	jsr	(a1)				; Call MT_End

.exit:
	bra	AudioMenu

.chan1:
	bchg	#1,(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan2:
	bchg	#1,1(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan3:
	bchg	#1,2(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.chan4:
	bchg	#1,3(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.filter:
	bchg	#1,4(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.volup:
	cmp.b	#64,5(a1)			; Check if volume is already at max
	beq	.volmax
	add.b	#1,5(a1)
.volmax:
	clr.b	BUTTON-V(a6)
	bra	.keydone
		
.voldown:
	cmp.b	#0,5(a1)
	beq	.volmin
	sub.b	#1,5(a1)
.volmin:
	clr.b	BUTTON-V(a6)
	bra	.keydone
.left:
	bchg	#1,6(a1)			; Toggle left. copy it to chan1 & 4
	move.b	6(a1),(a1)
	move.b	6(a1),3(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
.right:
	bchg	#1,7(a1)
	move.b	7(a1),1(a1)
	move.b	7(a1),2(a1)
	clr.b	BUTTON-V(a6)
	bra	.keydone
	
AudioModStatus:
	PUSH
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	lea	AudioModStatFormerData-V(a6),a2	; Get statusvariable
	move.l	#3,d7
	move.l	#20,d6
.loop:
	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.done			; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data

	move.l	d6,d0
	move.l	#26,d1
	bsr	SetPos

	cmp.b	#0,(a1)			; if it is 0, channel is on
	bne	.off
	lea	ON,a0			; Print ON
	move.l	#2,d1
	bsr	Print
	beq	.done
.off:
	lea	OFF,a0			; Print OFF
	move.l	#1,d1
	bsr	Print
.done:
	add.l	#1,a2			; add 1 to fomerdatapos
	add.l	#1,a1
	add.l	#16,d6			; change variable to put next string 16 chars away
	dbf	d7,.loop	


	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.donefilter		; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data

	move.l	#33,d0
	move.l	#27,d1
	bsr	SetPos

	cmp.b	#0,(a1)			; if it is 0, channel is on
	bne	.filteroff
	bsr	FilterON
	lea	ON,a0			; Print ON
	move.l	#2,d1
	bsr	Print
	beq	.donefilter
.filteroff:
	bsr	FilterOFF
	lea	OFF,a0			; Print OFF
	move.l	#1,d1
	bsr	Print
.donefilter:	

	add.l	#1,a2			; add 1 to fomerdatapos
	add.l	#1,a1


	move.b	(a1),d2
	cmp.b	(a2),d2			; Compare 2 data, if we had a change
	beq	.donevol		; if no change do not do anything
	move.b	d2,(a2)			; Store the real value into former data
	
	move.l	#59,d0
	move.l	#27,d1
	bsr	SetPos

	clr.l	d0
	move.b	d2,d0
	bsr	bindec
	move.l	#2,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
.donevol:
	move.l	AudioModMVol-V(a6),a0
	move.b	(a1),(a0)+				; Set Mastervolume
	lea	AudioModStatData-V(a6),a1	; Get statusvariable
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+	
	move.b	(a1)+,(a0)+			; Copy data to protrackerroutine.
						; move.l WILL crash on non 020+ machines
	POP
	rts


	else

	bra	Not1K

	endc

;------------------------------------------------------------------------------------------

MemtestMenu:
	bsr	InitScreen
	move.w	#3,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

CheckDetectedChip:
	bsr	ClearScreen
	lea	MemtestDetChipTxt,a0
	move.l	#2,d1
	bsr	Print

	move.b	#0,CheckMemNoShadow-V(a6)

	ifne	rommode
		move.l	ChipStart-V(a6),d0
		lea	TotalChip-V(a6),a0	; Total Chipmem detected
		move.l	(a0),d1

		mulu	#1024,d1
		add.l	d0,d1
		sub.l	#$400,d1

	else
		move.l	#$1a0000,d0
		move.l	#$200000,d1
	endc
		move.l	#0,d2
		clr.b	CheckMemRow-V(a6)
		bsr	CheckMemory

	bsr	WaitButton
	bra	MemtestMenu


CheckExtendedChip:
	bsr	ClearScreen
	lea	MemtestExtChipTxt,a0
	move.l	#2,d1
	bsr	Print
	move.b	#0,CheckMemNoShadow-V(a6)

	ifne	rommode

		move.l	#$400,d0
		move.l	#$200000,d1

	else
		move.l	#$1a0000,d0
		move.l	#$200000,d1
	endc
		clr.l	d2
		clr.b	CheckMemRow-V(a6)
		bsr	CheckMemory

	bsr	WaitButton
	bra	MemtestMenu


CheckDetectedMBMem:
	bsr	ClearScreen
	clr.b	nomem-V(a6)
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)
	move.b	#12,CheckMemRow-V(a6)

	lea	$200000,a0
	lea	$a00000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem
	
	clr.b	temp-V(a6)				; Clear tempvariable

	lea	MemtestDetMBMemTxt3,a0

	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bra	.next
.nomem:
	add.b	#1,nomem-V(a6)				; Store 1 into temp, telling we had no memory
.next:

	bsr	.ClearTop
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)
	lea	$4000000,a0
	lea	$8000000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem2

	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	d0
	clr.l	d1
	bsr	SetPos

	lea	MemtestDetMBMemTxt,a0
	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	move.l	#2,d2
;	move.b	#20,CheckMemRow-V(a6)

	bsr	CheckMemory
	bra	.next2

.nomem2:
	add.b	#1,nomem-V(a6)
.next2:

	bsr	.ClearTop
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)

	lea	$8000000,a0
	lea	$10000000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem3

	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	d0
	clr.l	d1
	bsr	SetPos

	lea	MemtestDetMBMemTxt2,a0
	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	move.l	#2,d2
	bsr	CheckMemory
	bra	.next3

.nomem3:
	add.b	#1,nomem-V(a6)
.next3:

	bsr	.ClearTop
	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	FirstMBMem-V(a6)
	clr.l	MBMemSize-V(a6)

	lea	$40000000,a0
	lea	$80000000,a1
	bsr	DetectMem

	move.l	a0,FirstMBMem-V(a6)
	move.l	d0,MBMemSize-V(a6)

	cmp.l	#0,d0					; Check if we had nomem
	beq	.nomem4

	clr.b	temp-V(a6)				; Clear tempvariable
	clr.l	d0
	clr.l	d1
	bsr	SetPos

	lea	MemtestDetMBMemTxtZ,a0
	bsr	.CheckPrint
	clr.l	d2
	move.l	FirstMBMem-V(a6),d0
	move.l	d0,d1
	add.l	MBMemSize-V(a6),d1
	move.b	#0,CheckMemNoShadow-V(a6)
	move.l	#2,d2
	bsr	CheckMemory
	bra	.next4

.nomem4:
	add.b	#1,nomem-V(a6)
.next4:

	cmp.b	#3,nomem-V(a6)				; Check if we had no memory. put errormessage
	bne	.wehadmem

	lea	MemtestNORAM,a0
	move.l	#1,d1
	bsr	Print

.wehadmem:
	bsr	.ClearTop
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	lea	AnyKeyMouseTxt,a0
	move.l	#4,d1
	bsr	Print
	bsr	WaitButton
	bra	MemtestMenu


.ClearTop:
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	lea	EmptyRowTxt,a0
	bsr	Print
	rts


.CheckPrint:
	PUSH
	move.l	#2,d1
	bsr	Print


	move.l	MBMemSize-V(a6),d0

	asr.l	#8,d0
	asr.l	#2,d0

	bsr	bindec
	move.l	#2,d1
	bsr	Print
	lea	KB,a0
	bsr	Print

	POP
	rts

ForceExtended16MBMem:
	bsr	ClearScreen

	lea	MemtestExtMBMemTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#$7000000,d0
	move.l	#$7ffffff,d1

	move.l	#0,d2
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bsr	WaitButton
	bra	MemtestMenu



CheckExtended16MBMem:
	bsr	ClearScreen

	lea	MemtestExtMBMemTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#$7000000,d0
	move.l	#$7ffffff,d1

	move.l	#1,d2
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bsr	WaitButton
	bra	MemtestMenu


CheckExtendedMBMem:
	bsr	ClearScreen
	lea	MemtestExtMBMemTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#$4000000,d0
	move.l	#$fffffff,d1

	move.l	#1,d2
	move.b	#0,CheckMemNoShadow-V(a6)
	bsr	CheckMemory
	bsr	WaitButton
	bra	MemtestMenu


CheckMemManual:
	bsr	ClearScreen
	lea	MemtestManualTxt,a0
	move.l	#6,d1
	bsr	Print

	move.b	#41,d0
	move.b	#13,d1

	lea	$0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit

	move.l	d0,d6

	lea	MemtestManualEndTxt,a0
	move.l	#6,d1
	bsr	Print

	lea	$0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit

	move.l	d0,d7

	lea	MemtextManualModeTxt,a0
	move.l	#6,d1
	bsr	Print

.loop:
	bsr	GetChar
	cmp.b	#0,d0
	beq	.nochar

	cmp.b	#$1b,d0
	beq	.done3

	bclr	#5,d0				; make it uppercase

	cmp.b	#"F",d0
	beq	.fast

	cmp.b	#"S",d0
	beq	.slow

.nochar:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a5)
	beq	.fast
	cmp.b	#1,LMB-V(a6)
	bne	.loop

.fast:
	move.l	#1,d2
	bra	.done

.slow:
	move.l	#0,d2
	bra	.done

.done:


	lea	MemtextManualShadowTxt,a0
	move.l	#6,d1
	bsr	Print

.loop2:
	bsr	GetChar
	cmp.b	#0,d0
	beq	.nochar2

	cmp.b	#$1b,d0
	beq	.done

	bclr	#5,d0				; make it uppercase

	cmp.b	#"Y",d0
	beq	.shadow
	bra	.done2
.nochar2:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a5)
	beq	.done2
	cmp.b	#1,LMB-V(a6)
	bne	.loop2

.shadow:
	move.b	#1,CheckMemNoShadow-V(a6)
	bra	.done3

.done2:
	move.b	#0,CheckMemNoShadow-V(a6)
.done3:
	bsr	ClearScreen

	move.l	d7,d1
	move.l	d6,d0
	bsr	CheckMemory


	bsr	WaitButton
.exit:
	bra	MemtestMenu


CheckMemEdit:
	bsr	ClearScreen
	lea	CheckMemEditTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#34,d0
	move.l	#1,d1
	bsr	SetPos
	lea	OFF,a0
	move.l	#3,d1
	bsr	Print
;	clr.b	CpuCache-V(a6)			; Set status to off

	move.b	#0,CheckMemEditXpos-V(a6)
	move.b	#0,CheckMemEditYpos-V(a6)	; Clear X and Y positions
	move.b	#0,CheckMemEditOldXpos-V(a6)
	move.b	#0,CheckMemEditOldYpos-V(a6)	; Clear X and Y positions

	clr.l	d0
	move.l	#3,d1
	bsr	SetPos

	move.l	CheckMemEditScreenAdr-V(a6),d0
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen

.loop:

	bsr	.putcursor

	bsr	GetMouse
	cmp.b	#1,RMB-V(a6)
	beq	.exit

.ansimode:
	bsr	GetChar

	cmp.b	#$1b,d0
	beq	.exit
	
	cmp.b	#30,d0
	beq	.up	

	cmp.b	#31,d0
	beq	.down
	
	cmp.b	#28,d0
	beq	.right

	cmp.b	#29,d0
	beq	.left

	move.b	d0,d1				; Copy char to d1, so we do not trash for hexnumbers
	bclr	#5,d1				; make it uppercase
	cmp.b	#"G",d1
	beq	.GotoMem			; G was pressed, let user enter address to dump


	cmp.b	#"R",d1
	beq	.Refresh

	cmp.b	#"H",d1
	beq	.Cache


	bsr	GetHex				; OK, convert it to hex. if anything is left now, we have a hexdigit that
	cmp.b	#"0",d0
	blt	.nohex

.tobin:
	cmp.b	#"A",d0				; Check if it is "A"
	blt	.nochar				; Lower then A, this is not a char
	sub.l	#7,d0				; ok we have a char, subtract 7
.nochar:
	sub.l	#$30,d0				; Subtract $30, converting it to binary.

	move.l	d0,d2				; Store d0 into d2 temporary

	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr			; a0 will now contain the address of memoryadress where cursor is
	clr.l	d7
	move.b	(a0),d7				; and D7 will contain what that address contains

	move.l	d2,d0				; Restore d2

	cmp.b	#0,CheckMemEditCharPos-V(a6)
	bne	.nocurleft

	and.b	#$f,d7				; Strip out high nibble from d7
	asl	#4,d0				; rotate input data to high nibble
	add.b	d0,d7				; add them together
	move.b	d7,(a0)				; store in memory
	add.b	#1,CheckMemEditCharPos-V(a6)	; add 1 to pos, for next nibble
	bra	.editdone
.nocurleft:
	and.b	#$f0,d7				; Strip out low nibble
	add.b	d0,d7				; add indata with the rest of d7
	move.b	d7,(a0)				; store in memory
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	cmp.b	#15,CheckMemEditXpos-V(a6)
	beq	.noright
	add.b	#1,CheckMemEditXpos-V(a6)	; move one step to the right

.editdone:

						; Should go into memory. (Whaa.  BANGING on da shit here)

.nohex:
.keydone:
	bra	.loop

.getcursoradr:					; Get memoryaddress of X, Y pos
						; INDATA:
						;	d0 = xpos
						;	d1 = ypos
						;
						; OUTDATA:
						;	a0 = memoryaddress
	and.l	#$ff,d0
	and.l	#$ff,d1
	move.l	CheckMemEditScreenAdr-V(a6),a0
	add.l	d0,a0
	asl.l	#4,d1
	add.l	d1,a0
	rts

.putcursor:
	clr.l	d2
	clr.l	d3
	clr.l	d4
	clr.l	d5
	move.b	CheckMemEditXpos-V(a6),d2
	move.b	CheckMemEditYpos-V(a6),d3
	move.b	CheckMemEditOldXpos-V(a6),d4
	move.b	CheckMemEditOldYpos-V(a6),d5
	cmp.b	d2,d4
	bne	.notequal
	cmp.b	d3,d5
	bne	.notequal			; ok cursorpos have changed.. lets put a nonrevesed char in spot
.equal:
	move.l	#10,d0
	move.l	#4,d1

	mulu	#3,d2


	add.l	d2,d0
	add.l	d3,d1
	bsr	SetPos				; First byte


	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr

	clr.l	d0

	move.b	(a0),d0
	move.l	d0,d7				; Store d0 to d7 temporary
	bsr	binhexbyte
	move.l	#11,d1
	bsr	Print				; Print what is in current memorypos as a HEX digit and yellow.

	move.l	#60,d0
	move.l	#4,d1

	add.b	CheckMemEditXpos-V(a6),d0
	add.b	CheckMemEditYpos-V(a6),d1

	bsr	SetPos
	

	move.b	CheckMemEditXpos-V(a6),d0
	move.b	CheckMemEditYpos-V(a6),d1
	bsr	.getcursoradr

	clr.l	d0
	move.b	(a0),d0
	bsr	MakePrintable
	move.l	#11,d1
	bsr	PrintChar

	move.l	#17,d0
	move.l	#25,d1
	bsr	SetPos

	move.l	a0,d0
	bsr	binhex
	move.l	#3,d1
	bsr	Print	


	move.l	#52,d0
	move.l	#25,d1
	bsr	SetPos

	move.l	d7,d0				; restore d0 with value from current pos
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print


	rts

.notequal:					; We had movement.  lets put stuff to "normal" case
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.b	d2,CheckMemEditOldXpos-V(a6)
	move.b	d3,CheckMemEditOldYpos-V(a6)	; Set current pos to "old" pos

	move.l	d4,d7				; Copy d4 to d7 so we do not screw up data for later
	move.l	#10,d0
	move.l	#4,d1
	mulu	#3,d7				; Multiply X pos with 3 so we have space for 2 hexchars and a space
	add.l	d7,d0
	add.l	d5,d1

	PUSH					; Store this in stack, we will need it later
	bsr	SetPos				; Put cursor on screen
	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr			; Get what memoryaddress we are pointing on
	clr.l	d0
	move.b	(a0),d0
	bsr	binhexbyte
	move.l	#7,d1
	bsr	Print				; Print that byte.
	POP					; ok roll back stack, we will need this data again

	move.l	d4,d0
	move.l	d5,d1
	add.l	#60,d0
	add.l	#4,d1
	bsr	SetPos
	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr
	clr.l	d0
	move.b	(a0),d0
	bsr	MakePrintable
	move.l	#7,d1
	bsr	PrintChar

	bra	.equal


	PUSH					; Store in stack
	bsr	SetPos
	POP					; ok. d4 and d5 still contains x and y

	move.l	d4,d0
	move.l	d5,d1
	bsr	.getcursoradr
	add.l	#10,d0
	add.l	#4,d1
	bsr	SetPos

	move.b	(a0),d0
	bsr	binhexbyte
	move.l	#7,d1
	bsr	Print

	bra	.equal


.GotoMem:
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.l	#0,d0
	move.l	#3,d1
	bsr	SetPos
	lea	CheckMemEditGotoTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	add.l	#$150,d0			; Add $150 to that, (next screen)
	move.l	d0,a0
	bsr	InputHexNum
	cmp.l	#-1,d0
	beq	.exit
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen	; Update the screen
	bsr	.ClearCommandRow		; Clear the "goto" row.
	bra	.loop

.Cache:	bchg	#1,CPUCache-V(a6)		; Change status of Cacheflag
	clr.l	d0

	move.l	#34,d0
	move.l	#1,d1
	bsr	SetPos

	move.b	CPUCache-V(a6),d0
	cmp.b	#0,d0				; is it off?
	beq	.CacheOff
						; no, it is on
	lea	ON,a0
	move.l	#2,d1
	bsr	Print
	bsr	EnableCache
	bra	.Refresh
.CacheOff:
	lea	OFF,a0
	move.l	#3,d1
	bsr	Print
	bsr	DisableCache
	bra	.Refresh
.Refresh:
	clr.b	CheckMemEditCharPos-V(a6)	; Clear charpos
	move.l	CheckMemEditScreenAdr-V(a6),a0	; Get address
	bsr	CheckMemEditUpdateScreen	; Update the screen
	bsr	.ClearCommandRow		; Clear the "goto" row.
	bra	.loop
	

.exit:
	bra	MemtestMenu

.up:
	cmp.b	#0,CheckMemEditYpos-V(a6)
	beq	.noup
	sub.b	#1,CheckMemEditYpos-V(a6)
	bra	.keydone
.noup:
	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	sub.l	#$10,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen
	bra	.keydone
	
.down:
	cmp.b	#20,CheckMemEditYpos-V(a6)
	beq	.nodown
	add.b	#1,CheckMemEditYpos-V(a6)
	bra	.keydone
.nodown:
	move.l	CheckMemEditScreenAdr-V(a6),d0	; Read the screenaddress currently showed
	add.l	#$10,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)	; Store address in memory
	move.l	d0,a0
	bsr	CheckMemEditUpdateScreen
	bra	.keydone


.right:
	cmp.b	#15,CheckMemEditXpos-V(a6)
	beq	.noright
	add.b	#1,CheckMemEditXpos-V(a6)
.noright:
	bra	.keydone

.left:
	cmp.b	#0,CheckMemEditXpos-V(a6)
	beq	.noleft
	sub.b	#1,CheckMemEditXpos-V(a6)
.noleft:
	bra	.keydone
	
.ClearCommandRow:
	move.l	#0,d0
	move.l	#3,d1
	bsr	SetPos
	lea	EmptyRowTxt,a0
	bsr	Print
	rts

CheckMemEditUpdateScreen:			; Updates the whole screen with memorydump
						; INDATA:
						;	A0 = Startaddress
	move.l	#1,d0
	move.l	#20,d7
.loop:
	bsr	CheckMemEditUpdateRow
	add.l	#16,a0
	add.l	#1,d0
	dbf	d7,.loop			; Print 21 rows of memorydump on screen

	move.l	#0,d0
	move.l	#25,d1
	bsr	SetPos

	lea	CheckMemAdrTxt,a0
	move.l	#2,d1
	bsr	Print

	move.l	#28,d0
	move.l	#25,d1
	bsr	SetPos
	lea	CheckMemBinaryTxt,a0
	move.l	#2,d1
	bsr	Print

	rts


CheckMemEditUpdateRow:
	;	Show memoryadress on screen
	;	INDATA:
	;		a0 = memory address
	;		d0 = row to update

	PUSH
	move.l	a0,a1				; store a0 in a1 for usage here.. as a0 is used
	add.l	#3,d0				; Add 3 to line to work on.
	move.l	d0,d1				; copy d0 to d1 to use it as Y adress
	clr.l	d0				; clear X pos
	bsr	SetPos				; Set position
	
	move.l	a0,d0
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print address

	clr.l	d2				; Column to print
	move.l	#15,d7
.loop:
	lea	SpaceTxt,a0
	bsr	Print
	clr.l	d0				; Clear d0 just to be sure
	move.b	(a1,d2),d0
	bsr	binhexbyte			; Convert that byte to hex
	move.l	#7,d1
	bsr	Print				; Print it
	add.l	#1,d2
	dbf	d7,.loop
	lea	ColonTxt,a0			; Print a Colon
	move.l	#3,d1
	bsr	Print

	move.l	#15,d7				; Now print the same bytes.  as chars instead	
	clr.l	d2
.loop2:
	clr.l	d0
	move.b	(a1,d2),d0
	bsr	MakePrintable			; make the char printable.  strip controlstuff..
	add.l	#1,d2
	move.l	#7,d1
	bsr	PrintChar
	dbf	d7,.loop2
	POP
	rts


;------------------------------------------------------------------------------------------

IRQCIAtestMenu:
	bsr	InitScreen
	move.w	#4,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

IRQCIAIRQTest:
	bsr	InitScreen
	lea	IRQCIAIRQTestText,a0
	move.w	#2,d1
	bsr	Print

.loop:
	bsr	GetInput

	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exit
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	cmp.b	#1,BUTTON-V(a6)
	bne	.loop

	lea	IRQCIAIRQTestText2,a0
	move.w	#7,d1
	bsr	Print

	bsr	WaitReleased
	
	move.w	#$2000,sr			; Set SR to allow IRQs
	
	lea	IRQLev1Txt,a0
	move.l	#6,d1
	bsr	Print

	move.l	#IRQLevTest,$64			; Set up IRQ Level 1
	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.w	#$9000,$dff09c
	move.w	#$c004,$dff09a			; Enable IRQ
	move.w	#$c004,$dff09a			; Enable IRQ
	move.w	#$8004,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	bne	.done1

	bsr	WaitReleased
	
.done1:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev2Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$68			; Set up IRQ Level 2
	move.w	#$c008,$dff09a			; Enable IRQ
	move.w	#$c008,$dff09a			; Enable IRQ
	move.w	#$8008,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	cmp.b	#2,d0
	beq	.done2

	bsr	WaitReleased

.done2:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev3Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$8020,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done3

	bsr	WaitReleased

.done3:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev4Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$70			; Set up IRQ Level 4
	move.w	#$c080,$dff09a			; Enable IRQ
	move.w	#$c080,$dff09a			; Enable IRQ
	move.w	#$8080,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done4

	bsr	WaitReleased

.done4:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev5Txt,a0
	move.l	#6,d1
	bsr	Print


	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$74			; Set up IRQ Level 5
	move.w	#$c800,$dff09a			; Enable IRQ
	move.w	#$c800,$dff09a			; Enable IRQ
	move.w	#$8800,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done5

	bsr	WaitReleased

.done5:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev6Txt,a0
	move.l	#6,d1
	bsr	Print

	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$78			; Set up IRQ Level 6
	move.w	#$e000,$dff09a			; Enable IRQ
	move.w	#$e000,$dff09a			; Enable IRQ
	move.w	#$a000,$dff09c			; Trigger IRQ
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done6

	bsr	WaitReleased

.done6:
	lea	NewLineTxt,a0
	bsr	Print
	lea	IRQLev7Txt,a0
	move.l	#6,d1
	bsr	Print

	clr.w	IRQLevDone-V(a6)		; Clear variable, we let the IRQ set it. if it gets set. we have working IRQ
	move.l	#IRQLevTest,$78			; Set up IRQ Level 7
	bsr	TestIRQ
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	cmp.b	#2,d0
	beq	.done7

	bsr	WaitReleased

.done7:


	lea	IRQTestDone,a0
	move.l	#2,d1
	bsr	Print


	

	bsr	WaitButton

.exit:
	bsr	IRQCIAtestMenu


TestIRQ:				; Test if IRQ was triggered
					; OUT:
					;	d0 = 0	== Everything sucessful
					;	d0 = 1	== We have failure
					;	d0 = 2	== User pressed cancel
	clr.l	d0
	move.w	#100,d7
.loop:
	bsr	GetInput			; Check for input from user
	cmp.b	#1,BUTTON-V(a6)			; If button is pressed, exit
	beq	.exitloop
	bsr	WaitLong
	cmp.w	#1,IRQLevDone-V(a6)		; Check if IRQLevDone is set, done in IRQ routine
	beq	.yes
	dbf	d7,.loop
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print
	move.b	#1,d0				; we exited loop, test failed
	rts
.yes:
	lea	OK,a0
	move.l	#2,d1
	bsr	Print
	rts
.exitloop:
	lea	CANCELED,a0
	move.l	#3,d1
	bsr	Print
	rts

	move.b	#2,d0
	rts
	

IRQLevTest:					; Small IRQ Rouine, all it does is to set IRQLevDone to 1
	move.w	#$fff,$dff180
	move.w	#1,IRQLevDone-V(a6)
	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ
	rte


CIATIME	EQU	174
;	equ	174			(10000ms / 1.3968255 for PAL)

IRQCIACIATest:
	cmp.b	#1,RASTER-V(a6)			; Check if we have a working raster, if not we are unable to
	bne	.noraster			; count frames (for timing) so not possible to perform tests

	bsr	InitScreen


	lea	CIATestTxt,a0
	move.w	#2,d1
	bsr	Print
	lea	CIATestTxt2,a0
	move.w	#2,d1
	bsr	Print
.loop:
	bsr	GetInput
	cmp.b	#$1b,GetCharData-V(a6)
	beq	IRQCIAtestMenu
	cmp.b	#1,RMB-V(a6)
	beq	IRQCIAtestMenu

	cmp.b	#1,BUTTON-V(a6)
	bne.s	.loop

	lea	CIATestTxt3,a0
	move.w	#4,d1
	bsr	Print


	move.w	#$7fff,$dff09a			; Kill all chip interrupts


	lea	CIAATestAATxt,a0
	lea	$bfe001,a5			; load a5 with a base
	lea	$bfe001,a4			; load a5 with a base
	lea	$bfee01,a3			; load a5 with a base
	move.l	#0,d2
	move.l	#7,d5	
	bsr	.TestCIA


	lea	CIAATestBATxt,a0
	lea	$bfe201,a5			; load a5 with a base
	lea	$bfe001,a4			; load a5 with a base
	lea	$bfef01,a3			; load a5 with a base
	move.l	#1,d2
	move.l	#8,d5	
	bsr	.TestCIA

	bsr	TestATOD

	lea	CIAATestABTxt,a0
	lea	$bfd000,a5			; load a5 with a base
	lea	$bfd000,a4			; load a5 with a base
	lea	$bfde00,a3			; load a5 with a base
	move.l	#0,d2
	move.l	#10,d5	
	bsr	.TestCIA


	lea	CIAATestBBTxt,a0
	lea	$bfd200,a5			; load a5 with a base
	lea	$bfd000,a4			; load a5 with a base
	lea	$bfdf00,a3			; load a5 with a base
	move.l	#1,d2
	move.l	#11,d5	
	bsr	.TestCIA

	bsr	TestBTOD




.keyloop:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne.s	 .keyloop

	bra	IRQCIAtestMenu
	
.noraster:					; We had no working raster, print errormessage
	bsr	InitScreen			; and prompt for keypress to go back to mainmenu.
	lea	CIANoRasterTxt,a0
	move.w	#1,d1
	bsr	Print
	lea	CIANoRasterTxt2,a0
	move.w	#2,d1
	bsr	Print
.nrloop:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne.s	.nrloop
	bra	MainMenu



.TestCIA:

	clr.l	d0
	move.l	d5,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.w	TickFrame-V(a6)
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ

	move.w	#$2000,sr			; Set SR to allow IRQs


	move.b	(a3),d0				; Set control register A on CIAA
	move.b	d0,CIACtrl-V(a6)
	andi.b	#$c0,d0				; Do not touch bits we are not
	ori.b	#8,d0				; Using...
	move.b	d0,(a3)



	move.w	#7812,d6
	clr.l	d7


.loopa:
	move.l	#$f0,$dff180

	move.b	$400(a5),CIACtrl-V+1(a6)
	move.b	$500(a5),CIACtrl-V+2(a6)

	move.b	#(CIATIME&$FF),$400(a5)
	move.b	#(CIATIME>>8),$500(a5)			; Set registers to wait for 10000ms

.wait:
	move.w	#$0,$dff180

	cmp.w	#120,Frames-V(a6)
	bge	.vblankoverrun

	btst	d2,$d00(a4)
	beq	.wait
	add.l	#1,Ticks-V(a6)
	move.w	#$f,$dff180
.no:

	dbf	d6,.loopa				; Repeat this so we are doing it for a while
	bset	#0,(a3)
	clr.l	d6				; Clear D6, meaning we have executed this without Vblank overrun

	bra	.exit

.vblankoverrun:	
	move.l	#1,d6				; Set it as 1, to mark we had a overrun

.exit:

	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code

	move.b	CIACtrl-V(a6),(a3)
	move.b	CIACtrl-V+1(a6),$400(a5)
	move.b	CIACtrl-V+2(a6),$500(a5)
	

	move.w	Frames-V(a6),TickFrame-V(a6)

	move.l	#35,d0
	move.l	d5,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0
	asl.l	#8,d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ms,a0
	bsr	Print


	move.w	TickFrame-V(a6),d0

;	cmp.w	#105,d0
;	bge	.underrun
	cmp.w	#95,d0
	ble	.underrun
	bra	.nounderrun

.underrun:
	lea	VblankUnderrunTXT,a0
	move.l	#1,d1
	bsr	Print
	move.l	#2,d6
	bra	.nooverrun

.nounderrun:

	cmp.b	#1,d6
	bne	.nooverrun
	lea	VblankOverrunTXT,a0
	move.l	#1,d1
	bsr	Print
	
.nooverrun:

	cmp.b	#0,d6				; Check d6, if it isnt 0, we had a failure
	beq	.nooverrun2

	move.l	#70,d0
	move.l	d5,d1
	bsr	SetPos

	lea	FAILED,a0
	move.w	#1,d1
	bsr	Print
	rts
		
.nooverrun2:
	move.l	#70,d0
	move.l	d5,d1
	bsr	SetPos
	lea	OK,a0
	move.l	#2,d1
	bsr	Print



	rts
	
	clr.l	d0
	move.l	#1,d1
	bsr	SetPos
	clr.l	d0
	move.w	TickFrame-V(a6),d0
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	rts

CIALevTst:
	move.w	#$020,$dff09c			; Enable IRQ
	move.w	#$020,$dff09c			; Enable IRQ
	add.w	#1,Frames-V(a6)				; Add 1 to Frames so we can keep count of frames shown.
							; (or VBlanks)
;	move.w	#$f4,$dff180
	TOGGLEPWRLED
.no:
	rte





TestATOD:
	lea	CIATestATOD,a0
	clr.l	d0
	move.l	#9,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ;
;	move.w	$dff01c,$d7
	bclr	#7,$bfef01
	move.b	#0,$bfea01
	move.b	#0,$bfe901
	move.b	#0,$bfe801

.loopa:

	moveq	#0,d6
	move.b	$bfea01,d6
	lsl.l	#8,d6
	move.b	$bfe901,d6
	lsl.l	#7,d6
	move.b	$bfe801,d6


	cmp.l	Ticks-V(a6),d6
	beq.s	.no
	move.w	#$f,$dff180
.no:

	move.l	d6,Ticks-V(a6)

	clr.l	d0
	move.l	#10,d1
	bsr	SetPos
	clr.l	d0

	cmp.w	#100,Frames-V(a6)		; Check if we have tested for 200 VBlanks
	blt	.loopa


	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code



	move.l	#35,d0
	move.l	#9,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ticks,a0
	bsr	Print



	cmp.l	#95,d6
	ble	.tooslow
	cmp.l	#105,d6
	bge	.toofast

	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos

	lea	OK,a0
	move.w	#2,d1
	bsr	Print
	rts

.tooslow:
	move.l	#1,d1
	lea	CIATickSlowTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts
.toofast:
	move.l	#1,d1
	lea	CIATickFastTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#9,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts




TestBTOD:
	lea	CIATestBTOD,a0
	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	
	move.l	#3,d1
	bsr	Print


	clr.w	Frames-V(a6)			; Clear number frames
	clr.l	Ticks-V(a6)

	move.l	#CIALevTst,$6c			; Set up IRQ Level 3
	move.w	#$c020,$dff09a			; Enable IRQ
	move.w	#$c020,$dff09a			; Enable IRQ;
;	move.w	$dff01c,$d7
	bclr	#7,$bfdf00
	move.b	#0,$bfda00
	move.b	#0,$bfd900
	move.b	#0,$bfd800

.loopa:

	moveq	#0,d6
	move.b	$bfda00,d6
	lsl.l	#8,d6
	move.b	$bfd900,d6
	lsl.l	#8,d6
	move.b	$bfd800,d6


	cmp.l	Ticks-V(a6),d6
	beq.s	.no
	move.w	#$f,$dff180
.no:

	move.l	d6,Ticks-V(a6)

	clr.l	d0
	move.l	#12,d1
	bsr	SetPos
	clr.l	d0

	cmp.w	#100,Frames-V(a6)		; Check if we have tested for 200 VBlanks
	ble	.loopa


	move.w	#$7fff,$dff09c			; Disable all INTREQ
	move.w	#$7fff,$dff09a			; Disable all INTREQ

	move.l	#RTEcode,$6c			; Restore IRC Vector to empty code



	move.l	#35,d0
	move.l	#12,d1
	bsr	SetPos

	move.l	Ticks-V(a6),d0

	bsr	bindec
	move.w	#2,d1
	bsr	Print
	lea	ticks,a0
	bsr	Print



	cmp.l	#30000,d6
	ble	.tooslow
	cmp.l	#32000,d6
	bge	.toofast
	
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos

	lea	OK,a0
	move.w	#2,d1
	bsr	Print
	rts

.tooslow:
	move.l	#1,d1
	lea	CIATickSlowTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts
.toofast:
	move.l	#1,d1
	lea	CIATickFastTxt,a0
	bsr	Print
	move.l	#70,d0
	move.l	#12,d1
	bsr	SetPos
	lea	FAILED,a0
	move.l	#1,d1
	bsr	Print

	rts





;------------------------------------------------------------------------------------------




GFXtestMenu:
	bsr	InitScreen
	move.w	#5,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

GFXTestScreen:
	ifeq	a1k
	
	bsr	ClearScreen
	move.l	#EndTestPic-TestPic,d0
	move.l	d0,d2
	bsr	GetChip
	cmp.l	#0,d0
	beq	.exit
	cmp.l	#1,d0
	beq	.exit
	move.l	#LOWRESSize,d1
	lea	ECSCopper-V(a6),a0			; Location of copperlist in memory
	lea	ECSTestColor,a1
	bsr	FixECSCopper


	move.l	d0,a0					; Copy the address of start of screen to a0
	lea	TestPic,a1				; Set a1 to where testscreen is in ROM
.loop:
	move.b	(a1)+,(a0)+				; Copy testimage to Chipmem
	dbf	d2,.loop

.exit:
	bsr	WaitButton

	bsr	SetMenuCopper
	bra	GFXtestMenu

	else

	bra	Not1K

	endc

GFXtest320x200:

	move.w	#$83f0,$dff096				; Turn on all DMA required


	bsr	ClearScreen
	move.l	#HIRESSize*5,d0
	bsr	GetChip
	cmp.l	#0,d0
	beq	.exit
	cmp.l	#1,d0
	beq	.exit
	move.l	#HIRESSize,d1
	lea	ECSCopper-V(a6),a0			; Location of copperlist in memory
	lea	ECSColor32,a1

	bsr	FixECSCopper

	clr.l	d0
	clr.l	d1
	move.l	#640,d2
	move.l	#512,d3
	move.l	#6,d4
	bsr	DrawLine

	move.l	#640,d0
	clr.l	d1
	clr.l	d2
	move.l	#512,d3
	move.l	#6,d4
	bsr	DrawLine



	move.l	#640,d7
	move.l	#1,d2
	clr.l	d0
.loop6:
	move.l	#236,d1
	move.l	#40,d6
.loop5:
	bsr	PlotPixel
	add.l	#1,d1
	dbf	d6,.loop5
	move.l	d7,d2
	asr	#4,d2

	add.l	#1,d0
	dbf	d7,.loop6



	clr.l	d0
	move.l	#511,d1
.loop:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d1,.loop
	move.l	#640,d0
.loop2:
	move.l	#511,d1
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d0,.loop2

	move.l	#639,d0
	move.l	#511,d1
.loop3:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d1,.loop3

	move.l	#639,d0
	clr.l	d1
.loop4:
	move.l	#1,d2
	bsr	PlotPixel
	dbf	d0,.loop4






	



	bsr	WaitButton

	move.w	#$3ff,$dff096				; Turn off all DMA
	
.exit:
	bsr	SetMenuCopper
	bsr	GFXtestMenu



GFXTestScroll:
	ifeq	a1k
	
	bsr	ClearScreen
	move.l	#EndTestPic-TestPic+4096,d0
	move.l	d0,d2
	bsr	GetChip
	cmp.l	#0,d0
	beq	.exit
	cmp.l	#1,d0
	beq	.exit
	move.l	#LOWRESSize+1024,d1
	lea	ECSCopper2-V(a6),a0			; Location of copperlist in memory
	lea	ECSTestColor,a1
	bsr	FixECSCopper2


	move.l	d0,a0					; Copy the address of start of screen to a0
	move.l	d0,d7					; Make a backup of address
	lea	TestPic,a1				; Set a1 to where testscreen is in ROM


	move.w	#1023,d4
.loop2:
	move.w	#39,d3
.loop:
	move.b	(a1)+,(a0)+				; Copy testimage to Chipmem
	dbf	d3,.loop
	add.l	#4,a0
	dbf	d4,.loop2



	add.l	#62*44,d7
.scrollloop:
	cmp.b	#$bf,$dff006
	bne	.scrollloop
	bsr	.blit

	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne	.scrollloop
	
.exit:
	bsr	SetMenuCopper
	bra	GFXtestMenu


.blit:
	PUSH
	move.w	#3,d6
.blitloop:
	move.w	#113,d4
	move.l	d7,a0
	lea	JunkBuffer-V(a6),a1
.copyloop:
	move.b	(a0),d5
	and.b	#%10000000,d5
	lsr.l	#7,d5
	move.b	d5,(a1)+
	add.l	#44,a0
	dbf	d4,.copyloop
	
	clr.w	$dff042
	move.w	#$ffff,$dff044
	move.w	#$ffff,$dff046
	move.w	#$8040,$dff096
	move.w	#$f9f0,$dff040
	move.l	d7,d0
	sub.l	#2,d0
	move.l	d0,d1
	add.l	#2,d1
	move.l	d1,$dff050
	move.l	d0,$dff054
	move.w	#0,$dff066
	move.w	#0,$dff064	
	move.w	#114*64+22,$dff058
	move.b	d5,40(a0)
	VBLT

	move.w	#113,d4
	move.l	d7,a0
	lea	JunkBuffer-V(a6),a1
.copyloop2:
	move.b	(a1)+,d5
	and.b	#254,39(a0)
	or.b	d5,39(a0)
	add.l	#44,a0
	dbf	d4,.copyloop2


	add.l	#LOWRESSize+1024,d7
	dbf	d6,.blitloop

	POP
	rts


	else

	bra	Not1K

	endc







							; INDATA:
							;	a0 = ECSCopperlist
							;	a1 = List of colors to be set
							;	d0 = Startaddress of space
							;	d1 = Size of bytes of one screen

FixECSCopper:
	PUSH
	add.l	#96,a0					; Add so we get to the spot where palette starts.
	move.l	#31,d7
	move.w	#$180,d6				; Start with $180
.loop:
	move.w	d6,(a0)+
	move.w	(a1)+,(a0)+
	add.w	#2,d6
	dbf	d7,.loop				; Loop around and do all colors
	


	move.l	d0,d6

	lea	GfxTestBpl-V(a6),a2

	move.l	#4,d7
.loop2:
	move.l	d6,(a2)+
	move.w	d6,6(a0)
	swap	d6
	move.w	d6,2(a0)
	swap	d6
	add.l	#8,a0
	add.l	d1,d6
	dbf	d7,.loop2				; Set all bitplanepointers




.Slut:


	lea	InitCOP1LCH,a0
	bsr	SendSerial
	move.l	a6,d0
	add.l	#ECSCopper-V,d0
	move.l	d0,$dff080			;Load new copperlist
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitCOPJMP1,a0
	bsr	SendSerial
	move.w	$dff088,d0
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitDMACON,a0
	bsr	SendSerial
	move.w	#$8380,$dff096
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitBEAMCON0,a0
	bsr	SendSerial
	move.w	#32,$dff1dc			;Hmmm
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	GFXtestNoSerial,a0
	bsr	SendSerial
;.exit:
	POP
	rts


FixECSCopper2:
	PUSH
	add.l	#96,a0					; Add so we get to the spot where palette starts.
	move.l	#31,d7
	move.w	#$180,d6				; Start with $180
.loop:
	move.w	d6,(a0)+
	move.w	(a1)+,(a0)+
	add.w	#2,d6
	dbf	d7,.loop				; Loop around and do all colors
	


	move.l	d0,d6

	lea	GfxTestBpl-V(a6),a2

	move.l	#4,d7
.loop2:
	move.l	d6,(a2)+
	move.w	d6,6(a0)
	swap	d6
	move.w	d6,2(a0)
	swap	d6
	add.l	#8,a0
	add.l	d1,d6
	dbf	d7,.loop2				; Set all bitplanepointers




.Slut:


	lea	InitCOP1LCH,a0
	bsr	SendSerial
	move.l	a6,d0
	add.l	#ECSCopper2-V,d0
	move.l	d0,$dff080			;Load new copperlist
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitCOPJMP1,a0
	bsr	SendSerial
	move.w	$dff088,d0
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitDMACON,a0
	bsr	SendSerial
	move.w	#$8380,$dff096
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	InitBEAMCON0,a0
	bsr	SendSerial
	move.w	#32,$dff1dc			;Hmmm
	lea	InitDONEtxt,a0
	bsr	SendSerial

	lea	GFXtestNoSerial,a0
	bsr	SendSerial
;.exit:
	POP
	rts




DrawLine:							
	PUSH
	asr	#1,d0
	asr	#1,d1
	asr	#1,d2
	asr	#1,d3
	lea	GfxTestBpl-V(a6),a5		; Load pointerlist for bitplanes
	move.l	#4,d7				; number of bitplanes to handle - 1
	clr.l	d6				; Clear d6, d6 is bit to test for palette
	move.l	#40,a1
.loop:
	move.l	(a5)+,a0				; A0 now contains address of bitplane
	btst	d6,d4				; Check if pixel is to be set of cleared
	bne.s	.set				; it is to be set
	bra.s	.clear				; if not, clear it

		
.set:
	move.l	#$ffffffff,a2
	bsr	.DrawLine
	bra	.done
.clear:
	move.l	#$0,a2
	bsr	.DrawLine
.done:
	add.l	#1,d6
	dbf	d7,.loop

	POP

	rts


.DrawLine:
	; d0 = x1
	; d1 = y1
	; d2 = x2
	; d3 = y2
	; a0 = Bitplanr
	; a1 = bitplanewidth in bytes
	; a2 = word written directly to mast register
	PUSH
;	asr.l	#1,d0
;	asr.l	#1,d1
;	asr.l	#1,d2
;	asr.l	#1,d3
	clr.l	d5	
	cmp.w	#320,d0
	ble	.nohighx1
	rts
.nohighx1:	
	cmp.w	#256,d1
	ble	.nohighy1
	rts
.nohighy1:	
	cmp.w	#640,d2
	ble	.nohighx2
	rts
.nohighx2:	
	cmp.w	#256,d3
	ble	.nohighy2
	rts
.nohighy2:	
	clr.l	d4
	add.w	d4,d2
	add.w	d4,d3

	move.l	a1,d4			; Width in work register
	mulu	d1,d4			;Y1 * byte per line
	moveq	#-$10,d5		; No leading characters $f0
	and.w	d0,d5			; Bottom four bits masked from x1
	lsr.w	#3,d5			; Reminder divided by 8
	add.w	d5,d4			; Y1 * bytes per line + x1/8
	add.l	a0,d4			; Plus startong adress of the bitplanes

	clr.l	d5
	sub.w	d1,d3			; Y2-Y1 DeltaY from D3
	roxl.b	#1,d5			; Shift leading char from DeltaY in D5
	tst.w	d3			; Restore N-Flag
	bge.s	.y2gy1			; When DeltaY positive, goto g2gy1
	neg.w	d3			; DeltaY invert (if not positive)

.y2gy1:
	sub.w	d0,d2			; X2-X1 DeltaX to D2
	roxl.b	#1,d5			; move leading char in DeltaX to d5
	tst.w	d2			; Restore N-Flag
	bge.s	.x2gx1			; When Delta X positive
	neg.w	d2			; DeltaX invert

.x2gx1:
	move.w	d3,d1			; DeltaY to d1
	sub.w	d2,d1			; DeltaY-DeltaX
	bge.s	.dygdx			; When DeltaY > DeltaX
	exg	d2,d3			; Smaller delta goto d2
.dygdx:	
	roxl.b	#1,d5			; D5 contains result of 3 comparisons
	lea	Octant_Table,a5
	move.b	(a5,d5),d5		; Get matching octants
	add.w	d2,d2			; Smaller Delta * 2

	VBLT

	move.w	d2,$dff062		;2*Smaller delta tp BLTBMOD
	sub.w	d3,d2			; 2*smaller delta - larger delta
	ble.s	.signn1			;When 2*small delta > largedelta to signn1

	or.b	#$40,d5			;Sign flag set
.signn1:
	move.w	d2,$dff052		; 2*smal delta - large delta in BLTAPTL
	sub.w	d3,d2			; 2*smaller delta -2*larger delta
	move.w	d2,$dff064		; tp BLTAMOD

	move.w	#$8000,$dff074		; BLTADAT
	move.w	a2,$dff072		; mask from a2 in BLTBDAT
	move.w	#$ffff,$dff044		; BLTAFWM
	and.w	#$000f,d0		; Bottom 4 bits from X1
	ror.w	#4,d0			; to START0-3
	or.w	#$0bca,d0		; USEx and LFx set
	move.w	d0,$dff040		; BLTCON0
	move.w	d5,$dff042		; Octant ib blitter BLTCON1
	move.l	d4,$dff048		; Start adress of line  BLTCPTH
	move.l	d4,$dff054		; BLTDPTH
	move.w	a1,$dff060		; Width of bitplanes i both BLTCMOD
	move.w	a1,$dff066		; and BLTDMOD registers

	lsl.l	#6,d3			; Length * 64
	addq.w	#2,d3			; Plus wodth=2
	move.w	d3,$dff058		; set size and start blit
	POP
	rts

PlotPixel:						; Plots a pixel
							; INDATA:
							;	D0 = XPos
							;	D1 = YPos
							;	D2 = Color
							
	PUSH

	asr.l	#1,d0
	asr.l	#1,d1

	move.l	d0,d4				; Make a copy of the X Cordinate
	asr	#3,d0				; Divide te XCordinate with 8 to get what byte to do stuff on
	move.l	d0,d3				; Make a copy of this byte
	asl	#3,d3				; multiply it with 8
	sub.l	d3,d4				; Diff it, so we know what BIT to set

	move.l	#7,d5				; But as it is "reversed" put 7 into d5 and
	sub.l	d4,d5				; Subtract but to do stuff in, d5 now contains bit

	mulu	#40,d1				; Multiply with 40 to get Y position

	add.l	d1,d0				; Add d1 to d0. so d0 now contains how much to add for the pixel

	lea	GfxTestBpl-V(a6),a2		; Load pointerlist for bitplanes
	move.l	#4,d7				; number of bitplanes to handle - 1
	clr.l	d6				; Clear d6, d6 is bit to test for palette

.loop:
	move.l	(a2)+,a0				; A0 now contains address of bitplane
	btst	d6,d2				; Check if pixel is to be set of cleared
	bne.s	.set				; it is to be set
	bra.s	.clear				; if not, clear it

		
.set:
	bset	d5,(a0,d0)
	bra	.done
.clear:
	bclr	d5,(a0,d0)
.done:
	add.l	#1,d6
	dbf	d7,.loop

	POP
	rts



;--------------------------------------------------
;
; Clear screen with blitter..
;
;--------------------------------------------------



BlitterClear:
	; Clears area with blitter
	; INDATA
	; D0 = Pointer to plane.
	; D1 = Number of rows
	; D2 = Number of Words in width
	; D3 = Modulo
	
	PUSH
	VBLT					;Wait for blitter to finish before using the blitter again
	move.w	#$100,$dff040			;Use D,A Set minterm D=A
	clr.w	$dff042				;O=BLTCON1
	move.w	#$ffff,$dff044
	move.w	#$ffff,$dff046
	move.w	#$8040,$dff096			;Turn on blitter DMA
	move.l	d0,$dff054
	move.w	d3,$dff066			;Modulo D
	asl.l	#6,d1
	add.l	d2,d1
	move.w	d1,$dff058			;Set Size and start blitter
	POP
	rts

EnableCache:
	PUSH
	move.l	#$0808,d1
	movec	d1,CACR
	move.l	#$0101,d1
	movec	d1,CACR
	POP
	rts

DisableCache:
	PUSH
	move.l	#$0808,d1
	movec	d1,CACR
	move.l	#0,d1
	movec	d1,CACR
	POP
	rts

;------------------------------------------------------------------------------------------



SystemInfoTest:
	bsr	InitScreen
	lea	SystemInfoTxt,a0
	move.w	#2,d1
	bsr	Print
	lea	SystemInfoHWTxt,a0
	move.w	#2,d1
	bsr	Print

	bsr	GetHWReg
	bsr	PrintHWReg

	lea	NewLineTxt,a0
	bsr	Print


	move.l	#2,d1
	lea	ChipstartTxt,a0
	bsr	Print

	move.l	ChipStart-V(a6),d0			; Get startaddress of chipmem
	move.l	d0,d7					; make a backup of address
	bsr	binhex
	bsr	Print

	move.l	#2,d1
	lea	AndendTxt,a0
	bsr	Print


	move.l	ChipEnd-V(a6),d0			; Get startaddress of chipmem
	bsr	binhex
	move.l	#2,d1
	bsr	Print


	lea	UnusedChipTxt,a0
	move.l	#2,d1
	bsr	Print


	move.l	ChipUnreserved-V(a6),d0
	bsr	bindec
	bsr	Print

	lea	Bytes,a0
	bsr	Print


	bsr	WaitButton
	bra	MainMenu
	


;------------------------------------------------------------------------------------------




PortTestMenu:
	bsr	InitScreen
	move.w	#6,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

PortTestPar:
	bsr	ClearScreen
	lea	PortParTest,a0
	move.l	#7,d1
	bsr	Print

	lea	PortParTest1,a0
	move.l	#3,d1
	bsr	Print

	lea	PortParTest2,a0
	move.l	#2,d1
	bsr	Print

.loop:
	bsr	GetInput
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	move.b	GetCharData-V(a6),d0
	cmp.b	#$1b,d0	
	beq	.exit


	cmp.b	#0,BUTTON-V(a6)
	beq	.loop


	lea	PortParTest3,a0
	move.l	#6,d1
	bsr	Print

	move.b	#$ff,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101
	bsr	WaitLong
	move.b	#%11111111,$bfe301	; set pins output
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	move.b	#0,$bfd200
	clr.l	Passno-V(a6)

.loopa:
	clr.l	d0
	move.l	#10,d1
	bsr	SetPos
	lea	PassTxt,a0
	move.l	#4,d1
	bsr	Print
	clr.l	d0
	add.l	#1,Passno-V(a6)
	move.l	Passno-V(a6),d0
	bsr	bindec
	move.l	#6,d1
	bsr	Print			; Print out passnumber


	bsr	WaitLong
	move.b	#%00000101,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	lea	PortParTest12,a0
	move.l	#3,d1
	bsr	Print
	move.b	#0,d0
	move.b	#1,d1
	bsr	.TestPin



	bsr	WaitLong
	move.b	#%00000010,$bfe301
	bsr	WaitLong
	lea	PortParTest21,a0
	move.l	#3,d1
	bsr	Print
	move.b	#1,d0
	move.b	#0,d1
	bsr	.TestPin


	bsr	WaitLong
	move.b	#%00000100,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	lea	PortParTest34,a0
	move.l	#3,d1
	bsr	Print
	move.b	#2,d0
	move.b	#3,d1
	bsr	.TestPin


	bsr	WaitLong
	move.b	#%00001000,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	lea	PortParTest43,a0
	move.l	#3,d1
	bsr	Print
	move.b	#3,d0
	move.b	#2,d1
	bsr	.TestPin


	bsr	WaitLong
	move.b	#%00010000,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	lea	PortParTest56,a0
	move.l	#3,d1
	bsr	Print
	move.b	#4,d0
	move.b	#5,d1
	bsr	.TestPin

	bsr	WaitLong
	move.b	#%00100000,$bfe301
	bsr	WaitLong
	move.b	#0,$bfe101		; Set all pins to 0
	lea	PortParTest65,a0
	move.l	#3,d1
	bsr	Print
	move.b	#5,d0
	move.b	#4,d1
	bsr	.TestPin


	bsr	WaitLong
	move.b	#%01000000,$bfe301
	move.b	#0,$bfd200
	move.b	#%00000000,$bfe101
	bsr	WaitLong
	lea	PortParTest7p,a0
	move.l	#3,d1
	bsr	Print
	move.b	#1,d1
	move.b	#6,d0
	bsr	.TestPins



	bsr	WaitLong
	move.b	#2,$bfd200
	move.b	#0,$bfd000
	move.b	#0,$bfe301
	bsr	WaitLong
	lea	PortParTestp7,a0
	move.l	#3,d1
	bsr	Print
	move.b	#6,d1
	move.b	#1,d0
	bsr	.TestPins2




	bsr	WaitLong
	move.b	#%01000000,$bfe301
	move.b	#0,$bfd200
	move.b	#%00000000,$bfe101
	bsr	WaitLong
	lea	PortParTest7s,a0
	move.l	#3,d1
	bsr	Print
	move.b	#2,d1
	move.b	#6,d0
	bsr	.TestPins


	bsr	WaitLong
	move.b	#4,$bfd200
	move.b	#0,$bfd000
	move.b	#0,$bfe301
	bsr	WaitLong
	lea	PortParTests7,a0
	move.l	#3,d1
	bsr	Print
	move.b	#6,d1
	move.b	#2,d0
	bsr	.TestPins2

	bsr	WaitLong
	move.b	#%10000000,$bfe301
	bsr	WaitShort
	move.b	#0,$bfd000
	move.b	#%00000000,$bfe101
	bsr	WaitLong
	lea	PortParTest8b,a0
	move.l	#3,d1
	bsr	Print
	move.b	#0,d1
	move.b	#7,d0
	bsr	.TestPins


	bsr	WaitLong
	move.b	#1,$bfd200
	move.b	#0,$bfd000
	move.b	#0,$bfe301
	bsr	WaitLong
	lea	PortParTestb8,a0
	move.l	#3,d1
	bsr	Print
	move.b	#7,d1
	move.b	#0,d0
	bsr	.TestPins2



	bsr	GetInput

.nolmb:
	cmp.b	#1,BUTTON-V(a6)
	beq	.exit

	bne	.loopa
	
.exit:

	bra	PortTestMenu


.TestPin:					;	Test pin of par port
						; IN:
						;	d0 = bit to write
						;	d1 = bit to read
						; OUT:
						;	d2 = 0 = OK, 1=Fail

	clr.l	d2				; Clear errorregister
	bsr	WaitLong
	btst	d1,$bfe101			; First test that bit is 0, if not something is wrong
						; (like missing dongle! but something else can also be a problem)
	beq	.null
	bra	.fail
.null:						; bit was 0, lets set bit and test that it got high
	bset	d0,$bfe101
	bsr	WaitLong
	btst	d1,$bfe101
	beq	.was0
	lea	OOK,a0
	move.b	#2,d1
	bsr	Print
	rts
						; bit was 1, we are OK
.was0:						; ok bit was 0, something is wrong, exit with fail
	bra	.fail
	rts

.fail:
	lea	BAD,a0
	move.b	#1,d1
	bsr	Print
	rts


.TestPins:					; Same as testpin but checks CIAB instead

	clr.l	d2				; Clear errorregister
	bsr	WaitLong
	btst	d1,$bfd000			; First test that bit is 0, if not something is wrong
						; (like missing dongle! but something else can also be a problem)
	beq	.nulls
	bra	.fail
.nulls:						; bit was 0, lets set bit and test that it got high
	bset	d0,$bfe101
	bsr	WaitLong
	btst	d1,$bfd000
	beq	.was0
	lea	OOK,a0
	move.b	#2,d1
	bsr	Print
	rts

.TestPins2:					; Same as testpins but sets CIAB instead

	clr.l	d2				; Clear errorregister
	bsr	WaitLong
	btst	d1,$bfe101			; First test that bit is 0, if not something is wrong
						; (like missing dongle! but something else can also be a problem)
	beq	.nulls2
	bra	.fail
.nulls2						; bit was 0, lets set bit and test that it got high
	bset	d0,$bfd000
	bsr	WaitLong
	btst	d1,$bfe101
	beq	.was0
	lea	OOK,a0
	move.b	#2,d1
	bsr	Print
	rts


PortTestSer:
	bsr	ClearScreen
	lea	PortSerTest,a0
	move.l	#7,d1
	bsr	Print

	lea	PortSerTest1,a0
	move.l	#3,d1
	bsr	Print

	lea	PortSerTest2,a0
	move.l	#2,d1
	bsr	Print

.loop:
	bsr	GetInput
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	move.b	GetCharData-V(a6),d0
	cmp.b	#$1b,d0	
	beq	.exit


	cmp.b	#0,BUTTON-V(a6)
	beq	.loop

	clr.l	Passno-V(a6)
	move.w	#0,SerTstBps-V(a6)

.loopa:
;	bsr	ClearScreen
	lea	PortParTest3,a0			; Lets steal that string
	move.l	#6,d1
	bsr	Print


.testloop:
	clr.l	d0
	move.l	#16,d1
	bsr	SetPos
	lea	PassTxt,a0
	move.l	#4,d1
	bsr	Print
	clr.l	d0
	add.l	#1,Passno-V(a6)
	move.l	Passno-V(a6),d0
	bsr	bindec
	move.l	#6,d1
	bsr	Print			; Print out passnumber

	lea	PortSerBps,a0
	move.l	#4,d1
	bsr	Print

	move.b	#$ff,$bfd200
	move.b	#0,$bfd000

	add.w	#1,SerTstBps-V(a6)
	cmp.w	#5,SerTstBps-V(a6)
	bne	.notmax
	move.w	#1,SerTstBps-V(a6)

.notmax:
	move.w	SerTstBps-V(a6),d0		; Get SerialSpeed value
	mulu	#4,d0				; Multiply with 4
	lea	SerText,a0			; Load table of pointers to different texts
	move.l	(a0,d0.l),a0			; load a0 with the value that a0+d0 points to (text of speed)
	move.l	#7,d1
	bsr	Print

	lea	SerSpeeds,a0
	move.l	(a0,d0),d0			; Load d0 with the value to write to the register for the correct speed.
	move.w	d0,$dff032			; Set the speed of the serialport


	lea	PortSerTest3,a0
	move.l	#3,d1
	bsr	Print

	move.l	#67,d0
	move.l	#18,d1
	bsr	SetPos


	clr.l	d6
	lea	PortSerString,a0
.serloop:
	move.b	(a0)+,d2
	cmp.b	#0,d2
	beq	.donetest

	bsr	RealLoopbacktest
	bra	.serloop

.donetest:

	move.l	d6,d0
	move.l	#2,d1
	bsr	bindec
	bsr	Print

	lea	PortSerTestB45,a0		; Test RTS->CTS
	move.l	#3,d1
	bsr	Print
	move.b	#$c0,$bfd200
	move.b	#6,d0
	move.b	#4,d1
	bsr	.TestPin

	lea	PortSerTestB46,a0		; Test RTS -> DSR
	move.l	#3,d1
	bsr	Print
	move.b	#$c0,$bfd200
	move.b	#0,$bfd000
	bsr	WaitLong
	move.b	#6,d0
	move.b	#3,d1
	bsr	.TestPin


	lea	PortSerTestB208,a0		; Test DTR -> CD
	move.l	#3,d1
	bsr	Print
	move.b	#$c0,$bfd200
	move.b	#0,$bfd000
	bsr	WaitLong
	move.b	#%10000000,$bfd200		; Set what pin is output
	move.b	#7,d0
	move.b	#5,d1
	bsr	.TestPin

	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne	.testloop



;	bsr	WaitReleased

.exit:
.loopend:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne.s	.loopend
	bsr	Init_Serial
	bra	PortTestMenu


.TestPin:
						; Sets a bit and checks is a bit is set�at CIAB Register
						; IN
						;	D0 = Bit to set
						;	D1 = Bit to test

	clr.l	d3
	bset	d0,d3
	clr.l	d2
	move.b	d3,$bfd000
	bsr	WaitLong

	btst	d1,$bfd000
	bne	.bitset
	bra	.bitclrtst
.bitset:
	add.b	#1,d2
.bitclrtst:
	bclr	d0,d3
	move.b	d3,$bfd000
	bsr	WaitLong

	btst	d1,$bfd000
	beq	.bitclear
	bra	.showresult
.bitclear:
	add.b	#1,d2
.showresult:

	cmp.b	#2,d2
	bne	.testfail
	lea	OOK,a0
	move.b	#2,d1
	bsr	Print
	rts
.testfail:
	lea	BAD,a0
	move.b	#1,d1
	bsr	Print
	rts

ClearSerial:					; Just read serialport, to empty it
	move.l	#1,d6				; load d6 with 1, so we run this, twice to be sure serialbuffer is cleared
.loop:
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	move.l	#10000,d7
.timeoutloop2
	move.b	$bfe001,d0			;nonsenseread
	cmp.l	#0,d7
	beq	.exitloop
	sub.l	#1,d7
	move.w	$dff018,d0
	btst	#14,d0				; Buffer full, we have a new char
	beq	.timeoutloop2
.exitloop:
	dbf	d6,.loop
	rts



RealLoopbacktest:				; Test if we have a loopbackadapter connected.
						; Simply by outputing the char in D2 and check if the same char comes back.
						; if so, 1 is added to D6
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	move.l	#10000,d7			; Load d7 with a timeoutvariable
.timeoutloop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d7				; count down timeout value
	cmp.l	#0,d7				; if 0, timeout.
	beq	.endloop
	move.w	$dff018,d0
	btst	#13,d0				; Check TBE bit
	beq.s	.timeoutloop			; Loop until all is ok to send or until timeout hits
.endloop:

	move.w	#$0100,d1
	move.b	d2,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit


	move.l	#10000,d7
.timeoutloop2
	move.b	$bfe001,d0			;nonsenseread
	cmp.l	#0,d7
	beq	.exitloop
	sub.l	#1,d7
	move.w	$dff018,d0
	btst	#14,d0				; Buffer full, we have a new char
	beq	.timeoutloop2
	bra	.check
.exitloop:
	clr.l	d0
.check:
	cmp.b	d0,d2				; Check if in and out was the same char

	bne.w	.exittest				; no so lets exit
	add.b	#1,d6				; Yes, add 1 to d6
.exittest:
	rts



PortTestJoystick:
	bsr	ClearScreen

	move.w	#$ffff,JOY0DAT-V(a6)
	move.w	#$ffff,JOY1DAT-V(a6)
	move.w	#$ffff,POT0DAT-V(a6)
	move.w	#$ffff,POT1DAT-V(a6)
	move.w	#$ffff,POTINP-V(a6)	
	move.b	#$ff,CIAAPRA-V(a6)
	clr.l	PortJoy0-V(a6)
	clr.l	PortJoy1-V(a6)
	move.w	#$fff,PortJoy0OLD-V(a6)
	move.w	#$fff,PortJoy1OLD-V(a6)
	clr.w	P0Fire-V(a6)
	clr.w	P1Fire-V(a6)
	move.w	#$fff,P0FireOLD-V(a6)
	move.w	#$fff,P1FireOLD-V(a6)
	
	lea	PortJoyTest,a0
	move.l	#7,d1
	bsr	Print
	lea	PortJoyTest1,a0
	move.l	#6,d1
	bsr	Print
	lea	PortJoyTestHW1,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW2,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW3,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW4,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW5,a0
	move.l	#3,d1
	bsr	Print
	lea	PortJoyTestHW6,a0
	move.l	#3,d1
	bsr	Print


	move.l	#0,d0
	move.l	#11,d1
	bsr	SetPos

	lea	PortJoyTest2,a0
	move.l	#6,d1
	bsr	Print
	lea	PortJoyTest3,a0
	move.l	#6,d1
	bsr	Print


	move.l	#0,d0
	move.l	#23,d1
	bsr	SetPos

	lea	PortJoyTestExitTxt,a0
	move.l	#7,d1
	bsr	Print




.loop:
	move.w	$dff00a,d7
	lea	JOY0DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samejoy0dat
	move.w	d7,(a0)
	move.w	d7,PortJoy0-V(a6)
	move.l	#36,d0
	move.l	#4,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#4,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samejoy0dat:

	move.w	$dff00c,d7
	lea	JOY1DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samejoy1dat
	move.w	d7,(a0)
	move.w	d7,PortJoy1-V(a6)

	move.l	#36,d0
	move.l	#5,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#5,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	PUSH
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print

	POP

.samejoy1dat:
	move.w	$dff012,d7
	lea	POT0DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepot0dat
	move.w	d7,(a0)
	move.l	#36,d0
	move.l	#6,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#6,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print

.samepot0dat:

	move.w	$dff014,d7
	lea	POT1DAT-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepot1dat
	move.w	d7,(a0)


	move.l	#36,d0
	move.l	#7,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#7,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samepot1dat:


	move.w	$dff016,d7
	lea	POTINP-V(a6),a0
	cmp.w	(a0),d7
	beq	.samepotinp
	move.w	d7,(a0)

	move.l	#36,d0
	move.l	#8,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#8,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samepotinp:
	clr.l	d7
	move.b	$bfe001,d7
	lea	CIAAPRA-V(a6),a0
	cmp.w	(a0),d7
	beq	.samefire
	move.w	d7,(a0)

	btst	#6,$bfe001
	bne	.noport0
	move.w	#1,P0Fire-V(a6)
	bra	.p1
.noport0:
	move.w	#0,P0Fire-V(a6)
.p1:
	btst	#7,$bfe001
	bne	.noport1
	move.w	#1,P1Fire-V(a6)
	bra	.nop
.noport1:
	move.w	#0,P1Fire-V(a6)
.nop:
	move.l	#36,d0
	move.l	#9,d1
	bsr	SetPos
	clr.l	d0
	move.l	d7,d0
	bsr	binhexword
	move.l	#2,d1
	bsr	Print
	move.l	#47,d0
	move.l	#9,d1
	bsr	SetPos
	move.l	d7,d0
	bsr	binstring
	add.l	#16,a0
	move.l	#2,d1
	bsr	Print
.samefire:
	clr.l	d0
	move.w	PortJoy0-V(a6),d0
	cmp.w	PortJoy0OLD-V(a6),d0
	beq	.samejoy0
	move.w	d0,PortJoy0OLD-V(a6)
	bsr	GetJoy
	move.l	d0,d7
	move.l	#0,d2
	bsr	PrintJoy

.samejoy0:

	clr.l	d0
	move.w	PortJoy1-V(a6),d0
	cmp.w	PortJoy1OLD-V(a6),d0
	beq	.samejoy1


	move.w	d0,PortJoy1OLD-V(a6)

	clr.l	d0
	move.w	PortJoy1-V(a6),d0
	bsr	GetJoy
	move.l	d0,d7
	move.l	#37,d2
	bsr	PrintJoy
.samejoy1:


	clr.l	d0
	move.w	P0Fire-V(a6),d0
	cmp.w	P0FireOLD-V(a6),d0
	beq	.samefire0

	TOGGLEPWRLED

	move.w	d0,P0FireOLD-V(a6)


	move.l	#19,d0
	move.l	#17,d1
	bsr	SetPos
	lea	FIRE,a0
	cmp.w	#0,P0Fire-V(a6)
	bne	.nop0
	move.l	#6,d1
	bra	.p0
.nop0:
	move.l	#1,d1
.p0:
	bsr	Print

.samefire0:


	clr.l	d0
	move.w	P1Fire-V(a6),d0
	cmp.w	P1FireOLD-V(a6),d0
	beq	.samefire1

	move.w	d0,P1FireOLD-V(a6)


	move.l	#56,d0
	move.l	#17,d1
	bsr	SetPos
	lea	FIRE,a0
	cmp.w	#0,P1Fire-V(a6)
	bne	.nop1
	move.l	#6,d1
	bra	.p2
.nop1:
	move.l	#1,d1
.p2:
	bsr	Print

.samefire1:



	bsr	GetInput

	cmp.b	#$1b,GetCharData-V(a6)
	beq	.exit

	cmp.b	#1,RMB-V(a6)
	bne	.loop
	move.w	#$44,$dff180
	cmp.b	#1,LMB-V(a6)
	bne	.loop

	bsr	WaitReleased
	
.exit:
	bra	PortTestMenu



PrintJoy:				; Print Joystatus
					; IN =	d7 = joydata
					;	d2 = how much to add in X axis
	move.l	#20,d0
	add.l	d2,d0
	move.l	#15,d1
	bsr	SetPos
	lea.l	UP,a0

	btst	#2,d7
	beq	.noup
	move.l	#1,d1				; 4 blue   6 cyan
	bra	.up
.noup:
	move.l	#6,d1
.up:
	bsr	Print


	move.l	#19,d0
	add.l	d2,d0
	move.l	#19,d1
	bsr	SetPos

	lea.l	DOWN,a0

	btst	#0,d7
	beq	.nodown
	move.l	#1,d1
	bra	.down
.nodown:
	move.l	#6,d1
.down:	
	bsr	Print


	move.l	#13,d0
	add.l	d2,d0
	move.l	#17,d1
	bsr	SetPos
	lea	LEFT,a0

	btst	#3,d7
	beq	.noleft
	move.l	#1,d1
	bra	.left
.noleft:
	move.l	#6,d1
.left:
	bsr	Print


	move.l	#25,d0
	add.l	d2,d0
	move.l	#17,d1
	bsr	SetPos
	lea	RIGHT,a0
	btst	#1,d7
	beq	.noright
	move.l	#1,d1
	bra	.right
.noright:
	move.l	#6,d1
.right:
	bsr	Print
	rts


GetJoy:
	;			IN d0=joy data
	;			OUT: D0   bits =  0=down, 1=right, 2=up, 3=left
	PUSH
	clr.l	d7
	move.l	d0,d6
	move.l	d0,d1
	and.w	#1,d1
	and.w	#2,d0
	asr.w	#1,d0
	eor.w	d1,d0
	btst	#0,d0
	beq	.nodown
	bset	#0,d7
.nodown:
	move.l	d6,d0
	btst	#1,d0
	beq	.noright
	bset	#1,d7
.noright:
	move.l	d0,d1
	and.w	#256,d1
	asr	#8,d1
	and.w	#512,d0
	asr	#8,d0

	asr.w	#1,d0
	eor.w	d1,d0
	btst	#0,d0
	beq	.noup
	bset	#2,d7
.noup:
	move.l	d6,d0
	asr.l	#8,d0
	btst	#1,d0
	beq	.noleft
	bset	#3,d7
.noleft:

	move.l	d7,temp-V(a6)
	POP
	move.l	temp-V(a6),d0
	rts


;------------------------------------------------------------------------------------------




KeyBoardTest:
	bsr	InitScreen
	lea	KeyBoardTestText,a0
	move.l	#7,d1
	bsr	Print
	lea	KeyBoardTestCodeTxt,a0
	move.l	#6,d1
	bsr	Print
	lea	KeyBoardTestCodeTxt2,a0
	move.l	#6,d1
	bsr	Print
	move.b	#0,KeyBOld-V(a6)

.loop:
	bsr	GetInput
	bsr	WaitShort			; just wait a short time
	move.b	scancode-V(a6),d0
	cmp.b	#0,d0
	beq	.null				; If scancode was 0 we had noting

	move.b	KeyBOld-V(a6),d1
	cmp.b	d0,d1				; Check if it is the same as last scan
	beq	.samecode
	move.b	d0,KeyBOld-V(a6)


	move.l	#43,d0
	move.l	#2,d1
	bsr	SetPos
	lea	Space3,a0
	bsr	Print
	move.l	#43,d0
	move.l	#2,d1
	bsr	SetPos
	clr.l	d0
	move.b	scancode-V(a6),d0
	cmp.b	#116,d0				; is it 116? (esc released)
	beq	.exit
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	move.l	#17,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	scancode-V(a6),d0
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print

	move.l	#32,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	scancode-V(a6),d0
	move.l	#3,d1
	bsr	binhexbyte
	bsr	Print
	
	move.l	#62,d0
	move.l	#2,d1
	bsr	SetPos

	clr.l	d0
	move.b	key-V(a6),d0
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	move.l	#58,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	key-V(a6),d0
	bsr	binstringbyte
	move.l	#3,d1
	bsr	Print

	move.l	#73,d0
	move.l	#3,d1
	bsr	SetPos

	move.b	key-V(a6),d0
	bsr	binhexbyte
	move.l	#3,d1
	bsr	Print


	move.l	#73,d0
	move.l	#2,d1
	bsr	SetPos
	move.l	#2,d1

	lea	keyresult-V(a6),a0
	move.b	(a0),d0
	cmp.b	#0,d0				; Check if it was no char, then do not print
	beq	.samecode
	move.l	#3,d1
	bsr	MakePrintable
	bsr	PrintChar
.null:
.samecode:
	cmp.b	#$1b,Serial-V(a6)
	beq	.exit
	cmp.b	#1,MBUTTON-V(a6)
	bne.w	.loop
.exit:

	bra	MainMenu



SSPError:
	move.l	a0,DebugA0-V(a6)		; Store a0 to DebugA0 so we have it saved. as next line will overwrite it
	lea	SSPErrorTxt,a0
	bra	ErrorScreen

BusError:
	move.l	a0,DebugA0-V(a6)
	lea	BusErrorTxt,a0
	bra	ErrorScreen

AddressError:
	move.l	a0,DebugA0-V(a6)
	lea	AddressErrorTxt,a0
	bra	ErrorScreen

IllegalError:
	move.l	a0,DebugA0-V(a6)
	lea	IllegalErrorTxt,a0
	bra	ErrorScreen

DivByZero:
	move.l	a0,DebugA0-V(a6)
	lea	DivByZeroTxt,a0
	bra	ErrorScreen

ChkInst:
	move.l	a0,DebugA0-V(a6)
	lea	ChkInstTxt,a0
	bra	ErrorScreen

TrapV:
	move.l	a0,DebugA0-V(a6)
	lea	TrapVTxt,a0
	bra	ErrorScreen

PrivViol:
	move.l	a0,DebugA0-V(a6)
	lea	PrivViolTxt,a0
	bra	ErrorScreen

Trace:
	move.l	a0,DebugA0-V(a6)
	lea	TraceTxt,a0
	bra	ErrorScreen

UnimplInst:
	move.l	a0,DebugA0-V(a6)
	lea	UnImplInstrTxt,a0
	bra	ErrorScreen
	
Trap:
	move.l	a0,DebugA0-V(a6)
	lea	TrapTxt,a0
	bra	ErrorScreen





POSTBusError:
	lea	BusErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$fff,d6
	bra	POSTErrorScreen

POSTAddressError:
	lea	AddressErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$f0f,d6
	bra	POSTErrorScreen

POSTIllegalError:
	lea	IllegalErrorTxt,a0
	move.w	#$f00,d5
	move.l	#$0ff,d6
	bra	POSTErrorScreen

POSTDivByZero:
	lea	DivByZeroTxt,a0
	move.w	#$f00,d5
	move.l	#$ff0,d6
	bra	POSTErrorScreen

POSTChkInst:
	lea	ChkInstTxt,a0
	move.w	#$f00,d5
	move.l	#$00f,d6
	bra	POSTErrorScreen

POSTTrapV:
	lea	TrapVTxt,a0
	move.w	#$000,d5
	move.l	#$fff,d6
	bra	POSTErrorScreen

POSTPrivViol:
	lea	PrivViolTxt,a0
	move.w	#$000,d5
	move.l	#$f0f,d6
	bra	POSTErrorScreen

POSTTrace:
	lea	TraceTxt,a0
	move.w	#$000,d5
	move.l	#$0ff,d6
	bra	POSTErrorScreen

POSTUnimplInst:
	lea	UnImplInstrTxt,a0
	move.w	#$000,d5
	move.l	#$ff0,d6
	bra	POSTErrorScreen

POSTErrorScreen:
	move.w	#$200,$dff100
	move.w	#0,$dff110

	move.l	a0,a2
	
	lea	NewLineTxt,a0		; Tell user on serialport that we are totally halted.
	lea	.post1,a1
	bra	DumpSerial
.post1:
	move.l	a2,a0
	add.l	#1,a0			; Skip first char as we do not use it in this routine.
	lea	.post2,a1
	bra	DumpSerial

.post2:
	lea	HaltTxt,a0
	lea	.loop,a1
	bra	DumpSerial
	

.loop:
	TOGGLEPWRLED		; Change value of Powerled.
	bne	.not
	move.w	d6,$dff180		; Set Screencolor to d6 (usual chipmemproblem color)
	bra	.yes
.not:
	move.w	d5,$dff180		; just every 2:nd turn, show a DARK green color instead. making the screen flash some.
.yes:
	move.l	#$ffff,d7		; Do a nonsense loop
.loopa:
	move.b	$bfe001,d5		; Actually a nonsense read. but CIA space is slow to read from.
	move.b	$bfd400,d5		; Actually a nonsense read. but CIA space is slow to read from.
	move.b	$400,d5
	dbf	d7,.loopa
	bra.w	.loop			; Loop forever



bitcheck:
						;IN:
						;	d0 = Written value
						;	d1 = Read value
						;	d2 = errorlongword (errors will be set)
						;	a0 = as no stack. return JUMP value
	move.l	#31,d6				; We will check 31+1 bits (longword)
	clr.l	d7
.bitloop:
	btst	d6,d0
	bne	.set
						; ok read bit should be 0
	btst	d6,d1
	beq	.correct
	bset	d6,d2				; Set bit at d2 as error
	bra	.correct			; Well not true. but reusing labels

.set:						; ok read but should be 1
	btst	d6,d1
	bne	.correct
	bset	d6,d2
						; ok read bit should be 1
.correct:
	dbf	d6,.bitloop
	jmp	(a0)


ErrorScreen:
	bsr	ClearScreen
	move.l	d1,DebugD1-V(a6)
	move.l	#1,d1
	bsr	Print
	move.l	DebugA0-V(a6),a0
	move.l	DebugD1-V(a6),d1
	bsr	DebugScreen

	bsr	WaitButton
	bra	MainMenu

;------------------------------------------------------------------------------------------

Setup:
	bsr	ClearScreen
	lea	SetupTxt,a0
	move.l	#1,d1
	bsr	Print
	bsr	DebugScreen
	bsr	WaitButton
	bra	MainMenu


;------------------------------------------------------------------------------------------

OtherTest:
	bsr	InitScreen
	move.w	#7,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop

RTCTest:
	bsr	ClearScreen

	bsr	DevPrint
	clr.l	RTCold-V(a6)

.loopa:
	move.b	#8,$dc0037
	lea	$dc0003,a1
	clr.l	d0
	move.b	(a1),d0
	asl.l	#8,d0
	add.b	1(a1),d0
	asl.l	#8,d0
	add.b	2(a1),d0
	asl.l	#8,d0
	add.b	3(a1),d0			; Now we have read a longword. 68k friendly from odd address

	cmp.l	RTCold-V(a6),d0			; Check if first byte have changed.
	beq.w	.nochange
	move.l	d0,RTCold-V(a6)

	clr.l	d0
	clr.l	d1
	bsr	SetPos

	lea	RTCByteTxt,a0
	lea	RTCString-V(a6),a2
	move.l	#3,d1
	bsr	Print

	move.l	#13,d7
.loop:
	move.b	#8,$dc0037
	clr.l	d0
	move.b	(a1),d0
	move.b	d0,d1
	and.b	#$f,d1				;Strip away top 4 bits
	move.b	d1,(a2)+
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print
	add.l	#4,a1
	dbf	d7,.loop

	lea	NewLineTxt,a0
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print


	lea	RTCBitTxt,a0
	move.l	#3,d1
	bsr	Print

	move.b	#8,$dc0037

	lea	RTCString-V(a6),a1
	move.l	#13,d7
.loop1:
	clr.l	d0
	move.b	(a1)+,d0
	bsr	binstringbyte
	move.l	#2,d1
	bsr	Print
	lea	SpaceTxt,a0
	bsr	Print
	cmp.b	#7,d7
	bne	.nope
	lea	NewLineTxt,a0
	bsr	Print
.nope:
	dbf	d7,.loop1

	lea	NewLineTxt,a0
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	

	bsr	ricoh
	bsr	oki


.nochange:
	bsr	GetInput
	cmp.b	#1,BUTTON-V(a6)
	bne	.loopa

;	bsr	WaitButton
	bra	OtherTest


ricoh:						; RICOH chipset detected.
	lea	RTCRicoh,a0
	move.l	#6,d1
	bsr	Print
	move.l	#2,d1
	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	lea	RTCDay,a1
	clr.l	d0
	move.b	6(a0),d0
	mulu	#10,d0
	move.l	a1,a0
	add.l	d0,a0
	bsr	Print

	move.b	#" ",d0
	bsr	PrintChar


	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	clr.l	d0
	move.b	12(a0),d0
	mulu	#10,d0
	add.b	11(a0),d0			; We have now the year, 2 digits

	cmp.b	#78,d0				; Check for 78
	bge	.r19				; more or equal to 78. we are in 19xx

	add.l	#2000,d0
	bra	.rno19
.r19:
	add.l	#1900,d0

.rno19
	bsr	bindec
	bsr	Print
						; Now year is printed
	move.b	#"-",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC

	clr.l	d0
	move.b	10(a0),d0
	mulu	#10,d0
	add.b	9(a0),d0			; We have now the month

	sub.l	#1,d0

	cmp.b	#11,d0
	blt	.rnoover
	move.l	#12,d0
.rnoover:
	mulu	#4,d0				; Multiply with 4 to get where string start

	lea	RTCMonth,a5
	move.l	a5,a0
	add.l	d0,a0
	bsr	Print

	move.b	#"-",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	clr.l	d0
	
	move.b	8(a0),d0
	add.b	#$30,d0
	bsr	PrintChar

	move.b	7(a0),d0
	add.b	#$30,d0
	bsr	PrintChar

	move.b	#" ",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	add.l	#6,a0
	move.l	#5,d7
	clr.l	d6				; Clear d6 as it is a counter when to print a :
.rloop:
	cmp.b	#2,d6				; time to print : ?
	bne	.rnocolon
	move.b	#":",d0
	bsr	PrintChar
	clr.l	d6
.rnocolon:
	add.l	#1,d6

	move.b	-(a0),d0
	add.b	#$30,d0
	bsr	PrintChar
	dbf	d7,.rloop


	lea	NewLineTxt,a0
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	rts

oki:
	lea	RTCOKI,a0
	move.l	#6,d1
	bsr	Print
	move.l	#2,d1
	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	lea	RTCDay,a1
	clr.l	d0
	move.b	6(a0),d0
	mulu	#10,d0
	move.l	a1,a0
	add.l	d0,a0
	bsr	Print

	move.b	#" ",d0
	bsr	PrintChar


	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	clr.l	d0
	move.b	11(a0),d0
	mulu	#10,d0
	add.b	10(a0),d0			; We have now the year, 2 digits

	add.l	#1900,d0
	bsr	bindec
	move.l	#2,d1
	bsr	Print


	move.b	#"-",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC

	clr.l	d0
	move.b	9(a0),d0
	mulu	#10,d0
	add.b	8(a0),d0			; We have now the month
	sub.l	#1,d0

	cmp.b	#11,d0
	blt	.okinoover
	move.l	#12,d0
.okinoover:
	mulu	#4,d0				; Multiply with 4 to get where string start


	lea	RTCMonth,a5
	move.l	a5,a0
	add.l	d0,a0
	bsr	Print

	move.b	#"-",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	clr.l	d0
	
	move.b	7(a0),d0
	add.b	#$30,d0
	bsr	PrintChar

	move.b	6(a0),d0
	add.b	#$30,d0
	bsr	PrintChar

	move.b	#" ",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	clr.l	d0
	clr.l	d7				; if d7 is not 0, we are in PM
	move.b	5(a0),d0
	btst	#2,d0
	beq	.ono
	move.b	#1,d7				; Set that we are in PM
	bclr	#2,d0

.ono:
	mulu	#10,d0
	add.b	4(a0),d0
	cmp.b	#0,d7
	beq.w	.ono1
	sub.b	#2,d0

	cmp.b	#254,d0
	beq.b	.oki8
	cmp.b	#255,d0
	beq.b	.oki9
	bra	.ono2
.oki8:
	move.b	#8,d0
	bra.s	.ono2
.oki9:
	move.b	#9,d0
	bra.w	.ono2
.ono2:
	add.b	#12,d0
.ono1:
	cmp.b	#9,d0
	bgt	.okilow
	PUSH
	move.b	#"0",d0
	bsr	PrintChar
	POP
.okilow:
	bsr	bindec
	bsr	Print

	move.b	#":",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	move.b	3(a0),d0
	add.b	#"0",d0
	bsr	PrintChar
	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	move.b	2(a0),d0
	add.b	#"0",d0
	bsr	PrintChar
	move.b	#":",d0
	bsr	PrintChar

	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	move.b	1(a0),d0
	add.b	#"0",d0
	bsr	PrintChar
	lea	RTCString-V(a6),a0		; load a0 to string from RTC
	move.b	(a0),d0
	add.b	#"0",d0
	bsr	PrintChar
	rts

;------------------------------------------------------------------------------------------

AutoConfig:					; Do Autoconfigmagic
	bsr	ClearScreen
	move.b	#0,AutoConfMode-V(a6)		; Set that we do not want a more detailed autoconfig mode
	bsr	DoAutoconfig

	lea	AnyKeyMouseTxt,a0
	move.l	#3,d1
	bsr	Print
	bsr	WaitButton
	bra	MainMenu

AutoConfigDetail:				; Do Autoconfigmagic
	bsr	ClearScreen
	move.b	#1,AutoConfMode-V(a6)		; Set that we want a more detailed autoconfig mode
	bsr	DoAutoconfig

	lea	AnyKeyMouseTxt,a0
	move.l	#3,d1
	bsr	Print
	bsr	WaitButton
	bra	MainMenu


; Autoconfigcode.  based much Terriblefires code, Added support for several cards
; and more information.

E_EXPANSIONBASE		EQU	$e80000
EZ3_EXPANSIONBASE	EQU	$ff000000

ERT_TYPEMASK		EQU	$c0	;Bits 7-6
ERT_TYPEBIT		EQU	6
ERT_TYPESIZE		EQU	2
ERT_NEWBOARD		EQU	$c0
ERT_ZORROII		EQU	ERT_NEWBOARD
ERT_ZORROIII		EQU	$80
; ** other bits defined in er_Type **
; ** er_Type field memory size bits ** 
ERT_MEMMASK		EQU	$07	;Bits 2-0
ERT_MEMBIT		EQU	0
ERT_MEMSIZE		EQU	3
	
			rsreset
er_Type 		rs.b	1	;Board type, size and flags
er_Product		rs.b	1	;Product number, assigned by manufacturer
er_Flags		rs.b	1	;Flags
er_Reserved03		rs.b	1	;Must be zero ($ff inverted)
er_Manufacturer 	rs.w	1	;Unique ID,ASSIGNED BY COMMODORE-AMIGA!
er_SerialNumber 	rs.l	1	;Available for use by manufacturer
er_InitDiagVec		rs.w	1	;Offset to optional "DiagArea" structure
er_Reserved0c		rs.b	1
er_Reserved0d		rs.b	1
er_Reserved0e		rs.b	1
er_Reserved0f		rs.b	1
ExpansionRom_SIZEOF	rs.b	0

			rsreset
ec_Interrupt		rs.b	1	;Optional interrupt control register
ec_Z3_HighBase		rs.b	1	;Zorro III   : Bits 24-31 of config address
ec_BaseAddress		rs.b	1	;Zorro II/III: Bits 16-23 of config address
ec_Shutup		rs.b	1	;The system writes here to shut up a board
ec_Reserved14		rs.b	1
ec_Reserved15		rs.b	1
ec_Reserved16		rs.b	1
ec_Reserved17		rs.b	1
ec_Reserved18		rs.b	1
ec_Reserved19		rs.b	1
ec_Reserved1a		rs.b	1
ec_Reserved1b		rs.b	1
ec_Reserved1c		rs.b	1
ec_Reserved1d		rs.b	1
ec_Reserved1e		rs.b	1
ec_Reserved1f		rs.b	1
ExpansionControl_SIZEOF rs.b	0

DoAutoconfig:
	lea	AutoConfBuffer-V(a6),a2
	move.b	#$20,AutoConfZ2Ram-V(a6)
	move.w	#$4000,AutoConfZ3-V(a6)	; Set defaultvalues for different cardtypes
	move.b	#$20,AutoConfZ2Ram-V(a6)
	move.b	#$e9,AutoConfZ2IO-V(a6)

	lea	AutoConfZ2Txt,a0
	move.l	#6,d1
	bsr	Print


	move.l	#1,d6			; Clear boardnumber
.loopz2:
	lea	E_EXPANSIONBASE,a0
	bsr	.ReadRom
	cmp.b	#0,AutoConfType-V(a6)	; Check type of card, if 0, no card found
	beq	.noz2	
	bsr	.WriteByte
	add.l	#1,d6
	cmp.l	#32,d6			; if we hit 32 boards.. something is wrong, exit
	bgt	.toomuch
	cmp.b	#0,AutoConfExit-V(a6)	; Check the force exitflag
	bne	.noz3
	bra	.loopz2
.noz2:


	lea	AutoConfZ3Txt,a0
	move.l	#6,d1
	bsr	Print

.loopz3:
	lea	EZ3_EXPANSIONBASE,a0
	bsr	.ReadRom
	cmp.b	#0,AutoConfType-V(a6)	; Check type of card, if 0, no card found
	beq	.noz3	
	bsr	.WriteByte
	add.l	#1,d6
	cmp.l	#32,d6			; if we hit 32 boards.. something is wrong, exit
	bgt	.toomuch
	cmp.b	#0,AutoConfExit-V(a6)	; Check the force exitflag
	bne	.noz3

	bra	.loopz3
.noz3:

	lea	AutoConfAllTxt,a0
	move.l	#6,d1
	bsr	Print

	rts	
.toomuch:
	lea	AutoConfToomuchTxt,a0
	move.l	#1,d1
	bra	Print

.ReadRom:
	clr.b	AutoConfType-V(a6)	; Set type to 0 (no card found)
	clr.b	AutoConfZorro-V(a6)	; Set zorrotype to 2 (0)
	clr.l	AutoConfSize-V(a6)	; Clear the size of the board

	clr.l	d0
	move.l	a0,a3			; Backup of card
	move.l	a2,a4			; Backup of zorrobuffer
	bsr	.ReadByte

	move.b	d0,(a2)+
	; All other bytes are inverted
	moveq.l	#1,d2
.ReadRomLoop:
	move.l	d2,d0
	move.l	a3,a0			; Huh
	bsr	.ReadByte
	not.b	d0
	move.b	d0,(a2)+
	addq.w	#1,d2
	cmp.w	#ExpansionRom_SIZEOF,d2	; check if we read enough data
	bls.s	.ReadRomLoop

	move.l	a4,a2			; Restore zorrobuffer

	tst.b	er_Reserved03(a2)	; Check if it is 0, if not, we have no card
	bne	.NoCard

	tst	er_Manufacturer(a2)	; Check if it is 0, if so, we have no card
	beq	.NoCard

	cmp.b	#0,AutoConfMode-V(a6)
	beq	.nodetail


	PUSH
	lea	AutoConfBoardTxt,a0
	move.l	#5,d1
	bsr	Print
	move.l	d6,d0			; Take boardnumber to d0
	bsr	bindec
	move.l	#2,d1
	bsr	Print

	lea	AutoConfManuTxt,a0
	move.l	#3,d1
	bsr	Print

	move.w	er_Manufacturer(a2),d0
	bsr	bindec
	move.w	#2,d1
	bsr	Print

	lea	AutoConfSerTxt,a0
	move.l	#3,d1
	bsr	Print

	move.w	er_SerialNumber(a2),d0
	bsr	bindec
	move.w	#2,d1
	bsr	Print

	lea	AutoConfZorTypeTxt,a0
	move.l	#3,d1
	bsr	Print	

	clr.l	d0			; Print if it is Zorro II or III
	move.b	er_Type(a2),d0
	and.b	#$c0,d0			; Strip out all except top 2 bits
	cmp.b	#$c0,d0
	beq	.readz2
	lea	III,a0
	move.l	#6,d1
	bsr	Print
	bra	.readz3
.readz2:
	lea	II,a0
	move.l	#6,d1
	bsr	Print

.readz3:

	lea	AutoConfLinkTxt,a0
	move.l	#3,d1
	bsr	Print	

	btst	#5,er_Type(a2)		; Check if it is Linked to system pool (RAM)
	beq	.readnomem
	bsr	PrintYes
	bra	.readmem
.readnomem:
	bsr	PrintNo
.readmem:
	lea	AutoConfAutoBTxt,a0
	move.l	#3,d1
	bsr	Print	

	btst	#4,er_Type(a2)		; Check if there is any Autobootstuff
	bne	.readnoboot
	bsr	PrintNo
	bra	.readboot
.readnoboot:
	bsr	PrintYes
.readboot:


	lea	AutoConfLinked2NextTxt,a0
	move.l	#3,d1
	bsr	Print	

	btst	#4,er_Type(a2)		; Check if linked to next card
	beq	.readnolink
	bsr	PrintYes
	bra	.readlink
.readnolink:
	bsr	PrintNo
.readlink:

	lea	AutoConfExtSizeTxt,a0
	move.l	#3,d1
	bsr	Print

	clr.l	d7			; Clear d7 to have as a variable. if changed we have extended size
	btst	#5,er_Flags(a2)		; Check if Extended sizes will be used
	beq	.readnoextsize
	moveq.l	#1,d7			; Set d7 to 1, we have extended sizes
	bsr	PrintYes
	bra	.readextsize
.readnoextsize:
	bsr	PrintNo
.readextsize:
	lea	AutoConfSizeTxt,a0
	move.l	#3,d1
	bsr	Print	

	clr.l	d0
	move.b	er_Type(a2),d0
	and.b	#7,d0			; D0 now contains sizebits
	asl	#2,d0			; Multiply with 4, to get correct location in pointerlist


	lea	SizeTxtPointer,a0
	cmp.b	#0,d7			; Check if d7 is 0, if so we have not extended size
	beq	.readnoext
	lea	ExtSizeTxtPointer,a0
.readnoext:
	move.l	(a0,d0.l),a0		; A0 now points to the correct textstring
	move.l	#2,d1
	bsr	Print

	lea	AutoConfBufTxt,a0
	move.l	#6,d1
	bsr	Print
	move.l	a2,a1
	move.l	#ExpansionRom_SIZEOF-1,d7
.printloop:
	move.b	(a1)+,d0
	bsr	binhexbyte
	move.l	#2,d1
	bsr	Print
	lea	SpaceTxt,a0
	bsr	Print
	dbf	d7,.printloop

	move.l	a4,a2			; Restore backup of zorrobuffer
	POP
.nodetail:

					; ok detailed VERBOSE output done, lets do it "again" quiet and set variables.



	btst	#5,er_Type(a2)		; Check if it is Linked to system pool (RAM)
	beq	.readsetnomem
	move.b	#2,AutoConfType-V(a6)	; Set type to 2 = RAM
	bra	.readsetmem
.readsetnomem:
	clr.l	d0
	move.b	er_Type(a2),d0
	and	#7,d0
	
	cmp	#2,d0			; Check if space is more than 128K then allocate it to Z2 area instead. (but not ram)
	bge	.readsetz2space


	move.b	#1,AutoConfType-V(a6)	; Set type to 1 = ROM
.readsetmem:


	clr.l	d0			; Check if it is Zorro II or III
	move.b	er_Type(a2),d0
	and.b	#$c0,d0			; Strip out all except top 2 bits
	cmp.b	#$c0,d0
	beq	.readsetz2
	move.b	#1,AutoConfZorro-V(a6)
	bra	.readsetz3
.readsetz2space:			; To be assigned in Z2 space, but not RAM
	move.b	#3,AutoConfType-V(a6)	; Set type to 3 = Z2Space no ram
	bra	.readsetz3

.readsetz2:
	move.b	#0,AutoConfZorro-V(a6)
.readsetz3:



	clr.l	d7			; Clear d7 to have as a variable. if changed we have extended size
	btst	#5,er_Flags(a2)		; Check if Extended sizes will be used
	beq	.readsetnoextsize
	moveq.l	#1,d7			; Set d7 to 1, we have extended sizes
.readsetnoextsize:

	clr.l	d0
	move.b	er_Type(a2),d0
	and.b	#7,d0			; D0 now contains sizebits
	asl	#2,d0			; Multiply with 4, to get correct location in pointerlist


	lea	SizePointer,a0
	cmp.b	#0,d7			; Check if d7 is 0, if so we have not extended size
	beq	.readsetnoext
	lea	ExtSizePointer,a0
.readsetnoext:
	move.l	(a0,d0.l),d0		; D0 now contains the size of the card.

	move.l	d0,AutoConfSize-V(a6)	; Write the size to the buffer
	rts
.NoCard:
	move.b	#0,AutoConfType-V(a6)	; Ser that we have no card
	rts

.ReadByte:			; Reads one byte from Cardexpansion.
				; IN:
				; 	D0 = Location into buffer to read
				;	A0 = Card
				;	A2 = Destionationbuffer
				; OUT:
				;	D0 = Byte read

	lsl.w	#2,d0		;	Multiply with 4
	lea.l	0(a0,d0.w),a0	; a0 now contain pointer to real card.

	move.l	a0,d1
	bmi	.Z3		; Check for Z3
	move.b	$2(a0),d1
	bra	.doRead
.Z3:
	move.b	$100(a0),d1
.doRead:
	lsr.b	#4,d1		; Strip away so we just keep a nibble
	moveq.l	#0,d0
	move.b	(a0),d0
	and.b	#$f0,d0		; Strip away so we just keep a nibble
	or.b	d1,d0		; Put those 2 nibbles together, and we get a byte read.
	rts

.WriteByte:				; Write configbyte to configure card. (ok WORD for Z3!)
	clr.b	AutoConfIllegal-V(a6)	; Clear the illegalflag
	clr.l	d0
	lea	NewLineTxt,a0
	bsr	Print

	move.b	AutoConfType-V(a6),d0	; Get what type of card
	cmp.b	#0,d0			; No card found
	beq	.exit
	cmp.b	#1,AutoConfZorro-V(a6)	; Check if Z3 Card
	beq	.WriteZ3
	cmp.b	#1,d0			; Check if Z2 ROM
	beq	.WriteZ2IO
	cmp.b	#3,d0			; Check if Z3 Area card (NO RAM)
	beq	.WriteZ2noram

	lea	AutoConfRamCardTxt,a0	; We got a Z2 RAM Card
	clr.l	d1
	move.b	AutoConfZ2Ram-V(a6),d1
	move.w	d1,AutoConfWByte-V(a6)
	move.l	d1,d0
	swap	d0
	move.l	d0,AutoConfAddr-V(a6)
	add.l	AutoConfSize-V(a6),d0
	cmp.l	#$a00002,d0
	blo	.writenoz2illegal
	PUSH
	lea	AutoConfIllegalTxt,a0
	move.l	#1,d1
	bsr	Print
	move.b	#1,AutoConfIllegal-V(a6)	; Set the illegal flag
	POP
.writenoz2illegal:
	swap	d0
	move.b	d0,AutoConfZ2Ram-V(a6)
	lea	E_EXPANSIONBASE,a1
	bra	.Write

.WriteZ2noram:
	lea	AutoConfRomCardTxt,a0	; We got a Z2 RAM Card
	clr.l	d1
	move.b	AutoConfZ2Ram-V(a6),d1
	move.w	d1,AutoConfWByte-V(a6)
	move.l	d1,d0
	swap	d0
	move.l	d0,AutoConfAddr-V(a6)
	add.l	AutoConfSize-V(a6),d0
	cmp.l	#$c0000002,d0
	blo	.writenoz3illegal
	PUSH
	lea	AutoConfIllegalTxt,a0
	move.l	#1,d1
	bsr	Print
	move.b	#1,AutoConfIllegal-V(a6)	; Set the illegal flag
	POP
.writenoz3illegal:


	swap	d0
	move.b	d0,AutoConfZ2Ram-V(a6)
	lea	E_EXPANSIONBASE,a1
	bra	.Write


.WriteZ3:
	lea	AutoConfZ3CardTxt,a0	; We got a Z3 Card
	clr.l	d1
	move.w	AutoConfZ3-V(a6),d1
	move.w	d1,AutoConfWByte-V(a6)
	move.l	d1,d0
	swap	d0
	move.l	d0,AutoConfAddr-V(a6)
	add.l	AutoConfSize-V(a6),d0
	swap	d0
	move.w	d0,AutoConfZ3-V(a6)
	lea	EZ3_EXPANSIONBASE,a1
	bra	.Write

.WriteZ2IO:
	lea	AutoConfRomCardTxt,a0	; We got a Z2 ROM Card
	clr.l	d1

	move.b	AutoConfZ2IO-V(a6),d1
	clr.l	d1
	move.b	AutoConfZ2IO-V(a6),d1
	move.w	d1,AutoConfWByte-V(a6)
	move.l	d1,d0
	swap	d0
	move.l	d0,AutoConfAddr-V(a6)
	add.l	AutoConfSize-V(a6),d0
	swap	d0
	move.b	d0,AutoConfZ2IO-V(a6)
	lea	E_EXPANSIONBASE,a1
	bra	.Write

.Write:					; OK! we have a card, not Z3 or Z2io. it must be Z2 RAM!
	cmp.b	#0,AutoConfIllegal-V(a6)	; Check if the illegalfag was set
	bne	.WriteNoAssign			; it was not 0, so it is set, shutdown card
	move.l	d1,d3
	move.l	#2,d1
	bsr	Print

					; IN now:
					; A0 = String to output
					; D0 = Startadr of Autoconfig, cleartext
					; D2 = Endadr
					; D3 = Startadr of Autoconfig, short
					; A1 = Expansionbase

	move.l	AutoConfAddr-V(a6),d0	; Get address to assign board to
	move.l	d0,d2			; Store size in D2
	bsr	binhex
	move.l	#6,d1
	bsr	Print
	lea	MinusTxt,a0
	move.l	#3,d1
	bsr	Print

	move.l	d2,d0			; move back size to D0
	add.l	AutoConfSize-V(a6),d0	; Add the size, to get the endaddress
	bsr	binhex
	move.l	#6,d1
	bsr	Print

	lea	NewLineTxt,a0
	bsr	Print

	cmp.b	#0,AutoConfMode-V(a6)
	beq	.WriteFast
	lea	AutoConfEnableTxt,a0
	move.l	#2,d1
	bsr	Print

	clr.b	AutoConfExit-V(a6)	; Clear the force exitflag
.WriteLoop:
	bsr	GetInput	; Get inputdata
	cmp.b	#0,BUTTON-V(a6)
	beq	.WriteLoop
	cmp.b	#1,LMB-V(a6)
	beq	.WriteFast
	cmp.b	#1,RMB-V(a6)	
	beq	.WriteNoAssign
	move.b	GetCharData-V(a6),d7	; Get chardata
	bclr	#5,d7		; Make it uppercase
	cmp.b	#"Y",d7
	beq	.WriteFast
	cmp.b	#"N",d7
	beq	.WriteNoAssign
	cmp.b	#$1b,d7
	beq	.forceexit
	bra	.WriteLoop

.WriteFast:
	move.l	a1,a0			; Set correct Expansionbase
	move.l	d3,d1
	bsr	.WriteCard
	rts
.WriteNoAssign:
	move.l	a1,a0			; Set correct Expansionbase
	moveq	#ec_Shutup+ExpansionRom_SIZEOF,d0
	bsr	.WriteCard
	move.l	#-2,d0
.exit:	rts
.forceexit:
	move.b	#1,AutoConfExit-V(a6)	; Set force exit flag
	rts	
.WriteCard:
	move.l	#ec_BaseAddress+ExpansionRom_SIZEOF,d0
	clr.l	d1
	move.w	AutoConfWByte-V(a6),d1	; Get data to write

	cmp.b	#0,AutoConfMode-V(a6)
	beq	.WriteCardFast
.WriteCardFast:
	lsl.l	#2,d0			; Multiply with 4
	move.l	a0,a1
	lea.l	0(a0,d0.w),a0


	cmp.l	#EZ3_EXPANSIONBASE,a0
	bhs.s	.writez3

	move.l	d1,d0
	lsl.b	#4,d0
	move.b	d0,$2(a0)
	move.b	d1,(a0)
	rts

.writez3:
	move.l	d1,d2
	move.l	d1,d0
	lsl.b	#4,d0
	move.b	d0,$100(a0)
	move.b	d1,(a0)
	move.l	a1,a0
	move.l	#$44,d0
	lea	0(a0,d0.w),a0
	move.w	d2,(a0)


.dowrite:
	rts


;------------------------------------------------------------------------------------------

DiskTest:
	bsr	InitScreen
	move.w	#8,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	bra	MainLoop




DiskdriveTest:
	move.l	#12980,d0			; Size of a track
	bsr	GetChip				; get chipmemaddress for this block
	cmp.l	#0,d0
	beq	.exit
	move.l	d0,trackbuff-V(a6)
	bsr	.Initdisk

.DiskdriveTester:
	bsr	ClearScreen
	clr.b	oldbfe001-V(a6)
	clr.b	oldbfd100-V(a6)

	move.w	#0,MenuNumber-V(a6)
	move.b	#1,PrintMenuFlag-V(a6)
	move.l	#DriveTestMenu,Menu-V(a6)	; Set different menu




	move.l	a6,d0
	add.l	#DriveTestVar-V,d0		; Pointer to variables
	move.l	d0,a0
	move.l	d0,MenuVariable-V(a6)


.loop:
	bsr	.StepToTrack			; Check if drivestepping is needed, if so do it
	move.l	MenuVariable-V(a6),a0		; Load a0 with pointer to where variable is
	clr.l	d0
	move.w	DriveNo-V(a6),d0		; Load with drivenumber
	mulu	#5,d0				; Multiply it with 4 to get to correct drivetext
	lea	DF0,a1
	add.l	d0,a1
	move.w	DriveOK-V(a6),d0
	cmp.b	#0,d0
	bne	.driveok
	move.w	#1,(a0)+
	bra	.okdone
.driveok:
	move.w	#2,(a0)+
.okdone:
	move.l	a1,(a0)+
	
	move.l	#6,d0				; Show Tracknumber
	move.l	#2,d1
	bsr	SetPos
	lea	Track,a0
	move.l	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	move.l	#13,d0
	move.l	#2,d1
	bsr	SetPos

	clr.l	d0
	move.b	TrackNo-V(a6),d0
	bsr	bindec
	move.l	#5,d1
	bsr	Print

	clr.l	d7				; Clear d7, if still clear after those 2 tests, nothing to update
	move.b	$bfe001,d0
	cmp.b	oldbfe001-V(a6),d0
	beq	.nobfe001change
	move.b	d0,oldbfe001-V(a6)
	move.b	#1,d7				; just set d7 to something
.nobfe001change:
	move.b	$bfd100,d0
	cmp.b	oldbfd100-V(a6),d0
	beq	.nobfd100change
	move.b	d0,oldbfd100-V(a6)
	move.b	#1,d7
.nobfd100change:
	cmp.b	#0,d7
	beq	.noupdate			; we had no update. skip to print it
	

	move.l	#18,d0				; Show diskside
	move.l	#2,d1
	bsr	SetPos
	lea	Side,a0
	move.l	#3,d1
	bsr	Print
	cmp.b	#0,SideNo-V(a6)
	bne	.Lower
	lea	UPPER,a0
	move.l	#5,d1
	bsr	Print
;	bclr.b	#2,$bfd100

	bra	.SideDone
.Lower:
	lea	LOWER,a0
	move.l	#5,d1
	bsr	Print
;	bset.b	#2,$bfd100

.SideDone:

	move.l	#32,d0				; Show motorstatus
	move.l	#2,d1
	bsr	SetPos
	lea	Motor,a0
	move.l	#3,d1
	bsr	Print
	btst	#7,$bfd100
	beq	.MotorIsOn
	lea	OFF,a0
	move.l	#5,d1
	bsr	Print
	bra	.MotorDone
.MotorIsOn:
	lea	ON,a0
	move.l	#5,d1
	bsr	Print

.MotorDone:


	move.l	#45,d0				; Show writeprotectionstatus
	move.l	#2,d1
	bsr	SetPos
	lea	WProtect,a0
	move.l	#3,d1
	bsr	Print
	btst	#3,$bfe001
	beq	.nowrite
	lea	OFF,a0
	move.l	#2,d1
	bsr	Print
	bra	.writedone
.nowrite:
	lea	ON,a0
	move.l	#1,d1
	bsr	Print
.writedone:
	move.l	#64,d0				; Show disk status
	move.l	#2,d1
	bsr	SetPos
	lea	DiskIN,a0
	move.l	#3,d1
	bsr	Print
	btst	#2,$bfe001
	beq	.nochange
	lea	YES,a0
	move.l	#2,d1
	bsr	Print
	bra	.changedone
.nochange:
	lea	NO,a0
	move.l	#1,d1
	bsr	Print
.changedone:


	move.l	#6,d0				; Show Tracknumber
	move.l	#3,d1
	bsr	SetPos
	lea	RDY,a0
	move.l	#3,d1
	bsr	Print

	btst	#5,$bfe001
	bne	.nordy
	lea	YES,a0
	move.l	#2,d1
	bsr	Print
	bra	.rdydone
.nordy:
	lea	NO,a0
	move.l	#1,d1
	bsr	Print
.rdydone:

	move.l	#18,d0				; Show Tracknumber
	move.l	#3,d1
	bsr	SetPos
	lea	TRACK0,a0
	move.l	#3,d1
	bsr	Print

	btst	#4,$bfe001
	bne	.notrk0
	lea	YES,a0
	move.l	#2,d1
	bsr	Print
	bra	.trk0done
.notrk0:
	lea	NO,a0
	move.l	#1,d1
	bsr	Print

.trk0done:
	move.l	#36,d0
	move.l	#3,d1
	bsr	SetPos
	lea	BFE001Txt,a0
	move.l	#3,d1
	bsr	Print
	move.b	$bfe001,d0
	bsr	binstringbyte
	move.l	#6,d1
	bsr	Print


	move.l	#56,d0
	move.l	#3,d1
	bsr	SetPos
	lea	BFD100Txt,a0
	move.l	#3,d1
	bsr	Print

	move.b	$bfd100,d0
	bsr	binstringbyte
	move.l	#6,d1
	bsr	Print

.noupdate:
	bsr	PrintMenu
	bsr	GetInput
	bsr	WaitLong
	cmp.b	#0,d0
	beq	.no


	move.b	keyresult-V(a6),d1		; Read value from last keyboard read
	cmp.b	#$a,d1				; if it was enter, select this item
	beq	.action
	move.b	Serial-V(a6),d2			; Read value from last serialread
	cmp.b	#$a,d2
	beq	.action
	cmp.b	#1,LMB-V(a6)
	beq	.action

	lea	DriveTestMenuKey,a5		; Load list of keys in menu
	clr.l	d0				; Clear d0, this is selected item in list

.keyloop:
	move.b	(a5)+,d3			; Read item
	cmp.b	#0,d3				; Check if end of list
	beq	.nokey
	cmp.b	d1,d3				; fits with keyboardread?
	beq	.goaction
	cmp.b	d2,d3				; fits with serialread?
	beq	.goaction			; if so..  do it
	add.l	#1,d0				; Add one to d0, selecting next item
	bra	.keyloop
.goaction:
	move.b	d0,MenuPos-V(a6)
	bra	.action

.nokey:	
	cmp.b	#1,RMB
	beq	Exit
	bra	.no

.action:
	bsr	WaitReleased

	clr.l	d0
	move.b	MenuPos-V(a6),d0

	cmp.b	#0,d0				; Check if it is item 0, meaning change drive ID
	beq	.ChangeDrive

	cmp.b	#1,d0
	beq	.Motor

	cmp.b	#2,d0
	beq	.Side

	cmp.b	#3,d0
	beq	.TrackOut

	cmp.b	#4,d0
	beq	.TrackIn

	cmp.b	#5,d0
	beq	.Track10Out

	cmp.b	#6,d0
	beq	.Track10In

	cmp.b	#7,d0
	beq	.ReadTrack

	cmp.b	#8,d0
	beq	.WriteTrack

	cmp.b	#9,d0
	beq	.ShowMem

	cmp.b	#11,d0
	beq	MainMenu


.no:
	bra	.loop

.ChangeDrive:
	move.b	#1,UpdateMenuNumber-V(a6)
	move.b	#2,PrintMenuFlag-V(a6)

	add.w	#1,DriveNo-V(a6)		; Bump up drivenumber with 1
	cmp.w	#4,DriveNo-V(a6)		; if it is too high
	bne	.nowrap
	clr.w	DriveNo-V(a6)			; Reset the counter
.nowrap
	bsr	.SelectDrive
	bsr	.GotoZero
	bra	.no


.Motor:
	bchg	#0,DriveMotor-V(a6)
	cmp.b	#0,DriveMotor-V(a6)
	bne	.SetMotorOn
	bsr	.MotorOff
	bra	.MotorSetDone
.SetMotorOn:
	lea	ON,a0
	move.l	#5,d1
	bsr	Print
	bsr	.MotorOn
.MotorSetDone:
	bra	.no


.Side:
	bchg	#0,SideNo-V(a6)
	bra	.no

.TrackOut:
	add.b	#1,WantedTrackNo-V(a6)
	cmp.b	#84,WantedTrackNo-V(a6)
	beq	.outover
	bra	.no
.outover:
	move.b	#83,WantedTrackNo-V(a6)
	bra	.no


.TrackIn:
	sub.b	#1,WantedTrackNo-V(a6)
	cmp.b	#255,WantedTrackNo-V(a6)
	beq	.outless
	bra	.no
.outless
	move.b	#0,WantedTrackNo-V(a6)
	bra	.no

.Initdisk:
	move.w	#$4489,$dff07e			; Disk sync pattern register for disk read
	move.w	#$7f00,$dff09e			; Audio, Disk, UART Control
	move.w	#$9500,$dff09e			; Check later what it does... MEMPREC, FAST, WORDSYNC set
	clr.w	DriveNo-V(a6)			; Set drivenumber to 0
	bsr	.SelectDrive			; Select the drive
	bsr	.GotoZero			; Step to track 0
	bsr	.UnSelectDrive
	rts
		
.Track10Out:
	add.b	#10,WantedTrackNo-V(a6)
	cmp.b	#83,WantedTrackNo-V(a6)
	bge	.outover
	bra	.no

.Track10In:
	sub.b	#10,WantedTrackNo-V(a6)
	cmp.b	#255,WantedTrackNo-V(a6)
	ble	.outless
	bra	.no

.GotoZero:					; Steps back to track 0
	move.w	#1,DriveOK-V(a6)		; Set Drive as OK
	move.l	#84,d7				; Do this for 85 times (meaning more tracks than on a disk)
.ZeroLoop
	bsr	WaitLong			; Wait for a while

	btst	#4,$bfe001			; Are we at track 0?
	bne	.nozero
	clr.b	TrackNo-V(a6)			; Clear trackno
	clr.b	WantedTrackNo-V(a6)		; Also clear the wanted trackno, or it will just step there.
	rts
.nozero:
	move.w	#$ff,$dff180
	bset.b	#1,$bfd100			; CIAB_DSKDIREC
	bclr.b	#0,$bfd100			; Step
	tst	$dff1fe
	bset	#0,$bfd100
	dbf	d7,.ZeroLoop			; do this until all "tracks" are done, if this loop goes to an end. we have for sure no diskdrive
	clr.w	DriveOK-V(a6)			; Set that drive was NOT ok

	rts

.StepToTrack:					; Check the WantedTrackNo and steps one step to that direction
	clr.l	d0
	move.b	WantedTrackNo-V(a6),d0		; Load D0 with the wanted track
	cmp.b	TrackNo-V(a6),d0
	beq	.AlreadyThere			; ok we are already at wanted position. do nothing
	blt	.GoIn				; Lets step in
	bgt	.GoOut
.AlreadyThere:
	rts

.GoOut:
	bsr	.SelectDrive
	bsr	WaitLong
	bclr.b	#1,$bfd100			; CIAB_DSKDIREC
	bclr.b	#0,$bfd100			; Step
	tst	$dff1fe
	bset	#0,$bfd100
	add.b	#1,TrackNo-V(a6)
	bsr	WaitLong
	bsr	.UnSelectDrive
	rts

.GoIn:
	bsr	.SelectDrive
	bsr	WaitLong
	bset.b	#1,$bfd100			; CIAB_DSKDIREC
	bclr.b	#0,$bfd100			; Step
	tst	$dff1fe
	bset	#0,$bfd100
	sub.b	#1,TrackNo-V(a6)
	bsr	WaitLong
	bsr	.UnSelectDrive
	rts


.MotorOff:
	bsr	.SelectDrive
	or.b	#$78,$bfd100			; Deselect all drives
	bsr	WaitLong
	clr.l	d0
	move.w	DriveNo-V(a6),d0		; load A6 with drive to select
	add.w	#3,d0				; Add 3 to it.  now we know what bit to clear to select drive
	bset.b	#7,$bfd100			; CIAB_DSKMOTOR
	bsr	WaitLong
	bclr.b	d0,$bfd100			; CIAB_DSKSEL0	Select that drive
	bsr	.UnSelectDrive

	rts

.MotorOn:
	bsr	.SelectDrive
	bsr	WaitLong
	clr.l	d0
	move.w	DriveNo-V(a6),d0		; load A6 with drive to select
	add.w	#3,d0				; Add 3 to it.  now we know what bit to clear to select drive
	bclr.b	#7,$bfd100			; CIAB_DSKMOTOR
	bsr	WaitLong
	bclr.b	d0,$bfd100			; CIAB_DSKSEL0	Select that drive
	rts

.SelectDrive:
	bsr	.UnSelectDrive
	clr.l	d0
	move.w	DriveNo-V(a6),d0		; load D0 with drive to select
	add.w	#3,d0				; Add 3 to it.  now we know what bit to clear to select drive

	bclr.b	d0,$bfd100			; Select that drive
	bsr	WaitLong
	rts

.UnSelectDrive:
	or.b	#$78,$bfd100			; Deselect all drives
	bsr	WaitLong
	rts

.ReadTrack:
	bsr	.SelectDrive
	bsr	WaitLong
	bsr	.MotorOn
	bsr	.WaitReady
	bsr	.SelectDrive			; YEAH!  again
	
	move.w	#$4000,$dff024
	move.l	trackbuff-V(a6),$dff020
	move.w	#$4489,$dff07e
	move.w	#$7f00,$dff09e
	move.w	#$9500,$dff09e
	move.w	#2,$dff09c	
	move.w	#$8210,$dff096

	move.w	#$8000+$1900,d1
	move.w	d1,$dff024
	move.w	d1,$dff024

	move.w	#$fff,$dff180
	move.l	#$ffffff,d7
.waittrack:
	move.b	$bfe001,d0			; Nonsenseread, to just make loop slower
	sub.l	#1,d7
	cmp.l	#0,d7
	beq	.timeout
	btst	#1,$dff01f
	beq	.waittrack
.timeout:
	move.w	#$4000,$dff024
	bsr	WaitLong
	bsr	.MotorOff
	bsr	WaitLong
	bsr	.UnSelectDrive
	bra	.no


.WriteTrack:
	bsr	.SelectDrive
	bsr	WaitLong
	bsr	.MotorOn
	bsr	.WaitReady
	bsr	.SelectDrive			; YEAH!  again!

;	move.w	#$4000,$dff024
	move.l	trackbuff-V(a6),$dff020
;	move.w	#$4489,$dff07e
	move.w	#$7f00,$dff09e
	move.w	#$8100,$dff09e
	move.w	#2,$dff09c	
	move.w	#$8210,$dff096

	move.w	#$d978,$dff024
	move.w	#$d978,$dff024

	move.w	#$f00,$dff180
	move.l	#$ffffff,d7
.waittrack2:
	move.b	$bfe001,d0			; Nonsenseread, to just make loop slower
	sub.l	#1,d7
	cmp.l	#0,d7
	beq	.timeout2
	btst	#1,$dff01f
	beq	.waittrack2
.timeout2:
	move.w	#$4000,$dff024
	bsr	.UnSelectDrive
	bra	.no



.WaitReady:
	move.l	#$ffff,d7
.waitrdy:
	move.b	$bfe001,d0
	sub.l	#1,d7
	cmp.l	#0,d7
	beq	.readytimeout
	btst	#5,$bfe001
	beq	.waitrdy
.readytimeout:
	rts
	
.ShowMem:
	clr.l	d3				; Sector to find
.Showmems:
	bsr	ClearScreen

	PUSH

	bsr	.FindSector
	cmp.l	#-1,d0				; Was d0 -1, then we had an error
	beq	.sectorerror

	lea	$38(a1),a1
	clr.l	d6				; Clear rowcounter
	clr.l	d5				; clear "address" of how far into buffer we are

	
.secloop:
	lea	sectorbuff-V(a6),a2
	bsr	.decodebuffer
	PUSH
	move.l	d6,d0
	lea	sectorbuff-V(a6),a0
	bsr	.Showdata
	POP
	add.l	#$10,d5
	add.l	#1,d6
	cmp.l	#20,d6
	bne	.secloop	
	POP

	lea	AnyKeyMouseTxt,a0
	move.l	#4,d1
	bsr	Print
.exloop:
	bsr	GetInput
	cmp.b	#0,BUTTON-V(a6)
	beq	.exloop


	cmp.b	#1,RMB-V(a6)

; 	bne.w	.Showmems
	
	bra	.DiskdriveTester



.exit:
	bra	MainMenu

.decodebuffer:					; Decodes a small part of the MFM buffer to be able to print it.
	move.l	#$55555555,d7
	move.l	#3,d4
.decode:
	move.l	$200(a1),d1
	move.l	(a1)+,d0
	and.l	d7,d0
	asl.l	#1,d0
	and.l	d7,d1
	or.l	d1,d0
	move.l	d0,(a2)+			; Store it in the small buffer

	dbra	d4,.decode
	rts

.sectorerror
	bsr	ClearScreen
	lea	SectorErrorTxt,a0
	move.l	#1,d1
	bsr	Print
	lea	AnyKeyMouseTxt,a0
	move.l	#4,d1
	bsr	Print
	bsr	WaitButton
	bra	.DiskdriveTester


.FindSector
	move.l	trackbuff-V(a6),a0		; A0 now contains pointer to where the MFM data is
	move.l	a0,a1
	move.w	#$4489,d5			; Syncword
	move.l	#$55555555,d7

	clr.l	d3
;	move.b	sector-V(a6),d3			; Load d3 with the wanted sector
	move.l	a0,d6
	add.l	#12980,d6			; D6 now contains the last address of trackbuffer
.getsync:
	cmp.l	a1,d6
	blt	.overflow			; ok we went too far
	cmp.w	(a1)+,d5
	bne.s	.getsync
;	cmp.w	(a1),d5				; Another syncword?
;	beq.s	.getsync
	

;	add.l	#6,a1
	move.l	(a1),d0
	move.l	4(a1),d1

	and.l	d7,d0
	asl.l	#1,d0
	and.l	d7,d1
	or.l	d1,d0
	ror.l	#8,d0

	PUSH
	bsr	binhex
	move.l	#3,d1
	bsr	Print
	clr.l	d0
	move.b	#" ",d0
	bsr	PrintChar

	move.l	a1,d0
	bsr	binhex
	move.l	#5,d1
	bsr	Print
	clr.l	d0
	move.b	#" ",d0
	bsr	PrintChar


	POP

;	cmp.b	d3,d0				; Are we on correct sector?
;	beq	.sectorOK			; Yes
	move.b	d0,sector-V(a6)

.sectorOK:	
	clr.l	d0
	rts

.overflow:
	move.l	#-1,d0				; Set d0 to -1 to show that we had an error.
	rts


.Showdata:
	PUSH
	move.l	a0,a1				; store a0 in a1 for usage here.. as a0 is used
	add.l	#3,d0				; Add 3 to line to work on.
	move.l	d0,d1				; copy d0 to d1 to use it as Y adress
	clr.l	d0				; clear X pos
	bsr	SetPos				; Set position
	
	move.l	d5,d0
	bsr	binhex
	move.l	#6,d1
	bsr	Print				; Print address

	clr.l	d2				; Column to print
	move.l	#15,d7
.showloop:
	lea	SpaceTxt,a0
	bsr	Print
	clr.l	d0				; Clear d0 just to be sure
	move.b	(a1,d2),d0
	bsr	binhexbyte			; Convert that byte to hex
	move.l	#7,d1
	bsr	Print				; Print it
	add.l	#1,d2
	dbf	d7,.showloop
	lea	ColonTxt,a0			; Print a Colon
	move.l	#3,d1
	bsr	Print

	move.l	#15,d7				; Now print the same bytes.  as chars instead	
	clr.l	d2
.showloop2:
	clr.l	d0
	move.b	(a1,d2),d0
	bsr	MakePrintable			; make the char printable.  strip controlstuff..
	add.l	#1,d2
	move.l	#7,d1
	bsr	PrintChar
	dbf	d7,.showloop2
	POP
	rts

	
PrintYes:
	lea	YES,a0
	move.l	#2,d1
	bsr	Print
	rts
PrintNo:
	lea	NO,a0
	move.l	#1,d1
	bsr	Print
	rts
; =============== S U B	R O U T	I N E =======================================

DumbConfigBoard:
		move.l	#-1,d0
		moveq	#$FFFFFF00+ERT_TYPEMASK,d1
		and.b	er_Type(a0),d1
		cmp.b	#ERT_ZORROII,d1
		bne.s	.ConfigBoard_Z3

	;;  pass the type byte
		move.b	er_Type(a0),d0
		bra	.ConfigBoard_Z2_RAM
	
.ConfigBoard_Z3:	
		moveq	#ec_Shutup+ExpansionRom_SIZEOF,d0
		bsr	WriteExpansionByte

		move.l	#-1,d0
        rts

.ConfigBoard_Z2_RAM:

		btst	#5,d0
		beq	.ConfigBoard_NonRAM

;;;  hack to put a Z2 memory card at address 0x200000
		move.l	#$20,d1
		moveq	#ec_BaseAddress+ExpansionRom_SIZEOF,d0
		bsr	WriteExpansionByte

.ConfigBoard_Done:
		move.l	#0,d0
        rts

.ConfigBoard_NonRAM:
		move.l	#$E9,d1
		moveq	#ec_BaseAddress+ExpansionRom_SIZEOF,d0
		bsr	WriteExpansionByte

		move.l	#2,d0
        rts
	
.ConfigBoard_Shutup:
		moveq	#ec_Shutup+ExpansionRom_SIZEOF,d0 
		bsr	WriteExpansionByte

		move.l	#-2,d0
		rts


; =============== S U B	R O U T	I N E =======================================

IDECheckStatus:
		SPRINT	aIDEInterruptIntStatusReading
		move.b	$0DA8000,d0
		SPRINTHEX
		SPRINT aCrLf
		rts

IDECheckChanged:
		SPRINT	aIDEChange
		move.w	$0DA9000,d0
		PRINTHEX16
		SPRINT 	aCrLf

		rts
	
IDECommand:	move.b	d0,$0DA001C
		rts

IDEReadData:
		SPRINT	aIDERead
		SPRINT	aCrLf
		move.l	#0,d3
		move.l	#0,d4
.loop
		move.w	AT_Data(a2),d0
		
		SPRINTHEX16
		SCHAROUT 32
		
		addq.l 	#1,d3
		addq.l 	#1,d4
		cmp	#8,d4
		ble	.loop
		SPRINT	aCrLf
	
		moveq.l	#0,d4
		cmp	#256,d3
		ble	.loop
	
		rts

IDEWaitRDY:
		move.w	#10,d2
		move.w	d0,$800
.loop
		move.w	$800,d2
		sub.w	#1,d2
		move.w	d2,$800

		SPRINT	aIDERDY
		move.b	$0DA001C,d0
		and.b	#$C1,d0
		move.b	d0,d4
		PRINTHEX
		CHAROUT 32
		CHAROUT 40
		move.w	$0DA001C,d0
		PRINTHEX16
		CHAROUT 41
		SPRINT 	aCrLf

		move.w	$800,d2
		cmp.w	#0,d2
		beq	.exit
	
		cmp.b	#$40,d4
		bne	.loop
.exit	
		rts

IDEWaitDRQ:
		SPRINT	aIDEDRQ
		move.b	$0DA001C,d0
		and.b	#$C9,d0
		move.b	d0,d4
		PRINTHEX
		CHAROUT 32
		CHAROUT 40
		move.w	$0DA001C,d0
		PRINTHEX16
		CHAROUT 41
		SPRINT 	aCrLf
		cmp.b	#$48,d4
		bne	IDEWaitDRQ
		rts


; =============== S U B	R O U T	I N E =======================================; 
get_gid_bit:			; read a gary / gayle bit
		move.b	(a1),d0
		lsl.b	#1,d0
		roxl.b	#1,d1
		rts


; =============== S U B	R O U T	I N E =======================================; 	
charout:
		move.w	#$4000,($DFF09A).l
		move.w	#$175,($DFF032).l
		move.b	#$4F,($BFD000).l
		move.w	#$801,($DFF09A).l
		move.w	#$801,($DFF09C).l
		clr.l	d7

		move.l	#$3710,d2
.wait
		move.b	($BFE001).l,d7
		subi.l	#1,d2
		cmpi.l	#0,d2
		beq.w	.done
		move.w	($DFF018).l,d7
		btst	#$D,d7
		beq.s	.wait

.done
		move.w	#$100,d7
		move.b	d1,d7
		move.w	d7,($DFF030).l
		move.w	#1,($DFF09C).l

		jmp	(a1)

; =============== S U B	R O U T	I N E =======================================


PrintRom: ; a0 = card, a2 = dest
		move.l	a0,a3
		SCHAROUT 32
		SCHAROUT 48
	        SCHAROUT 120
		
		clr.l	d0
		bsr	ReadExpansionByte
		
		SPRINTHEX
	;; all the other bytes are inverted
		moveq.l	#1,d2

.readrom_loop:
	
		SCHAROUT 32
		SCHAROUT 48
	        SCHAROUT 120

		move.l	d2,d0
		move.l	a3,a0
		
		bsr	ReadExpansionByte
		not.b	d0
		
		SPRINTHEX

		addq.w	#1,d2
		cmp.w	#ExpansionRom_SIZEOF,d2
		bls	.readrom_loop

		rts

	
ReadRom: ; a0 = card, a2 = dest
		move.l	a0,a3
	
		clr.l	d0
		bsr	ReadExpansionByte
		move.b	d0,(a2)+

	;; all the other bytes are inverted
		moveq.l	#1,d2

readrom_loop:
		move.l	d2,d0
		move.l	a3,a0

		bsr	ReadExpansionByte
		not.b	d0
		move.b	d0,(a2)+

		addq.w	#1,d2
		cmp.w	#ExpansionRom_SIZEOF,d2
		bls.s	readrom_loop

		rts

WriteExpansionByte:
		lsl.w	#2,d0		
		lea.l	0(a0,d0.w),a0

		move.b	d1,d0		
		lsl.b	#4,d0		

		cmpa.l	#EZ3_EXPANSIONBASE,a0
		bhs.s	.zorroIII
		move.b	d0,$002(a0)
		bra.s	.doWrite
.zorroIII:	move.b	d0,$100(a0)	
.doWrite:
		move.b	d1,(a0)

		clr.l	d0
		rts


ReadExpansionByte:	
		lsl.w	#2,d0	
		lea.l	0(a0,d0.w),a0

		move.l	a0,d1	
		bmi.s	.zorroIII ; check for zorro ii 
		move.b	$002(a0),d1
		bra.s	.doRead
.zorroIII:	move.b	$100(a0),d1 ; check for zorro 3
.doRead:	lsr.b	#4,d1

		moveq.l #0,d0
		move.b	(a0),d0
		and.b	#$f0,d0
		or.b	d1,d0
		
		rts


;------------------------------------------------------------------------------------------

DevPrint:
	clr.l	d0
	move.l	#25,d1
	bsr	SetPos
	lea	UnderDevTxt,a0
	move.l	#1,d1
	bsr	Print
	clr.l	d0
	clr.l	d1
	bsr	SetPos
	rts


NotImplemented:
	bsr	ClearScreen
	lea	NotImplTxt,a0
	move.l	#1,d1
	bsr	Print

	lea	AnyKeyMouseTxt,a0
	move.l	#2,d1
	bsr	Print
	
	bsr	DebugScreen
	bsr	WaitButton
	bra	MainMenu


Not1K:
	bsr	ClearScreen
	lea	NotA1kTxt,a0
	move.l	#1,d1
	bsr	Print
	bsr	WaitButton
	bra	MainMenu


DebugScreen:					; This dumps out registers..
	move.l	d0,DebD0-V(a6)			; first store everything in registers
	move.l	d1,DebD1-V(a6)			; and for visability etc.. I do several move instead of movem. dunno why :)
	move.l	d2,DebD2-V(a6)
	move.l	d3,DebD3-V(a6)
	move.l	d4,DebD4-V(a6)
	move.l	d5,DebD5-V(a6)
	move.l	d6,DebD6-V(a6)
	move.l	d7,DebD7-V(a6)
	move.l	a0,DebA0-V(a6)
	move.l	a1,DebA1-V(a6)
	move.l	a2,DebA2-V(a6)
	move.l	a3,DebA3-V(a6)
	move.l	a4,DebA4-V(a6)
	move.l	a5,DebA5-V(a6)
	move.l	a6,DebA6-V(a6)
	move.l	a7,DebA7-V(a6)			; OK now everything is stored.

	PUSH

	clr.l	d0
	move.l	#2,d1
	bsr	SetPos
	lea	DebugTxt,a0
	move.l	#3,d1
	bsr	Print

	clr.l	d0
	move.l	#3,d1
	bsr	SetPos
	move.l	DebD0-V(a6),d0
	bsr	binhex
	move.l	#2,d1
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD1-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD2-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD3-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD4-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD5-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD6-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebD7-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA0-V(a6),d0
	bsr	binhex
	move.l	#3,d1
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA1-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA2-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA3-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA4-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA5-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA6-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	move.l	DebA7-V(a6),d0
	bsr	binhex
	bsr	Print
	lea	SPACE,a0
	bsr	Print
	clr.l	d0


	clr.l	d7
	lea	$64,a5				; Level1 pointer

.irqloop:
	add.b	#1,d7
	cmp.b	#8,d7
	beq	.endloop

	lea	NewLineTxt,a0
	bsr	Print
	lea	DebugIRQ,a0
	move.l	#3,d1
	bsr	Print

	move.l	d7,d0
	bsr	bindec
	move.l	#3,d1
	bsr	Print

	lea	DebugIRQPoint,a0
	bsr	Print

	move.l	(a5),d0				; Get where IRQ points to
	move.l	d0,a4				; Store a copy of it in A4, to be able to print content
	bsr	binhex
	bsr	Print

	lea	DebugContent,a0
	bsr	Print

	move.l	#15,d6
	clr.l	d5
.contentloop:
	clr.l	d0
	move.b	(a4)+,d0
	bsr	binhexbyte
	bsr	Print
	add.b	#1,d5
	cmp.b	#4,d5				; 4th byte?
	bne	.not4
	move.b	#" ",d0
	bsr	PrintChar
	clr.l	d5
.not4:
	dbf	d6,.contentloop
	add.l	#4,a5
	bra	.irqloop
	
.endloop:

	lea	NewLineTxt,a0
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	lea	DebugROM,a0
	bsr	Print

	cmp.w	#$1114,$0
	bne	.no1114at0
	lea	YES,a0
	move.l	#1,d1
	bsr	Print
	bra	.yes1114at0

.no1114at0:
	lea	NO,a0
	move.l	#2,d1
	bsr	Print
.yes1114at0

	lea	NewLineTxt,a0
	bsr	Print
	lea	DebugROM2,a0
	move.l	#3,d1
	bsr	Print

	cmp.w	#$1114,$f80000
	bne	.no1114atf8
	lea	YES,a0
	move.l	#2,d1
	bsr	Print
	bra	.yes1114atf8

.no1114atf8:
	lea	NO,a0
	move.l	#1,d1
	bsr	Print
.yes1114atf8:

;	move.w	SR,d0
;	bsr	binhexword
;	bsr	Print
;	lea	SPACE,a0
;	bsr	Print
;	clr.l	d0
;	move.w	CCR,d0
;	bsr	binhexword
;	bsr	Print
	POP
	rts


DebugSerial:					; This dumps out registers..
	PUSH
	move.l	d0,DebD0-V(a6)			; first store everything in registers
	move.l	d1,DebD1-V(a6)			; and for visability etc.. I do several move instead of movem. dunno why :)
	move.l	d2,DebD2-V(a6)
	move.l	d3,DebD3-V(a6)
	move.l	d4,DebD4-V(a6)
	move.l	d5,DebD5-V(a6)
	move.l	d6,DebD6-V(a6)
	move.l	d7,DebD7-V(a6)
	move.l	a0,DebA0-V(a6)
	move.l	a1,DebA1-V(a6)
	move.l	a2,DebA2-V(a6)
	move.l	a3,DebA3-V(a6)
	move.l	a4,DebA4-V(a6)
	move.l	a5,DebA5-V(a6)
	move.l	a6,DebA6-V(a6)
	move.l	a7,DebA7-V(a6)			; OK now everything is stored.

	lea	DebugTxt,a0
	bsr	ForceSer

	lea	NewLineTxt,a0
	bsr	ForceSer
	lea	NewLineTxt,a0
	bsr	ForceSer
	move.l	DebD0-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD1-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD2-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD3-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD4-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD5-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD6-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebD7-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	NewLineTxt,a0
	bsr	ForceSer
	move.l	DebA0-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA1-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA2-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA3-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA4-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA5-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA6-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	SPACE,a0
	bsr	ForceSer
	move.l	DebA7-V(a6),d0
	bsr	binhex
	bsr	ForceSer
	lea	NewLineTxt,a0
	
	POP
	rts



ForceSer:					; For debug. print stuff on serialport. if port disabled force 9600BPS


						; Indata a0=string to send to serialport
						; nullterminated

	cmp.w	#0,SerialSpeed-V(a6)
	beq	.noserial
	cmp.w	#5,SerialSpeed-V(a6)
	beq	.noserial
.serial:

	PUSH
	clr.l	d0				; Clear d0
.loop:
	move.b	(a0)+,d0
	cmp.b	#0,d0				; end of string?
	beq	.nomore				; yes
	bsr	.out

	bra.s	.loop
.nomore:
	POP
	rts


.out:						; Send what is in d0 to serialport
	PUSH
	move.l	#10000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
.timeoutloop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d2				; count down timeout value
	cmp.l	#0,d2				; if 0, timeout.
	beq	.endloop
	move.w	$dff018,d1
	btst	#13,d1				; Check TBE bit
	beq.s	.timeoutloop
.endloop:
	move.w	#$0100,d1
	move.b	d0,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit
	POP
	rts
.noserial:
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c
	bra	.serial
	


DumpHexByte:				; PRE MEM-CODE!  dumps content of BYTE in d1 to serialport-
					; INDATA:
					;	D1 = byte to print
					;	A2 = address to jump after done

	lea	bytehextxt,a0
	clr.l	d2
	move.b	d1,d2
	asl	#1,d2
	add.l	d2,a0
	lea	.char1,a1
	jmp	DumpSerialChar
.char1:
	lea	.char2,a1
	jmp	DumpSerialChar
.char2:
	jmp	(a2)


DumpHexLong:
					; Same as DumpHexByte but longword.
					; A3 is jumppointer for exit
	move.l	d1,d6
	swap	d1
	asr.l	#8,d1
	lea	.byte1,a2
	bra	DumpHexByte
.byte1:
	move.l	d6,d1
	swap	d1
	lea	.byte2,a2
	bra	DumpHexByte
.byte2:
	move.l	d6,d1
	asr	#8,d1
	lea	.byte3,a2
	bra	DumpHexByte		
.byte3:
	move.l	d6,d1
	lea	.byte4,a2
	bra	DumpHexByte
.byte4:
	jmp	(a3)


DumpClearSerial:				; Just read serialport, to empty it, this is pre-memory, so no return.
						; a0 contains jumpaddress where to go after exiting
	move.l	#1,d6				; load d6 with 1, so we run this, twice to be sure serialbuffer is cleared
.loop:
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	move.l	#10000,d7
.timeoutloop2
	move.b	$bfe001,d0			;nonsenseread
	cmp.l	#0,d7
	beq	.exitloop
	sub.l	#1,d7
	move.w	$dff018,d0
	btst	#14,d0				; Buffer full, we have a new char
	beq	.timeoutloop2
.exitloop:
	dbf	d6,.loop
	jmp	(a0)				; Jump to a0



DumpSerial:				; This is only for PRE-Memory usage. Dumps a string to serialport.
					; IN:
					; a0 = String to put out on serial port.
					; a1 = where to jump after code is run. Remember we have NO stack
					; meaning that there is no place to store returnadresses for bsr/jsr


	move.l	a4,d7				; Copy the value in A4 (temporary data of mousebutttons pressed) to d7
	btst	#1,d7				; check if LMB on Joyport 1 was pressed. if so. skip serial output.
	bne	.nomore				; it was pressed. skip all this
	btst	#4,d7				; Check if we had loopback installed
	bne	.nomore
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	clr.l	d7				; Clear d0
.loop:
	move.b	(a0)+,d7
	cmp.b	#0,d7				; end of string?
	beq	.nomore				; yes

	move.l	#40000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
.timeoutloop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d2				; count down timeout value
	cmp.l	#0,d2				; if 0, timeout.
	beq	.endloop
	move.w	$dff018,d1
	btst	#13,d1				; Check TBE bit
	beq.s	.timeoutloop
.endloop:
	move.w	#$0100,d1
	move.b	d7,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit

	bra.s	.loop
.nomore:
	jmp	(a1)				; AS we cannot use RTS (and bsr/jsr) jump here after we are done.


DumpSerialChar:				; This is only for PRE-Memory usage. Dumps a string to serialport.
					; IN:
					; a0 = pointer to char to print
					; a1 = where to jump after code is run. Remember we have NO stack
					; meaning that there is no place to store returnadresses for bsr/jsr

	move.l	a4,d7				; Copy the value in A4 (temporary data of mousebutttons pressed) to d7
	btst	#1,d7				; check if LMB on Joyport 1 was pressed. if so. skip serial output.
	bne	.nomore				; it was pressed. skip all this
	btst	#4,d7				; Check if we had loopback installed
	bne	.nomore

	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	clr.l	d7				; Clear d0
	move.b	(a0)+,d7
	move.l	#10000,d2			; Load d2 with a timeoutvariable. only test this number of times.
						; IF CIA for serialport is dead we will not end up in a wait-forever-loop.
						; and as we cannot use timers. we have to do this dirty style of coding...
.timeoutloop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d2				; count down timeout value
	cmp.l	#0,d2				; if 0, timeout.
	beq	.endloop
	move.w	$dff018,d1
	btst	#13,d1				; Check TBE bit
	beq.s	.timeoutloop
.endloop:
	move.w	#$0100,d1
	move.b	d7,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit
.nomore:
	jmp	(a1)				; AS we cannot use RTS (and bsr/jsr) jump here after we are done.


Loopbacktest:					; Test if we have a loopbackadapter connected.
						; Simply by outputing the char in D2 and check if the same char comes back.
						; if so, 1 is added to D6
	move.w	#$4000,$dff09a
	move.w	#373,$dff032			; Set the speed of the serialport (9600BPS)
	move.b	#$4f,$bfd000			; Set DTR high
	move.w	#$0801,$dff09a
	move.w	#$0801,$dff09c

	move.l	#10000,d7			; Load d7 with a timeoutvariable
.timeoutloop:	
	move.b	$bfe001,d1			; just read crapdata, we do not care but reading from CIA is slow... for timeout stuff only
	sub.l	#1,d7				; count down timeout value
	cmp.l	#0,d7				; if 0, timeout.
	beq	.endloop
	move.w	$dff018,d0
	btst	#13,d0				; Check TBE bit
	beq.s	.timeoutloop			; Loop until all is ok to send or until timeout hits
.endloop:

	move.w	#$0100,d1
	move.b	d2,d1
	move.w	d1,$dff030			; send it to serial
	move.w	#$0001,$dff09c			; turn off the TBE bit


	move.l	#10000,d7

.timeoutloop2
	move.b	$bfe001,d0			; Nonsenseread
	cmp.l	#0,d7
	beq	.exitloop
	sub.l	#1,d7
	move.w	$dff018,d0
	btst	#14,d0				; Buffer full, we have a new char
	beq	.timeoutloop2
	bra	.check
.exitloop:
	clr.l	d0
.check:
	cmp.b	d0,d2				; Check if in and out was the same char
	bne.s	.exit				; no so lets exit
	add.b	#1,d6				; Yes, set d6 to 1
.exit:
	jmp	(a0)


InputHexNum:					; Inputs a 32 bit hexnumber
						; INDATA
						;	A0 = Defualtaddress
	PUSH
	move.b	Xpos-V(a6),CheckMemManualX-V(a6)
	move.b	Ypos-V(a6),CheckMemManualY-V(a6); Store X and Y positions

	move.l	a0,d0				; Store the defaultaddress in d0
	bsr	binhex				; Convert it to hex
	add.l	#1,a0				; Skip first $ sign in string
	move.l	#8,d0
	lea	CheckMemStartAdrTxt-V(a6),a1	; Clear workspace
.clearloop:
	clr.b	(a1,d0)
	dbf	d0,.clearloop
	move.l	#7,d0
	
	clr.l	d7				; Clear d7, if this is 0 later we had not had any 0 yet
.hexloop:
	move.b	(a0)+,d1			; Store char in d1
	cmp.b	#"0",d1				; is it a 0?
	bne	.nozero
	cmp.b	#0,d7				; Check if d7 is 0. if so, we will skip this
	beq	.zero
.nozero:
	move.b	d1,(a1)+			; Copy to where a1 points to
	move.b	#1,d7				; We had a nonzero.  set d7 to 1 so we handle 0 in the future
.zero:
	dbf	d0,.hexloop			; Copy string to defaultadress to be shown

	lea	CheckMemStartAdrTxt-V(a6),a5	; Store pointer to string at a5
	move.l	a5,a0

	move.l	#7,d1
	bsr	Print				; Print it
	bsr	StrLen				; Get Stringlength
	move.l	d0,d6


	clr.l	d7				; Clear d7, this is the current position of the string
	sub.b	#1,d7				; Change d7 so we will force a update of cursor first time
.loop:
	bsr	GetMouse
	cmp.b	#1,RMB-V(a6)
	beq	.exit
	cmp.b	#1,LMB-V(a6)
	beq	.exit
	bsr	WaitShort
	bsr	GetChar				; Get a char from keyboard/serial
	bsr	WaitLong
	cmp.b	#"x",d0				; did user press X?
	beq	.xpressed

	cmp.b	#$7f,d0				; did we have backspace from serial?
	beq	.backspace


.gethex:
	bsr	GetHex				; Strip it to hexnumbers
	cmp.b	#0,d0				; if returned value is 0, we had no keypress
	beq	.no
	cmp.b	#$1b,d0				; Was ESC pressed?
	beq	.exit				; if so, Exit
	cmp.b	#$a,d0				; did user press enter?
	beq	.enter				; if so, we are done


	cmp.b	#$8,d0				; Did we have a backspace?
	bne	.nobackspace			; no
						; oh. we had. lets erase one char
.backspace:
	move.b	#$0,(a5,d6)			; Store a null at that position
	cmp.b	#0,d6				; check if we are at the back?
	beq	.backmax			; yes, do not remove
	move.b	#" ",d0
	sub.b	#1,d6				; Subtract one
	move.b	d0,(a5,d6)			; Put char in memory
	bra	.back
.nobackspace:
	cmp.b	#8,d6				; Check if we have max number of chars
	beq	.nomore
	move.b	d0,(a5,d6)			; Put char in memory
	add.b	#1,d6

.back:
	move.l	#7,d1
	bsr	PrintChar			; Print the char
.backmax:
.nomore:

.no:	cmp.b	d6,d7				; Check if d6 and d7 is same, if not, update cursor
	beq	.same
	move.b	d6,d7
	bsr	.putcursor			; Put cursor
.same:
	bra	.loop

.exit:
	POP
	move.l	#-1,d0				; Show we had an exit
	rts


.xpressed:					; X is pressed, lets clear the whole area.
	clr.l	d6

	move.l	#7,d0
.xloop:
	move.b	#" ",(a5,d0)
	dbf	d0,.xloop
	clr.l	d7
	bsr	.putcursor
	lea	space8,a0
	move.l	#7,d1
	bsr	Print
	clr.l	d7
	bsr	.putcursor
	clr.l	d6
	clr.l	d0
	bra.w	.gethex

.enter:
	cmp.b	#0,d6				; was cursor at 0? then we had nothing
	beq	.exit
	bsr	.putcursor
	move.l	#" ",d0
	bsr	PrintChar			; Print a space to remove the old cursor

	clr.l	d6				; Clear d6, we need to check how many numbers we have

.countloop:
	move.b	(a5,d6),d0			; load char in string
	cmp.b	#0,d0				; is it a null?
	beq	.null
	cmp.b	#" ",d0				; same with space
	beq	.null
	add.b	#1,d6				; nope, so lets add 1 to the counter
	cmp.b	#8,d6				; Check if we actually DID have 8 chars, then no rotate of data is needed
	beq	.norotate
	bra	.countloop			; do it all over again

.null:						; ok we had a null, before doing 8 chars.
						; We had less then 8 chars, meaning we need to trimp it to 8 chars.
	move.l	d6,d7
	sub.b	#1,d7
	move.l	#7,d0
.copyloop2:
	move.b	(a5,d7),(a5,d0)
	sub.b	#1,d0
	dbf	d7,.copyloop2
						; ok now we have moved the data to the end of the string, lets fill up with 0
	move.l	#8,d0
	sub.b	d6,d0				; d0 now contains of how many 0 to put in
	sub.b	#1,d0
.fill:
	move.b	#"0",(a5,d0)
	dbf	d0,.fill
.norotate:
	move.b	CheckMemManualX-V(a6),d0
	move.b	CheckMemManualY-V(a6),d1
	sub.l	#1,d0				; Set cursor to the first adress, minus pone

	bsr	SetPos
	lea	CheckMemStartAdrTxt-V(a6),a0
	bsr	hexbin
	POP
	move.l	HexBinBin-V(a6),d0		; return the value
	rts

.putcursor:
	PUSH
	move.b	CheckMemManualX-V(a6),d0
	add.b	d7,d0				; Add postion to X pos to get correct position
	move.b	CheckMemManualY-V(a6),d1
	bsr	SetPos
	clr.l	d0
	move.b	(a5,d7),d0			; Load current char from string
	move.l	#11,d1
	bsr	PrintChar			; Print it reversed
	move.b	CheckMemManualX-V(a6),d0
	add.b	d7,d0				; Add postion to X pos to get correct position
	move.b	CheckMemManualY-V(a6),d1
	bsr	SetPos
	POP
	rts	



WaitShort:					; Wait a short time, aprox 10 rasterlines. (or exact IF we have detected working raster)
	PUSH
	cmp.b	#1,RASTER-V(a6)			; Check if we have a confirmed working raster
	beq	.raster
	move.l	#$1000,d0			; if now.  lets try to wait some anyway.
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case
.loop:
	move.b	$bfe001,d1			; Dummyread from slow memory
	move.b	$dff006,d1
	dbf	d0,.loop
	POP
	rts
.raster:
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case
	move.b	$dff006,d0			; Get what rasterline we are at now
	add.b	#10,d0				; Add 10
.rasterloop:
	cmp.b	$dff006,d0
	bne.s	 .rasterloop
	POP
	rts


WaitLong:					; Wait a short time, aprox 10 rasterlines. (or exact IF we have detected working raster)
	PUSH
	cmp.b	#1,RASTER-V(a6)			; Check if we have a confirmed working raster
	beq	.raster
	move.w	#3,d1
	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case
.loop2
	move.l	#$ffff,d0			; if now.  lets try to wait some anyway.
.loop:
	move.b	$bfe001,d2			; Dummyread from slow memory
	move.b	$dff006,d2
	dbf	d0,.loop
	dbf	d1,.loop2
	POP
	rts

.raster:
	cmp.b	#$90,$dff006
	bne.s	.raster				; Wait for rasterline $90

	bsr	ReadSerial			; as we have no IRQs..  read serialport just in case

.rasterloop:
	cmp.b	#$8f,$dff006
	bne.s	 .rasterloop			; Wait for rasterline $8f, meaning we have waited for one frame
	POP
	rts


DefaultVars:					; Set defualtvalues
	move.l	a6,d0
	add.l	#EndData-V,d0
	move.l	d0,CheckMemEditScreenAdr-V(a6)
	rts

GetHWReg:					; Dumps all readable HW registers to memory
	move.w	$dff000,BLTDDAT-V(a6)
	move.w	$dff002,DMACONR-V(a6)
	move.w	$dff004,VPOSR-V(a6)
	move.w	$dff006,VHPOSR-V(a6)
	move.w	$dff008,DSKDATR-V(a6)
	move.w	$dff00a,JOY0DAT-V(a6)
	move.w	$dff00c,JOY1DAT-V(a6)
	move.w	$dff00e,CLXDAT-V(a6)
	move.w	$dff010,ADKCONR-V(a6)
	move.w	$dff012,POT0DAT-V(a6)
	move.w	$dff014,POT1DAT-V(a6)
	move.w	$dff016,POTINP-V(a6)
	move.w	$dff018,SERDATR-V(a6)
	move.w	$dff01a,DSKBYTR-V(a6)
	move.w	$dff01c,INTENAR-V(a6)
	move.w	$dff01e,INTREQR-V(a6)
	move.w	$dff07c,DENISEID-V(a6)
	move.w	$dff1da,HHPOSR-V(a6)
	rts

PrintHWReg:
	lea	BLTDDATTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	BLTDDAT-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	DMACONRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	DMACONR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	VPOSRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	VPOSR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	lea	VHPOSRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	VHPOSR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	DSKDATRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	DSKDATR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	JOY0DATTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	JOY0DAT-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	lea	POT0DATTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	POT0DAT-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	POT1DATTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	POT1DAT-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	POTINPTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	POTINP-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	lea	SERDATRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	SERDATR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	DSKBYTRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	DSKBYTR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	INTENARTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	INTENAR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print
	lea	INTREQRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	INTREQR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	DENISEIDTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	DENISEID-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	Space3,a0
	bsr	Print
	lea	HHPOSRTxt,a0
	move.w	#7,d1
	bsr	Print
	move.w	HHPOSR-V(a6),d0
	bsr	binhexword
	move.w	#3,d1
	bsr	Print
	lea	NewLineTxt,a0
	bsr	Print

	rts


RTEcode:					; Just to have something to point IRQ to.. doing nothing
	move.w	#$444,$dff180
	rte

GetChip:					; Gets extra chipmem below the reserved workarea.
						; IN = D0=Size requested
						; OUT = D0=Startaddress of chipmem.  1=not enough, 0=no chipmem
	PUSH


	clr.l	GetChipAddr-V(a6)		; Clear the address replied.
	cmp.l	#0,TotalChip-V(a6)		; if there are no chipmem, exit
	beq	.exit	

	move.l	ChipUnreserved-V(a6),d1		; Get total amount of nonused chipmem
	cmp.l	d0,d1				; Compare it with amount of mem wanted
	blt	.low				; we did not have enough. exit

	move.l	ChipUnreservedAddr-V(a6),d1	; ok load d1 with value of last usable noreserved chipmemarea
	sub.l	d0,d1				; Subtract with amount of memory wanted
	move.l	d1,GetChipAddr-V(a6)		; Store it to returnvalue

	move.l	d1,a0				; Now lets clear the ram
	asr.l	#2,d0
.loop:
	clr.l	(a0)+
	dbf	d0,.loop	



	bra	.exit

.low:
	move.l	#1,GetChipAddr-V(a6)		; put 1 into returnvalue, telling we did not have enough mem.
.exit:
	POP
	move.l	GetChipAddr-V(a6),d0		; Return the value
	rts

FilterOFF:
	bset	#1,$bfe001
	rts
FilterON:
	bclr	#1,$bfe001
	rts



	;	This is the protrackerreplayer, to be copied to chipmem due to the fact it would require too mucg
	; 	of reprogramming to make it work in ROM. <-  YUPP!  being a lazy fuck



* ProTracker2.2a replay routine by Crayon/Noxious. Improved and modified
* by Teeme of Fist! Unlimited in 1992. Share and enjoy! :)
* Rewritten for Devpac (slightly..) by CJ. Devpac does not like bsr.L
* cmpi is compare immediate, it requires immediate data! And some
* labels had upper/lower case wrong...
*
* Now improved to make it work better if CIA timed - thanks Marco!

* Call MT_Init with A0 pointing to your module data...
* mastervolumepatch by Chucky of The Gang
* mt_mastervol is a byte  0 to 64 containing the mastervolume


N_Note = 0  ; W
N_Cmd = 2  ; W
N_Cmdlo = 3  ; B
N_Start = 4  ; L
N_Length = 8  ; W
N_LoopStart = 10 ; L
N_Replen = 14 ; W
N_Period = 16 ; W
N_FineTune = 18 ; B
N_Volume = 19 ; B
N_DMABit = 20 ; W
N_TonePortDirec = 22 ; B
N_TonePortSpeed = 23 ; B
N_WantedPeriod = 24 ; W
N_VibratoCmd = 26 ; B
N_VibratoPos = 27 ; B
N_TremoloCmd = 28 ; B
N_TremoloPos = 29 ; B
N_WaveControl = 30 ; B
N_GlissFunk = 31 ; B
N_SampleOffset = 32 ; B
N_PattPos = 33 ; B
N_LoopCount = 34 ; B
N_FunkOffset = 35 ; B
N_WaveStart = 36 ; L
N_RealLength = 40 ; W
MT_SizeOf = 42*4+22
MT_SongDataPtr = -18
MT_Speed = -14
MT_Counter = -13
MT_SongPos = -12
MT_PBreakPos = -11
MT_PosJumpFlag = -10
MT_PBreakFlag = -9
MT_LowMask = -8
MT_PattDelTime = -7
MT_PattDelTime2 = -6
MT_PatternPos = -4
MT_DMACONTemp = -2
MT_CiaSpeed = 0
MT_Signal = 2
MT_TimerSpeed = 4
MT_CiaBase = 8
MT_CiaTimer = 12
MT_Volume = 14

MT_Init:
	move.l	a5,-(sp)
	lea	MT_Variables(pc),a5
	move.l	a0,MT_SongDataPtr(a5)
	lea	952(a0),a1
	moveq	#127,D0
	moveq	#0,D1
MTLoop:
	move.l	d1,d2
	subq.w	#1,d0
MTLoop2:
	move.b	(a1)+,d1
	cmp.b	d2,d1
	bgt.s	MTLoop
	dbf	d0,MTLoop2
	addq.b	#1,d2
			
	move.l	a5,a1
	suba.w	#142,a1
	asl.l	#8,d2
	asl.l	#2,d2
	addi.l	#1084,d2
	add.l	a0,d2
	move.l	d2,a2
	moveq	#30,d0
MTLoop3:
;	clr.l	(a2)
	move.l	a2,(a1)+
	moveq	#0,d1
	move.w	42(a0),d1
	add.l	d1,d1
	add.l	d1,a2
	adda.w	#30,a0
	dbf	d0,MTLoop3

	ori.b	#2,$bfe001
	move.b	#6,MT_Speed(a5)
	clr.b	MT_Counter(a5)
	clr.b	MT_SongPos(a5)
	clr.w	MT_PatternPos(a5)
	move.l	(sp)+,a5
MT_End:	clr.w	$0A8(a5)
	clr.w	$0B8(a5)
	clr.w	$0C8(a5)
	clr.w	$0D8(a5)
	move.w	#$f,$096(a5)
	rts

MT_Music:
	movem.l	d0-d4/a0-a6,-(a7)
	move.l	a5,a6
	lea	MT_Variables(pc),a5
	addq.b	#1,MT_Counter(a5)
	move.b	MT_Counter(a5),d0
	cmp.b	MT_Speed(a5),d0
	blo.s	MT_NoNewNote
	clr.b	MT_Counter(a5)
	tst.b	MT_PattDelTime2(a5)
	beq	MT_GetNewNote
	bsr.s	MT_NoNewAllChannels
	bra	MT_Dskip

	IFD	ST_CiaOn
MT_SetCia
	movem.l	a0/d0/d2,-(sp)
	cmp.w	#32,d0
	bge.s	.right
	moveq.l	#32,d0
.right	and.w	#$FF,d0
	move.w	d0,MT_CiaSpeed(a5)
	move.l	MT_TimerSpeed(a5),d2
	divu	d0,d2
	tst.w	MT_CiaTimer(a5)
	beq.s	.settia
	move.l	MT_CiaBase(a5),a0
	move.b	d2,ciatblo(a0)
	lsr.w	#8,d2
	move.b	d2,ciatbhi(a0)
.skip	movem.l	(sp)+,a0/d0/d2
	rts
.settia	move.l	MT_CiaBase(a5),a0
	move.b	d2,ciatalo(a0)
	lsr.w	#8,d2
	move.b	d2,ciatahi(a0)
	movem.l	(sp)+,a0/d0/d2
	rts
	ENDC

MT_NoNewNote:
	bsr.s	MT_NoNewAllChannels
	bra	MT_NoNewPosYet
MT_NoNewAllChannels:
	move.w	#$a0,d5
	move.l	a5,a4
	suba.w	#318,a4
	bsr	MT_CheckEfx
	move.w	#$b0,d5
	adda.w	#44,a4
	bsr	MT_CheckEfx
	move.w	#$c0,d5
	adda.w	#44,a4
	bsr	MT_CheckEfx
	move.w	#$d0,d5
	adda.w	#44,a4
	bra	MT_CheckEfx
MT_GetNewNote:
	move.l	MT_SongDataPtr(a5),a0
	lea	12(a0),a3
	lea	952(a0),a2	;pattpo
	lea	1084(a0),a0	;patterndata
	moveq	#0,d0
	moveq	#0,d1
	move.b	MT_SongPos(a5),d0
	move.b	(a2,d0.w),d1
	asl.l	#8,d1
	asl.l	#2,d1
	add.w	MT_PatternPos(a5),d1
	clr.w	MT_DMACONTemp(a5)

	move.w	#$a0,d5
	move.l	a5,a4
	suba.w	#318,a4
	bsr.s	MT_PlayVoice
	move.w	#$b0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	move.w	#$c0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	move.w	#$d0,d5
	adda.w	#44,a4
	bsr.s	MT_PlayVoice
	bra	MT_SetDMA

MT_PlayVoice:
	tst.l	(a4)
	bne.s	MT_PlvSkip
	bsr	MT_PerNop
MT_PlvSkip:
	move.l	(a0,d1.l),(a4)
	addq.l	#4,d1
	moveq	#0,d2
	move.b	N_Cmd(a4),d2
	andi.b	#$f0,d2
	lsr.b	#4,d2
	move.b	(a4),d0
	andi.b	#$f0,d0
	or.b	d0,d2
	beq	MT_SetRegs
	moveq	#0,d3
	move.l	a5,a1
	suba.w	#142,a1
	move	d2,d4
	subq.l	#1,d2
	asl.l	#2,d2
	mulu	#30,d4
	move.l	(a1,d2.l),N_Start(a4)
	move.w	(a3,d4.l),N_Length(a4)
	move.w	(a3,d4.l),N_RealLength(a4)
	move.b	2(a3,d4.l),N_FineTune(a4)
	move.b	3(a3,d4.l),N_Volume(a4)
	move.w	4(a3,d4.l),d3 ; Get repeat
	beq.s	MT_NoLoop
	move.l	N_Start(a4),d2 ; Get start
	add.w	d3,d3
	add.l	d3,d2		; Add repeat
	move.l	d2,N_LoopStart(a4)
	move.l	d2,N_WaveStart(a4)
	move.w	4(a3,d4.l),d0	; Get repeat
	add.w	6(a3,d4.l),d0	; Add replen
	move.w	d0,N_Length(a4)
	move.w	6(a3,d4.l),N_Replen(a4)	; Save replen
	moveq	#0,d0
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
	bra.s	MT_SetRegs

MT_NoLoop:
	move.l	N_Start(a4),d2
	add.l	d3,d2
	move.l	d2,N_LoopStart(a4)
	move.l	d2,N_WaveStart(a4)
	move.w	6(a3,d4.l),N_Replen(a4)	; Save replen
	moveq	#0,d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	move.b	N_Volume(a4),d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
MT_SetRegs:
	move.w	(a4),d0
	andi.w	#$0fff,d0
	beq	MT_CheckMoreEfx	; If no note
	move.w	2(a4),d0
	andi.w	#$0ff0,d0
	cmpi.w	#$0e50,d0
	beq.s	MT_DoSetFineTune
	move.b	2(a4),d0
	andi.b	#$0f,d0
	cmpi.b	#3,d0	; TonePortamento
	beq.s	MT_ChkTonePorta
	cmpi.b	#5,d0
	beq.s	MT_ChkTonePorta
	cmpi.b	#9,d0	; Sample Offset
	bne.s	MT_SetPeriod
	bsr	MT_CheckMoreEfx
	bra.s	MT_SetPeriod

MT_DoSetFineTune:
	bsr	MT_SetFineTune
	bra.s	MT_SetPeriod

MT_ChkTonePorta:
	bsr	MT_SetTonePorta
	bra	MT_CheckMoreEfx

MT_SetPeriod:
	movem.l	d0-d1/a0-a1,-(a7)
	move.w	(a4),d1
	andi.w	#$0fff,d1
	lea	MT_PeriodTable(pc),a1
	moveq	#0,d0
	moveq	#36,d7
MT_FtuLoop:
	cmp.w	(a1,d0.w),d1
	bhs.s	MT_FtuFound
	addq.l	#2,d0
	dbf	d7,MT_FtuLoop
MT_FtuFound:
	moveq	#0,d1
	move.b	N_FineTune(a4),d1
	mulu	#72,d1
	add.l	d1,a1
	move.w	(a1,d0.w),N_Period(a4)
	movem.l	(a7)+,d0-d1/a0-a1

	move.w	2(a4),d0
	andi.w	#$0ff0,d0
	cmpi.w	#$0ed0,d0 ; Notedelay
	beq	MT_CheckMoreEfx

	move.w	N_DMABit(a4),$096(a6)
	btst	#2,N_WaveControl(a4)
	bne.s	MT_Vibnoc
	clr.b	N_VibratoPos(a4)
MT_Vibnoc:
	btst	#6,N_WaveControl(a4)
	bne.s	MT_Trenoc
	clr.b	N_TremoloPos(a4)
MT_Trenoc:
	move.l	N_Start(a4),(a6,d5.w)	; Set start
	move.w	N_Length(a4),4(a6,d5.w)	; Set length
	move.w	N_Period(a4),d0
	move.w	d0,6(a6,d5.w)		; Set period
	move.w	N_DMABit(a4),d0
	or.w	d0,MT_DMACONTemp(a5)
	bra	MT_CheckMoreEfx
 
MT_SetDMA:
	bsr	MT_DMAWaitLoop
	move.w	MT_DMACONTemp(a5),d0
	ori.w	#$8000,d0
	move.w	d0,$096(a6)
	bsr	MT_DMAWaitLoop
	move.l	a5,a4
	suba.w	#186,a4
	move.l	N_LoopStart(a4),$d0(a6)
	move.w	N_Replen(a4),$d4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$c0(a6)
	move.w	N_Replen(a4),$c4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$b0(a6)
	move.w	N_Replen(a4),$b4(a6)
	suba.w	#44,a4
	move.l	N_LoopStart(a4),$a0(a6)
	move.w	N_Replen(a4),$a4(a6)

MT_Dskip:
	addi.w	#16,MT_PatternPos(a5)
	move.b	MT_PattDelTime(a5),d0
	beq.s	MT_Dskc
	move.b	d0,MT_PattDelTime2(a5)
	clr.b	MT_PattDelTime(a5)
MT_Dskc:
	tst.b	MT_PattDelTime2(a5)
	beq.s	MT_Dska
	subq.b	#1,MT_PattDelTime2(a5)
	beq.s	MT_Dska
	sub.w	#16,MT_PatternPos(a5)
MT_Dska:
	tst.b	MT_PBreakFlag(a5)
	beq.s	MT_Nnpysk
	clr.b	MT_PBreakFlag(a5)
	moveq	#0,d0
	move.b	MT_PBreakPos(a5),d0
	clr.b	MT_PBreakPos(a5)
	lsl.w	#4,d0
	move.w	d0,MT_PatternPos(a5)
MT_Nnpysk:
	cmpi.w	#1024,MT_PatternPos(a5)
	blo.s	MT_NoNewPosYet
MT_NextPosition:	
	moveq	#0,d0
	move.b	MT_PBreakPos(a5),d0
	lsl.w	#4,d0
	move.w	d0,MT_PatternPos(a5)
	clr.b	MT_PBreakPos(a5)
	clr.b	MT_PosJumpFlag(a5)
	addq.b	#1,MT_SongPos(a5)
	andi.b	#$7F,MT_SongPos(a5)
	move.b	MT_SongPos(a5),d1
	move.l	MT_SongDataPtr(a5),a0
	cmp.b	950(a0),d1
	blo.s	MT_NoNewPosYet
	clr.b	MT_SongPos(a5)
	st	MT_Signal(a5)
MT_NoNewPosYet:	
	tst.b	MT_PosJumpFlag(a5)
	bne.s	MT_NextPosition
	movem.l	(a7)+,d0-d4/a0-a6
	rts

MT_CheckEfx:
	bsr	MT_UpdateFunk
	move.w	N_Cmd(a4),d0
	andi.w	#$0fff,d0
	beq.s	MT_PerNop
	move.b	N_Cmd(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_Arpeggio
	cmpi.b	#1,d0
	beq	MT_PortaUp
	cmpi.b	#2,d0
	beq	MT_PortaDown
	cmpi.b	#3,d0
	beq	MT_TonePortamento
	cmpi.b	#4,d0
	beq	MT_Vibrato
	cmpi.b	#5,d0
	beq	MT_TonePlusVolSlide
	cmpi.b	#6,d0
	beq	MT_VibratoPlusVolSlide
	cmpi.b	#$E,d0
	beq	MT_E_Commands
SetBack:
	move.w	N_Period(a4),6(a6,d5.w)
	cmpi.b	#7,d0
	beq	MT_Tremolo
	cmpi.b	#$a,d0
	beq	MT_VolumeSlide
MT_Return2:
	rts

MT_PerNop:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)	; Set volume
	move.w	N_Period(a4),6(a6,d5.w)
	rts

MT_Arpeggio:
	moveq	#0,d0
	move.b	MT_Counter(a5),d0
	divs	#3,d0
	swap	d0
	tst.w	D0
	beq.s	MT_Arpeggio2
	cmpi.w	#2,d0
	beq.s	MT_Arpeggio1
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	lsr.b	#4,d0
	bra.s	MT_Arpeggio3

MT_Arpeggio1:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#15,d0
	bra.s	MT_Arpeggio3

MT_Arpeggio2:
	move.w	N_Period(a4),d2
	bra.s	MT_Arpeggio4

MT_Arpeggio3:
	add.w	d0,d0
	moveq	#0,d1
	move.b	N_FineTune(a4),d1
	mulu	#72,d1
	lea	MT_PeriodTable(pc),a0
	add.w	d1,a0
	moveq	#0,d1
	move.w	N_Period(a4),d1
	moveq	#36,d7
MT_ArpLoop:
	move.w	(a0,d0.w),d2
	cmp.w	(a0),d1
	bhs.s	MT_Arpeggio4
	addq.w	#2,a0
	dbf	d7,MT_ArpLoop
	rts

MT_Arpeggio4:
	move.w	d2,6(a6,d5.w)
	rts

MT_FinePortaUp:
	tst.b	MT_Counter(a5)
	bne.w	MT_Return2
	move.b	#$0f,MT_LowMask(a5)
MT_PortaUp:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	and.b	MT_LowMask(a5),d0
	st	MT_LowMask(a5)
	sub.w	d0,N_Period(a4)
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	cmpi.w	#113,d0
	bpl.s	MT_PortaUskip
	andi.w	#$f000,N_Period(a4)
	ori.w	#113,N_Period(a4)
MT_PortaUskip:
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	move.w	d0,6(a6,d5.w)
	rts
 
MT_FinePortaDown:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	#$0f,MT_LowMask(a5)
MT_PortaDown:
	clr.w	d0
	move.b	N_Cmdlo(a4),d0
	and.b	MT_LowMask(a5),d0
	st	MT_LowMask(a5)
	add.w	d0,N_Period(a4)
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	cmpi.w	#856,d0
	bmi.s	MT_PortaDskip
	andi.w	#$f000,N_Period(a4)
	ori.w	#856,N_Period(a4)
MT_PortaDskip:
	move.w	N_Period(a4),d0
	andi.w	#$0fff,d0
	move.w	d0,6(a6,d5.w)
	rts

MT_SetTonePorta:
	move.l	a0,-(a7)
	move.w	(a4),d2
	andi.w	#$0fff,d2
	moveq	#0,d0
	move.b	N_FineTune(a4),d0
	mulu	#74,d0
	lea	MT_PeriodTable(pc),a0
	add.w	d0,a0
	moveq	#0,d0
MT_StpLoop:
	cmp.w	(a0,d0.w),d2
	bhs.s	MT_StpFound
	addq.w	#2,d0
	cmpi.w	#74,d0
	blo.s	MT_StpLoop
	moveq	#70,d0
MT_StpFound:
	move.b	N_FineTune(a4),d2
	andi.b	#8,d2
	beq.s	MT_StpGoss
	tst.w	d0
	beq.s	MT_StpGoss
	subq.w	#2,d0
MT_StpGoss:
	move.w	(a0,d0.w),d2
	move.l	(a7)+,a0
	move.w	d2,N_WantedPeriod(a4)
	move.w	N_Period(a4),d0
	clr.b	N_TonePortDirec(a4)
	cmp.w	d0,d2
	beq.s	MT_ClearTonePorta
	bge	MT_Return2
	move.b	#1,N_TonePortDirec(a4)
	rts

MT_ClearTonePorta:
	clr.w	N_WantedPeriod(a4)
	rts

MT_TonePortamento:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_TonePortNoChange
	move.b	d0,N_TonePortSpeed(a4)
	clr.b	N_Cmdlo(a4)
MT_TonePortNoChange:
	tst.w	N_WantedPeriod(a4)
	beq	MT_Return2
	moveq	#0,d0
	move.b	N_TonePortSpeed(a4),d0
	tst.b	N_TonePortDirec(a4)
	bne.s	MT_TonePortaUp
MT_TonePortaDown:
	add.w	d0,N_Period(a4)
	move.w	N_WantedPeriod(a4),d0
	cmp.w	N_Period(a4),d0
	bgt.s	MT_TonePortaSetPer
	move.w	N_WantedPeriod(a4),N_Period(a4)
	clr.w	N_WantedPeriod(a4)
	bra.s	MT_TonePortaSetPer

MT_TonePortaUp:
	sub.w	d0,N_Period(a4)
	move.w	N_WantedPeriod(a4),d0
	cmp.w	N_Period(a4),d0     	; was cmpi!!!!
	blt.s	MT_TonePortaSetPer
	move.w	N_WantedPeriod(a4),N_Period(a4)
	clr.w	N_WantedPeriod(a4)

MT_TonePortaSetPer:
	move.w	N_Period(a4),d2
	move.b	N_GlissFunk(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_GlissSkip
	moveq	#0,d0
	move.b	N_FineTune(a4),d0
	mulu	#72,d0
	lea	MT_PeriodTable(pc),a0
	add.w	d0,a0
	moveq	#0,d0
MT_GlissLoop:
	cmp.w	(a0,d0.w),d2
	bhs.s	MT_GlissFound
	addq.w	#2,d0
	cmpi.w	#72,d0
	blo.s	MT_GlissLoop
	moveq	#70,d0
MT_GlissFound:
	move.w	(a0,d0.w),d2
MT_GlissSkip:
	move.w	d2,6(a6,d5.w) ; Set period
	rts

MT_Vibrato:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_Vibrato2
	move.b	N_VibratoCmd(a4),d2
	andi.b	#$0f,d0
	beq.s	MT_VibSkip
	andi.b	#$f0,d2
	or.b	d0,d2
MT_VibSkip:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$f0,d0
	beq.s	MT_VibSkip2
	andi.b	#$0f,d2
	or.b	d0,d2
MT_VibSkip2:
	move.b	d2,N_VibratoCmd(a4)
MT_Vibrato2:
	move.b	N_VibratoPos(a4),d0
	lea	MT_VibratoTable(pc),a0
	lsr.w	#2,d0
	andi.w	#$001f,d0
	moveq	#0,d2
	move.b	N_WaveControl(a4),d2
	andi.b	#$03,d2
	beq.s	MT_Vib_Sine
	lsl.b	#3,d0
	cmpi.b	#1,d2
	beq.s	MT_Vib_RampDown
	st	d2
	bra.s	MT_Vib_Set
MT_Vib_RampDown:
	tst.b	N_VibratoPos(a4)
	bpl.s	MT_Vib_RampDown2
	st	d2
	sub.b	d0,d2
	bra.s	MT_Vib_Set
MT_Vib_RampDown2:
	move.b	d0,d2
	bra.s	MT_Vib_Set
MT_Vib_Sine:
	move.b	(a0,d0.w),d2
MT_Vib_Set:
	move.b	N_VibratoCmd(a4),d0
	andi.w	#15,d0
	mulu	d0,d2
	lsr.w	#7,d2
	move.w	N_Period(a4),d0
	tst.b	N_VibratoPos(a4)
	bmi.s	MT_VibratoNeg
	add.w	d2,d0
	bra.s	MT_Vibrato3
MT_VibratoNeg:
	sub.w	d2,d0
MT_Vibrato3:
	move.w	d0,6(a6,d5.w)
	move.b	N_VibratoCmd(a4),d0
	lsr.w	#2,d0
	andi.w	#$3C,d0
	add.b	d0,N_VibratoPos(a4)
	rts

MT_TonePlusVolSlide:
	bsr	MT_TonePortNoChange
	bra	MT_VolumeSlide

MT_VibratoPlusVolSlide:
	bsr.s	MT_Vibrato2
	bra	MT_VolumeSlide

MT_Tremolo:
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_Tremolo2
	move.b	N_TremoloCmd(a4),d2
	andi.b	#$0f,d0
	beq.s	MT_TreSkip
	andi.b	#$f0,d2
	or.b	d0,d2
MT_TreSkip:
	move.b	N_Cmdlo(a4),d0
	and.b	#$f0,d0
	beq.s	MT_TreSkip2
	andi.b	#$0f,d2
	or.b	d0,d2
MT_TreSkip2:
	move.b	d2,N_TremoloCmd(a4)
MT_Tremolo2:
	move.b	N_TremoloPos(a4),d0
	lea	MT_VibratoTable(pc),a0
	lsr.w	#2,d0
	andi.w	#$1f,d0
	moveq	#0,d2
	move.b	N_WaveControl(a4),d2
	lsr.b	#4,d2
	andi.b	#3,d2
	beq.s	MT_Tre_Sine
	lsl.b	#3,d0
	cmpi.b	#1,d2
	beq.s	MT_Tre_RampDown
	st	d2
	bra.s	MT_Tre_Set
MT_Tre_RampDown:
	tst.b	N_VibratoPos(a4)
	bpl.s	MT_Tre_RampDown2
	st	d2
	sub.b	d0,d2
	bra.s	MT_Tre_Set
MT_Tre_RampDown2:
	move.b	d0,d2
	bra.s	MT_Tre_Set
MT_Tre_Sine:
	move.b	(a0,d0.w),d2
MT_Tre_Set:
	move.b	N_TremoloCmd(a4),d0
	andi.w	#15,d0
	mulu	d0,d2
	lsr.w	#6,d2
	moveq	#0,d0
	move.b	N_Volume(a4),d0
	tst.b	N_TremoloPos(a4)
	bmi.s	MT_TremoloNeg
	add.w	d2,d0
	bra.s	MT_Tremolo3
MT_TremoloNeg:
	sub.w	d2,d0
MT_Tremolo3:
	bpl.s	MT_TremoloSkip
	clr.w	d0
MT_TremoloSkip:
	cmpi.w	#$40,d0
	bls.s	MT_TremoloOk
	move.w	#$40,d0
MT_TremoloOk:
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	move.b	N_TremoloCmd(a4),d0
	lsr.w	#2,d0
	andi.w	#$3c,d0
	add.b	d0,N_TremoloPos(a4)
	rts

MT_SampleOffset:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	beq.s	MT_SoNoNew
	move.b	d0,N_SampleOffset(a4)
MT_SoNoNew:
	move.b	N_SampleOffset(a4),d0
	lsl.w	#7,d0
	cmp.w	N_Length(a4),d0
	bge.s	MT_SofSkip
	sub.w	d0,N_Length(a4)
	add.w	d0,d0
	add.l	d0,N_Start(a4)
	rts
MT_SofSkip:
	move.w	#1,N_Length(a4)
	rts

MT_VolumeSlide:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	lsr.b	#4,d0
	tst.b	d0
	beq.s	MT_VolSlideDown
MT_VolSlideUp:
	add.b	d0,N_Volume(a4)
	cmpi.b	#$40,N_Volume(a4)
	bmi.s	MT_VsuSkip
	move.b	#$40,N_Volume(a4)
MT_VsuSkip:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_VolSlideDown:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
MT_VolSlideDown2:
	sub.b	d0,N_Volume(a4)
	bpl.s	MT_VsdSkip
	clr.b	N_Volume(a4)
MT_VsdSkip:
	move.b	N_Volume(a4),d0
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_PositionJump
	move.b	N_Cmdlo(a4),d0
	subq.b	#1,d0
	cmp.b	MT_SongPos(a5),d0
	bge.s	.nosign
	st	MT_Signal(a5)
.nosign	move.b	d0,MT_SongPos(a5)
MT_PJ2	clr.b	MT_PBreakPos(a5)
	st 	MT_PosJumpFlag(a5)
	rts

MT_VolumeChange:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	cmpi.b	#$40,d0
	bls.s	MT_VolumeOk
	moveq	#$40,d0
MT_VolumeOk:
	move.b	d0,N_Volume(a4)
	mulu	MT_Volume(a5),d0
	lsr.w	#6,d0
	bsr	mt_MasterVolume
	move.w	d0,8(a6,d5.w)
	rts

MT_PatternBreak:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	move.l	d0,d2
	lsr.b	#4,d0
	mulu	#10,d0
	andi.b	#$0f,d2
	add.b	d2,d0
	cmpi.b	#63,d0
	bhi.s	MT_PJ2
	move.b	d0,MT_PBreakPos(a5)
	st	MT_PosJumpFlag(a5)
	rts

	IFD	ST_CiaOn
MT_SetSpeed:
	moveq.l	#0,d0
	move.b	3(a4),d0
	beq	MT_Return2
	cmp.b	#32,d0
	bhs.s	.ciatim
	clr.b	MT_Counter(a5)
	move.b	d0,MT_Speed(a5)
	rts
.ciatim	bra	MT_SetCia
	ELSE
MT_SetSpeed:
	moveq.l	#0,d0
	move.b	3(a4),d0
	beq	MT_Return2
	cmp.b	#32,d0
	bhs.s	.ciatim
	clr.b	MT_Counter(a5)
	move.b	d0,MT_Speed(a5)
.ciatim	rts
	ENDC

MT_CheckMoreEfx:
	bsr	MT_UpdateFunk
	move.b	2(a4),d0
	andi.b	#$0f,d0
	cmpi.b	#$9,d0
	beq	MT_SampleOffset
	cmpi.b	#$b,d0
	beq	MT_PositionJump
	cmpi.b	#$d,d0
	beq.s	MT_PatternBreak
	cmpi.b	#$e,d0
	beq.s	MT_E_Commands
	cmpi.b	#$f,d0
	beq.s	MT_SetSpeed
	cmpi.b	#$c,d0
	beq	MT_VolumeChange
	bra	MT_PerNop

MT_E_Commands:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$f0,d0
	lsr.b	#4,d0
	beq.s	MT_FilterOnOff
	cmpi.b	#1,d0
	beq	MT_FinePortaUp
	cmpi.b	#2,d0
	beq	MT_FinePortaDown
	cmpi.b	#3,d0
	beq.s	MT_SetGlissControl
	cmpi.b	#4,d0
	beq	MT_SetVibratoControl
	cmpi.b	#5,d0
	beq	MT_SetFineTune
	cmpi.b	#6,d0
	beq	MT_JumpLoop
	cmpi.b	#7,d0
	beq	MT_SetTremoloControl
	cmpi.b	#9,d0
	beq	MT_RetrigNote
	cmpi.b	#$a,d0
	beq	MT_VolumeFineUp
	cmpi.b	#$b,d0
	beq	MT_VolumeFineDown
	cmpi.b	#$c,d0
	beq	MT_NoteCut
	cmpi.b	#$d,d0
	beq	MT_NoteDelay
	cmpi.b	#$e,d0
	beq	MT_PatternDelay
	cmpi.b	#$f,d0
	beq	MT_FunkIt
	rts

MT_FilterOnOff:
	move.b	N_Cmdlo(a4),d0
	andi.b	#1,d0
	add.b	d0,d0
	andi.b	#$fd,$bfe001
	or.b	d0,$bfe001
	rts

MT_SetGlissControl:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	andi.b	#$f0,N_GlissFunk(a4)
	or.b	d0,N_GlissFunk(a4)
	rts

MT_SetVibratoControl:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	andi.b	#$f0,N_WaveControl(a4)
	or.b	d0,N_WaveControl(a4)
	rts

MT_SetFineTune:
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	move.b	d0,N_FineTune(a4)
	rts

MT_JumpLoop:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_SetLoop
	tst.b	N_LoopCount(a4)
	beq.s	MT_JumpCnt
	subq.b	#1,N_LoopCount(a4)
	beq	MT_Return2
MT_JmpLoop:
	move.b	N_PattPos(a4),MT_PBreakPos(a5)
	st	MT_PBreakFlag(a5)
	rts

MT_JumpCnt:
	move.b	d0,N_LoopCount(a4)
	bra.s	MT_JmpLoop

MT_SetLoop:
	move.w	MT_PatternPos(a5),d0
	lsr.w	#4,d0
	move.b	d0,N_PattPos(a4)
	rts

MT_SetTremoloControl:
	move.b	N_Cmdlo(a4),d0
*	andi.b	#$0f,d0
	lsl.b	#4,d0
	andi.b	#$0f,N_WaveControl(a4)
	or.b	d0,N_WaveControl(a4)
	rts

MT_RetrigNote:
	move.l	d1,-(a7)
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	beq.s	MT_RtnEnd
	moveq	#0,d1
	move.b	MT_Counter(a5),d1
	bne.s	MT_RtnSkp
	move.w	(a4),d1
	andi.w	#$0fff,d1
	bne.s	MT_RtnEnd
	moveq	#0,d1
	move.b	MT_Counter(a5),d1
MT_RtnSkp:
	divu	d0,d1
	swap	d1
	tst.w	d1
	bne.s	MT_RtnEnd
MT_DoRetrig:
	move.w	N_DMABit(a4),$096(a6)	; Channel DMA off
	move.l	N_Start(a4),(a6,d5.w)	; Set sampledata pointer
	move.w	N_Length(a4),4(a6,d5.w)	; Set length
	bsr	MT_DMAWaitLoop
	move.w	N_DMABit(a4),d0
	ori.w	#$8000,d0
*	bset	#15,d0
	move.w	d0,$096(a6)
	bsr	MT_DMAWaitLoop
	move.l	N_LoopStart(a4),(a6,d5.w)
	move.l	N_Replen(a4),4(a6,d5.w)
MT_RtnEnd:
	move.l	(a7)+,d1
	rts

MT_VolumeFineUp:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	bra	MT_VolSlideUp

MT_VolumeFineDown:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	bra	MT_VolSlideDown2

MT_NoteCut:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	cmp.b	MT_Counter(a5),d0   ; was cmpi!!!
	bne	MT_Return2
	clr.b	N_Volume(a4)
	clr.w	8(a6,d5.w)
	rts

MT_NoteDelay:
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	cmp.b	MT_Counter(a5),d0   ; was cmpi!!!
	bne	MT_Return2
	move.w	(a4),d0
	beq	MT_Return2
	move.l	d1,-(a7)
	bra	MT_DoRetrig

MT_PatternDelay:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	moveq	#0,d0
	move.b	N_Cmdlo(a4),d0
	andi.b	#$0f,d0
	tst.b	MT_PattDelTime2(a5)
	bne	MT_Return2
	addq.b	#1,d0
	move.b	d0,MT_PattDelTime(a5)
	rts

MT_FunkIt:
	tst.b	MT_Counter(a5)
	bne	MT_Return2
	move.b	N_Cmdlo(a4),d0
*	andi.b	#$0f,d0
	lsl.b	#4,d0
	andi.b	#$0f,N_GlissFunk(a4)
	or.b	d0,N_GlissFunk(a4)
	tst.b	d0
	beq	MT_Return2
MT_UpdateFunk:
	movem.l	a0/d1,-(a7)
	moveq	#0,d0
	move.b	N_GlissFunk(a4),d0
	lsr.b	#4,d0
	beq.s	MT_FunkEnd
	lea	MT_FunkTable(pc),a0
	move.b	(a0,d0.w),d0
	add.b	d0,N_FunkOffset(a4)
	btst	#7,N_FunkOffset(a4)
	beq.s	MT_FunkEnd
	clr.b	N_FunkOffset(a4)

	move.l	N_LoopStart(a4),d0
	moveq	#0,d1
	move.w	N_Replen(a4),d1
	add.l	d1,d0
	add.l	d1,d0
	move.l	N_WaveStart(a4),a0
	addq.w	#1,a0
	cmp.l	d0,a0
	blo.s	MT_FunkOk
	move.l	N_LoopStart(a4),a0
MT_FunkOk:
	move.l	a0,N_WaveStart(a4)
	moveq	#-1,d0
	sub.b	(a0),d0
	move.b	d0,(a0)
MT_FunkEnd:
	movem.l	(a7)+,a0/d1
	rts

MT_DMAWaitLoop:
	move.w	d1,-(sp)
;	moveq	#5,d0		; wait 5+1 lines
;.loop	move.b	6(a6),d1		; read current raster position
;.wait	cmp.b	6(a6),d1
;	beq.s	.wait		; wait until it changes
;	dbf	d0,.loop		; do it again


	move.b	$dff006,d1
	add.b	#5,d1
.loop:	cmp.b	$dff006,d1
	bne.s	.loop

	move.w	(sp)+,d1
	rts


mt_MasterVolume:	; Patch by Chucky of The Gang
;	rts
			; Mastervolumesupport
			; IN:  D0 = Wanted volume
			; OUT: D0 = Real Volume after fade with mt_MasterVol
	movem.l D1-D3,-(SP)
	cmp.w	#0,d0
	beq.w	.Zero
			; First check if one chnnel is to be muted
	cmp.w	#$a0,d5	; chan1?
	bne.w	.chan1
	move.b	mt_Chan1(PC),d1
	cmp.b	#0,d1
	beq.w	.chan1
	bra	.Zero

.chan1:
	cmp.w	#$b0,d5	; chan2?
	bne.s	.chan2
	move.b	mt_Chan2(PC),d1
	cmp.b	#0,d1
	beq.s	.chan2
	bra	.Zero

.chan2:
	cmp.w	#$c0,d5	; chan3?
	bne.s	.chan3
	move.b	mt_Chan3(PC),d1
	cmp.b	#0,d1
	beq.s	.chan3
	bra	.Zero

.chan3:
	cmp.w	#$d0,d5	; chan4?
	bne.s	.chan4
	move.b	mt_Chan4(PC),d1
	cmp.b	#0,d1
	beq.s	.chan4
	bra	.Zero

.chan4:
	clr.l	d1
	move.b	mt_MasterVol(PC),d1
	clr.l	d2
	clr.l	d3
	move.w	d0,d2
	move.w	#64,d3
	cmp.w	#0,d2
	beq.s	.Zero
	divu	d2,d3
	cmp.w	#0,d3
	beq.s	.Zero
	divu	d3,d1	
	cmp.w	d1,d0
	blt	.stor
	bra.s	.exit
.Zero:
	clr.l	d1
.exit:
	move.l	d1,d0
	movem.l	(SP)+,D1-D3
	rts

.stor:
	move.w	d0,d1
	bra.s	.exit

MT_FunkTable:
	dc.b	0,5,6,7,8,10,11,13,16,19,22,26,32,43,64,128

MT_VibratoTable:
	dc.b	0,24,49,74,97,120,141,161
	dc.b	180,197,212,224,235,244,250,253
	dc.b	255,253,250,244,235,224,212,197
	dc.b	180,161,141,120,97,74,49,24

MT_PeriodTable:
; Tuning 0, Normal
	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
	dc.w	428,404,381,360,339,320,302,285,269,254,240,226
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
; Tuning 1
	dc.w	850,802,757,715,674,637,601,567,535,505,477,450
	dc.w	425,401,379,357,337,318,300,284,268,253,239,225
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
; Tuning 2
	dc.w	844,796,752,709,670,632,597,563,532,502,474,447
	dc.w	422,398,376,355,335,316,298,282,266,251,237,224
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
; Tuning 3
	dc.w	838,791,746,704,665,628,592,559,528,498,470,444
	dc.w	419,395,373,352,332,314,296,280,264,249,235,222
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
; Tuning 4
	dc.w	832,785,741,699,660,623,588,555,524,495,467,441
	dc.w	416,392,370,350,330,312,294,278,262,247,233,220
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
; Tuning 5
	dc.w	826,779,736,694,655,619,584,551,520,491,463,437
	dc.w	413,390,368,347,328,309,292,276,260,245,232,219
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
; Tuning 6
	dc.w	820,774,730,689,651,614,580,547,516,487,460,434
	dc.w	410,387,365,345,325,307,290,274,258,244,230,217
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
; Tuning 7
	dc.w	814,768,725,684,646,610,575,543,513,484,457,431
	dc.w	407,384,363,342,323,305,288,272,256,242,228,216
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
; Tuning -8
	dc.w	907,856,808,762,720,678,640,604,570,538,508,480
	dc.w	453,428,404,381,360,339,320,302,285,269,254,240
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
; Tuning -7
	dc.w	900,850,802,757,715,675,636,601,567,535,505,477
	dc.w	450,425,401,379,357,337,318,300,284,268,253,238
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
; Tuning -6
	dc.w	894,844,796,752,709,670,632,597,563,532,502,474
	dc.w	447,422,398,376,355,335,316,298,282,266,251,237
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
; Tuning -5
	dc.w	887,838,791,746,704,665,628,592,559,528,498,470
	dc.w	444,419,395,373,352,332,314,296,280,264,249,235
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
; Tuning -4
	dc.w	881,832,785,741,699,660,623,588,555,524,494,467
	dc.w	441,416,392,370,350,330,312,294,278,262,247,233
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
; Tuning -3
	dc.w	875,826,779,736,694,655,619,584,551,520,491,463
	dc.w	437,413,390,368,347,328,309,292,276,260,245,232
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
; Tuning -2
	dc.w	868,820,774,730,689,651,614,580,547,516,487,460
	dc.w	434,410,387,365,345,325,307,290,274,258,244,230
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
; Tuning -1
	dc.w	862,814,768,725,684,646,610,575,543,513,484,457
	dc.w	431,407,384,363,342,323,305,288,272,256,242,228
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114

MT_Chan1Temp:
	dc.l	0,0,0,0,0,$00010000,0,0,0,0,0
MT_Chan2Temp:
	dc.l	0,0,0,0,0,$00020000,0,0,0,0,0
MT_Chan3Temp:
	dc.l	0,0,0,0,0,$00040000,0,0,0,0,0
MT_Chan4Temp:
	dc.l	0,0,0,0,0,$00080000,0,0,0,0,0
MT_SampleStarts:
	dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.l	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
*MT_SongDataPtr:
	dc.l	0
*MT_Speed:
	dc.b	6
*MT_Counter:
	dc.b	0
*MT_SongPos:
	dc.b	0
*MT_PBreakPos:
	dc.b	0
*MT_PosJumpFlag:
	dc.b	0
*MT_PBreakFlag:
	dc.b	0
*MT_LowMask:
	dc.b	0
*MT_PattDelTime:
	dc.b	0
*MT_PattDelTime2:
	dc.b	0,0
*MT_PatternPos:
	dc.w	0
*MT_DMACONtemp:
	dc.w	0
MT_Variables:
*MT_CiaSpeed
	dc.w	125
*MT_Signal
	dc.w	0
*MT_TimerSpeed
	dc.l	0
*MT_CiaBase
	dc.l	0
*MT_CiaTimer
	dc.w	0
*MT_VolumeControl
	dc.w	64
*mt_data:
	dc.l	0
mt_MasterVol:
	dc.b	64
mt_Chan1:			; If not 0 channel is to be muted
	dc.b	0		; NO Data between Mastervol and this or you will have BUGS
mt_Chan2:
	dc.b	0
mt_Chan3:
	dc.b	0
mt_Chan4:
	dc.b	0
	EVEN


mt_END:

bin2hex:
             cmp.b   #0,d1
             bne.s   .nxt0
             move.w   #$3030,d1
             jmp     (a1)
.nxt0:
             cmp.b   #1,d1
             bne.s   .nxt1
             move.w   #$3130,d1
             jmp     (a1)
.nxt1:
             cmp.b   #2,d1
             bne.s   .nxt2
             move.w   #$3230,d1
             jmp     (a1)
.nxt2:
             cmp.b   #3,d1
             bne.s   .nxt3
             move.w   #$3330,d1
             jmp     (a1)
.nxt3:
             cmp.b   #4,d1
             bne.s   .nxt4
             move.w   #$3430,d1
             jmp     (a1)
.nxt4:
             cmp.b   #5,d1
             bne.s   .nxt5
             move.w   #$3530,d1
             jmp     (a1)
.nxt5:
             cmp.b   #6,d1
             bne.s   .nxt6
             move.w   #$3630,d1
             jmp     (a1)
.nxt6:
             cmp.b   #7,d1
             bne.s   .nxt7
             move.w   #$3730,d1
             jmp     (a1)
.nxt7:
             cmp.b   #8,d1
             bne.s   .nxt8
             move.w   #$3830,d1
             jmp     (a1)
.nxt8:
             cmp.b   #9,d1
             bne.s   .nxt9
             move.w   #$3930,d1
             jmp     (a1)
.nxt9:
             cmp.b   #10,d1
             bne.s   .nxt10
             move.w   #$4130,d1
             jmp     (a1)
.nxt10:
             cmp.b   #11,d1
             bne.s   .nxt11
             move.w   #$4230,d1
             jmp     (a1)
.nxt11:
             cmp.b   #12,d1
             bne.s   .nxt12
             move.w   #$4330,d1
             jmp     (a1)
.nxt12:
             cmp.b   #13,d1
             bne.s   .nxt13
             move.w   #$4430,d1
             jmp     (a1)
.nxt13:
             cmp.b   #14,d1
             bne.s   .nxt14
             move.w   #$4530,d1
             jmp     (a1)
.nxt14:
             cmp.b   #15,d1
             bne.s   .nxt15
             move.w   #$4630,d1
             jmp     (a1)
.nxt15:
             cmp.b   #16,d1
             bne.s   .nxt16
             move.w   #$3031,d1
             jmp     (a1)
.nxt16:
             cmp.b   #17,d1
             bne.s   .nxt17
             move.w   #$3131,d1
             jmp     (a1)
.nxt17:
             cmp.b   #18,d1
             bne.s   .nxt18
             move.w   #$3231,d1
             jmp     (a1)
.nxt18:
             cmp.b   #19,d1
             bne.s   .nxt19
             move.w   #$3331,d1
             jmp     (a1)
.nxt19:
             cmp.b   #20,d1
             bne.s   .nxt20
             move.w   #$3431,d1
             jmp     (a1)
.nxt20:
             cmp.b   #21,d1
             bne.s   .nxt21
             move.w   #$3531,d1
             jmp     (a1)
.nxt21:
             cmp.b   #22,d1
             bne.s   .nxt22
             move.w   #$3631,d1
             jmp     (a1)
.nxt22:
             cmp.b   #23,d1
             bne.s   .nxt23
             move.w   #$3731,d1
             jmp     (a1)
.nxt23:
             cmp.b   #24,d1
             bne.s   .nxt24
             move.w   #$3831,d1
             jmp     (a1)
.nxt24:
             cmp.b   #25,d1
             bne.s   .nxt25
             move.w   #$3931,d1
             jmp     (a1)
.nxt25:
             cmp.b   #26,d1
             bne.s   .nxt26
             move.w   #$4131,d1
             jmp     (a1)
.nxt26:
             cmp.b   #27,d1
             bne.s   .nxt27
             move.w   #$4231,d1
             jmp     (a1)
.nxt27:
             cmp.b   #28,d1
             bne.s   .nxt28
             move.w   #$4331,d1
             jmp     (a1)
.nxt28:
             cmp.b   #29,d1
             bne.s   .nxt29
             move.w   #$4431,d1
             jmp     (a1)
.nxt29:
             cmp.b   #30,d1
             bne.s   .nxt30
             move.w   #$4531,d1
             jmp     (a1)
.nxt30:
             cmp.b   #31,d1
             bne.s   .nxt31
             move.w   #$4631,d1
             jmp     (a1)
.nxt31:
             cmp.b   #32,d1
             bne.s   .nxt32
             move.w   #$3032,d1
             jmp     (a1)
.nxt32:
             cmp.b   #33,d1
             bne.s   .nxt33
             move.w   #$3132,d1
             jmp     (a1)
.nxt33:
             cmp.b   #34,d1
             bne.s   .nxt34
             move.w   #$3232,d1
             jmp     (a1)
.nxt34:
             cmp.b   #35,d1
             bne.s   .nxt35
             move.w   #$3332,d1
             jmp     (a1)
.nxt35:
             cmp.b   #36,d1
             bne.s   .nxt36
             move.w   #$3432,d1
             jmp     (a1)
.nxt36:
             cmp.b   #37,d1
             bne.s   .nxt37
             move.w   #$3532,d1
             jmp     (a1)
.nxt37:
             cmp.b   #38,d1
             bne.s   .nxt38
             move.w   #$3632,d1
             jmp     (a1)
.nxt38:
             cmp.b   #39,d1
             bne.s   .nxt39
             move.w   #$3732,d1
             jmp     (a1)
.nxt39:
             cmp.b   #40,d1
             bne.s   .nxt40
             move.w   #$3832,d1
             jmp     (a1)
.nxt40:
             cmp.b   #41,d1
             bne.s   .nxt41
             move.w   #$3932,d1
             jmp     (a1)
.nxt41:
             cmp.b   #42,d1
             bne.s   .nxt42
             move.w   #$4132,d1
             jmp     (a1)
.nxt42:
             cmp.b   #43,d1
             bne.s   .nxt43
             move.w   #$4232,d1
             jmp     (a1)
.nxt43:
             cmp.b   #44,d1
             bne.s   .nxt44
             move.w   #$4332,d1
             jmp     (a1)
.nxt44:
             cmp.b   #45,d1
             bne.s   .nxt45
             move.w   #$4432,d1
             jmp     (a1)
.nxt45:
             cmp.b   #46,d1
             bne.s   .nxt46
             move.w   #$4532,d1
             jmp     (a1)
.nxt46:
             cmp.b   #47,d1
             bne.s   .nxt47
             move.w   #$4632,d1
             jmp     (a1)
.nxt47:
             cmp.b   #48,d1
             bne.s   .nxt48
             move.w   #$3033,d1
             jmp     (a1)
.nxt48:
             cmp.b   #49,d1
             bne.s   .nxt49
             move.w   #$3133,d1
             jmp     (a1)
.nxt49:
             cmp.b   #50,d1
             bne.s   .nxt50
             move.w   #$3233,d1
             jmp     (a1)
.nxt50:
             cmp.b   #51,d1
             bne.s   .nxt51
             move.w   #$3333,d1
             jmp     (a1)
.nxt51:
             cmp.b   #52,d1
             bne.s   .nxt52
             move.w   #$3433,d1
             jmp     (a1)
.nxt52:
             cmp.b   #53,d1
             bne.s   .nxt53
             move.w   #$3533,d1
             jmp     (a1)
.nxt53:
             cmp.b   #54,d1
             bne.s   .nxt54
             move.w   #$3633,d1
             jmp     (a1)
.nxt54:
             cmp.b   #55,d1
             bne.s   .nxt55
             move.w   #$3733,d1
             jmp     (a1)
.nxt55:
             cmp.b   #56,d1
             bne.s   .nxt56
             move.w   #$3833,d1
             jmp     (a1)
.nxt56:
             cmp.b   #57,d1
             bne.s   .nxt57
             move.w   #$3933,d1
             jmp     (a1)
.nxt57:
             cmp.b   #58,d1
             bne.s   .nxt58
             move.w   #$4133,d1
             jmp     (a1)
.nxt58:
             cmp.b   #59,d1
             bne.s   .nxt59
             move.w   #$4233,d1
             jmp     (a1)
.nxt59:
             cmp.b   #60,d1
             bne.s   .nxt60
             move.w   #$4333,d1
             jmp     (a1)
.nxt60:
             cmp.b   #61,d1
             bne.s   .nxt61
             move.w   #$4433,d1
             jmp     (a1)
.nxt61:
             cmp.b   #62,d1
             bne.s   .nxt62
             move.w   #$4533,d1
             jmp     (a1)
.nxt62:
             cmp.b   #63,d1
             bne.s   .nxt63
             move.w   #$4633,d1
             jmp     (a1)
.nxt63:
             cmp.b   #64,d1
             bne.s   .nxt64
             move.w   #$3034,d1
             jmp     (a1)
.nxt64:
             cmp.b   #65,d1
             bne.s   .nxt65
             move.w   #$3134,d1
             jmp     (a1)
.nxt65:
             cmp.b   #66,d1
             bne.s   .nxt66
             move.w   #$3234,d1
             jmp     (a1)
.nxt66:
             cmp.b   #67,d1
             bne.s   .nxt67
             move.w   #$3334,d1
             jmp     (a1)
.nxt67:
             cmp.b   #68,d1
             bne.s   .nxt68
             move.w   #$3434,d1
             jmp     (a1)
.nxt68:
             cmp.b   #69,d1
             bne.s   .nxt69
             move.w   #$3534,d1
             jmp     (a1)
.nxt69:
             cmp.b   #70,d1
             bne.s   .nxt70
             move.w   #$3634,d1
             jmp     (a1)
.nxt70:
             cmp.b   #71,d1
             bne.s   .nxt71
             move.w   #$3734,d1
             jmp     (a1)
.nxt71:
             cmp.b   #72,d1
             bne.s   .nxt72
             move.w   #$3834,d1
             jmp     (a1)
.nxt72:
             cmp.b   #73,d1
             bne.s   .nxt73
             move.w   #$3934,d1
             jmp     (a1)
.nxt73:
             cmp.b   #74,d1
             bne.s   .nxt74
             move.w   #$4134,d1
             jmp     (a1)
.nxt74:
             cmp.b   #75,d1
             bne.s   .nxt75
             move.w   #$4234,d1
             jmp     (a1)
.nxt75:
             cmp.b   #76,d1
             bne.s   .nxt76
             move.w   #$4334,d1
             jmp     (a1)
.nxt76:
             cmp.b   #77,d1
             bne.s   .nxt77
             move.w   #$4434,d1
             jmp     (a1)
.nxt77:
             cmp.b   #78,d1
             bne.s   .nxt78
             move.w   #$4534,d1
             jmp     (a1)
.nxt78:
             cmp.b   #79,d1
             bne.s   .nxt79
             move.w   #$4634,d1
             jmp     (a1)
.nxt79:
             cmp.b   #80,d1
             bne.s   .nxt80
             move.w   #$3035,d1
             jmp     (a1)
.nxt80:
             cmp.b   #81,d1
             bne.s   .nxt81
             move.w   #$3135,d1
             jmp     (a1)
.nxt81:
             cmp.b   #82,d1
             bne.s   .nxt82
             move.w   #$3235,d1
             jmp     (a1)
.nxt82:
             cmp.b   #83,d1
             bne.s   .nxt83
             move.w   #$3335,d1
             jmp     (a1)
.nxt83:
             cmp.b   #84,d1
             bne.s   .nxt84
             move.w   #$3435,d1
             jmp     (a1)
.nxt84:
             cmp.b   #85,d1
             bne.s   .nxt85
             move.w   #$3535,d1
             jmp     (a1)
.nxt85:
             cmp.b   #86,d1
             bne.s   .nxt86
             move.w   #$3635,d1
             jmp     (a1)
.nxt86:
             cmp.b   #87,d1
             bne.s   .nxt87
             move.w   #$3735,d1
             jmp     (a1)
.nxt87:
             cmp.b   #88,d1
             bne.s   .nxt88
             move.w   #$3835,d1
             jmp     (a1)
.nxt88:
             cmp.b   #89,d1
             bne.s   .nxt89
             move.w   #$3935,d1
             jmp     (a1)
.nxt89:
             cmp.b   #90,d1
             bne.s   .nxt90
             move.w   #$4135,d1
             jmp     (a1)
.nxt90:
             cmp.b   #91,d1
             bne.s   .nxt91
             move.w   #$4235,d1
             jmp     (a1)
.nxt91:
             cmp.b   #92,d1
             bne.s   .nxt92
             move.w   #$4335,d1
             jmp     (a1)
.nxt92:
             cmp.b   #93,d1
             bne.s   .nxt93
             move.w   #$4435,d1
             jmp     (a1)
.nxt93:
             cmp.b   #94,d1
             bne.s   .nxt94
             move.w   #$4535,d1
             jmp     (a1)
.nxt94:
             cmp.b   #95,d1
             bne.s   .nxt95
             move.w   #$4635,d1
             jmp     (a1)
.nxt95:
             cmp.b   #96,d1
             bne.s   .nxt96
             move.w   #$3036,d1
             jmp     (a1)
.nxt96:
             cmp.b   #97,d1
             bne.s   .nxt97
             move.w   #$3136,d1
             jmp     (a1)
.nxt97:
             cmp.b   #98,d1
             bne.s   .nxt98
             move.w   #$3236,d1
             jmp     (a1)
.nxt98:
             cmp.b   #99,d1
             bne.s   .nxt99
             move.w   #$3336,d1
             jmp     (a1)
.nxt99:
             cmp.b   #100,d1
             bne.s   .nxt100
             move.w   #$3436,d1
             jmp     (a1)
.nxt100:
             cmp.b   #101,d1
             bne.s   .nxt101
             move.w   #$3536,d1
             jmp     (a1)
.nxt101:
             cmp.b   #102,d1
             bne.s   .nxt102
             move.w   #$3636,d1
             jmp     (a1)
.nxt102:
             cmp.b   #103,d1
             bne.s   .nxt103
             move.w   #$3736,d1
             jmp     (a1)
.nxt103:
             cmp.b   #104,d1
             bne.s   .nxt104
             move.w   #$3836,d1
             jmp     (a1)
.nxt104:
             cmp.b   #105,d1
             bne.s   .nxt105
             move.w   #$3936,d1
             jmp     (a1)
.nxt105:
             cmp.b   #106,d1
             bne.s   .nxt106
             move.w   #$4136,d1
             jmp     (a1)
.nxt106:
             cmp.b   #107,d1
             bne.s   .nxt107
             move.w   #$4236,d1
             jmp     (a1)
.nxt107:
             cmp.b   #108,d1
             bne.s   .nxt108
             move.w   #$4336,d1
             jmp     (a1)
.nxt108:
             cmp.b   #109,d1
             bne.s   .nxt109
             move.w   #$4436,d1
             jmp     (a1)
.nxt109:
             cmp.b   #110,d1
             bne.s   .nxt110
             move.w   #$4536,d1
             jmp     (a1)
.nxt110:
             cmp.b   #111,d1
             bne.s   .nxt111
             move.w   #$4636,d1
             jmp     (a1)
.nxt111:
             cmp.b   #112,d1
             bne.s   .nxt112
             move.w   #$3037,d1
             jmp     (a1)
.nxt112:
             cmp.b   #113,d1
             bne.s   .nxt113
             move.w   #$3137,d1
             jmp     (a1)
.nxt113:
             cmp.b   #114,d1
             bne.s   .nxt114
             move.w   #$3237,d1
             jmp     (a1)
.nxt114:
             cmp.b   #115,d1
             bne.s   .nxt115
             move.w   #$3337,d1
             jmp     (a1)
.nxt115:
             cmp.b   #116,d1
             bne.s   .nxt116
             move.w   #$3437,d1
             jmp     (a1)
.nxt116:
             cmp.b   #117,d1
             bne.s   .nxt117
             move.w   #$3537,d1
             jmp     (a1)
.nxt117:
             cmp.b   #118,d1
             bne.s   .nxt118
             move.w   #$3637,d1
             jmp     (a1)
.nxt118:
             cmp.b   #119,d1
             bne.s   .nxt119
             move.w   #$3737,d1
             jmp     (a1)
.nxt119:
             cmp.b   #120,d1
             bne.s   .nxt120
             move.w   #$3837,d1
             jmp     (a1)
.nxt120:
             cmp.b   #121,d1
             bne.s   .nxt121
             move.w   #$3937,d1
             jmp     (a1)
.nxt121:
             cmp.b   #122,d1
             bne.s   .nxt122
             move.w   #$4137,d1
             jmp     (a1)
.nxt122:
             cmp.b   #123,d1
             bne.s   .nxt123
             move.w   #$4237,d1
             jmp     (a1)
.nxt123:
             cmp.b   #124,d1
             bne.s   .nxt124
             move.w   #$4337,d1
             jmp     (a1)
.nxt124:
             cmp.b   #125,d1
             bne.s   .nxt125
             move.w   #$4437,d1
             jmp     (a1)
.nxt125:
             cmp.b   #126,d1
             bne.s   .nxt126
             move.w   #$4537,d1
             jmp     (a1)
.nxt126:
             cmp.b   #127,d1
             bne.s   .nxt127
             move.w   #$4637,d1
             jmp     (a1)
.nxt127:
             cmp.b   #128,d1
             bne.s   .nxt128
             move.w   #$3038,d1
             jmp     (a1)
.nxt128:
             cmp.b   #129,d1
             bne.s   .nxt129
             move.w   #$3138,d1
             jmp     (a1)
.nxt129:
             cmp.b   #130,d1
             bne.s   .nxt130
             move.w   #$3238,d1
             jmp     (a1)
.nxt130:
             cmp.b   #131,d1
             bne.s   .nxt131
             move.w   #$3338,d1
             jmp     (a1)
.nxt131:
             cmp.b   #132,d1
             bne.s   .nxt132
             move.w   #$3438,d1
             jmp     (a1)
.nxt132:
             cmp.b   #133,d1
             bne.s   .nxt133
             move.w   #$3538,d1
             jmp     (a1)
.nxt133:
             cmp.b   #134,d1
             bne.s   .nxt134
             move.w   #$3638,d1
             jmp     (a1)
.nxt134:
             cmp.b   #135,d1
             bne.s   .nxt135
             move.w   #$3738,d1
             jmp     (a1)
.nxt135:
             cmp.b   #136,d1
             bne.s   .nxt136
             move.w   #$3838,d1
             jmp     (a1)
.nxt136:
             cmp.b   #137,d1
             bne.s   .nxt137
             move.w   #$3938,d1
             jmp     (a1)
.nxt137:
             cmp.b   #138,d1
             bne.s   .nxt138
             move.w   #$4138,d1
             jmp     (a1)
.nxt138:
             cmp.b   #139,d1
             bne.s   .nxt139
             move.w   #$4238,d1
             jmp     (a1)
.nxt139:
             cmp.b   #140,d1
             bne.s   .nxt140
             move.w   #$4338,d1
             jmp     (a1)
.nxt140:
             cmp.b   #141,d1
             bne.s   .nxt141
             move.w   #$4438,d1
             jmp     (a1)
.nxt141:
             cmp.b   #142,d1
             bne.s   .nxt142
             move.w   #$4538,d1
             jmp     (a1)
.nxt142:
             cmp.b   #143,d1
             bne.s   .nxt143
             move.w   #$4638,d1
             jmp     (a1)
.nxt143:
             cmp.b   #144,d1
             bne.s   .nxt144
             move.w   #$3039,d1
             jmp     (a1)
.nxt144:
             cmp.b   #145,d1
             bne.s   .nxt145
             move.w   #$3139,d1
             jmp     (a1)
.nxt145:
             cmp.b   #146,d1
             bne.s   .nxt146
             move.w   #$3239,d1
             jmp     (a1)
.nxt146:
             cmp.b   #147,d1
             bne.s   .nxt147
             move.w   #$3339,d1
             jmp     (a1)
.nxt147:
             cmp.b   #148,d1
             bne.s   .nxt148
             move.w   #$3439,d1
             jmp     (a1)
.nxt148:
             cmp.b   #149,d1
             bne.s   .nxt149
             move.w   #$3539,d1
             jmp     (a1)
.nxt149:
             cmp.b   #150,d1
             bne.s   .nxt150
             move.w   #$3639,d1
             jmp     (a1)
.nxt150:
             cmp.b   #151,d1
             bne.s   .nxt151
             move.w   #$3739,d1
             jmp     (a1)
.nxt151:
             cmp.b   #152,d1
             bne.s   .nxt152
             move.w   #$3839,d1
             jmp     (a1)
.nxt152:
             cmp.b   #153,d1
             bne.s   .nxt153
             move.w   #$3939,d1
             jmp     (a1)
.nxt153:
             cmp.b   #154,d1
             bne.s   .nxt154
             move.w   #$4139,d1
             jmp     (a1)
.nxt154:
             cmp.b   #155,d1
             bne.s   .nxt155
             move.w   #$4239,d1
             jmp     (a1)
.nxt155:
             cmp.b   #156,d1
             bne.s   .nxt156
             move.w   #$4339,d1
             jmp     (a1)
.nxt156:
             cmp.b   #157,d1
             bne.s   .nxt157
             move.w   #$4439,d1
             jmp     (a1)
.nxt157:
             cmp.b   #158,d1
             bne.s   .nxt158
             move.w   #$4539,d1
             jmp     (a1)
.nxt158:
             cmp.b   #159,d1
             bne.s   .nxt159
             move.w   #$4639,d1
             jmp     (a1)
.nxt159:
             cmp.b   #160,d1
             bne.s   .nxt160
             move.w   #$3041,d1
             jmp     (a1)
.nxt160:
             cmp.b   #161,d1
             bne.s   .nxt161
             move.w   #$3141,d1
             jmp     (a1)
.nxt161:
             cmp.b   #162,d1
             bne.s   .nxt162
             move.w   #$3241,d1
             jmp     (a1)
.nxt162:
             cmp.b   #163,d1
             bne.s   .nxt163
             move.w   #$3341,d1
             jmp     (a1)
.nxt163:
             cmp.b   #164,d1
             bne.s   .nxt164
             move.w   #$3441,d1
             jmp     (a1)
.nxt164:
             cmp.b   #165,d1
             bne.s   .nxt165
             move.w   #$3541,d1
             jmp     (a1)
.nxt165:
             cmp.b   #166,d1
             bne.s   .nxt166
             move.w   #$3641,d1
             jmp     (a1)
.nxt166:
             cmp.b   #167,d1
             bne.s   .nxt167
             move.w   #$3741,d1
             jmp     (a1)
.nxt167:
             cmp.b   #168,d1
             bne.s   .nxt168
             move.w   #$3841,d1
             jmp     (a1)
.nxt168:
             cmp.b   #169,d1
             bne.s   .nxt169
             move.w   #$3941,d1
             jmp     (a1)
.nxt169:
             cmp.b   #170,d1
             bne.s   .nxt170
             move.w   #$4141,d1
             jmp     (a1)
.nxt170:
             cmp.b   #171,d1
             bne.s   .nxt171
             move.w   #$4241,d1
             jmp     (a1)
.nxt171:
             cmp.b   #172,d1
             bne.s   .nxt172
             move.w   #$4341,d1
             jmp     (a1)
.nxt172:
             cmp.b   #173,d1
             bne.s   .nxt173
             move.w   #$4441,d1
             jmp     (a1)
.nxt173:
             cmp.b   #174,d1
             bne.s   .nxt174
             move.w   #$4541,d1
             jmp     (a1)
.nxt174:
             cmp.b   #175,d1
             bne.s   .nxt175
             move.w   #$4641,d1
             jmp     (a1)
.nxt175:
             cmp.b   #176,d1
             bne.s   .nxt176
             move.w   #$3042,d1
             jmp     (a1)
.nxt176:
             cmp.b   #177,d1
             bne.s   .nxt177
             move.w   #$3142,d1
             jmp     (a1)
.nxt177:
             cmp.b   #178,d1
             bne.s   .nxt178
             move.w   #$3242,d1
             jmp     (a1)
.nxt178:
             cmp.b   #179,d1
             bne.s   .nxt179
             move.w   #$3342,d1
             jmp     (a1)
.nxt179:
             cmp.b   #180,d1
             bne.s   .nxt180
             move.w   #$3442,d1
             jmp     (a1)
.nxt180:
             cmp.b   #181,d1
             bne.s   .nxt181
             move.w   #$3542,d1
             jmp     (a1)
.nxt181:
             cmp.b   #182,d1
             bne.s   .nxt182
             move.w   #$3642,d1
             jmp     (a1)
.nxt182:
             cmp.b   #183,d1
             bne.s   .nxt183
             move.w   #$3742,d1
             jmp     (a1)
.nxt183:
             cmp.b   #184,d1
             bne.s   .nxt184
             move.w   #$3842,d1
             jmp     (a1)
.nxt184:
             cmp.b   #185,d1
             bne.s   .nxt185
             move.w   #$3942,d1
             jmp     (a1)
.nxt185:
             cmp.b   #186,d1
             bne.s   .nxt186
             move.w   #$4142,d1
             jmp     (a1)
.nxt186:
             cmp.b   #187,d1
             bne.s   .nxt187
             move.w   #$4242,d1
             jmp     (a1)
.nxt187:
             cmp.b   #188,d1
             bne.s   .nxt188
             move.w   #$4342,d1
             jmp     (a1)
.nxt188:
             cmp.b   #189,d1
             bne.s   .nxt189
             move.w   #$4442,d1
             jmp     (a1)
.nxt189:
             cmp.b   #190,d1
             bne.s   .nxt190
             move.w   #$4542,d1
             jmp     (a1)
.nxt190:
             cmp.b   #191,d1
             bne.s   .nxt191
             move.w   #$4642,d1
             jmp     (a1)
.nxt191:
             cmp.b   #192,d1
             bne.s   .nxt192
             move.w   #$3043,d1
             jmp     (a1)
.nxt192:
             cmp.b   #193,d1
             bne.s   .nxt193
             move.w   #$3143,d1
             jmp     (a1)
.nxt193:
             cmp.b   #194,d1
             bne.s   .nxt194
             move.w   #$3243,d1
             jmp     (a1)
.nxt194:
             cmp.b   #195,d1
             bne.s   .nxt195
             move.w   #$3343,d1
             jmp     (a1)
.nxt195:
             cmp.b   #196,d1
             bne.s   .nxt196
             move.w   #$3443,d1
             jmp     (a1)
.nxt196:
             cmp.b   #197,d1
             bne.s   .nxt197
             move.w   #$3543,d1
             jmp     (a1)
.nxt197:
             cmp.b   #198,d1
             bne.s   .nxt198
             move.w   #$3643,d1
             jmp     (a1)
.nxt198:
             cmp.b   #199,d1
             bne.s   .nxt199
             move.w   #$3743,d1
             jmp     (a1)
.nxt199:
             cmp.b   #200,d1
             bne.s   .nxt200
             move.w   #$3843,d1
             jmp     (a1)
.nxt200:
             cmp.b   #201,d1
             bne.s   .nxt201
             move.w   #$3943,d1
             jmp     (a1)
.nxt201:
             cmp.b   #202,d1
             bne.s   .nxt202
             move.w   #$4143,d1
             jmp     (a1)
.nxt202:
             cmp.b   #203,d1
             bne.s   .nxt203
             move.w   #$4243,d1
             jmp     (a1)
.nxt203:
             cmp.b   #204,d1
             bne.s   .nxt204
             move.w   #$4343,d1
             jmp     (a1)
.nxt204:
             cmp.b   #205,d1
             bne.s   .nxt205
             move.w   #$4443,d1
             jmp     (a1)
.nxt205:
             cmp.b   #206,d1
             bne.s   .nxt206
             move.w   #$4543,d1
             jmp     (a1)
.nxt206:
             cmp.b   #207,d1
             bne.s   .nxt207
             move.w   #$4643,d1
             jmp     (a1)
.nxt207:
             cmp.b   #208,d1
             bne.s   .nxt208
             move.w   #$3044,d1
             jmp     (a1)
.nxt208:
             cmp.b   #209,d1
             bne.s   .nxt209
             move.w   #$3144,d1
             jmp     (a1)
.nxt209:
             cmp.b   #210,d1
             bne.s   .nxt210
             move.w   #$3244,d1
             jmp     (a1)
.nxt210:
             cmp.b   #211,d1
             bne.s   .nxt211
             move.w   #$3344,d1
             jmp     (a1)
.nxt211:
             cmp.b   #212,d1
             bne.s   .nxt212
             move.w   #$3444,d1
             jmp     (a1)
.nxt212:
             cmp.b   #213,d1
             bne.s   .nxt213
             move.w   #$3544,d1
             jmp     (a1)
.nxt213:
             cmp.b   #214,d1
             bne.s   .nxt214
             move.w   #$3644,d1
             jmp     (a1)
.nxt214:
             cmp.b   #215,d1
             bne.s   .nxt215
             move.w   #$3744,d1
             jmp     (a1)
.nxt215:
             cmp.b   #216,d1
             bne.s   .nxt216
             move.w   #$3844,d1
             jmp     (a1)
.nxt216:
             cmp.b   #217,d1
             bne.s   .nxt217
             move.w   #$3944,d1
             jmp     (a1)
.nxt217:
             cmp.b   #218,d1
             bne.s   .nxt218
             move.w   #$4144,d1
             jmp     (a1)
.nxt218:
             cmp.b   #219,d1
             bne.s   .nxt219
             move.w   #$4244,d1
             jmp     (a1)
.nxt219:
             cmp.b   #220,d1
             bne.s   .nxt220
             move.w   #$4344,d1
             jmp     (a1)
.nxt220:
             cmp.b   #221,d1
             bne.s   .nxt221
             move.w   #$4444,d1
             jmp     (a1)
.nxt221:
             cmp.b   #222,d1
             bne.s   .nxt222
             move.w   #$4544,d1
             jmp     (a1)
.nxt222:
             cmp.b   #223,d1
             bne.s   .nxt223
             move.w   #$4644,d1
             jmp     (a1)
.nxt223:
             cmp.b   #224,d1
             bne.s   .nxt224
             move.w   #$3045,d1
             jmp     (a1)
.nxt224:
             cmp.b   #225,d1
             bne.s   .nxt225
             move.w   #$3145,d1
             jmp     (a1)
.nxt225:
             cmp.b   #226,d1
             bne.s   .nxt226
             move.w   #$3245,d1
             jmp     (a1)
.nxt226:
             cmp.b   #227,d1
             bne.s   .nxt227
             move.w   #$3345,d1
             jmp     (a1)
.nxt227:
             cmp.b   #228,d1
             bne.s   .nxt228
             move.w   #$3445,d1
             jmp     (a1)
.nxt228:
             cmp.b   #229,d1
             bne.s   .nxt229
             move.w   #$3545,d1
             jmp     (a1)
.nxt229:
             cmp.b   #230,d1
             bne.s   .nxt230
             move.w   #$3645,d1
             jmp     (a1)
.nxt230:
             cmp.b   #231,d1
             bne.s   .nxt231
             move.w   #$3745,d1
             jmp     (a1)
.nxt231:
             cmp.b   #232,d1
             bne.s   .nxt232
             move.w   #$3845,d1
             jmp     (a1)
.nxt232:
             cmp.b   #233,d1
             bne.s   .nxt233
             move.w   #$3945,d1
             jmp     (a1)
.nxt233:
             cmp.b   #234,d1
             bne.s   .nxt234
             move.w   #$4145,d1
             jmp     (a1)
.nxt234:
             cmp.b   #235,d1
             bne.s   .nxt235
             move.w   #$4245,d1
             jmp     (a1)
.nxt235:
             cmp.b   #236,d1
             bne.s   .nxt236
             move.w   #$4345,d1
             jmp     (a1)
.nxt236:
             cmp.b   #237,d1
             bne.s   .nxt237
             move.w   #$4445,d1
             jmp     (a1)
.nxt237:
             cmp.b   #238,d1
             bne.s   .nxt238
             move.w   #$4545,d1
             jmp     (a1)
.nxt238:
             cmp.b   #239,d1
             bne.s   .nxt239
             move.w   #$4645,d1
             jmp     (a1)
.nxt239:
             cmp.b   #240,d1
             bne.s   .nxt240
             move.w   #$3046,d1
             jmp     (a1)
.nxt240:
             cmp.b   #241,d1
             bne.s   .nxt241
             move.w   #$3146,d1
             jmp     (a1)
.nxt241:
             cmp.b   #242,d1
             bne.s   .nxt242
             move.w   #$3246,d1
             jmp     (a1)
.nxt242:
             cmp.b   #243,d1
             bne.s   .nxt243
             move.w   #$3346,d1
             jmp     (a1)
.nxt243:
             cmp.b   #244,d1
             bne.s   .nxt244
             move.w   #$3446,d1
             jmp     (a1)
.nxt244:
             cmp.b   #245,d1
             bne.s   .nxt245
             move.w   #$3546,d1
             jmp     (a1)
.nxt245:
             cmp.b   #246,d1
             bne.s   .nxt246
             move.w   #$3646,d1
             jmp     (a1)
.nxt246:
             cmp.b   #247,d1
             bne.s   .nxt247
             move.w   #$3746,d1
             jmp     (a1)
.nxt247:
             cmp.b   #248,d1
             bne.s   .nxt248
             move.w   #$3846,d1
             jmp     (a1)
.nxt248:
             cmp.b   #249,d1
             bne.s   .nxt249
             move.w   #$3946,d1
             jmp     (a1)
.nxt249:
             cmp.b   #250,d1
             bne.s   .nxt250
             move.w   #$4146,d1
             jmp     (a1)
.nxt250:
             cmp.b   #251,d1
             bne.s   .nxt251
             move.w   #$4246,d1
             jmp     (a1)
.nxt251:
             cmp.b   #252,d1
             bne.s   .nxt252
             move.w   #$4346,d1
             jmp     (a1)
.nxt252:
             cmp.b   #253,d1
             bne.s   .nxt253
             move.w   #$4446,d1
             jmp     (a1)
.nxt253:
             cmp.b   #254,d1
             bne.s   .nxt254
             move.w   #$4546,d1
             jmp     (a1)
.nxt254:
             cmp.b   #255,d1
             bne.s   .nxt255
             move.w   #$4646,d1
             jmp     (a1)
.nxt255:
         move.w   #$0,d1
         jmp     (a1)


;------------------------------------------------------------------------------------------


; STATIC Data located here.  (HEY!! it IS in ROM!)

MEMCheckPattern:
	dc.l	$aaaaaaaa,$55555555,$f0f0f0f0,$0f0f0f0f,$ffffffff,0,0
MEMCheckPatternFast:
	dc.l	$aaaaaaaa,$55555555,$f0f0f0f0,$0f0f0f0f,0,0

RomFont:
	incbin	"TopazFont.bin"
EndRomFont:
	EVEN

RomMenuCopper:
MenuSprite:
	dc.l	$01200000,$01220000,$01240000,$01260000,$01280000,$012a0000,$012c0000,$012e0000,$01300000,$01320000,$01340000,$01360000,$01380000,$013a0000,$013c0000,$013e0000

	dc.l	$0100b200,$0092003c,$009400d4,$008e2c81,$00902cc1,$01020000,$01080000,$010a0000
	dc.l	$01800000,$01820f00,$018400f0,$01860ff0,$0188000f,$018a0f0f,$018c00ff,$018e0fff,$01900ff0

MenuBplPnt:
	dc.l	$00e00000,$00e20000,$00e40000,$00e60000,$00e80000,$00ea0000
	dc.l	$fffffffe	;End of copperlist
EndRomMenuCopper:


RomEcsCopper:
	dc.l	$01200000,$01220000,$01240000,$01260000,$01280000,$012a0000,$012c0000,$012e0000,$01300000,$01320000,$01340000,$01360000,$0138000,$013a0000,$013c0000,$013e0000
	dc.l	$01005200,$00920038,$009400d0,$008e2c81,$00902cc1,$01020000,$01080000,$010a0000

	blk.l	32,0
;MenuBplPnt2:
	dc.l	$00e00000,$00e20000,$00e40000,$00e60000,$00e80000,$00ea0000,$00ec0000,$00ee0000,$00f00000,$00f20000

	dc.l	$fffffffe	;End of copperlist
EndRomEcsCopper:
RomEcsCopper2:
	dc.l	$01200000,$01220000,$01240000,$01260000,$01280000,$012a0000,$012c0000,$012e0000,$01300000,$01320000,$01340000,$01360000,$0138000,$013a0000,$013c0000,$013e0000
	dc.l	$01005200,$00920038,$009400d0,$008e2c81,$00902cc1,$01020000,$01080004,$010a0004

	blk.l	32,0
;MenuBplPnt2:
	dc.l	$00e00000,$00e20000,$00e40000,$00e60000,$00e80000,$00ea0000,$00ec0000,$00ee0000,$00f00000,$00f20000

	dc.l	$fffffffe	;End of copperlist
EndRomEcsCopper2:

ECSColor32:
	dc.w	$000,$fff,$eee,$ddd,$ccc,$aaa,$999,$888,$777,$555,$444,$333,$222,$111,$f00,$800
	dc.w	$400,$0f0,$080,$040,$00f,$008,$004,$ff0,$880,$440,$f0f,$808,$404,$0ff,$088,$044
ECSTestColor:
	dc.w	$000,$aaa,$666,$777,$777,$00b,$76e,$0b0,$397,$790,$0bb,$fff,$971,$b48,$bb0,$888
	dc.w	$999,$333,$b00,$ddd,$333,$444,$555,$666,$777,$888,$999,$aaa,$ccc,$ddd,$eee,$fff
ECSColor16:
	dc.w	$000,$fff,$ddd,$aaa,$888,$555,$333,$f00
	dc.w	$400,$0f0,$040,$00f,$00f,$ff0,$440,$f0f


Texts:

parfftxt:
	dc.b 	"- Parallel Code $ff - Start of ROM, CPU Seems somewhat alive",$a,$d,0
parfetxt:
	dc.b	"- Parallel Code $fe - Test UDS/LDS line",$a,$d,0
parfdtxt:
	dc.b	"- Parallel Code $fd - Start of chipmemdetection",$a,$d,0
parfctxt:
	dc.b	"- Parallel Code $fc - Start of motherboard fastmemdetection",$a,$d,0
parfbtxt:
	dc.b	"- Parallel Code $fb - Memorydetection done",$a,$d,0
parfatxt:
	dc.b	"- Parallel Code $fa - Starting to use detected memory",$a,$d,0
parfatxtdebug:
	dc.b	"   - Debugdata as binary: ",0
parfatxtdebug2:
	dc.b	"  Debugdata done",$a,$d,0
parf9txt:
	dc.b	"- Parallel Code $f9 - Detected memory in use, we now have a stack etc",$a,$d,0
parf8txt:
	dc.b	"- Parallel Code $f8 - Starting up screen, text echoed to serialport",$a,$d,0

par80txt:
	dc.b	"- Parallel Code $80 - NO Chipmem detected",$a,$d,0
par81txt:
	dc.b	"- Parallel Code $fd - Not enough Chipmem detected",$a,$d,0
HALTTXT:
	dc.b	"- NO MEMORY FOUND - HALTING SYSTEM",0

aParallelCodeDD:dc.b '- Parallel Code $dd - Start of Agnus/Gary Bus Tests',$A
		dc.b $D,0

aParallelCodeDE:dc.b '- Parallel Code $de - Start of Zorro Tests', $A, $D, 0
aChipsetMirror	dc.b '    Checking for a chipset mirror: ',0
aFloppyTests	dc.b '- Starting Floppy Tests', $A, $D, 0
aFloppyMTRON	dc.b '    Turning on Disk Motor DF0: ', 0
aFloppyTRK0	dc.b '    Stepping Disk to TRK0: ', 0
aFloppyTRK40	dc.b '    Stepping Disk to Track 40: ', 0

aAccessTests	dc.b '- Starting Access Tests', $A, $D, 0
aAccessFastRAMR	dc.b '    Reading $200000: ',0
aAccessFastRAMW	dc.b '    Writing $200000: ',0
aAccessGary	dc.b '    Reading $DE1000: ',0

aAccessGStatus	dc.b '    Reading $DA8000: ',0
aAccessGChange	dc.b '    Reading $DA9000: ',0

aAccessConf	dc.b '    Reading $E90000: ',0	
aIDETests	dc.b '- Starting IDE Tests', $A, $D, 0
aIDERDY		dc.b '    Waiting for Drive RDY (Mask 0xC1): ', 0
aIDEDRQ		dc.b '    Waiting for Drive DRQ (Mask 0xC9): ', 0
aIDEStatus	dc.b '    Reading Interrupt Status: ', 0
aIDEChange	dc.b '    Reading Interrupt Change: ', 0
aIDERead	dc.b '    Reading Data From Drive: ', 0,0,0
aIDEInterruptCheck dc.b '    Checking we have a pending IDE Interrupt.',$A,$D,0
aIDEInterruptClearedDrive dc.b '    IDE Interrupt Cleared at the Drive',$A,$D,0
aIDEInterruptDetected dc.b '    IDE Interrupt Detected',$A,$D,0
aIDEInterruptNotDetected dc.b '    IDE Interrupt Not Detected: ',0
aIDEInterruptIntChangedReading dc.b '    Reading Gayle IntChanged: ', 0
aIDEInterruptIntChangedWriting dc.b '    Writing Gayle IntChanged: ', 0
aIDEInterruptIntStatusReading dc.b '    Reading Gayle IntStatus: ', 0
aMirrorNotDetected dc.b ' Mirror Not Detected ', $A, $D, 0
aMirrorDetected dc.b ' Mirror Detected ', $A, $D, 0
aIDEInterfaceNotFound dc.b '    No IDE Interface Found (Aborting IDE Tests)', $A, $D, 0
aIDEInterfaceFound dc.b '    IDE Interface Found (Running IDE Tests)', $A, $D, 0
aReadGayleVersion dc.b '    Reading Gayle Version: ',0

aCacheTests	dc.b '- Starting Cache Tests', $A, $D, 0
aCACRRead	dc.b '    Reading CACR Register:', 0
aCACRWrite	dc.b '    Writing CACR Register:', 0
	
aCacheWriteByte	dc.b '    Writing Byte to Cached Memory ', 0
aCacheWriteWord	dc.b '    Writing Word to Cached Memory ', 0
aCacheWriteLong	dc.b '    Writing Long to Cached Memory ', 0

aCacheReadByte	dc.b '    Reading Byte from Cached Memory ', 0
aCacheReadWord	dc.b '    Reading Word from Cached Memory ', 0
aCacheReadLong	dc.b '    Reading Long from Cached Memory ', 0
	
aFPUTests	dc.b '- Starting FPU Tests', $A, $D, 0
aFPUReset	dc.b '  Resetting the FPU: ',0
aFPUVersion	dc.b '  Checking FPU Version: ',0
aFPUStatus	dc.b '  Reading  FPU Status: ',0
aFPUFound:	dc.b ' FOUND',$A, $D,0
aFPUNotFound:	dc.b ' NOT FOUND',$A, $D,0
aFPU81:	dc.b 'MC68881',$A, $D,0
aFPU82:	dc.b 'MC68882',$A, $D,0
aCrLf		dc.b	$A,$d,0
aZRAMError: 	dc.b '   - Error Detected. Expected: ',0
aZRAMActual: 	dc.b 'Actual: ',0
aZorroTest: 	dc.b '   - Zorro Byte Read: ',0
aZorroDone: 	dc.b 'NO MORE BOARDS',$A, $D,0
aZorroIIICheck 	dc.b 'Checking in Z3 Space',$A, $D,0
aZorroTestEqual:dc.b '   - Checking Zorro Consistent Read: ',0
aZorroDoConfig:	dc.b '   - Attempting To Configure: ',0
aZorroIIISkipped:dc.b 'SHUTUP (Zorro III Card)', $A, $D,0
aZorroIINonRAMDone:  dc.b 'DONE (Zorro II Non-RAM Card)', $A, $D,0
aZorroIIDone:  dc.b 'DONE (Zorro II RAM Card)', $A, $D,0
aZorroRAMTest	dc.b '- Checking Zorro Memory Location $200000',  $A, $D,0
aMMCReset	dc.b '- Resetting MMC Card on port 0 ',0
aTestPassed:	dc.b 'PASSED', $A, $D,0
aTestFailed:	dc.b 'FAILED', $A, $D,0

writeffff:
	dc.b	"  - Test of writing word $FFFF to $400 ",0
write00ff:
	dc.b	"  - Test of writing word $00FF to $400 ",0
writeff00:
	dc.b	"  - Test of writing word $FF00 to $400 ",0
write0000:
	dc.b	"  - Test of writing word $0000 to $400 ",0
writebeven:
	dc.b	"  - Test of writing byte (even) $ff to $400 ",0
writebodd:
	dc.b	"  - Test of writing byte (odd) $ff to $401 ",0
	

InitSerial:
	dc.b	1,2,4,8,16,32,64,128,240,15,170,85,$a,$d,$a,$d
	dc.b	"Garbage before this text was binary numbers: 1, 2, 4, 8, 16, 32, 64, 128, 240, 15, 170 and 85",$a,$d
	dc.b	"To help you find biterrors to paula. Now starting normal startuptext etc",$a,$d
	dc.b	12,27,"[0m"
InitTxt:
	dc.b	"Amiga DiagROM "
	VERSION
	dc.b	" - "
		incbin	"BuildDate.txt"
	dc.b	" - By John (Chucky/The Gang) Hertell",$a,$d,$a,$d,0
LoopSerTest:
	dc.b	$a,$d,"Testing if serial loopbackadapter is installed: ",0

WaitReleasedTxt:
	dc.b	"Waiting for all buttons to be released",$a
	dc.b	"Release all buttons NOW or they will be disabled",$a,0

Initmousetxt:
	dc.b	"    Checking status of mousebuttons for different startups: ",$a,$d
	dc.b	"            ",0
InitINTENAtxt:
	dc.b	"    Set all Interrupt enablebits (INTENA $dff09a) to Disabled: ",0
InitINTREQtxt:
	dc.b	"    Set all Interrupt requestbits (INTREQ $dff09c) to Disabled: ",0
InitDMACONtxt:
	dc.b	"    Set all DMA enablebits (DMACON $dff096) to Disabled: ",0
InitCOP1LCH:
	dc.b	"    Set Start of copper (COP1LCH $dff080): ",0
InitCOPJMP1:
	dc.b	"    Starting Copper (COPJMP1 $dff088): ",0
InitDMACON:
	dc.b	"    Set all DMA enablebits (DMACON $dff096) to Enabled: ",0
InitBEAMCON0:
	dc.b	"    Set Beam Conter control register to 32 (PAL) (BEAMCON0 $dff1dc): ",0
InitPOTGO:
	dc.b	"    Set POTGO to all OUTPUT ($FF00) (POTGO $dff034): ",0

InitDONEtxt:
	dc.b	"Done",$a,$d,0	
Donetxt:
	dc.b	"Done",$a,0
InitP1LMBtxt:
	dc.b	"P1LMB ",0
InitP2LMBtxt:
	dc.b	"P2LMB ",0
InitP1RMBtxt:
	dc.b	"P1RMB ",0
InitP2RMBtxt:
	dc.b	"P2RMB ",0

InitSerial2:
	dc.b	$a,$d,$a,$d,"To use serial communication please hold down ANY key now",$a,$d
	dc.b	"OR click the RIGHT mousebutton.",$a,$d
	dc.b	"Holding down the LEFT mousebutton will force serial on and turn off screen",$a,$d
	dc.b	"forcing stuff to run in fastmem if avaible",$a,$d,$a,$d,0
EndSerial:
	dc.b	27,"[0m",$a,$d,"No key pressed, disabling any serialcommunications. Enable it in program",$a,$d,0

Ansi:
	dc.b	27,"[",0
AnsiNull:
	dc.b	27,"[0m",27,"[40m",27,"[37m",0
Black:
	dc.b	27,"[30m",0
StatusLine:
	dc.b	"Serial: ",1,1,1,1,1," BPS - CPU: ",1,1,1,1,1," - Chip: ",1,1,1,1,1,1," - KBFast: ",1,1,1,1,1,1," Base: ",0
Space3:
	dc.b	"   ",0

	EVEN
	
CPU:	dc.b	"680x0",0,"68010",0,"68020",0,"68030",0,"68040",0,"68060",0,"68???",0

Bps:
	dc.l	BpsNone,Bps2400,Bps9600,Bps38400,Bps115200,BpsLoop
	
BpsNone:
	dc.b	"N/A   ",0
Bps2400:
	dc.b	"2400  ",0
Bps9600:
	dc.b	"9600  ",0
Bps38400:
	dc.b	"38400 ",0
Bps115200:
	dc.b	"115200",0
BpsLoop:
	dc.b	"LOOP  ",0
ON:
	dc.b	"ON ",0
OFF:
	dc.b	"OFF",0
YES:
	dc.b	"YES",0
NO:
	dc.b	"NO ",0
SPACE:
	dc.b	" ",0
MB:
	dc.b	"MB",0
KB:
	dc.b	"KB",0
DOWN:
	dc.b	"DOWN",0
UP:
	dc.b	"UP  ",0
LEFT:
	dc.b	"LEFT",0
RIGHT:
	dc.b	"RIGHT",0
FIRE:
	dc.b	"FIRE",0
FAILED:
	dc.b	"FAILED",0
DDETECTED:
	dc.b	" DETECTED",$a,$d,0
DETECTED:
	dc.b	"DETECTED",0
NoLoopback:
	dc.b	" NOT DETECTED",$a,$d,0
CANCELED:
	dc.b	"CANCELED",0
II:
	dc.b	" II",0
III:
	dc.b	"III",0
UPPER:
	dc.b	"Upper",0
LOWER:
	dc.b	"Lower",0
OOK:
	dc.b	" "	; Combined with next will generate a space before OK. nothing between here
OK:
	dc.b	"OK",0
BAD:
	dc.b	"BAD",0
MinusTxt:
	dc.b	" - ",0	
SPACEOK:
	dc.b	"   OK",0
SPACEFAIL:
	dc.b	"  FAILED",$a,$d,0
ms:
	dc.b	"ms",0
space8:
	dc.b	"        ",0
ticks:
	dc.b	" Ticks",0
Bytes:
	dc.b	" Bytes",0
DF0:
	dc.b	"DF0:",0
DF1:
	dc.b	"DF1:",0
DF2:
	dc.b	"DF2:",0
DF3:
	dc.b	"DF3:",0

Track:
	dc.b	"Track: ",0
Side:
	dc.b	"Side: ",0
Motor:
	dc.b	"Motor: ",0
WProtect:
	dc.b	"WProtection: ",0
DiskIN:
	dc.b	"Disk: ",0
RDY:
	dc.b	"Ready: ",0
TRACK0:
	dc.b	"Track0: ",0
BFE001Txt:
	dc.b	"$bfe001: ",0
BFD100Txt:
	dc.b	"$bfd100: ",0

	EVEN
SerSpeeds:		; list of Baudrates (3579545/BPS)+1
	dc.l	0,1492,373,94,32,0,0
SerText:
	dc.l	BpsNone,Bps2400,Bps9600,Bps38400,Bps115200,BpsLoop,BpsNone
	
Menus:					; Pointers to the menus
	dc.l	MainMenuItems,0,AudioMenuItems,MemtestMenuItems,IRQCIAtestMenuItems,GFXtestMenuItems,PortTestMenuItems,OtherTestItems,DiskTestMenuItems,0,0
MenuCode:				; Pointers to pointers of the menus.
	dc.l	MainMenuCode,0,AudioMenuCode,MemtestMenuCode,IRQCIAtestMenuCode,GFXtestMenuCode,PortTestMenuCode,OtherTestCode,DiskTestMenuCode,0,0
MenuKeys:
	dc.l	MainMenuKey,0,AudioMenuKey,MemtestMenuKey,IRQCIAtestMenuKey,GFXtestMenuKey,PortTestMenuKey,OtherTestKey,DiskTestMenuKey,0,0

MainMenuText:
	dc.b	"                    DiagROM "
		ifne	a1k
		dc.b	"A1000 "
		endc
	VERSION
	dc.b	" - Amiga32 Edition"," - "
	incbin	"BuildDate.txt"
	dc.b	$a
	dc.b	"                        By John (Chucky / The Gang) Hertell",$a,$a
	dc.b	"                                       MAIN MENU",$a,$a,0

MainMenu1:
	dc.b	"0 - Systeminfo",0
MainMenu2:
	dc.b	"1 - Audiotests",0
MainMenu3:
	dc.b	"2 - Memorytests",0
MainMenu4:
	dc.b	"3 - IRQ/CIA Tests",0
MainMenu5:
	dc.b	"4 - Graphictests",0
MainMenu6:
	dc.b	"5 - Porttests",0
MainMenu7:
	dc.b	"6 - Drivetests",0
MainMenu8:
	dc.b	"7 - Keyboardtests",0
MainMenu9:
	dc.b	"8 - Other tests",0
MainMenu10:
	dc.b	"S - Setup",0
	EVEN
MainMenuItems:
	dc.l	MainMenuText,MainMenu1,MainMenu2,MainMenu3,MainMenu4,MainMenu5,MainMenu6,MainMenu7,MainMenu8,MainMenu9,MainMenu10,0,0
MainMenuCode:
	dc.l	SystemInfoTest,AudioMenu,MemtestMenu,IRQCIAtestMenu,GFXtestMenu,PortTestMenu,DiskTest,KeyBoardTest,OtherTest,Setup
MainMenuKey:	; Keys needed to choose menu. first byte keykode 2:nd byte serialcode.
	dc.b	"0","1","2","3","4","5","6","7","8","9","s",0
NotImplTxt:
	dc.b	2,"This function is not implemented yet. Anyday.. soon(tm), Thursday?",$a,$a,0
NotA1kTxt:
	dc.b	2,"This function is not available on A1000 version",$a,$a,0
AnyKeyMouseTxt:
	dc.b	2,"Press any key/mouse to continue",0
SetupTxt:
	dc.b	2,"Setupmenu",$a,0



SystemInfoTxt:
	dc.b	2,"Information of this machine:",$a,$a,0
ChipstartTxt:
	dc.b	"Chipmem starts at: ",0
AndendTxt:
	dc.b	" and Ends at: ",0
UnusedChipTxt:
	dc.b	"  Unused chip: ",0
SystemInfoHWTxt:
	dc.b	2,"Dump of all readable Custom Chipset HW Registers:",$a,0

	EVEN
DriveTestMenu:
	dc.l	DriveTestMenuItems,0
	dc.l	0
DriveTestMenuItems:
	dc.l	DriveTestMenu0,DriveTestMenu1,DriveTestMenu2,DriveTestMenu3,DriveTestMenu4,DriveTestMenu5,DriveTestMenu6,DriveTestMenu7,DriveTestMenu8,DriveTestMenu9,DriveTestMenu10,DriveTestMenu11,DriveTestMenu12,0
DriveTestMenuKey:
	dc.b	"1","2","3","4","5","6","7","8","9","s","0",$1b,0
DriveTestMenu0:
	dc.b	2,"Diskdrivetesting Menu",0
DriveTestMenu1:
	dc.b	"1 - Select disk: ",0
DriveTestMenu2:
	dc.b	"2 - Motor",0
DriveTestMenu3:
	dc.b	"3 - Change side",0
DriveTestMenu4:
	dc.b	"4 - Step out",0
DriveTestMenu5:
	dc.b	"5 - Step in",0
DriveTestMenu6:
	dc.b	"6 - Step out 10 tracks",0
DriveTestMenu7:
	dc.b	"7 - Step in 10 tracks",0
DriveTestMenu8:
	dc.b	"8 - Read track to buffer",0
DriveTestMenu9:
	dc.b	"9 - Write track from buffer **DANGEROUS EXPERIMENTAL**",0
DriveTestMenu10:
	dc.b	"S - Show first read sector (random) in buffermem",0
DriveTestMenu11:
	dc.b	"0 - Automatic test of selected disk",0
DriveTestMenu12:
	dc.b	"Esc - Exit from menu",0

AudioMenuText:
	dc.b	2,"Audiotests",$a,$a,0
AudioMenu1:
	dc.b	"1 - Simple waveformtest",0
AudioMenu2:
	dc.b	"2 - Play test-module",0
AudioMenu3:
	dc.b	"9 - MainMenu",0
	EVEN
AudioMenuItems:
	dc.l	AudioMenuText,AudioMenu1,AudioMenu2,AudioMenu3,0
AudioMenuCode:
	dc.l	AudioSimple,AudioMod,MainMenu
AudioMenuKey:
	dc.b	"1","2","9",0

AudioSimpleMenu:
	dc.l	AudioSimpleWaveItems,0
	dc.l	0
AudioSimpleWaveItems:
	dc.l	AudioSimpleWaveText,AudioSimpleWaveMenu1,AudioSimpleWaveMenu2,AudioSimpleWaveMenu3,AudioSimpleWaveMenu4,AudioSimpleWaveMenu5,AudioSimpleWaveMenu6,AudioSimpleWaveMenu7,AudioSimpleWaveMenu8,0,0
AudioSimpleWaveText:
	dc.b	2,"Simple Audiowavetest",0
AudioSimpleWaveMenu1:
	dc.b	"1 - Channel 1:",0
AudioSimpleWaveMenu2:
	dc.b	"2 - Channel 2:",0
AudioSimpleWaveMenu3:
	dc.b	"3 - Channel 3:",0
AudioSimpleWaveMenu4:
	dc.b	"4 - Channel 4:",0
AudioSimpleWaveMenu5:
	dc.b	"5 - Volume:",0
AudioSimpleWaveMenu6:
	dc.b	"6 - Waveform:",0
AudioSimpleWaveMenu7:
	dc.b	"7 - Filter:",0
AudioSimpleWaveMenu8:
	dc.b	"9 - AudioMenu",0
AudioSimpleWaveKeys:
	dc.b	"1","2","3","4","5","6","7","9",0
AudioModTxt:
	dc.b	2,"Play a Protracker module",$a,$a,0
AudioModCopyTxt:
	dc.b	"Copying moduledata from ROM to Chipmem: ",0
AudioModInitTxt:
	dc.b	"Initilize module: ",0
AudioModPlayTxt:
		;12345678901234567890123456789012345678901234567890123456789012345678901234567890
	dc.b	2,"Starting to play music, Press any key for option (1,2,3,4,f,+,-,l,r)",$a,0
AudioModOptionTxt:	
	dc.b	$a,"         Channel 1:      Channel 2:      Channel 3:      Channel 4:    ",$a
	dc.b	"                  Audio F)ilter:       Mastervolume (+ -):   ",$a,$a,0
AudioModEndTxt:
	dc.b	2,"Press any button to exit",0
AudioModName:
	dc.b	$a,"Modulename: ",0
AudioModInst:
	dc.b	$a,"Instruments:",$a,0
	EVEN	
MemtestText:
	dc.b	2,"Memorytests",$a,$a,0
MemtestMenu1:
	dc.b	"1 - Test detected chipmem",0
MemtestMenu2:
	dc.b	"2 - Extended chipmemtest",0
MemtestMenu3:
	dc.b	"3 - Test detected fastmem",0
MemtestMenu4:
	dc.b	"4 - Fast scan of 16MB fastmem-areas",0
MemtestMenu5:
	dc.b	"5 - Slow scan of 16MB fastmem-areas",0
MemtestMenu6:
	dc.b	"6 - Large Fast scan of fastmem-areas",0
MemtestMenu7:
	dc.b	"7 - Manual memorytest",0
MemtestMenu8:
	dc.b	"8 - Manual memoryedit",0
MemtestMenu9:
	dc.b	"9 - Autoconfig - Automatic",0
MemtestMenu10:
	dc.b	"0 - Mainmenu",0
	EVEN
MemtestMenuItems:
	dc.l	MemtestText,MemtestMenu1,MemtestMenu2,MemtestMenu3,MemtestMenu4,MemtestMenu5,MemtestMenu6,MemtestMenu7,MemtestMenu8,MemtestMenu9,MemtestMenu10,0
MemtestMenuCode:
	dc.l	CheckDetectedChip,CheckExtendedChip,CheckDetectedMBMem,CheckExtended16MBMem,ForceExtended16MBMem,CheckExtendedMBMem,CheckMemManual,CheckMemEdit,AutoConfig,MainMenu
MemtestMenuKey:
	dc.b	"1","2","3","4","5","6","7","8","9","0",0
	EVEN
OtherTestItems:
	dc.l	OtherTestText,OtherTestMenu1,OtherTestMenu2,OtherTestMenu3,0
OtherTestText:
	dc.b	2,"Other tests",$a,$a,0
OtherTestMenu1:
	dc.b	"1 - RTC Test",0
OtherTestMenu2:
	dc.b	"2 - Autoconfig - Detailed",0
OtherTestMenu3:
	dc.b	"9 - Mainmenu",0
	EVEN
OtherTestCode:
	dc.l	RTCTest,AutoConfigDetail,MainMenu
OtherTestKey:
	dc.b	"1","2","9",0

hextab:
	dc.b	"0123456789ABCDEF"	; For bin->hex convertion

MemtestDetChipTxt:
	dc.b	2,"Checking detected chipmem",0
MemtestExtChipTxt:
	dc.b	2,"Checking full Chipmemarea until 2MB or Shadow-Memory is detected",0
MemtestShadowTxt:
	dc.b	2,"Shadowmemory detected. Scan stopped. You can ignore the last error if any!",0
MemtestDetMBMemTxt:
	dc.b	" Detecting A3000/4000 Motherboard memory: Detected: ",0
MemtestDetMBMemTxt2:
	dc.b	" Detecting CPU Card memory: Detected: ",0
MemtestDetMBMemTxt3:
	dc.b	" Detecting Z2 memoryarea: Detected: ",0
MemtestDetMBMemTxtZ:
	dc.b	" Detecting Z3 memoryarea: Detected: ",0
MemtestExtMBMemTxt:
	dc.b	"Scanning for memory on all fastmem-areas (no autoconfig mem will be scanned)",0
MemtestNORAM:
	dc.b	2,"No memory found, Press any key/mouse!",0
MemtestManualTxt:
	dc.b	"                              Manual memoryscan",$a,$a
	dc.b	"Here you can enter a manual value of memoryadress to test, but please remember",$a
	dc.b	"that only NON Autoconfig memory will be possible to test. and if you select an",$a
	dc.b	"illegal area your machine might behave strange/crash etc.",$a,$a,"You are on your own!",$a,$a
	dc.b	"YOU HAVE BEEN WARNED!!!",$a,$a,$a
	dc.b	"Pressing a mousebutton or ESC cancels this screen",$a,$a
	dc.b	"Please enter startaddress to check from: $",0
MemtestManualEndTxt:
	dc.b	$a,$a,$a,"Please enter endadress to check to: $",0
MemtextManualModeTxt:
	dc.b	$a,$a,"Do you want to do a S)low test or a F)ast test?",0
MemtextManualShadowTxt:
	dc.b	$a,$a,"Do you want to disable shadowramtest? Y)es",0
CheckMemRangeTxt:
	dc.b	"Checking memory from ",1,1,1,1,1,1,1,1,1," to ",1,1,1,1,1,1,1,1,1," - Press any key/mousebutton to stop",0
CheckMemCheckAdrTxt:	
	dc.b	"Checking Address:",1,1,1,1,1,1,1,1,1,1,1,1,0
CheckMemBitErrTxt:
	dc.b	"|  Bit error shows max $FF errors due to space",$a,$a
	dc.b	"            8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1| 8|7|6|5|4|3|2|1|",$a,0
CheckMemBitErrorsTxt:
	dc.b	"Bit errors:",$a
	dc.b	"Byte errors:",$a,0
CheckMemCheckedTxt:
	dc.b	"Checked memory:",0
CheckMemUsableTxt:
	dc.b	"Usable memory:",0	
CheckMemNonUsableTxt:
	dc.b	"NONUsable memory:",0
CheckMemFastModeTxt:
	dc.b	"    ---   Running in Fast-Scan mode!",$a
	dc.b	"Only one longword every 1k block is tested and no errors reported",$a
	dc.b	"Result can be aproximate! No shadowmem tests! Used to scan for memoryareas",$a
	dc.b	"Dead block = ALL bits checked failed, most likly no mem at all",$a
	dc.b	"Bad block = Some bits works, most likly bad memory with biterrors",0	
CheckMemNumErrTxt:
	dc.b	"Number of errors:",0
CheckMemGoodTxt:
	dc.b	"Good Block start at ",0
CheckMemEndAtTxt:
	dc.b	" and ends at ",0
CheckMemSizeOfTxt:
	dc.b	" with a size of ",0
CheckMemBadTxt:
	dc.b	"Bad Block start at ",0
CheckMemDeadTxt:
	dc.b	"Dead Block start at ",0
CheckMemEditTxt:
	dc.b	"  Manual Memoryedit. BE WARNED, EVERYTHING HAPPENS IN REALTIME! NO PROTECTION!",$a
	dc.b	"G)oto address  R)efresh  H)Cache:      ESC)Main Menu",$a,0
CheckMemEditGotoTxt:
	dc.b	"Enter address to dump memory from: $",0
CheckMemAdrTxt:
	dc.b	"Current address: ",0
CheckMemBinaryTxt:
	dc.b	"Current byte in binary: ",0


IRQCIATestText:
	dc.b	2,"IRQ & CIA Tests",$a,$a,0
IRQCIATestMenu1:
	dc.b	"1 - Test IRQs",0
IRQCIATestMenu2:
	dc.b	"2 - Test CIAs",0
IRQCIAtestMenu7:
	dc.b	"9 - Mainmenu",0
	EVEN

IRQLev1Txt:
	dc.b	"Testing IRQ Level 1: ",0
IRQLev2Txt:
	dc.b	"Testing IRQ Level 2: ",0
IRQLev3Txt:
	dc.b	"Testing IRQ Level 3: ",0
IRQLev4Txt:
	dc.b	"Testing IRQ Level 4: ",0
IRQLev5Txt:
	dc.b	"Testing IRQ Level 5: ",0
IRQLev6Txt:
	dc.b	"Testing IRQ Level 6: ",0
IRQLev7Txt:
	dc.b	"Testing IRQ Level 7 (WILL Fail unless you press a custom IRQ7 button): ",0
IRQTestDone:
	dc.b	$a,$a,$a,"IRQ Tests done",$a,0

CIATestTxt:
	dc.b	2,"CIA Tests. Check if your CIAs can time stuff. REQUIRES LEV3 IRQ!",$a,$a,0
CIATestTxt2:
	dc.b	2,"Press any key to start tests (2 sec/each), Press ESC for mainmenu",$a,$a,$a,0
CIATestTxt3:
	dc.b	2,"Flashing on screen is fully normal, indicating CIA timing",$a,$a

CIAATestAATxt:
	dc.b	"Testing Timer A, on CIA-A (ODD) :",$a,0
CIAATestBATxt:
	dc.b	"Testing Timer B, on CIA-A (ODD) :",$a,0
CIATestATOD:
	dc.b	"Testing CIA-A TOD (Tick/VSync)  :",$a,0
CIAATestABTxt:
	dc.b	"Testing Timer A, on CIA-B (EVEN):",$a,0
CIAATestBBTxt:
	dc.b	"Testing Timer B, on CIA-B (EVEN):",$a,0
CIATestBTOD:
	dc.b	"Testing CIA-B TOD (HSync)       :",$a,0
VblankOverrunTXT:
	dc.b	" - CIA Timing too slow! ",0
VblankUnderrunTXT:
	dc.b	" - CIA Timing too fast! ",0
CIATickSlowTxt:
	dc.b	" - Too slow ticksignal ",0
CIATickFastTxt:
	dc.b	" - Too fast ticksignal ",0

CIANoRasterTxt:
	dc.b	2,"CIA Tests requires a working raster, Unable to test",$a,$a,0
CIANoRasterTxt2:
	dc.b	2,"Press any key to return to Main Menu",$a,0
	

	EVEN
IRQCIAtestMenuItems:
	dc.l	IRQCIATestText,IRQCIATestMenu1,IRQCIATestMenu2,IRQCIAtestMenu7,0,0
IRQCIAtestMenuCode:
	dc.l	IRQCIAIRQTest,IRQCIACIATest,MainMenu
IRQCIAtestMenuKey:
	dc.b	"1","2","9",0

IRQCIAIRQTestText:
	dc.b	2,"Testing IRQ Levels. Press any key to start.   ESC or RMB to exit",$a,$a,0
IRQCIAIRQTestText2:
	dc.b	2,"Screen Flashing during test is normal, it is a sign that IRQ is executed",$a,$a,0

	EVEN
GFXtestMenuItems:
	dc.l	GFXtestText,GFXtestMenu1,GFXtestMenu2,GFXtestMenu3,GFXtestMenu4,0
GFXtestMenuCode:
	dc.l	GFXTestScreen,GFXtest320x200,GFXTestScroll,MainMenu,0	
GFXtestMenuKey:
	dc.b	"1","2","3","9",0
GFXtestText:
	dc.b	2,"Graphicstests",$a,$a,0
GFXtestMenu1:
	dc.b	"1 - Testpicture in lowres 32Col",0
GFXtestMenu2:
	dc.b	"2 - Testscreen 320x200",0
GFXtestMenu3:
	dc.b	"3 - Test Scroll",0
GFXtestMenu4:
	dc.b	"9 - Exit to mainmenu",0
GFXtestNoSerial:
	dc.b	$a,$d,$a,$d,"GRAPHICTEST IN ACTION, Serialoutput is not possible during test",$a,$d,$a,$d,0

PortTestText:
	dc.b	2,"Porttests",$a,$a,0
PortTestMenu1:
	dc.b	"1 - Parallel Port",0
PortTestMenu2:
	dc.b	"2 - Serial Port",0
PortTestMenu3:
	dc.b	"3 - Joystick/Mouse Ports",0
PortTestMenu4:
	dc.b	"9 - Mainmenu",0
	EVEN
PortTestMenuItems:
	dc.l	PortTestText,PortTestMenu1,PortTestMenu2,PortTestMenu3,PortTestMenu4,0
PortTestMenuCode:
	dc.l	PortTestPar,PortTestSer,PortTestJoystick,MainMenu
PortTestMenuKey:
	dc.b	"1","2","3","9",0


DiskTestText:
	dc.b	2,"Disktests",$a,$a,0
DiskTestMenu1:
	dc.b	"1 - Diskdrivetest",0
DiskTestMenu2:
	dc.b	"9 - Mainmenu",0
	EVEN
DiskTestMenuItems:
	dc.l	DiskTestText,DiskTestMenu1,DiskTestMenu2,0
DiskTestMenuCode:
	dc.l	DiskdriveTest,MainMenu
DiskTestMenuKey:
	dc.b	"1","9",0

PortParTest:
	dc.b	2,"Parallelport tests",$a,$a,0
PortParTest1:
	dc.b	"To start paralleltest, make sure loopback is connected and press",$a
	dc.b	"any key to start, Press ESC or Right mouse to exit!",$a,$a,0
PortParTest2:
	dc.b	"Build a loopback adapter: Connect 1-10,2-3,4-5,6-7,9-11,8-12-13",$a
	dc.b	"14[+5V] -> LED+270ohm -> 18[GND] (LED will be bright if +5V gives power!)",$a,0
	
PortParTest3:
	dc.b	$a,"Test is running, any button to exit!",0
PortParTest12:
	dc.b	$a,"Testing Bit 1->2: ",0
PortParTest21:
	dc.b	$a,"Testing Bit 2->1: ",0
PortParTest34:
	dc.b	$a,"Testing Bit 3->4: ",0
PortParTest43:
	dc.b	$a,"Testing Bit 4->3: ",0
PortParTest56:
	dc.b	$a,"Testing Bit 5->6: ",0
PortParTest65:
	dc.b	$a,"Testing Bit 6->5: ",0
PortParTest7p:
	dc.b	$a,"Testing Bit 7->Paper out: ",0
PortParTest7s:
	dc.b	$a,"Testing Bit 7->Select: ",0
PortParTestp7:
	dc.b	$a,"Testing Paper out->Bit 7: ",0
PortParTests7:
	dc.b	$a,"Testing Select->Bit 7: ",0
PortParTest8b:
	dc.b	$a,"Testing Bit 8->Busy: ",0
PortParTestb8:
	dc.b	$a,"Testing Busy->Bit 8: ",0


PortSerTest:
	dc.b	2,"Serialport tests",$a,$a,0
PortSerTest1:
	dc.b	"To start serialtest, make sure loopback is connected and press",$a
	dc.b	"any key to start, This means if you are using serialconsole",$a
	dc.b	"you need to change that cable to a loopback adapter and not use",$a
	dc.b	"Serialport for controlling DiagROM!",$a,$a
	dc.b	"Press ESC or Right mouse to exit!",$a,$a,0
PortSerTest2:
	dc.b	"Build a loopback adapter: Connect 2-3, 4-5-6, 8-20-22",$a
	dc.b	"9[+12V] -> LED+1Kohm -> 7[GND]",$a
	dc.b	"7[GND] -> LED+1Kohm -> 10[-12V]",$a
	dc.b	"LED will be bright if +12 and -12V gives power",$a,0

PortSerBps:
	dc.b	"   BPS: ",0
PortSerTest3:
	dc.b	$a,$a,"Testing sending a 60 bytes test, number of correct received chars:        ",0
PortSerTestB45:
	dc.b	$a,"Testing pin 4 (RTS) to pin 5 (CTS):",0
PortSerTestB46:
	dc.b	$a,"Testing pin 4 (RTS) to pin 6 (DSR):",0
PortSerTestB208:
	dc.b	$a,"Testing pin 20 (DTR) to pin 8 (CD):",0

PortSerString:
	;	 123	456789012345678901234567890123456789012345678901234567890"
	dc.b	"This is a serialporttest for loopbackadapter! NOT Console!",$a,$d,0

PortJoyTest:
	dc.b	2,"Joystickport tests",$a,$a,0
PortJoyTest1:
	dc.b	2,"Dumping data of hardwareregisters:",$a,$a,0
PortJoyTestHW1:
	dc.b	2,"JOY0DAT ($DFF00A):       BIN:                 ",$a,0
PortJoyTestHW2:
	dc.b	2,"JOY1DAT ($DFF00C):       BIN:                 ",$a,0
PortJoyTestHW3:
	dc.b	2,"POT0DAT ($DFF012):       BIN:                 ",$a,0
PortJoyTestHW4:
	dc.b	2,"POT1DAT ($DFF014):       BIN:                 ",$a,0
PortJoyTestHW5:
	dc.b	2,"POTINP  ($DFF016):       BIN:                 ",$a,0
PortJoyTestHW6:
	dc.b	2,"CIAAPRA ($BFE001):       BIN:                 ",$a,0

PortJoyTest2:
	dc.b	2,"Joystick positions",$a,$a,0
PortJoyTest3:
	dc.b	2,"PORT0                               PORT1",0
PortJoyTestExitTxt:
	dc.b	2,"Exit with both mousebuttons or ESC",0


KeyBoardTestText:
	dc.b	2,"Keyboardtest ESC or mouse to exit",$a,$a,0
KeyBoardTestCodeTxt:
	dc.b	"Current Scancode read from Keyboardbuffer:      Keyboardcode:      Char: ",$a,0
KeyBoardTestCodeTxt2:
	dc.b	"Scancode binary:           HEX:      Keyboardcode binary:           HEX: ",0
RTCByteTxt:
	dc.b	"Raw RTC data in hex:",$a,0

RTCBitTxt:
	dc.b	"Raw RTC data in binary:",$a,0
RTCRicoh:
	dc.b	"Ricoh Chipset output:",$a,0
RTCOKI:
	dc.b	"OKI Chipset output:",$a,0
	EVEN
RTCMonth:
	dc.b	"Jan",0
	dc.b	"Feb",0
	dc.b	"Mar",0
	dc.b	"Apr",0
	dc.b	"May",0
	dc.b	"Jun",0
	dc.b	"Jul",0
	dc.b	"Aug",0
	dc.b	"Sep",0
	dc.b	"Oct",0
	dc.b	"Nov",0
	dc.b	"Dec",0
	dc.b	"BAD",0
RTCDay:
	dc.b	"   Sunday",0
	dc.b	"   Monday",0
	dc.b	"  Tuesday",0
	dc.b	"Wednesday",0
	dc.b	" Thursday",0
	dc.b	"   Friday",0
	dc.b	" Saturday",0	

AutoConfZ2Txt:
	dc.b	"Scanning Zorro II Area",$a,0
AutoConfZ3Txt:
	dc.b	"Scanning Zorro III Area",$a,0
AutoConfIllegalTxt:
	dc.b	$a,"  -- ILLEGAL CONFIGURATION, ZORROAREA OVERFLOW - SHUTTING DOWN CARD",$a,0
AutoConfAllTxt:
	dc.b	$a,"All boards done!",$a,0	
AutoConfBoardTxt:
	dc.b	$a,"Board #",0
AutoConfManuTxt:
	dc.b	$a,"  Manufacturer: ",0
AutoConfSerTxt:
	dc.b	"  Serialnumber: ",0
AutoConfZorTypeTxt:
	dc.b	$a,"     Zorrotype: ",0
AutoConfLinkTxt:
	dc.b	"  Link to system free pool: ",0
AutoConfAutoBTxt:
	dc.b	"  Autoboot: ",0
AutoConfLinked2NextTxt:
	dc.b	$a,"     Linked to next board: ",0
AutoConfExtSizeTxt:
	dc.b	"  Extended size: ",0
AutoConfSizeTxt:
	dc.b	"  Size: ",0
AutoConfBufTxt:
	dc.b	$a,"  Autoconfigbuffer: ",0
AutoConfRamCardTxt:
	dc.b	$a,"    Zorro II Memory detected and assigned to: ",0
AutoConfRomCardTxt:
	dc.b	$a,"    Zorro II I/O detected and assigned to: ",0
AutoConfZ3CardTxt:
	dc.b	$a,"    Zorro III Card detected and assigned to: ",0
AutoConfEnableTxt:
	dc.b	$a,"Assign board? Y)es (LMB) N)o (RMB) (If possible) or ESC)Exit",$a,0
AutoConfAssignZ2Ram:
	dc.b	$a,"Assigning RAM from $",0
AutoConfAssignZ2IO:
	dc.b	$a,"Assigning I/O from $",0
AutoConfAssignTo:
	dc.b	" to $",0
AutoConfToomuchTxt:
	dc.b	$a,"  ** ERRROR, looping autoconfig detected. (BUG!) exiting",$a,$a,0
	EVEN
SectorErrorTxt:
	dc.b	2,"Error finding sector possibly readerror",$a,$a,0


S8MB:
	dc.b	"8MB",0
S64k:
	dc.b	"64KB",0
S128k:
	dc.b	"128KB",0
S256k:
	dc.b	"256KB",0
S512k:
	dc.b	"512KB",0
S1MB:
	dc.b	"1MB",0
S2MB:
	dc.b	"2MB",0
S4MB:
	dc.b	"4MB",0
S16MB:
	dc.b	"16MB",0
S32MB:
	dc.b	"32MB",0
S64MB:
	dc.b	"64MB",0
S128MB:
	dc.b	"128MB",0
S256MB:
	dc.b	"256MB",0
S512MB:
	dc.b	"512MB",0
S1GB:
	dc.b	"1GB",0
SRes:
	dc.b	"RESERVED",0

	EVEN
SizeTxtPointer:
	dc.l	S8MB,S64k,S128k,S256k,S512k,S1MB,S2MB,S4MB
SizePointer:
	dc.l	$800000,$10000,$20000,$40000,$80000,$100000,$200000,$400000
ExtSizeTxtPointer:
	dc.l	S16MB,S32MB,S64MB,S128MB,S256MB,S512MB,S1GB,SRes
ExtSizePointer:
	dc.l	$1000000,$2000000,$4000000,$8000000,$10000000,$20000000,$40000000,$80000000

	
DividerTxt:
	dc.b	"--------------------------------------------------------------------------------",0
EmptyRowTxt:
	dc.b	"                                                                                ",0

DetChipTxt:
	dc.b	"Detected Chipmem: ",0
DetMBFastTxt:
	dc.b	"Detected Motherboard Fastmem: ",0
BaseAdrTxt:
	dc.b	"Basememory address: ",0
DetectRasterTxt:
	dc.b	"Detecting if we have a working raster: ",0
NoDrawTxt:
	dc.b	"We are in a nonchip/nodraw mode. Serialoutput is all we got. colorflash on screen",$a,$d
	dc.b	"is actually chars that should be printed on screen. telling user something happens",$a,$d,0
NewLineTxt:
	dc.b	$a,$d,0
DotTxt:
	dc.b	".",0
SpaceTxt:
	dc.b	" ",0
ColonTxt:
	dc.b	" : ",0
BLTDDATTxt:
	dc.b	"BLTDDAT ($dff000): ",0
DMACONRTxt:
	dc.b	"DMACONR  ($dff002): ",0
VPOSRTxt:
	dc.b	"VPOSR   ($dff004): ",0
VHPOSRTxt:
	dc.b	"VHPOSR  ($dff006): ",0
DSKDATRTxt:
	dc.b	"DSKDATR  ($dff008): ",0
JOY0DATTxt:
	dc.b	"JOY0DAT ($dff00a): ",0
JOY1DATTxt:
	dc.b	"JOY1DAT ($dff00c): ",0
CLXDATTxt:
	dc.b	"CLXDAT   ($dff00e): ",0
ADKCONRTxt:
	dc.b	"ADKCONR ($dff010): ",0
POT0DATTxt:
	dc.b	"POT0DAT ($dff012): ",0
POT1DATTxt:
	dc.b	"POT1DAT  ($dff014): ",0
POTINPTxt:
	dc.b	"POTINP  ($dff016): ",0
SERDATRTxt:
	dc.b	"SERDATR ($dff018): ",0
DSKBYTRTxt:
	dc.b	"DSKBYTR  ($dff01a): ",0
INTENARTxt:
	dc.b	"INTENAR ($dff01c): ",0
INTREQRTxt:
	dc.b	"INTREQR ($dff01e): ",0
DENISEIDTxt:
	dc.b	"DENISEID ($dff07c): ",0
HHPOSRTxt:
	dc.b	"HHPOSR  ($dff1dc): ",0

SSPErrorTxt:
	dc.b	2,"oOoooops Something went borked",0
BusErrorTxt:
	dc.b	2,"BusError Detected",0
AddressErrorTxt:
	dc.b	2,"AddressError Detected",0
IllegalErrorTxt:
	dc.b	2,"Illegal Instruction Detected",0
DivByZeroTxt:
	dc.b	2,"Division by Zero Detected",0
ChkInstTxt:
	dc.b	2,"Chk Inst Detected",0
TrapVTxt:
	dc.b	2,"Trap V Detected",0
PrivViolTxt:
	dc.b	2,"Privilige Violation Detected",0
TraceTxt:
	dc.b	2,"Trace Detected",0
UnImplInstrTxt:
	dc.b	2,"Unimplemented instruction Detected",0
TrapTxt:
	dc.b	2,"TRAP Detected",0
DebugTxt:
	dc.b	"Debugdata (Dump of CPU Registers D0-D7/A0-A7):",0
DebugIRQ:
	dc.b	"IRQ Level ",0
DebugIRQPoint:
	dc.b	" Points to: ",0
DebugContent:
	dc.b	" Content: ",0
DebugROM:
	dc.b	"Is $1114 readable at addr $0 (ROM still at $0): ",0
DebugROM2:	
	dc.b	"Is $1114 readable at addr $f80000 (Real ROM addr): ",0
	
HaltTxt:
	dc.b	$a,$d,"PANIC! System halted, not enough resources found to generate better dump",$a,$d,0
	
	EVEN
HexTxt:
	dc.b	"HEX: ",0
AddrTxt:
	dc.b	$d,"Addr $",0
	EVEN
StartAddrTxt:
	dc.b	$a,$d,"Startaddr: $",0
EndAddrTxt:
	dc.b	"  Endaddr: $",0
WTxt:
	dc.b	"  Write: $",0
RTxt:
	dc.b	"  Read: $",0
Txt32KBlock:
	dc.b	"  Number of 32K blocks found: $",0
PassTxt:
	dc.b	" Pass: ",0
PinTxt:
	dc.b	$a,"Pin no: ",0
Base1Txt:
	dc.b	$a,$d,"  Using $",0
Base2Txt:
	dc.b	" as start of workmem",$a,$d,$a,$d,0
UnderDevTxt:
	dc.b	2,"This function is under development, output can be weird, strange and false",$a,$d,$a,$d,0
NoChiptxt:
	dc.b	$a,$d,"NO Chipmem detected",$a,$d,0
NotEnoughChipTxt:
	dc.b	"Not enough chipmem detected",$a,$a,0
ShadowChiptxt:
	dc.b	$a,$d,"Chipmem Shadowram detected, guess there is no more chipmem, stopping here",$a,$d,0
bytehextxt:
	dc.b	"000102030405060708090A0B0C0D0E0F"
	dc.b	"101112131415161718191A1B1C1D1E1F"
	dc.b	"202122232425262728292A2B2C2D2E2F"
	dc.b	"303132333435363738393A3B3C3D3E3F"
	dc.b	"404142434445464748494A4B4C4D4E4F"
	dc.b	"505152535455565758595A5B5C5D5E5F"
	dc.b	"606162636465666768696A6B6C6D6E6F"
	dc.b	"707172737475767778797A7B7C7D7E7F"
	dc.b	"808182838485868788898A8B8C8D8E8F"
	dc.b	"909192939495969798999A9B9C9D9E9F"
	dc.b	"A0A1A2A3A4A5A6A7A8A9AAABACADAEAF"
	dc.b	"B0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF"
	dc.b	"C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF"
	dc.b	"D0D1D2D3D4D5D6D7D8D9DADBDCDDDEDF"
	dc.b	"E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEF"
	dc.b	"F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF"
	dc.b	0


EnglishKey:
	dc.b	"�1234567890-=| 0"
	dc.b	"qwertyuiop[] "; 1c
	dc.b	"123asdfghjkl;`" ; 2a
	dc.b	"  456 zxcvbnm,./ " ;3b
	dc.b	".789 "
	dc.b	8 ; backspace
	dc.b	9 ; Tab
	dc.b	$d ; Return
	dc.b    $a ; Enter (44)
	dc.b	27 ; esc
	dc.b	127 ; del
	dc.b	"   " ; Undefined
	dc.b	"-" ; - on numpad
	dc.b	" " ; Undefined
	dc.b	30 ; Up
	dc.b	31 ;down
	dc.b	28 ; forward
	dc.b	29 ; backward
	dc.b	"1" ;f1
	dc.b	"2" ;f2
	dc.b	"3" ;f3
	dc.b	"4" ;f4
	dc.b	"5" ;f5
	dc.b	"6" ;f6
	dc.b	"7" ;f7
	dc.b	"8" ;f8
	dc.b	"9" ;f9
	dc.b	"0" ;f10
	dc.b	"()/*+"
	dc.b	0 ; Help
EnglishKeyShifted:
	; Shifted
	dc.b	"~!@#$%^& ()_+| 0QWERTYUIOP{} 123ASDFGHJKL:",34,"  456 ZXCVBNM<>? .789          - "
	dc.b	0 ; Up
	dc.b	0 ;down
	dc.b	0 ; forward
	dc.b	0 ; backward
	dc.b	0 ;f1
	dc.b	0 ;f2
	dc.b	0 ;f3
	dc.b	0 ;f4
	dc.b	0 ;f5
	dc.b	0 ;f6
	dc.b	0 ;f7
	dc.b	0 ;f8
	dc.b	0 ;f9
	dc.b	0 ;f10
	dc.b	"()/*+"
	dc.b	0 ; Help


TTxt206:	dc.b	"Triangle 20.6Hz",0
TTxt55:		dc.b	"Triangle 55Hz  ",0
TTxt239:	dc.b	"Triangle 239Hz ",0
TTxt440:	dc.b	"Triangle 440Hz ",0
TTxt640:	dc.b	"Triangle 640Hz ",0
TTxt879:	dc.b	"Triangle 879Hz ",0
TTxt985:	dc.b	"Triangle 985Hz ",0
TTxt1295:	dc.b	"Triangle 1295Hz",0
TTxt1759:	dc.b	"Triangle 1759Hz",0
STxt206:	dc.b	"Sinus 20.6Hz   ",0
STxt55:		dc.b	"Sinus 55Hz     ",0
STxt239:	dc.b	"Sinus 239Hz    ",0
STxt440:	dc.b	"Sinus 440Hz    ",0
STxt640:	dc.b	"Sinus 640Hz    ",0
STxt879:	dc.b	"Sinus 879Hz    ",0
STxt985:	dc.b	"Sinus 985Hz    ",0
STxt1295:	dc.b	"Sinus 1295Hz   ",0
STxt1759:	dc.b	"Siuns 1759Hz   ",0

ROMAudioWaves:

ROMAudio64ByteTriangle:
	dc.b	127,119,111,103,95,87,79,71,63,55,47,39,31,23,15,6
	dc.b	-1,-9,-17,-25,-33,-41,-49,-57,-65,-73,-81,-89,-97,-105,-113,-121,-127
	dc.b	-121,-113,-105,-97,-89,-81,-73,-65,-57,-49,-41,-33,-25,-17,-9,-1
	dc.b	6,15,23,31,39,47,55,63,71,79,87,95,103,111,119,127,127
ROMAudio32ByteTriangle:
	dc.b	127,111,95,79,63,47,31,15
	dc.b	-1,-17,-33,-49,-65,-81,-97,-113,-127
	dc.b	-113,-97,-81,-65,-49,-33,-17,-1
	dc.b	15,31,47,63,79,95,111,127
ROMAudio16ByteTriangle:
	dc.b	127,95,63,31
	dc.b	-1,-33,-65,-97
	dc.b	-127,-97,-65,-33
	dc.b	-1,31,63,95
ROMAudio64ByteSinus:
	dc.b 	0,-12,-25,-37,-49,-61,-72,-82,-91,-100,-107,-113,-119,-123,-126,-127
	dc.b 	-127,-127,-124,-121,-116,-110,-103,-95,-87,-77,-66,-55,-43,-31,-19,-6
	dc.b 	6,19,31,43,55,66,77,87,95,103,110,116,121,124,127,127
	dc.b 	127,126,123,119,113,107,100,91,82,72,61,49,37,25,12,0
ROMAudio32ByteSinus:
	dc.b 	0,-25,-50,-73,-92,-108,-120,-126,-127,-123,-114,-101,-83,-62,-38,-12
	dc.b 	12,38,62,83,101,114,123,127,126,120,108,92,73,50,25,0
ROMAudio16ByteSinus:
	dc.b 	0,-52,-95,-121,-127,-110,-75,-26,26,75,110,127,121,95,52,0

	EVEN
EndROMAudioWaves:

AudioPointers:	; Pointers to actual waveform
	dc.l	0,0,0,0
	dc.l	ROMAudio32ByteTriangle-ROMAudioWaves,ROMAudio32ByteTriangle-ROMAudioWaves
	dc.l	ROMAudio16ByteTriangle-ROMAudioWaves,ROMAudio16ByteTriangle-ROMAudioWaves,ROMAudio16ByteTriangle-ROMAudioWaves
	dc.l	ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves,ROMAudio64ByteSinus-ROMAudioWaves
	dc.l	ROMAudio32ByteSinus-ROMAudioWaves,ROMAudio32ByteSinus-ROMAudioWaves
	dc.l	ROMAudio16ByteSinus-ROMAudioWaves,ROMAudio16ByteSinus-ROMAudioWaves,ROMAudio16ByteSinus-ROMAudioWaves
	
AudioLen:	; Length of audio
	dc.w	32,32,32,32,16,16,8,8,8,32,32,32,32,16,16,8,8,8,8
AudioPer:	; Period (speed) of audio
	dc.w	2390,1007,185,126,173,126,225,159,129,2390,1007,185,126,173,126,225,159,129
AudioName:	; Pointers to string of name of wave
	dc.l	TTxt206,TTxt55,TTxt239,TTxt440,TTxt640,TTxt879,TTxt985,TTxt1295,TTxt1759
	dc.l	STxt206,STxt55,STxt239,STxt440,STxt640,STxt879,STxt985,STxt1295,STxt1759

Octant_Table:
	dc.b	0*4+1
	dc.b	4*4+1
	dc.b	2*4+1
	dc.b	5*4+1
	dc.b	1*4+1
	dc.b	6*4+1
	dc.b	3*4+1
	dc.b	7*4+1


Music:
	ifeq	a1k

	incbin	"Music.MOD"
        endc
	EVEN


	ifeq	a1k
TestPic:
	incbin	"TestPIC.raw"
EndTestPic:
	endc
	EVEN
EndMusic:
	dc.b	"This is the brutal end of this ROM, everything after this are just pure noise.    End of Code...",0



EndRom:
	ifne	rommode

		ifeq	a1k
	blk.b	$80000-(EndRom-START)-16,0		; Crapdata that needs to be here
		else
	blk.b	$10000-(EndRom-START)-16,0		; Crapdata that needs to be here
		endc
	dc.l	$00180019,$001a001b,$001c001d,$001e001f	; or IRQ will TOTALLY screw up on machines with 68000-68010

	endc



ROMEND:

;		ifeq	rommode


		ifeq	rommode
	section data,code_c


BeforeUsed:
		blk.b	80*512*8,0

		endc



	EVEN



; Here you put REFERENCES to variabes in RAM. remember that you cannot know what is stored in
; this part of memory. so you have to set any default values in the code or data will be random.

Variables:
	blk.b	8192,0			; Just reserve memory for "Stack" not used in nonrom mode
Endstack:
	EVEN
V:
	dc.l	0			; Just a string to mark first part of data
StackSize:
	dc.l	0			; Will contain size of the stack	
StartAddress:
	dc.l	0
Bpl1Ptr:
	dc.l	0			; Pointer to Bitplane 1
Bpl2Ptr:
	dc.l	0			; Pointer to Bitplane 2
Bpl3Ptr:
	dc.l	0			; Pointer to Bitplane 3
BplEnd:
	dc.l	0			; Let it be 0
Xpos:	dc.l	0			; Variable for X position on screen to print on
Ypos:	dc.l	0			; Variable for Y position on screen to print on

shit:	dc.l	0			; crapvariable for debugging
b2dTemp:	dc.l	0,0
b2dString:	dc.l	0,0,0
bindecoutput:
	dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0
	EVEN
binhexoutput:
	blk.b	10,0
binstringoutput:
	blk.b	33,0

Color:	dc.b	0
	EVEN
HexBinBin:
	dc.l	0
SerialSpeed:
	dc.w	0
OldSerialSpeed:
	dc.w	0
keymap:
	dc.l	0			; Points to keymap to be used.
NoSerial:
	dc.b	0			; if other then 0, no serial output at start.
LoopB:
	dc.b	0			; if other than 0, Loopbackadapter was attached at boot
GetCharData:
	dc.b	0			; Result of GetChar
keypressed:
	dc.b	0,0			; What key is pressed
keypressedshifted:
	dc.b	0,0			; Same but without shift
keyresult:
	dc.b	0,0			; Actual result to be printed on screen
scancode:
	dc.b	0			; Scancode from buffer
key:
	dc.b	0			; Keycode
keyctrl:
	dc.b	0
keyalt:
	dc.b	0
keyshift:
	dc.b	0			; if !0 = shift is pressed Will actually contain the scancode
keycaps:
	dc.b	0
keyup:
	dc.b	0			; if 1 = key is pressed
keydown:
	dc.b	0
keystatus:
	dc.b	0
keynew:
	dc.b	0			; if 1 the keypress is new
keyrepeat:
	dc.b	0			; if 1 the key is still pressed down
CPUCache:
	dc.b	0			; Status of CPU Cache, 0 = off
	EVEN
	
ChipStart:
	dc.l	0			; Start of detected chipmem
ChipEnd:
	dc.l	0			; End of chipmem
ChipUnreserved:
	dc.l	0			; Total of UNRESERVED Chipmem detected
ChipUnreservedAddr:
	dc.l	0			; END of the Unreserved space
GetChipAddr:
	dc.l	0			; Response from GetChip routine
TotalChip:				; Total Chipmem detected
	dc.l	0
TotalFast:
	dc.l	0			; Total Motherboard Fastmem detected
ChipAdr:
	dc.l	0			; Where chipmem starts
oldkey:
	dc.l	0
InputRegister:
	dc.l	0	; the value of D0 of GetInput is stored here aswell
OldMouse1X:
	dc.b	0	; old value of mouseport X
OldMouse1Y:
	dc.b	0	; mouseport Y
OldMouse2X:
	dc.b	0	; old value of mouseDATA on non mouseport X
OldMouse2Y:
	dc.b	0	; Y
MouseX:
	dc.b	0	; Mouse X position
MouseY:
	dc.b	0	; Mouse Y Position
OldMouseX:
	dc.b	0
OldMouseY:
	dc.b	0
MOUSE:
	dc.b	0	; if not 0, moouse is moved
BUTTON:
	dc.b	0	; if not 0, a button is pressed
MBUTTON:
	dc.b	0	; if not 0, a mousebutton is pressed
LMB:
	dc.b	0	; if not 0, LMB pressed
RMB:
	dc.b	0	; if not 0, RMB pressed
MMB:
	dc.b	0	; if not 0, MMB pressed
P1LMB:
	dc.b	0	; if not 0, LMB port1 pressed
P2LMB:
	dc.b	0	; if not 0, LMB port2 pressed
P1RMB:
	dc.b	0	; if not 0, RMB port1 pressed
P2RMB:
	dc.b	0	; if not 0, RMB port1 pressed
P1MMB:
	dc.b	0	; if not 0, MMB port1 pressed
P2MMB:
	dc.b	0	; if not 0, MMB port1 pressed
STUCKP1LMB:
	dc.b	0	; if not 0, LMB port1 stuck and should be ignored
STUCKP2LMB:
	dc.b	0	; if not 0, LMB port2 stuck and should be ignored
STUCKP1RMB:
	dc.b	0	; if not 0, RMB port1 stuck and should be ignored
STUCKP2RMB:
	dc.b	0	; if not 0, RMB port1 stuck and should be ignored
STUCKP1MMB:
	dc.b	0	; if not 0, MMB port1 stuck and should be ignored
STUCKP2MMB:
	dc.b	0	; if not 0, MMB port1 stuck and should be ignored
RASTER:
	dc.b	0	; if not 0, We have detected working raster
SerData:
	dc.b	0	; if 0  we had no serialdata
Serial:
	dc.b	0	; Will contain data from the serialport
OldSerial:
	dc.b	0	; Will contain the last char that was detected on the serialport
SerBufLen:
	dc.b	0	; Current length of serialbuffer
SerBuf:
	blk.b	256,0	; 256 bytes of serialbuffer
SerAnsiFlag:
	dc.b	0	; nonzero means that we are in buffermode (number is actually number of chars in buffer)
SerAnsiBufLen:
	dc.b	0	; Buffertlength used for the moment.
	EVEN
SerAnsiChecks:
	dc.w	0	; Number of checks with a result of 0 in Ansimode.
SerAnsiBuff:
	dc.l	0	; Reserve a longword for ANSI serialbuffer
PrintMenuFlag:
	dc.b	0	; if set to anything else then 0, print the menu
UpdateMenuFlag:
	dc.b	0	; if set to anything else then 0, update the menu.
UpdateMenuNumber:
	dc.b	0	; What itemnumber to update. 0 = all  (0 is the only that prints label)
MenuEntrys:
	dc.b	0	; Will contain number of entrys in the menu being displayed
MenuPos:
	dc.b	0	; What menu item to highlight
MenuChoose:
	dc.b	0	; If anything else then 0, user have chosen this item on the menu
MenuMouseAdd:
	dc.w	0	; Variable for how many mousetics have been done..
MenuMouseSub:
	dc.w	0	
PortJoy0:		; Detected directions of Joystick 0
	dc.l	0
PortJoy1:		; Detected directions of Joystick 1
	dc.l	0
P0Fire:
	dc.w	0	; Detected fire on Joystick 0
P1Fire:
	dc.w	0	; Detected fire on Joystick 1
P0FireOLD:
	dc.w	0	; just to detect changes.
P1FireOLD:
	dc.w	0
PortJoy0OLD:
	dc.l	0
PortJoy1OLD:
	dc.l	0
SerTstBps:
	dc.w	0	; BPS of serialtest
OldMarkItem:
	dc.b	0	; Contains the item marked before
MarkItem:
	dc.b	0	; Contains the item being marked.
	EVEN
	dc.l	0
NoDraw:
	dc.b	0	; If this is other then 0, no screen is drawn, no text. for "no chipmem" modes
	EVEN
	dc.l	0
MenuNumber:
	dc.w	0	; Contains the menunuber to be printed, from the Menus�list
OldMenuNumber:
	dc.w	0	; Contain the old menunumber
NoChar:	dc.b	0	; if 0 print char, anything else, never do screenactions. (no chipmem avaible)
Inverted:
	dc.b	0	; if 0, former char was not inverted
	EVEN
Menu:
	dc.l	0	; What menulist to use
MenuVariable:
	dc.l	0	; List of pointers to variables to print after menuitem.

CurX:	dc.w	0	; Cursor X pos. "mouse" cursor
CurY:	dc.w	0	; Cursor Y pos
CurAddX:
	dc.w	0	; How much was added in X dir
CurSubX:
	dc.w	0	; How much was subtracted uin X dir
CurAddY:
	dc.w	0
CurSubY:
	dc.w	0
temp:	dc.l	0,0,0,0,0,0,0,0,0,0	; 10 longwords reserved for temporary crapdata
nomem:	dc.l	0
DriveTestVar:
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.l	0

DriveNo:
	dc.w	0	; Drivenumber to test
DriveOK:	
	dc.w	0	; Status of drive, 0=not ok, 1=OK
DriveMotor:
	dc.b	0	; 0 = Diskdrivemotor is OFF
SideNo:
	dc.b	9	; Side of disk.  0=Upper
TrackNo:
	dc.b	0	; Current tracknumber
WantedTrackNo:
	dc.b	0	; Wanted tracknumber
oldbfe001:
	dc.b	0	; Contains old value of bfe001
oldbfd100:
	dc.b	0	; Contains old value of bfd100
sector:
	dc.b	0	; Currend sector
	EVEN
trackbuff:
	dc.l	0	; Address to trackbuffer
sectorbuff:
	dc.l	0,0,0,0	; a small part of MFMdecoded sectordata.

AudSimpVar:		; Variablelist for the menusystem
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0
	dc.w	0
	dc.l	0

AudSimpChan1:
	dc.b	0
AudSimpChan2:
	dc.b	0
AudSimpChan3:
	dc.b	0
AudSimpChan4:
	dc.b	0
AudSimpVol:
	dc.b	0
AudSimpWave:
	dc.b	0
AudSimpFilter:
	dc.b	0	
AudSimpVolStr:
	blk.b	10,0
	EVEN
AudioWaveNo:
	dc.w	0			; What wave to play
AudioModAddr:
	dc.l	0			; Address of module in modtest
AudioModInit:
	dc.l	0			; Address to MT_Init
AudioModEnd:
	dc.l	0			; Address to MT_End
AudioModMusic:
	dc.l	0			; Address to MT_Music
AudioModMVol:
	dc.l	0			; Address to Mastervolume
AudioModData:
	dc.l	0			; Address to mt_data (pointer to mod)
AudioModStatData:			; Audiomod status
	dc.b	0,0,0,0			; if channels if turned off or not (1=OFF)
	dc.b	0			; Audiofilter
	dc.b	64			; Mastervolume
	dc.b	0,0
AudioModStatFormerData:			; NO DATA IN BETWEEN HERE!!! OR YOU WILL HAVE BUGS!!
	dc.b	0,0,0,0
	dc.b	0,0			; Just a backup of former state of above.
	dc.b	0,0			; so it will not update all everytime.
	
IRQLevDone:
	dc.w	0
Frames:	dc.w	0			; Number of frames shown
Ticks:	dc.l	0			; Number of "ticks" in CIA test
TickFrame:
	dc.w	0			; how many frames reached when CIA test was done.
CIACtrl:
	dc.l	0
RTCold:
	dc.l	0			; How RTC first longword was last read
RTCString:
	blk.b	14,0			; Block of RTC data
MemTestStart:
	dc.l	0
MemTestEnd:
	dc.l	0
MemTestFail:
	dc.l	0,0,0,0			; Add 1 to every byte that is wrong during check
	
GfxChipset:
	dc.b	0			; What GfxChipset is detected: 0 = OCS, 1 = ECS, 2 = AGA

	EVEN
BootMBFastmem:				; Amount of motherboard fastmem detected at bootpoint
	dc.l	0
CheckMemFrom:
	dc.l	0			; Startaddress of memory to check
CheckMemTo:
	dc.l	0			; endaddress to check memory
CheckMemCurrent: 
	dc.l	0			; current address to check
CheckMemChecked:
	dc.l	0			; how much memory is checked
CheckMemUsable:
	dc.l	0			; how much usable memory
CheckMemNonUsable:
	dc.l	0			; how much non usable memory
CheckMemBitErrors:
	blk.b	32,0			; number of errors in each bit in a longword (max 255 errors per bit)
CheckMemByteErrors:
	dc.l	0,0,0,0			; number of errors on each byte in a longword
CheckMemErrors:
	dc.l	0			; Number of errors foun
CheckMemType:
	dc.b	0			; type of memory detected last time 0=none  1=Error 2=Good
CheckMemOldType:
	dc.b	0
CheckMemTypeChange:			; if 0, there is no change of type
	dc.b	0
CheckMemRow:
	dc.b	0			; What row to print message of type of memory on
CheckMemCol:
	dc.b	0			; What color to print row at
CheckMemFast:
	dc.b	0			; if anything else then 0, a fast scan will be perfomed
CheckMemNoShadow:
	dc.b	0			; if anything else then 0, no shadowcheck will be done
CheckMemManualX:
	dc.b	0			; Contains X cord of current text to input while asking for memadress
CheckMemManualY:
	dc.b	0			; .... and Y
CheckMemStartAdrTxt:
	dc.b	0,0,0,0,0,0,0,0,0	; String for startaddress
CheckmemEndAdrTxt:
	dc.b	0,0,0,0,0,0,0,0,0	; String for endaddress
	EVEN
CheckMemTypeStart:
	dc.l	0			; Startaddress of this "type" of memory
CheckMemEditAdr:
	dc.l	0			; Current address cursor points to in edit-mode
CheckMemEditScreenAdr:
	dc.l	0			; Startaddress of memorydump on screen in edit-mode
CheckMemEditXpos:
	dc.b	0			; Current X pos of cursor
CheckMemEditYpos:
	dc.b	0			; Current Y pos of cursor
CheckMemEditOldXpos:
	dc.b	0			; Old X pos of cursor
CheckMemEditOldYpos:
	dc.b	0			; Old Y pos of cursor
CheckMemEditCharPos:
	dc.b	0			; Current pos to edit memory.  0 or 1, 0 = high nibble, 1 = low)
KeyBOld:
	dc.b	0			; Stores old scancode of keyboard

	even
FirstMBMem:
	dc.l	0
MBMemSize:
	dc.l	0
DebugA0:
	dc.l	0			; Store A0 in here, so we have it stored.. before string overwrites it.
DebugD1:
	dc.l	0
DebD0:
	dc.l	0			; For debug..  to store registers
DebD1:
	dc.l	0			; For debug..  to store registers
DebD2:
	dc.l	0			; For debug..  to store registers
DebD3:
	dc.l	0			; For debug..  to store registers
DebD4:
	dc.l	0			; For debug..  to store registers
DebD5:
	dc.l	0			; For debug..  to store registers
DebD6:
	dc.l	0			; For debug..  to store registers
DebD7:
	dc.l	0			; For debug..  to store registers
DebA0:
	dc.l	0			; For debug..  to store registers
DebA1:
	dc.l	0			; For debug..  to store registers
DebA2:
	dc.l	0			; For debug..  to store registers
DebA3:
	dc.l	0			; For debug..  to store registers
DebA4:
	dc.l	0			; For debug..  to store registers
DebA5:
	dc.l	0			; For debug..  to store registers
DebA6:
	dc.l	0			; For debug..  to store registers
DebA7:
	dc.l	0			; For debug..  to store registers



; Reserved area for dumps of customregisters
BLTDDAT:
	dc.w	0
DMACONR:
	dc.w	0
VPOSR:
	dc.w	0
VHPOSR:
	dc.w	0
DSKDATR:
	dc.w	0
JOY0DAT:
	dc.w	0
JOY1DAT:
	dc.w	0
CLXDAT:
	dc.w	0
ADKCONR:
	dc.w	0
POT0DAT:
	dc.w	0
POT1DAT:
	dc.w	0
POTINP:
	dc.w	0
SERDATR:
	dc.w	0
DSKBYTR:
	dc.w	0
INTENAR:
	dc.w	0
INTREQR:
	dc.w	0
DENISEID:
	dc.w	0
HHPOSR:
	dc.w	0
CIAAPRA:
	dc.w	0
Passno:
	dc.l	0
GfxTestBpl:				; Pointers to bitplanes for gfxtest
	dc.l	0,0,0,0,0,0,0,0
SHIT:
	dc.l	0			; SHITData
C:
	EVEN
MenuCopper:
	blk.b	EndRomMenuCopper-RomMenuCopper,0
	EVEN
ECSCopper:
	blk.b	EndRomEcsCopper-RomEcsCopper,0
ECSCopper2
	blk.b	EndRomEcsCopper-RomEcsCopper,0
JunkBuffer:
	blk.l	54,0			; Junkbuffer for 256 bytes

	; Put this data at the end of everything.


AudioWaves:
	blk.b	EndROMAudioWaves-ROMAudioWaves,0

	EVEN
DummySprite:
	dc.l	0


AutoConfMode:
	dc.b	0			; if set to anything but 0, a detailed (and more manual) autoconfig will be done.
	EVEN
AutoConfBuffer:
	blk.b	20,0			; Autoconfigbuffer.
	EVEN
AutoConfZ2Ram:
	dc.b	0			; AutoConf where to config ram to next Z2 card
AutoConfZ2IO:
	dc.b	0			; AutoConf where to config rom to next Z2 card
	EVEN
AutoConfZ3:
	dc.w	0			; AutoConf where to config to next Z3 card
AutoConfType:
	dc.b	0			; If set to 0, no board was found
					; 1 = ROM
					; 2 = RAM
					; 3 = Z2Space, not RAM
AutoConfExit:
	dc.b	0			; If anything than 0, force exit of loop
AutoConfIllegal:
	dc.b	0			; if anything than 0, cardconfig was illegal, force shutdown of card
AutoConfZorro:
	dc.b	0			; Should be set to 0 for Zorro II and 1 for Zorro III
	EVEN
AutoConfSize:
	dc.l	0			; Size of current board
AutoConfWByte:
	dc.w	0			; "Byte" to write to autoconfigboards (Word for Z3)
AutoConfAddr:
	dc.l	0			; Address to configure board to.
Bpl1str:
	dc.l	0			; Space for the "BPL1" string
Bpl1:
	blk.b	80*256,2		; bitplane 1
EndBpl1:

Bpl2str:
	dc.l	0			; Space for the "BPL1" string
Bpl2:
	blk.b	80*256,33		; bitplane 2
EndBpl2:


	
Bpl3str:
	dc.l	0			; Space for the "BPL1" string
Bpl3:
	blk.b	80*256,3		; bitplane 3
EndBpl3:

	dc.l	0			; extra null-longword

ptplay:
	blk.b	mt_END-MT_Init,0			; Reserve memory of protracker replayroutine

	EVEN


	dc.b	"This is the brutal end of this ROM, everything after this are just pure noise.    End of Code...",0
	EVEN
EndData:
	dc.l	0


; this is data for "non rom mode"..
STACKPOINTER:
	dc.l	0	
ActiveView:
	dc.l	0
sysstack:
	dc.l	0

irq1:	dc.l	0
irq2:	dc.l	0
irq3:	dc.l	0
irq4:	dc.l	0
irq5:	dc.l	0
irq6:	dc.l	0
irq7:	dc.l	0


graph:
	dc.b	"graphics.library",0
	even
SLASK:
	dc.l	0
