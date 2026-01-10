; Test that the interpreter can run a fixed program.

; Currently made to compile for neo6502 with 64tass --nostart
; Run on emulator by writing neo6502-firmware/bin/neo a.out@800 cold

*=$800              ; neo6502 cold start address
; Neo6502 Kernel API convenience macros
;.include '../neo6502-firmware/examples/assembly/neo6502.asm.inc'
WriteCharacter = $fff1

init:
  lda #0
  sta stringmem
  ldx #$FF
  txs

; Make a unique string. Should end up at start of dynamic stringmem.
  lda #<hello
  ldy #>hello
  jsr unique_string

; Run the test program
  lda #<program
  sta ip
  lda #>program
  sta ip+1
  jmp thread_loop

hello:
  .text 15, "Hello from Sgetti!", 0

program:
;  .text PRIM_SETB, PRIM_PUSHW, $2000, PRIM_PUSHB, 42, PRIM_EVAL, 3, PRIM_DONE
;  .text PRIM_PRINT, PRIM_PUSHW, hello, PRIM_EVAL, 2, PRIM_DONE
  .text PRIM_PRINT, PRIM_PUSHW, stringmem, PRIM_EVAL, 2, PRIM_DONE

