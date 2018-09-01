        ; compiler specific implementation of getting a build date
	IF	__VASM
	INCBIN <BuildDate.txt>
	ELSE
	INCBIN <RAM:BootDate.txt>
	ENDC
