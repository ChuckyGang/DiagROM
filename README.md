# DiagROM
The Amiga Diagnostic tool by John "Chucky/The Gang" Hertell.

This is a open project, it replaceses the Amiga Kickstart ROMs and try to make a diagnostic of the system.
Or atleast help you find out issues.

This is NOT for persons without technical knowledge of the Amiga system or atleast basic digital electronics.

Please do mind that I am taking a VERY VERY big step out of my comfortzone by opening this and I will be VERY
restrictive of what changes will be accepted, even good ideas just because of this. I have always only been coding
at a hobby basis, and never been in a project with several programmers etc.  So before doing anything larger etc, please
contact me first so we can have a discussion.

I hope there will not be gazillions of forks of this, you are allowed to do it but please let us try to make a good tool out of this
intead of a big mess.


Buildinstructions:

I code using AsmPro so all instructions is based for that assembler.

In my S:User-Startup I have the following:

date >ram:Date.txt
C:DateCrap >ram:BootDate.txt

file "DateCrap" is in the repo here.

This simply makes a textfile of the current date to include date in the assembled source

Anyway just load the source in AsmPro. (DiagROM.S)

in the beginning of the source there are some variables:

rommode =	0				; Set to 1 if to assemble as being in ROM
debug = 	0				; Set to 1 to enable some debugshit in code
amiga = 	1 				; Set to 1 to create an amiga header to write the ROM to disk

When being in "rommode" (set to 1) the Assembler assumes $f80000 as location. if not it is executeable in AsmPro.
debug is not really used.
amiga when set to 1 AND rommode set to 1, if you assemble and run, it saves the assebled binary to disk as the file "DiagROM" needed for
the romsplit software.

If rommode is 0 and you assemble and execute with j, it will start (some tests will give bogus numbers and even crash due to the nature
ofthe code), Pressing RIGHT mousebutton in a menu will exit the code. DiagRom WILL assume 2MB of chipmem etc at this situation.


To make a byteswapped version, just load the source "romsplit" and make sure asmpro is in the DiagROM directory,
it will load the DiagROM file and make the 3 files needed to program eproms.


---

For the code there are some very important rules, if this is not followed I will not accept any changes:

Do NOT take anything granted, like IRQ working etc. ok in some cases you must have working IRQ etc. but if possible avoid it.
also avoid waiting for ok signals etc. (like serialport waiting for bit of all data recieved)

also you can see in the code that there are 3 sections:

1. Code
2. Static Variables
3. Variables

Keep it like this. NO data in code segment and so on. also the addressregister A6 is "magic" in my code. it contains the Baseadress that
is actually where all workmemory is located. so ANY Variable must be relative to this address.  This is why I always use:

test-V(a6) to reach the variable "test"  as V is a label of where data starts.  Larger blocks must be at the end of this chunk of data.
by doing this, I can have the workmemory at any place in ram. And also, as variables can be anywhere in ram, you cannot expect data to be
initlized with a value expect anything.


I have not used ANY sizeoptimizing atall, actually more the opposite as I want the code to be as clear as possible to read. there is no need
of doing size and timingoptimize code anyway. (well mostly...)

And finally: Beware of dirty code, most is done while drinking belgian beers anyway :)
