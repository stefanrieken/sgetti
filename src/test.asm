; Test that the interpreter can run a fixed program.

init:
  lda #0
  sta stringmem
  ldx #$FF
  txs

; Make a unique string. Should end up at start of dynamic stringmem.
  lda #'"'
  sta tmp
  lda #<hello
  ldy #>hello
  jsr unique_string

; Run the test program
  lda #<program
  sta ip
  lda #>program
  sta ip+1
  jsr thread_loop
_endloop:
  jmp _endloop

hello:
  .text 15, "Hello from Sgetti!", 0

program:
;  .text PRIM_SETB, PRIM_PUSHW, $2000, PRIM_PUSHB, 42, PRIM_EVAL, 3, PRIM_DONE
;  .text PRIM_PRINT, PRIM_PUSHW, hello, PRIM_EVAL, 2, PRIM_DONE
  .text PRIM_PRINT, PRIM_PUSHW, stringmem, PRIM_EVAL, 2, PRIM_DONE

