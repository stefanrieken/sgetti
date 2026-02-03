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
  .text <push0-1, <push1-1, <push_byte-1, <push_word-1, <push_byte-1, <push_word-1, <ref_byte-1, <ref_word-1
  .text <push_result-1, <skipw-1, <skimw-1, <skimw-1, <eval-1, <done-1
  .text <return, <getb, <setb, <print, <if, <eval_block, <loop, <define, <get, <set, <bind, <funcall, <args, <hist, <listp, <save, <load
  .text <add, <sub, <band, <bor, <xor_or_not, <xor_or_not, <times, <div, <rem, <eq, <ne, <lt, <gt, <lte, <gte, <land, <lor, <lnot, <dollar
jumptable_msb:
  .text >push0-1, >push1-1, >push_byte-1, >push_word-1, >push_byte-1, >push_word-1, >ref_byte-1, >ref_word-1
  .text >push_result-1, >skipw-1, >skimw-1, >skimw-1, >eval-1, >done-1
  .text >return, >getb, >setb, >print, >if, >eval_block, >loop, >define, >get, >set, >bind, >funcall, >args, >hist, >listp, >save, >load
  .text >add, >sub, >band, >bor, >xor_or_not, >xor_or_not, >times, >div, >rem, >eq, >ne, >lt, >gt, >lte, >gte, >land, >lor, >lnot, >dollar

fixed_strings:
  .text 8, "return", 0
  .text 6, "getb", 0
  .text 6, "setb", 0
  .text 7, "print", 0
  .text 4, "if", 0
  .text 6, "eval", 0
  .text 6, "loop", 0
  .text 8, "define", 0
  .text 5, "get", 0
  .text 5, "set", 0
  .text 6, "bind", 0
  .text 9, "funcall", 0
  .text 6, "args", 0
  .text 6, "hist", 0
  .text 6, "list", 0
  .text 6, "save", 0
  .text 6, "load", 0
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
  .text 3, "!", 0
 .text 3, "$", 0, 0

NUM_FIXED_STRINGS=35

PRIM_PUSH0=0
PRIM_PUSH1=1
PRIM_PUSHB=2
PRIM_PUSHW=3
PRIM_STRB=4
PRIM_STRW=5
PRIM_REFB=6
PRIM_REFW=7
PRIM_PUSH_RESULT=8
PRIM_SKIPW=9
PRIM_KEEP=10
PRIM_SCRATCH=11
PRIM_EVAL=12
PRIM_DONE=13
PRIM_RETURN=14
PRIM_GETB=15
PRIM_SETB=16
PRIM_PRINT=17
PRIM_IF=18
PRIM_EVAL_BLOCK=19
PRIM_LOOP=20
PRIM_DEFINE=21
PRIM_GET=22
PRIM_SET=23
PRIM_BIND=24
PRIM_FUNCALL=25
PRIM_ARGS=26
PRIM_HIST=27
PRIM_LIST=28
PRIM_SAVE=29
PRIM_LOAD=30
PRIM_ADD=31
PRIM_SUB=32
PRIM_AND=33
PRIM_OR=34
PRIM_XOR=35
PRIM_NOT=36
PRIM_TIMES=37
PRIM_DIV=38
PRIM_REM=39
PRIM_EQ=40
PRIM_NE=41
PRIM_LT=42
PRIM_GT=43
PRIM_LTE=44
PRIM_GTE=45
PRIM_LAND=46
PRIM_LOR=47
PRIM_LNOT=48

MAX_CORE=PRIM_DONE

;
; Main engine
;

thread_loop:
  jsr next_byte         ; consider in-lining this code here to win back 12 cycles in main loop
  cmp #MAX_CORE+1       ; is prim > max core prim?
_push_instr:
  tay
  lda jumptable_msb,y   ; to potentially support full 256 instrs, use separate page for jumptable lsb / msb
  pha
  lda jumptable_lsb,y   ; (may also try to keep all jumps on one page so that msb is always the same)
  pha
_eval_if_core:
  bcs thread_loop ; _not_core         ; only push expression level primitive; leave eval to 'eval n'
  rts                   ; eval by JMP to address on stack PLUS ONE (so adjust core jump table accordingly)
_not_core:
  tya
  cmp #(MAX_CORE + NUM_FIXED_STRINGS) ; is prim out of bounds?
  bcc thread_loop
  jmp rt_error          ; TODO: cleanup ALL non-global vars on emergency exit

  ; All primitives should return by jumping to thread_loop.
  ; If not, this value triggers the monitor in the neo6502 emulator:
  #neo6502_breakpoint

; Get next byte from ip++
; Uses y
next_byte:
  ldy #0
  lda (ip),y
incr_ip:
  inc ip
  bne _done ; if circled back to zero, increment msb as well
  inc ip+1
_done:
  rts

