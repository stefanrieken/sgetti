sgetti.bin: parse.asm sgetti.asm uqstr.asm int.asm emit.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o sgetti.bin -l labels.txt

test: test.asm sgetti.asm uqstr.asm int.asm emit.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o $@ -l labels.txt

run: sgetti.bin
	../neo6502-firmware/bin/neo sgetti.bin@800 cold

clean:
	rm -rf tmp.asm sgetti.bin labels.txt memory.dump
