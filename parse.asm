; Parser. Presently a stand-alone demo.

*=$0800

stringbuf=5000 ; arbitrarily chosen. Max 256 bytes

ReadLine=$FFEB
WriteCharacter = $fff1
Parameters=$FF04

strlen = $20

init:
  lda #0
  sta stringmem
  ldx #$FF
  txs

; Parse code

parse:

  jsr read_new_line

clc
adc #$30
jsr WriteCharacter

  #next_char

_switch_on_first_char:

_try_number:
  cmp #$30
  bmi _nan ; < '0'
  cmp #$40
  bpl _nan ; > '9'
; yes!
  sec
  sbc #$30
  sta multiplicand  ; use multiplicand for 2-byte number result
  lda #$0
  sta multiplicand+1
_more_digits:
  #next_char
  cmp #$30
  bmi _num_done ; < '0'
  cmp #$40
  bpl _num_done ; > '9'
  sec
  sbc #$30
  pha
;  ldx #10  ; for base 10
;  jsr multiply_by_x
  lda #10  ; for base 10
  jsr multiply_by_a
  pla  ; and add new digit
  clc
  adc multiplicand
  sta multiplicand
  bcc _more_digits
  inc multiplicand
  jsr _more_digits
_num_done:
lda multiplicand
clc
adc #$30
jsr WriteCharacter
lda #13
jsr WriteCharacter
  jmp parse

_nan:
_parse_label:
  ldx #$1
  sta stringbuf,x
_next_char:
  #next_char
  cmp #$20 ; space
  beq _label_done
  cmp #13 ; newline
  beq _label_done
  inx
  sta stringbuf,x
  jmp _next_char
_label_done:
  inx
  lda #$0
  sta stringbuf,x
  inx
  stx stringbuf ; save total size
txa
clc
adc #$30
jsr WriteCharacter ; prints size
  lda #<stringbuf
  ldy #>stringbuf
  jsr unique_string
; Print string num
txa
adc #$30
jsr WriteCharacter
lda #13
jsr WriteCharacter
  ;brk
  jmp parse


next_char .macro
  iny
;  tya
;  cmp strlen ; because of size prefix, y = strlen+1, so this goes off at the first invalid char
;  bne _read_char
;  lda #13 ; newline
;  jsr read_new_line
;  jmp _done_reading
_read_char
  lda (wordptr0),y
;jsr WriteCharacter
_done_reading
.endmacro

; Read new line and set Y and strlen accordingly

read_new_line:
  jsr ReadLine

; Line is returned as a length prefixed string pointed to by parameters 0 and 1
; So copy that pointer to zero page so we can follow it
  lda Parameters+0
  sta wordptr0
  lda Parameters+1
  sta wordptr0+1

; Store string length
  ldy #$0
  lda (wordptr0),y
  sta strlen
  rts

; Invoke 'multiply' with 1-byte multiplier in a, and result copied back into multiplicand.

multiply_by_a:
  sta multiplier
  lda #$00
  sta multiplier+1
  ldx #8
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
