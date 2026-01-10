;
; Sgetti Is Threaded Pasta for the 6502
;
; main engine:
; - token threaded code
; - ip at zp address (or also use x or y)
; - byte index into primitive table
;   - Reserve some low prims for "push 0", "push 1", etc.
;   - Allow for 1-byte and 2-byte push (1 byte extends into 2 bytes)
;   - Allow for "typed push" variants to re-create source code
;     - Maybe use 1-byte string references
; - core prims (push, eval, get, skip) may read ahead args
; - function prims just push a pointer jumped to by 'eval'
;
; Challenge: base 6502 can't jump indexed.
; - So need to copy over the target to a fixed (non-ZP) address first, then jump. (11-15 bytes)
; - Better: push address, then rts from it (7-9 bytes depending on zp use)


; Because we jump into core prims by means of rts, these need address minus one
; Expression level primitives are jumped to instead
jumptable_lsb:
  .text <push0-1, <push1-1, <push_byte-1, <push_word-1, <push_byte-1, <push_word-1, <push_result-1, <skipw-1, <eval-1, <done-1
  .text <return, <setb, <print, <if, <evalb
  .text <add, <sub, <band, <bor, <xor, <bnot, <times, <div, <rem, <eq, <ne, <lt, <gt, <lte, <gte, <land, <lor, <lnot
jumptable_msb:
  .text >push0-1, >push1-1, >push_byte-1, >push_word-1, >push_byte-1, >push_word-1, >push_result-1, >skipw-1, >eval-1, >done-1
  .text >return, >setb, >print, >if, >evalb
  .text >add, >sub, >band, >bor, >xor, >bnot, >times, >div, >rem, >eq, >ne, >lt, >gt, >lte, >gte, >land, >lor, >lnot

fixed_strings:
  .text 8, "return", 0
  .text 6, "setb", 0
  .text 7, "print", 0
  .text 4, "if", 0
  .text 6, "eval", 0
  .text 3, "+", 0
  .text 3, "-", 0
  .text 3, "&", 0
  .text 3, "|", 0
  .text 3, "^", 0
  .text 3, "~", 0
  .text 3, "*", 0
  .text 3, "/", 0
  .text 3, "%", 0
  .text 3, "=", 0
  .text 4, "!=", 0
  .text 3, "<", 0
  .text 3, ">", 0
  .text 4, "<=", 0
  .text 4, ">=", 0
  .text 4, "&&", 0
  .text 4, "||", 0
  .text 3, "!", 0, 0

NUM_FIXED_STRINGS=23

PRIM_PUSH0=0
PRIM_PUSH1=1
PRIM_PUSHB=2
PRIM_PUSHW=3
PRIM_STRB=4
PRIM_STRW=5
PRIM_PUSH_RESULT=6
PRIM_SKIPW=7
PRIM_EVAL=8
PRIM_DONE=9
PRIM_RETURN=10
PRIM_SETB=11
PRIM_PRINT=12
PRIM_IF=13
PRIM_EVALB=14
PRIM_ADD=15
PRIM_SUB=16
PRIM_AND=17
PRIM_OR=18
PRIM_XOR=19
PRIM_NOT=20
PRIM_TIMES=21
PRIM_DIV=22
PRIM_REM=23
PRIM_EQ=24
PRIM_NE=25
PRIM_LT=26
PRIM_GT=27
PRIM_LTE=28
PRIM_GTE=29
PRIM_LAND=30
PRIM_LOR=31
PRIM_LNOT=32

MAX_CORE=9

;
; Main engine
;

thread_loop:
  jsr next_byte ; consider in-lining this code here to win back 12 cycles in main loop
  cmp #MAX_CORE+1   ; is prim > max core prim?
_push_instr:
  tay
  lda jumptable_msb,y ; to potentially support full 256 instrs, use separate page for jumptable lsb / msb
  pha
  lda jumptable_lsb,y ; (may also try to keep all jumps on one page so that msb is always the same)
  pha
_eval_if_core:
  bcs thread_loop ; only push expression level primitive; leave eval to 'eval n'
  rts ; eval by JMP to address on stack PLUS ONE (so adjust core jump table accordingly)

  ; All primitives should return by jumping to thread_loop.
  ; If not, this value triggers the monitor in the neo6502 emulator:
  #neo6502_breakpoint

; Get next byte from ip++
; Uses y
next_byte:
  ldy #0
  lda (ip),y
_incr_ip:
  inc ip
  bne _done ; if circled back to zero, increment msb as well
  inc ip+1
_done:
  rts

; utility callable versions of print & print error
syntax_error:
  lda #<stx_err
  ldx #>stx_err
print_ax:
  sta arg1
  stx arg1+1
print_arg1:
  ldy #0
  lda (arg1),y  ; load size of string in A
  beq _str_done     ; string size zero = terminator?
_loop:
  iny               ; next character
  lda (arg1),y  ; load character value
  beq _str_done     ; zero terminated
  jsr WriteCharacter
  bne _loop         ; = unconditional jump
_str_done:
  rts

stx_err:
  .text 15, "[?]", 13, 0

