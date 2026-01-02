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
  ldx #$16      ; easier to just count max cycles than to determine whether 2-byte multiplier is fully shifted out
multiply_x_bits ; target for a limited sized multiplier
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
  sta tmp        ; temporarily save half-subtraction result
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

