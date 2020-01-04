make:
	c:\cc65\bin\ca65  test.asm
	c:\cc65\bin\ld65  test.o -o test.nes -t nes
		