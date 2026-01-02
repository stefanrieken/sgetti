; Parser. Presently a stand-alone demo.

*=$0800

stringbuf=5000 ; arbitrarily chosen. Max 256 bytes
progmem=6000   ; equally arbitrary

ReadLine=$FFEB
WriteCharacter = $fff1
Parameters=$FF04

strlen = $20

init:
  lda #0
  sta stringmem
  lda progmem
  sta prgtop
  lda progmem+1
  sta prgtop+1
  ldx #$FF
  txs

;
; Parse code
;
; Presently we can just parse either a number or a label
; and provide some random feedback about it.
;

parse:

  jsr read_new_line

_parse_on:

  tya
  cmp strlen
  bcs parse

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
  lda #10  ; for base 10
  ldx #4   ; 10 is only 4 bits
  jsr multiply_by_a_x_bits
  pla  ; and add new digit
  clc
  adc multiplicand
  sta multiplicand
  bcc _more_digits
  inc multiplicand
  jsr _more_digits
_num_done:
  lda #PRIM_PUSHB
  jsr emit_optimized_cmd ; TODO totally untested

; for demo / test purposes, divide input by 11
lda #11
jsr divide_by_a

lda multiplicand
clc
adc #$30
jsr WriteCharacter
lda #13
jsr WriteCharacter

  jmp _parse_on

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
sbc #$30
  tya ; unique_string affects y
  pha ; so save y
  lda #<stringbuf
  ldy #>stringbuf
  jsr unique_string
  pla ; restore y
  tay
; String can be variable ref or expression level primitive.
; Since we have no vars yet, assume primitive. Push as idx+MAX_CORE
  txa
  clc

; Print string num
adc #$30
jsr WriteCharacter
sbc #$30

  adc #MAX_CORE
  jsr emit_byte ; TODO totally untested

lda #13
jsr WriteCharacter

  ;brk
  jmp _parse_on


next_char .macro
  iny
  lda (lineptr),y
.endmacro

; Read new line and set Y and strlen accordingly

read_new_line:
  jsr ReadLine

; Line is returned as a length prefixed string pointed to by parameters 0 and 1
; So copy that pointer to zero page so we can follow it
  lda Parameters+0
  sta lineptr
  lda Parameters+1
  sta lineptr+1

; Store string length
  ldy #$0
  lda (lineptr),y
  sta strlen

clc
adc #$30
jsr WriteCharacter
sbc #$30

  rts

