;APS00002206FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
; Takes a IFF file and makes it as a fontfile for DiagROM
; Execute in AsmPro, and save FontData->EndFontData


MakeFont:
	lea		Font,a0
	lea		FontData,a1
	move.w	#255-31,d0			;Number of chars to be handles. Skipp chars before space

.fontloop:

	move.w	#7,d1
	move.l	a0,a2
.charloop:
	move.b	(a2),(a1)+
	addi.l	#224,a2	
	dbf		d1,.charloop
	addi.l	#1,a0
	dbf		d0,.fontloop
	rts

Font:		inciff	"DiagRom/TopazFont.iff"

FontData:					; Data that should be stored as a font
			blk.b	8*225,0
EndFontData:
