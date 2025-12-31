; Parser. Presently a stand-alone demo.

*=$0800

stringbuf=5000 ; arbitrarily chosen. Max 256 bytes

ReadLine=$FFEB
WriteCharacter = $fff1
Parameters=$FF04

strlen = $20
wordptr2 = $22      ; c64: 'utility pointer area for the BASIC interpreter'

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
  sta wordptr1  ; use wordptr1 for 2-byte number result
  lda #$0
  sta wordptr1+1
_more_digits:
  #next_char
  cmp #$30
  bmi _num_done ; < '0'
  cmp #$40
  bpl _num_done ; > '9'
  sec
  sbc #$30
  pha
  ldx #10  ; for base 10
  jsr multiply_by_x
  pla  ; and add new digit
  clc
  adc wordptr1
  sta wordptr1
  bcc _more_digits
  inc wordptr1
  jsr _more_digits
_num_done:
  lda wordptr1
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

; Multiply wordptr1 by x, temporarily using wordptr2

multiply_by_x:
; clear target
  lda #$00
  sta wordptr2
  sta wordptr2+1
_add_if_set:
  and #$1
  beq _shift_source
  clc
  lda wordptr1
  adc wordptr2
  sta wordptr2
  lda wordptr1+1
  adc wordptr2+1
  sta wordptr2+1
_shift_source:
  asl wordptr1+1 ; msb: ignore overflow
  asl wordptr1   ; lsb
  bcc _shift_x
  inc wordptr1   ; apply shift overlfow
_shift_x:
  txa
  lsr a
  tax
  bne _add_if_set
  lda wordptr2
  sta wordptr1
  lda wordptr2+1
  sta wordptr1+1
  rts

