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
ip           = $06 ; The instructino pointer
tmp          = $08 ; General purpose temp

wordptr0     = $0A ; General use word / pointer size address
wordptr1     = $0C ; General use word / pointer size address
arg1         = $0E ; First argument (let's count these from 1)
arg2         = $10 ; Second argument
result       = $12 ; Result -- often gets copied back to arg1

; The same registers when used in division
remainder    = wordptr1 ; divident is gradually left shifted into remainder & subtracted with corresponding divisor bit
dividend     = arg1
divisor      = arg2
;result      = result

; And when used in multiplication
multiplicand = arg1
multiplier   = arg2
;result      = result



;
; Main engine
;

thread_loop:
  jsr fetch_into_y ; consider in-lining this code here to win back 12 cycles in main loop
_perform_instr:
  lda jumptable_msb,y ; to support full 256 instrs, use separate page for jumptable lsb / msb
  pha
  lda jumptable_lsb,y
  pha
_test_if_core:
  tya
  cmp #MAX_CORE   ; is prim > max core prim?
  bpl thread_loop ; then only push non-core prim; leave eval to 'eval n'
  rts ; jumps to pushed address MINUS ONE; so adjust core jump table accordingly

; Used both by main threadloop and by primitives to fetch data.
; The Y register appears useful in both cases, so you get the final TAY as a freebie.
fetch_into_y:
_fetch_instr:
  ldy #$00
  lda (ip),y
  tay
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
  ldy #$1
  bne push_byte_in_y
push_byte:
  jsr fetch_into_y ; then fall through:
push_byte_in_y:
  lda #$00 ; empty msb, then fall through:
push_word_in_y_a:
  pha ; msb
  tya ; lsb is pushed last so as to be pulled first
  pha
  jmp thread_loop
push_word:
  jsr fetch_into_y ; also into a
  tax ; keep lsb safe in x
  jsr fetch_into_y ; also into a
  pha ; push msb first
  txa
  pha ; push lsb last
  jmp thread_loop
eval:
_calc_fp:
  jsr fetch_into_y ; num of 2-byte stack items to eval; also fetched into a
  tsx
  clc
; arg $2000 is at sp-2*2; arg $42 is at sp-1*2; so pointer should be at sp-3*2
  sta tmp
  asl tmp ; tmp = arg count * 2 bytes
  txa ; a now holds (original) end of arg stack
  clc
  adc tmp ; a now holds 'frame pointer', i.e. start of args on stack (stack goes down, so A is higher)
_do_eval:
  tax
  jsr stack_x_to_wordptr0
  ; a now holds frame pointer; x next arg; y (still) holds arg count
  jmp(wordptr0) ; jump to primitive
done:
  rts ; to exit thread loop by returning to whoever called us

setb: ; 'setb $1234 42'
  tay ; save fp in y
  jsr stack_x_to_wordptr0
;  lda $0100,x  ; setb only uses lsb of value
  dex
  lda $0100,x  ; setb only uses lsb of value
  dex
jsr WriteCharacter
  #clear_stack_from_y_via_ax
  ldx #$00
  sta (wordptr0,x) ; and perform stack 
  jmp thread_loop

print: ; print a unique_string or similarly formatted string
  tay ; save fp in y
  jsr stack_x_to_wordptr0
  #clear_stack_from_y_via_ax
  ldy #0
  lda (wordptr0),y  ; load size of string in A
  beq _done         ; string size zero = terminator?
_loop:
    iny               ; next character
    lda (wordptr0),y  ; load character value
    beq _done         ; zero terminated
    jsr WriteCharacter
    bne _loop         ; = unconditional jump
_done:
;lda #$41
;jsr WriteCharacter
    jmp thread_loop
  

; store word on stack,x into wordptr0
; and decrement x
stack_x_to_wordptr0:
  lda $0100,x
  sta wordptr0+1
;adc #$30
;jsr WriteCharacter
  dex
  lda $0100,x
  sta wordptr0
;adc #$30
;jsr WriteCharacter
  dex
  rts

clear_stack_from_y_via_ax .macro
;  dey
;  dey
  tya ; y contains 'frame pointer' == base stack
  tax ; ...move it the long way around...
  txs ; to set stack size to before expression
.endmacro

; Because we jump into core prims by means of rts, we need address minus one
; Expression level primitives are jumped to instead
jumptable_lsb:
  .text <push0-1, <push1-1, <push_byte-1, <push_word-1, <eval-1, <done-1, <setb, <print
jumptable_msb:
  .text >push0-1, >push1-1, >push_byte-1, >push_word-1, >eval-1, >done-1, >setb, >print

fixed_strings:
  .text 6, "setb", 0
  .text 7, "print", 0, 0

NUM_FIXED_STRINGS=2

PRIM_PUSHB=2
PRIM_PUSHW=3
PRIM_EVAL=4
PRIM_DONE=5
PRIM_SETB=6
PRIM_PRINT=7
MAX_CORE=5

