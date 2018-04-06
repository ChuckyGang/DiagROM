;APSFFD31A8FFFD31A8FFFD31A8FFFD31A8FFFD31A8FFFD31A8FFFD31A8FFFD31A8FFFD31A8F58544B4C

; Simple program
; loads file "DiagROM" and saves three files:
; 16bit.bin - byteswapped image for burning 16 bit eproms
; 32bitHI.bin - byteswapped image of high word for burning 32 bit eproms
; 32bitLO.bin - byteswapped image of low word for burning 32 bit eproms

MEMF_FAST = 4
SIZE = 512*1024
SIZE64K =	64*1024

        move.l  4.w,a6
	lea	Dos,a1
	jsr	-408(a6)		;Open DOS library
	move.l	d0,DOSBase

	lea	InitTxt,a0
	bsr	Print


	lea	infile,a0
	bsr	LoadFile

	cmp.b	#0,end
	bne	Error

	move.l	d0,inadr

	move.l	#SIZE,d1
	move.l	d1,FileSize
	move.l	#512*1024,d0
	bsr	AllocateMemory		; My own memoryallocateroutine that can be easly freed with just one function for all allocations.

	cmp.b	#0,d0
	beq	outofmem

	move.l	d0,workadr

	bsr	CopyAll
	bsr	ByteSwap

	lea	Filename16,a0
	bsr	SaveFile
	cmp.l	#0,d0
	bne	Error

	bsr	CopyHigh
	bsr	ByteSwap

	lea	Filename32hi,a0
	bsr	SaveFile
	cmp.l	#0,d0
	bne	Error

	bsr	CopyLo
	bsr	ByteSwap

	lea	Filename32lo,a0
	bsr	SaveFile
	cmp.l	#0,d0
	bne	Error


	lea	infilea1k,a0
	bsr	LoadFile

	cmp.b	#0,end
	bne	Error

	move.l	d0,inadr

	move.l	#SIZE64K/2,FileSize

	bsr	CopyEven


	lea	FilenameA1kEven,a0
	bsr	SaveFile
	cmp.l	#0,d0
	bne	Error

	bsr	CopyOdd

	lea	FilenameA1kOdd,a0
	bsr	SaveFile
	cmp.l	#0,d0
	bne	Error


	bsr	FreeAllocated
	clr.l	d0
	clr.l	d1
	rts

Error:
	bchg	#1,$bfe001
	move.b	#1,end
	bsr	FreeAllocated
	move.l	#40,d0
	clr.l	d1
	rts

outofmem:
	lea	outmem,a0
	bsr	Print
	bra	Error


CopyAll:
	clr.l	d0
	move.l	inadr,a0
	move.l	workadr,a1
.loop:
	move.l	(a0)+,(a1)+
	add.l	#4,d0
	cmp.l	#SIZE,d0
	blt	.loop
	rts


CopyHigh:
	clr.l	d0
	move.l	inadr,a0
	move.l	workadr,a1
	move.l	a1,a2
	add.l	#SIZE/2,a2
.loop:
	move.w	(a0),d1
	move.w	d1,(a1)+
	move.w	d1,(a2)+
	addi.l	#4,a0
	add.l	#4,d0
	cmp.l	#SIZE,d0
	blt	.loop
	rts

CopyLo:
	clr.l	d0
	move.l	inadr,a0
	move.l	workadr,a1
	move.l	a1,a2
	add.l	#SIZE/2,a2
.loop:
	move.w	2(a0),d1
	move.w	d1,(a1)+
	move.w	d1,(a2)+
	addi.l	#4,a0
	add.l	#4,d0
	cmp.l	#SIZE,d0
	blt	.loop
	rts

ByteSwap:
	clr.l	d0
	move.l	workadr,a0
.loop:
	move.b	(a0),d1
	move.b	1(a0),d2
	move.b	d2,(a0)+
	move.b	d1,(a0)+
	add.l	#2,d0
	cmp.l	#SIZE,d0
	blt	.loop
	rts


CopyEven:
	clr.l	d0
	move.l	inadr,a0
	move.l	workadr,a1
.loop:
	move.b	(a0),(a1)+
	addi.l	#2,a0
	add.l	#2,d0
	cmp.l	#SIZE64K,d0
	blt	.loop
	rts

CopyOdd:
	clr.l	d0
	move.l	inadr,a0
	move.l	workadr,a1
.loop:
	move.b	1(a0),(a1)+
	addi.l	#2,a0
	add.l	#2,d0
	cmp.l	#SIZE64K,d0
	blt	.loop
	rts



;----------------------------------------

AllocateMemory:					;Allocate memory AND adds
						;in the Allocated memorylist
						;for easy deallocation.
						;IN: D0=Memoryblock wanted
						;    D1=memoryType wanted
						;OUT:D0=Memoryposition|0=Error

	movem.l	a0-a6/d1-d7,-(a7)
	add.l	#8,D0				;Adds bytes for handling
	bsr.s	AllocMem
	beq.s	.Error

	lea	Allocated_Memory_Pos,a0

