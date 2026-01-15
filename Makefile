sgetti.bin: src/neo.asm src/parse.asm src/emit.asm src/eval.asm src/base.asm src/int.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o $@ -l labels.txt

test: src/neo.asm src/test.asm src/eval.asm src/base.asm src/int.asm src/uqstr.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o sgetti.bin -l labels.txt

run: sgetti.bin
	../neo6502-firmware/bin/neo sgetti.bin@800 cold

clean:
	rm -rf tmp.asm sgetti.bin labels.txt memory.dump
