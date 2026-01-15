sgetti.bin: src/neo.asm src/parse.asm src/emit.asm src/eval.asm src/base.asm src/int.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o $@ -l labels.txt

test: src/neo.asm src/test.asm src/eval.asm src/base.asm src/int.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o sgetti.bin -l labels.txt

test64: src/c64.asm src/test.asm src/eval.asm src/base.asm src/int.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C tmp.asm -o test64.prg -l labels.txt

sgetti64: src/neo.asm src/parse.asm src/emit.asm src/eval.asm src/base.asm src/int.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -a -Wall -C --nostart tmp.asm -o sgetti64.prg -l labels.txt

run: sgetti.bin
	../neo6502-firmware/bin/neo sgetti.bin@800 cold

# Run with VICE: x64 test64.prg
# Or run with kernalemu, which is a fun project
run64: test64.prg
	../kernalemu/build/kernalemu test64.prg -text

clean:
	rm -rf tmp.asm sgetti.bin labels.txt memory.dump *.prg