.Loop:	move.l	(a0),a1
	cmp.l	#0,(a1)
	beq.w	.NextBlock
	move.l	a1,a0
	bra.s	.Loop				;Loop until next free block

.NextBlock:
	move.l	d0,(a0)
	move.l	a0,d1
	move.l	d0,a0
	move.l	#Allocated_Memory_Pos+4,(a0)
	move.l	d1,4(a0)
	add.l	#8,d0

.Error:	movem.l	(a7)+,a0-a6/d1-d7
	rts

;----------------------------------------
AllocMem:					;Allocates memory
	move.l	$4,a6				;IN: D0=memoryblock wanted
						;    D1=MemoryType wanted
						;OUT: D0=Where the memory is
        cmp.l	#0,d0				;      0=ERROR
	beq.s	.MemErr
	jsr	-684(a6)
.MemErr:
	rts

FreeMem:					;Free Memory	
        move.l	$4,a6				;IN: D0 = WHERE
	move.l	d0,a1
        jsr	-690(a6)
        rts

;----------------------------------------

FreeAllocated:                                  ;Free all allocated blocks
						;with AllocateMemory
						;NO IN or OUT variables
						;It just does it!
						;(It's a kinda MAGIC tadaatada)
	movem.l	a0-a6/d0-d7,-(a7)
	lea	Allocated_Memory_Pos,a0
	move.l	(a0),a1
	cmp.l	#0,(a1)
	beq.s	.End				;No Blocks allocated atall!
	move.l	(a0),a0

.Loop:	cmp.l	#0,(a0)
	beq.s	.End				;Last Block done
	move.l	(a0),a2
	move.l	a0,d0
	bsr	FreeMem
	move.l	a2,a0
	bra.s	.Loop
.End:	movem.l	(a7)+,a0-a6/d0-d7
	rts

;----------------------------------------

FreeBlock:					;Free a memoryblock from
						;memorylist allocated with
						;AllocateMemory
						; IN: D0=Where
						;OUT: D0: 0=Error (not found)
	movem.l	a0-a6/d1-d7,-(a7)
	lea	Allocated_Memory_Pos,a0
	sub.l	#8,d0
	move.l	(a0),a0

.Loop:	cmp.l	a0,d0
	beq.s	.ThatsIT			;We got the block
	cmp.l	#0,(a0)
	beq.s	.Error				;BlockNotFound
	move.l	(a0),a0
	bra.s	.Loop

.ThatsIT:
	move.l	(a0),a1				;get adr to the NEXT block.
	move.l	4(a0),a2			;get the adr to the block before.
	cmp.l	#0,(a1)
	beq.s	.NextNull			;this is the LAST block

	move.l	a1,(a2)
	move.l	a2,4(a1)

.Free:	
	bsr	FreeMem

.Ok:	bset	#1,d0
.NotOk:
	movem.l	(a7)+,a0-a6/d1-d7
	rts

.NextNull:
	move.l	a1,(a2)
	bra.s	.Free

.Error:	clr.l	d0
	bra.s	.NotOk


Allocated_Memory_Pos:
	dc.l	*+4,0				;Position of alloc mem list


Print:						;	Prints string in A0
	movem.l	a1-a6/d1-d7,-(a7)
						;	OLutput: D0 = length
	move.l	DOSBase,a6
	clr.l	d7
	move.l	a0,d2
.loop:
	add.l	#1,d7
	cmp.b	#0,(a0)+
	bne.s	.loop

	move.l	d7,d3
	jsr	-60(a6)
	move.l	d0,d1
	jsr	-48(a6)
	move.l	d7,d0
	movem.l	(a7)+,a1-a6/d1-d7
	rts	


LoadFile:					;Loads a file into memory
	move.l	a0,d7
	lea	.Loadtext,a0
	jsr	Print
	move.l	d7,a0
	jsr	Print
	lea	.Loadnewline,a0
	jsr	Print
	
	move.l	d7,a0	
	bsr	CheckLen			;Allocated memory with the
	beq.s	.Error				;AllocateMemory routine.
						;IN: A0 = Pointer to Filename
	move.l	d0,.LoadLength			;Out: D0=Memoryposition
	bsr	AllocateMemory			;     D1=FileLength
	beq.s	.Error2
	move.l	d0,.LoadInto

	move.l	$4,a6
	lea	Dos,a1				;IN: File=Filename (incl. path)
	jsr	-408(a6)			;    LoadInto=Where to load to
	move.l	d0,a6				;    LoadLength=Filelength
	move.l	FileName,d1
	move.l	#00001005,d2
	jsr	-30(a6)
	beq	.Error
	move.l	d0,.Peekare
	move.l	d0,d1
	move.l	.LoadInto,d2
	move.l	.LoadLength,d3
	jsr	-42(a6)
	move.l	.Peekare,d1
	jsr	-36(a6)

	beq.s	.Error
	move.l	.LoadLength,d1
	move.l	.LoadInto,d0
	rts

.Error:
	lea	.Loaderror,a0
	jsr	Print
	move.b	#1,end
	rts

.Error2:
	lea	.Loadmem,a0
	jsr	Print
	move.b	#1,end
	rts
.Peekare:
	dc.l	0
.LoadInto:
	dc.l	0
.LoadLength:
	dc.l	0
.Loadtext:
	dc.b	"Loading file: ",0
.Loadnewline:
	dc.b	$a,0
.Loaderror:
	dc.b	$a,"ERROR LOADING FILE - EXITING",$a,0
.Loadmem:
	dc.b	$a,"ERROR - OUT OF MEMORY - EXITING",$a,0	
	EVEN

SaveFile:
	move.l	a0,a5
	lea	.Savetext,a0
	bsr	Print

	move.l	a5,a0
	bsr	Print

	lea	.Savenewline,a0
	bsr	Print

	move.l	$4,a6
	lea	Dos,a1
	jsr	-408(a6)
	move.l	d0,a6
	move.l	a5,d1
	move.l	#1006,d2
	jsr	-30(a6)
	beq	.Error
	move.l	d0,.Peekare
	move.l	d0,d1
	move.l	workadr,d2
	move.l	FileSize,d3
	jsr	-48(a6)


	move.l	.Peekare,d1
		jsr	-36(a6)
	clr.l	d0
	rts

.Error:
	lea	.Errortext,a0
	bsr	Print
	move.l	#-1,d0
	move.b	#1,end
	rts

.Peekare:
	dc.l	0


.Savetext:
	dc.b	"Saving file: ",0
.Savenewline:
	dc.b	$a,0
.Errortext:
	dc.b	$a,"ERROR SAVING FILE",$a,0
	
FileSize:
	dc.l	0
	
;----------------------------------------

CheckLen:					;Checks length of file
	move.l	a0,FileName
        move.l	$4,a6				;IN:  A0=Pointer to filename
        lea	Dos,a1				;OUT: D0=Length
        jsr	-408(a6)			;     A0=File structure
        move.l	d0,a6
        move.l	FileName,d1			;Filename
        move.l	#-2,d2
        jsr	-84(a6)
        beq	.Error
        move.l	d0,.Lock
        move.l	d0,d1
        move.l	#.FileInfo,d2
        jsr	-102(a6)
        move.l	.Lock,d1
        jsr	-90(a6)
        lea	.FileInfo,a0
        cmp.w	#$1111,-2(a0)
        bne	.yeah
        addi.l	#2,a0
.yeah:
        move.l	122(a0),d0
        rts
.Error:
	move.l	#0,d0
        rts

.Lock:  dc.l	0

        dc.w	$1111
                  		;Dummy! DO NOT HAVE ANYTHING HERE
.FileInfo:
        blk.l	300,0


Dos:	dc.b	"dos.library",0
FileName:
	dc.l	0
DOSBase:
	dc.l	0	


inadr:
	dc.l	0	
workadr:
	dc.l	0
end:
	dc.l	0

Filename16:
	dc.b	"diagrom/16bit.bin",0
Filename32hi:
	dc.b	"diagrom/32bitHI.bin",0
Filename32lo:
	dc.b	"diagrom/32bitLO.bin",0
FilenameA1kEven:
	dc.b	"diagrom/A1kEVEN.bin",0
FilenameA1kOdd:
	dc.b	"diagrom/A1kODD.bin",0
	

InitTxt:
	dc.b	"Filesplitter V0.2 by John (Chucky) Hertell",$a,$a
	dc.b	"Simply reads the file indata.bin that should be a binary file for Kickstart ROM and splits it for burning",$a
	dc.b	"This software assumes 512MB Roms and will make 32 bit roms 2x512MB files with duplicate data",$a,$a
	dc.b	"Produces 3 files:",$a
	dc.b	" 16bit.bin - byteswapped image for burning 16 bit eproms",$a
	dc.b	" 32bitHI.bin - byteswapped image of high word for burning images for 32Bit",$a
	dc.b	" 32bitLO.bin - byteswapped image of low word for burning images for 32Bit",$a,$a
	dc.b	"AND if DiagROMA1k file exists it also creates:",$a,$a
	dc.b	" A1kEVEN.bin - Image for EVEN bytes",$a
	dc.b	" A1kODD.bin - Image for ODD bytes",$a,$a,0

infile:
	dc.b	"diagrom/DiagROM",0
infilea1k:
	dc.b	"diagrom/DiagROMA1k",0
	

outmem:
	dc.b	" -- ERROR: out of fastmem for work-buffer",$a,0
