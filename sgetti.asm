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

;
; Utility zero page registers.
;

lineptr      = $02 ; The line being parsed
prgtop       = $04 ; The top of program memory
ip           = $06 ; The instruction pointer
tmp          = $08 ; General purpose temp

result2      = $0A 
arg1         = $0C ; First argument (let's count these from 1)
arg2         = $0E ; Second argument
result       = $10 ; Result -- often gets copied back to arg1

; The same registers when used in division
remainder    = result2; divident is gradually left shifted into remainder & subtracted with corresponding divisor bit
dividend     = arg1
divisor      = arg2
;result      = result

; And when used in multiplication
multiplicand = arg1
multiplier   = arg2
;result      = result


neo6502_breakpoint .macro
.byte 3
.endmacro

;
; Main engine
;

thread_loop:
  jsr next_byte ; consider in-lining this code here to win back 12 cycles in main loop
_perform_instr:
  tay
  lda jumptable_msb,y ; to potentially support full 256 instrs, use separate page for jumptable lsb / msb
  pha
  lda jumptable_lsb,y ; (may also try to keep all jumps on one page so that msb is always the same)
  pha
_test_if_core:
  tya
  cmp #MAX_CORE+1   ; is prim > max core prim?
  bcs thread_loop ; then only push this expression level primitive; leave eval to 'eval n'
  rts ; use RTS to actually JMP to primitive code MINUS ONE; so adjust core jump table accordingly

  ; All primitives should return by jumping to thread_loop.
  ; If not, this value triggers the monitor in the neo6502 emulator:
  #neo6502_breakpoint

; Get next byte from ip++
; Uses y
next_byte:
  ldy #$00
  lda (ip),y
_incr_ip:
  inc ip
  bne _done ; if circled back to zero, increment msb as well
  inc ip+1
_done:
  rts

;
; Primitives
; 

push0:
  lda #$0
  pha
  pha
  jmp thread_loop
push1:
  lda #$1
  bne push_byte_in_x
push_byte:
  jsr next_byte ; then fall through:
  tax
push_byte_in_x:
  lda #$00 ; empty msb, then fall through:
push_word_in_x_a:
  pha ; msb
  txa ; lsb is pushed last so that it is pulled first
  pha
  jmp thread_loop
push_word:
  jsr next_byte
  tax ; keep lsb safe in x
  jsr next_byte
  pha ; push msb first
  txa
  pha ; push lsb last
  jmp thread_loop
eval:
_calc_fp:
  jsr next_byte; load num of 2-byte stack items to eval
  sta tmp
  asl tmp ; tmp = arg count * 2 bytes
  tsx
  txa
  clc
  adc tmp ; a now holds 'frame pointer', i.e. start of args on stack (stack goes down, so A is higher)
_do_eval:
  tay ; y now holds 'frame pointer'
  tax ; x holds same value, but is walked as argument index
  jsr stack_x_to_arg1 ; fetch first argument (the primitive to call)
  jmp(arg1) ; jump to primitive
done:
  rts ; to exit thread loop by returning to whoever called us

setb: ; 'setb $1234 42'
  jsr stack_x_to_arg1
  dex
  lda $0100,x  ; setb only uses lsb of value
  dex
jsr WriteCharacter
  #clear_stack_from_y_via_ax
  ldx #$00
  sta (arg1,x) ; and perform setb
  sta arg1     ; return the byte value in arg1
  lda #$0
  sta arg1+1
  jmp thread_loop

print: ; print a unique_string or similarly formatted string
  tya ; stash return sp
  pha
  lsr tmp ; restore num args
  dec tmp
_print_next_str:
  jsr stack_x_to_arg1
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
  dec tmp
  bne _print_next_str
  lda #13
  jsr WriteCharacter
  pla ; clear stack from pushed sp
  tax
  txs
  lda #0
  sta arg1
  sta arg1+1 ; return 0 (return values need not be pushed unless at end of block / subexpr)
  jmp thread_loop
  

; store word on stack,x into arg1
; and decrement x
stack_x_to_arg1:
  lda $0100,x
  sta arg1+1
;adc #$30
;jsr WriteCharacter
  dex
  lda $0100,x
  sta arg1
;adc #$30
;jsr WriteCharacter
  dex
  rts

clear_stack_from_y_via_ax .macro
  tya ; y contains 'frame pointer' == base stack
  tax ; ...move it the long way around...
  txs ; to set stack size to before expression
.endmacro

; Because we jump into core prims by means of rts, these need address minus one
; Expression level primitives are jumped to instead
jumptable_lsb:
  .text <push0-1, <push1-1, <push_byte-1, <push_word-1, <push_byte-1, <push_word-1, <eval-1, <done-1, <setb, <print
jumptable_msb:
  .text >push0-1, >push1-1, >push_byte-1, >push_word-1, >push_byte-1, >push_word-1, >eval-1, >done-1, >setb, >print

fixed_strings:
  .text 6, "setb", 0
  .text 7, "print", 0, 0

NUM_FIXED_STRINGS=2

PRIM_PUSH0=0
PRIM_PUSH1=1
PRIM_PUSHB=2
PRIM_PUSHW=3
PRIM_STRB=4
PRIM_STRW=5
PRIM_EVAL=6
PRIM_DONE=7
PRIM_SETB=8
PRIM_PRINT=9
MAX_CORE=7

