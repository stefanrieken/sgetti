;
; Integer primitives and underlying functions
;

add:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec argc
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
  dec argc
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
  dec argc
  bmi done_via_x2 ; but don't rely on having more parameters on stack
  lda arg1
  and $00FF,y
  sta arg1
  lda arg1+1
  and $0100,y
  jmp multi_arg_tail

bor:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec argc
  bmi done_via_x2 ; but don't rely on having more parameters on stack
  lda arg1
  ora $00FF,y
  sta arg1
  lda arg1+1
  ora $0100,y
  jmp multi_arg_tail

; Combine two functions so that missing PETSCII character `~`
; can fall back onto `^` (actually, arrow up) without featire loss.
xor_or_not:
  ; trust that 'eval' has put first arg in arg1 for us; otherwise produce garbage out
  dec argc
  bpl _loop
  lda #$FF               ; if only 1 arg, treat as 'not' == ^ arg1 0xFFFF
  pha
  pha
_loop:
  dec argc
  lda arg1
  eor $00FF,y
  sta arg1
  lda arg1+1
  eor $0100,y
  sta arg1+1
  dey
  dey
  dec argc
  bpl _loop
  bmi done_via_x2

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
done_via_x2:   ; shared tail
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
;done_via_x2:   ; shared tail
  txs
  jmp thread_loop


; Invoke 'multiply' with 1-byte multiplier in a, and result copied back into multiplicand.

multiply_by_a:
  ldy #8
multiply_by_a_y_bits:
  sta multiplier
  lda #$00
  sta multiplier+1
  jsr multiply_y_bits ; a is max 8 bits wide
  lda result
  sta multiplicand
  lda result+1
  sta multiplicand+1
  rts

; 16-bit multiply using (3 of) our 4 16-bit zero page registers
; by their appropriate alias (multiplier, multiplicand, result)
; Also uses x

multiply:
  ldy #$16       ; easier to just count max cycles than to determine whether 2-byte multiplier is fully shifted out
multiply_y_bits: ; target for a limited sized multiplier
; clear target
  lda #$00
  sta result
  sta result+1
_next_bit_in_carry:
  lsr multiplier+1
  ror multiplier
  bcc _shift_multiplicand
_add_multiplicand:
  clc
  lda result
  adc multiplicand
  sta result
  lda result+1
  adc multiplicand+1
  sta result+1
_shift_multiplicand:
  asl multiplicand
  rol multiplicand+1
  dey
  bne _next_bit_in_carry
  rts

divide_by_a:
  sta divisor
  lda #0
  sta divisor+1
  jsr divide
  lda result
  sta dividend
  lda result+1
  sta dividend+1
  rts

; 16-bit divide using our 4 16-bit zero page registers
; by their appropriate alias (remainder, dividend, divider, result)
; Also uses x

divide:
  ldy #16          ; because we start from msb, we can't too easily skip bits here
; clear remainder -- don't need to clear result if we go over all 16 bits
  lda #$00
  sta remainder
  sta remainder+1
_next_bit:
  asl dividend      ; rotate dividend one bit at the time
  rol dividend+1
  rol remainder     ; all the way into remainder
  rol remainder+1
  lda remainder     ; can we subtract divisor from remainder?
  sec
  sbc divisor
  sta tmp           ; temporarily save half-subtraction result
  lda remainder+1
  sbc divisor+1
  bcc _lt           ; c is still 1 if result of subtraction remained positive
  sta remainder+1   ; in which case, save that result
  lda tmp
  sta remainder
_lt
  rol result        ; set result bit from carry
  rol result+1
  dey
  bne _next_bit
  rts

; Print a number in base <divisor>
;
; Base 8 or 16 would be easy (just shift out 3/4 bits at the time),
; but base 10 needs a more mathematical approach.
; There may be other methods; here we just repeat dividing by 10 and pushing remainders.
;
; dividend = arg1
; divisor = 10 = arg2
; touches a,x,y
printnum_base_10:
   lda #10
   sta divisor
   lda #0
   sta divisor+1
printnum:
   ldx #0            ; digit counter
_more_digits:
   jsr divide
   lda remainder     ; expect a 1 byte remainder (for bases < 256)
   pha
   inx
   lda result        ; move result -> dividend
   sta dividend
   cmp divisor       ; if lsb result >= divisor, carry is set
   ldy result+1      ; if msb result is zero, zero bit is set; carry unaffected
   sty dividend+1
   bcs _more_digits  ; in case of lsb >= divisor
   bne _more_digits  ; in case of msb != 0
   tay               ; re-trigger status register test for zero
   beq _print_char   ; don't push a leading zero
   pha               ; push nonzero digit
   inx
_print_char:
   pla               ; print digits from stack
   clc
   adc #$30 ; ascii 0
   cmp #$3A ; >= 10 (e.g. hex)
   bcc _print
   adc #$31 ; difference from '0' to (friendly lowercase) 'a'
_print:
   jsr WriteCharacter
   dex               ; more digits on stack?
   bne _print_char
   rts

print_repl_result:
  lda #$5B ; [
  jsr WriteCharacter
  jsr printnum_base_10
  lda #$5D ; ]
  jsr WriteCharacter
  lda #13
  jsr WriteCharacter
  rts

