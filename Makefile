SOURCES=src/parse.asm src/emit.asm src/eval.asm src/core.asm src/base.asm src/int.asm src/print.asm src/vars.asm src/uqstr.asm src/list.asm
all: sgetti65.bin sgetti64.prg twist

sgetti65.bin: src/neo.asm $(SOURCES)
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o $@ -l labels.txt

test65: src/neo.asm src/test.asm src/eval.asm src/core.asm src/base.asm src/int.asm src/print.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	64tass -Wall -C --nostart tmp.asm -o sgetti65.bin -l labels.txt

test64: src/c64.asm src/test.asm src/eval.asm src/core.asm src/base.asm src/int.asm src/print.asm src/vars.asm src/uqstr.asm src/list.asm
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	echo ".endencode" >> tmp.asm
	64tass -Wall -C tmp.asm -o sgetti64.prg -l labels.txt

sgetti64.prg: src/c64.asm $(SOURCES)
	cat $^ > tmp.asm # overcome a multi file symbol retainment bug
	echo ".endencode" >> tmp.asm
	64tass -Wall -C tmp.asm -o sgetti64.prg -l labels.txt

run65: sgetti65.bin
	../neo6502-firmware/bin/neo sgetti65.bin@800 cold

twist: src/twist.c
	$(CC) $^ -o $@

regression: sgetti64.prg twist
	./twist < recipes/testset.pasta > test.tmp
	cat test.tmp | ../kernalemu/build/kernalemu sgetti64.prg -text

# Run with VICE: x64 test64.prg
# Or run with kernalemu, which is a fun project
run64: sgetti64.prg
	../kernalemu/build/kernalemu sgetti64.prg -text

disk: sgetti64.prg
	cc1541 -n "sgetti" -f "sgetti64" -w sgetti64.prg sgetti.d64

clean:
	rm -rf test.tmp tmp.asm labels.txt memory.dump *.bin *.prg twist
