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
tmp          = $08 ; General purpose temp (all kinds of uses in parse; consistently used as arg counter in eval)
tmp2         = $09 ; General purpose temp (used by divide)

result2      = $0A 
arg1         = $0C ; First argument (let's count these from 1)
arg2         = $0E ; Second argument
result       = $10 ; Result -- often gets copied back to arg1
primptr      = $12 ; Address of current expression level primitive, useful for looping

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

;
; Primitives
; 

push0:
  lda #0
  pha
  pha
  beq thread_loop
push1:
  ldx #$1
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
push_result:
  lda arg1+1       ; result of expression level prims is in arg1
  pha
  lda arg1         ; inject this core prim after a subexpr to push result value
  pha
  jmp thread_loop
skipw:
  jsr next_byte    ; temporarily store target in x, y
  tax
  jsr next_byte
  tay
  lda ip+1         ; push current ip == start of block
  pha
  lda ip
  pha
  stx ip           ; and set ip to target
  sty ip+1         ; for now skip is absolute instead of an offset
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
  tax ; x now holds 'frame pointer'
  tay ; y holds same value, but is walked as argument index
; Fetch first argument (the primitive to call)
  lda $0100,y
  sta primptr+1
  dey
  lda $0100,y
  sta primptr
  dey
  lsr tmp ; restore num args
  dec tmp
  beq +
; Fetch first real arg (if any) as a service to the primitives
  jsr stack_y_to_arg1
+
  jmp(primptr) ; jump to primitive
done:
  rts   ; to exit thread loop by returning to whoever called us
return: ; in the Pasta sense of returning the argument value as expression outcome
  txs ; restore stack
  jmp thread_loop
setb: ; 'setb 0x1234 42'
  dey
  lda $0100,y ; setb only uses lsb of value
  dey
  ldy #0
  sta (arg1),y ; and perform set
  ; done, now prepare return value in arg1
  sta arg1     ; return the byte value in arg1
  sty arg1+1
  txs ; restore stack
  jmp thread_loop
print: ; print a unique_string or similarly formatted string
  tya
  pha ; stash arg idx
  jsr print_arg1
  pla ; restore arg idx
  tay
  dec tmp   ; more args?
  bmi _done ; print those as well
  jsr stack_y_to_arg1_no_check  ; don't let this function return for us
  jmp print
_done
  lda #13                       ; so that we can write a newline (may remove this feature later)
  jsr WriteCharacter
  txs ; restore stack
  jmp thread_loop

if:
  lda arg1
  ora arg1+1
  bne _then
_else:
  dec tmp    ; continue to 'else' block (if any)
  dey
  dey
_then:
  jsr stack_y_to_arg1 ; and fall through to 'eval'
evalb: ; eval block
  txs                 ; early restore stack as we already have our only arg1
  lda ip+1            ; save current ip
  pha
  lda ip
  pha
  lda arg1            ; set ip to block
  sta ip
  lda arg1+1
  sta ip+1
  jsr thread_loop     ; eval block in sub thread_loop
  pla                 ; restore own ip
  sta ip
  pla
  sta ip+1
  jmp thread_loop     ; continue as usual

add:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec tmp
  bmi done_via_x ; but don't rely on having more parameters on stack
  clc
  lda arg1
  adc $00FF,y
  sta arg1
  lda arg1+1
  adc $0100,y
; Common tail for many multi-arg operators. Shaves off some 4 bytes per operator
; (Was more before, so reconsider whether this is still useful.)
; Notice that it also takes on the final 'sta arg1+1'
multi_arg_tail:
  sta arg1+1
  dey
  dey
  jmp(primptr) ; go for another round

sub:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr do_sub
  dey
  dey
  jmp(primptr) ; go for another round

do_sub:
  dec tmp
  bmi done_via_x ; but don't rely on having more parameters on stack
  sec
  lda arg1
  sbc $00FF,y
  sta arg1
  lda arg1+1
  sbc $0100,y
  sta arg1+1
  rts

band:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec tmp
  bmi done_via_x ; but don't rely on having more parameters on stack
  lda arg1
  and $00FF,y
  sta arg1
  lda arg1+1
  and $0100,y
  jmp multi_arg_tail

bor:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec tmp
  bmi done_via_x ; but don't rely on having more parameters on stack
  lda arg1
  ora $00FF,y
  sta arg1
  lda arg1+1
  ora $0100,y
  jmp multi_arg_tail

xor:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec tmp
  bmi done_via_x ; but don't rely on having more parameters on stack
  lda arg1
  eor $00FF,y
  sta arg1
  lda arg1+1
  eor $0100,y
  jmp multi_arg_tail

bnot:
  lda arg1
  eor #$FF
  sta arg1
  lda arg1+1
  eor #$FF
  sta arg1+1
done_via_x:
  txs
  jmp thread_loop

times:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr stack_y_to_arg2 ; and trust this function to exit when no more args
  tya
  pha
  jsr multiply
  jmp times_div_tail

div:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr stack_y_to_arg2 ; and trust this function to exit when no more args
  tya
  pha
  jsr divide
times_div_tail:
  pla
  tay
  lda result
  sta arg1
  lda result+1
  sta arg1+1
  jmp (primptr)

rem:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr stack_y_to_arg2 ; and trust this function to exit when no more args
  tya
  pha
  jsr divide
  pla
  tay
  lda result2
  sta arg1
  lda result2+1
  sta arg1+1
  txs
  jmp thread_loop ; no use for repeated arguments with remainder

eq:
  jsr do_sub ; have arg1+1 result in a
  ora arg1   ; any of these have 1's?
  bne nope
  beq yup
ne:
  jsr do_sub ; have arg1+1 result in a
  ora arg1   ; any of these have 1's?
  bne yup
  beq nope
lt:
  jsr do_sub
  bcc yup
  bcs nope
gt:
  jsr do_sub ; have arg1+1 result in a
  bcs nope
  ora arg1   ; any of these have 1's?
  beq nope
  bne yup
lte:
  jsr do_sub ; have arg1+1 result in a
  bcs yup
  ora arg1   ; any of these have 1's?
  beq yup
  bne nope
gte:
  jsr do_sub
  bcc yup
  bcs nope
land:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr stack_y_to_arg2 ; and trust this function to exit when no more args
  lda arg1
  ora arg1+1
  beq nope
  lda arg2
  ora arg2+1
  beq nope
  jmp yup
lor:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  jsr stack_y_to_arg2 ; and trust this function to exit when no more args
  lda arg1
  ora arg1+1
  ora arg2
  ora arg2+1
  beq nope
  bne yup
lnot:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  lda arg1
  ora arg1+1
  beq yup
  bne nope

yup:
  lda #1
  bne +
nope:
  lda #0
+
  sta arg1
  lda #0
  sta arg1+1
done_via_x2:   ; shared tail
  txs
  jmp thread_loop

; store word on stack,y into arg1
; and decrement y
stack_y_to_arg1:
  dec tmp
  bmi done_via_x2
stack_y_to_arg1_no_check:
  lda $0100,y
  sta arg1+1
  dey
  lda $0100,y
  sta arg1
  dey
  rts

; dumbly supply the same function for arg2
; as target is hard to parameterize (while keeping x intact)
stack_y_to_arg2:
  dec tmp
  bmi done_via_x2
  lda $0100,y
  sta arg2+1
  dey
  lda $0100,y
  sta arg2
  dey
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
