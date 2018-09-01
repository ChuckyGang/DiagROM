.PHONY: DiagROM
VASM=vasmm68k_mot 

all: main
main: split date
	$(VASM) -m68851 -m68882 -m68020up -no-opt -Fbin $(@).s -o $(@).rom -L $(@).lst
	dd conv=swab if=$(@).rom of=16bit.bin
	./split 16bit.bin 32bit
	dd bs=1K count=256 if=32bit.hi of=32bitHI.trim && rm 32bit.hi
	dd bs=1K count=256 if=32bit.lo of=32bitLO.trim && rm 32bit.lo 
	cat 32bitHI.trim 32bitHI.trim > 32bitHI.bin && rm 32bitHI.trim
	cat 32bitLO.trim 32bitLO.trim > 32bitLO.bin && rm 32bitLO.trim
split: split.o
	$(CXX) -o split split.o
split.o: split.cpp
date:	
	date +"%d-%b-%y" > BuildDate.txt
mif:
	bin2mif -w 16 DiagROM.rom  > 16bit.mif
clean:
	rm -f DiagROM.new *.lst a.out *~ \#* *.o split
