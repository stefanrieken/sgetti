; Invoke 'multiply' with 1-byte multiplier in a, and result copied back into multiplicand.

multiply_by_a:
  ldx #8
multiply_by_a_x_bits:
  sta multiplier
  lda #$00
  sta multiplier+1
  jsr multiply_x_bits ; a is max 8 bits wide
  lda result
  sta multiplicand
  lda result+1
  sta multiplicand+1
  rts

; 16-bit multiply using (3 of) our 4 16-bit zero page registers
; by their appropriate alias (multiplier, multiplicand, result)
; Also uses x

multiply:
  ldx #$16       ; easier to just count max cycles than to determine whether 2-byte multiplier is fully shifted out
multiply_x_bits: ; target for a limited sized multiplier
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
  dex
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
  ldx #16          ; because we start from msb, we can't too easily skip bits here
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
  dex
  bne _next_bit
  rts

; Print a number in base <dividend>
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
   ldy #0            ; digit counter
_more_digits:
   jsr divide
   lda remainder     ; expect a 1 byte remainder (for bases < 256)
   pha
   iny
   lda result        ; move result -> dividend
   sta dividend
   cmp divisor       ; if lsb result >= divisor, carry is set
   ldx result+1      ; if msb result is zero, zero bit is set; carry unaffected
   stx dividend+1
   bcs _more_digits  ; in case of lsb >= divisor
   bne _more_digits  ; in case of msb != 0
   tax               ; re-trigger test for zero
   beq _print_char   ; don't push a leading zero
   pha               ; push nonzero digit
   iny
_print_char:
   pla               ; print digits from stack
   clc
   adc #$30 ; ascii 0
   cmp #$3A ; >= 10 (e.g. hex)
   bcc _print
   adc #$31 ; difference from '0' to (friendly lowercase) 'a'
_print:
   jsr WriteCharacter
   dey               ; more digits on stack?
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

