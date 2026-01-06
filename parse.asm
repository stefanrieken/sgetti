; Parser. Presently a stand-alone demo.

*=$0800

stringbuf=$5000 ; arbitrarily chosen. Max 256 bytes
progmem=$6000   ; equally arbitrary

ReadLine=$FFEB
WriteCharacter = $fff1
Parameters=$FF04

strlen = $20

init:
  lda #0
  sta stringmem
  lda #<progmem
  sta prgtop
  sta ip
  lda #>progmem
  sta prgtop+1
  sta ip+1
  ldx #$FF
  txs

;
; Parse code
;
; Presently we can just parse either a number or a label
; and provide some random feedback about it.
;

parse:
  lda #$FF ; Count args per subexpr on stack
  pha      ; Start with -1 so we can start with an increment

  jsr read_new_line

_parse_on:
  pla      ; increment num args
  clc
  adc #1
  pha

_next_char:
  ; test for end of line
  tya      ; TODO do not hold y hostage for full REPL loop
  cmp strlen
  bcc _no_eol
;bcs _parse_new_line

_eval:
  pla       ; pull n args
  sta arg1
  ldx #PRIM_EVAL
  jsr emit_byte_cmd
  ; Temporarily append 'done'
  ldx #PRIM_DONE
  jsr emit_byte
  tya
  pha
  jsr thread_loop ; Run expression
  pla
  tay
  ; TODO print arg1 as result value

  ; Remove 'done' so that any later code is appended into one program
  lda prgtop
  sec
  sbc #1
  sta prgtop
  sta ip
  bcs +
  lda prgtop+1
  sbc #1
  sta prgtop
  sta ip
+
  ; And start new round
  tsx
;#neo6502_breakpoint
  jmp parse

_no_eol:

  #next_char

_switch_on_first_char:

_skip_whitespace:
  cmp #$20
  beq _next_char
_try_sep:
  cmp #$3B ; ';'
  bne _try_number
  pla       ; pull n args
  sta arg1
  ldx #PRIM_EVAL
  jsr emit_byte_cmd
  lda #0  ; start new arg count
  pha
  jmp _next_char
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
  ldx #PRIM_PUSHB
  jsr emit_optimized_cmd

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

_parse_string:
  cmp #$22         ; '"'
  bne _parse_label ; if not a string, then a label
  sta tmp          ; store quote to signal string
  #next_char
  jsr parse_string_or_label
;  #next_char ; skip closing '"'
  ldx #PRIM_STRB
  jsr emit_optimized_cmd
  ;brk
  jmp _parse_on ; discard closing '"' that was already parsed

_parse_label:
  ldx #$20        ; space delimits label
  stx tmp
  jsr parse_string_or_label
  txa             ; x contains unique string index
  clc
  adc #MAX_CORE+1 ; assuming valid prim, adjust to jump table offset
;clc
;adc #$30
;jsr WriteCharacter
;sec
;sbc #$30
  tax
  jsr emit_byte
  ;brk
  jmp _parse_on ; note that we discard the separating space. If we start to allow functional chars to separarate, don't discard these


;
; Parse string or label
;
; Pass end char in tmp
; Return values as defined by unique_string

parse_string_or_label:
  ldx #$1
  sta stringbuf,x
_next_char:
  #next_char
  cmp tmp ; either quote or space
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
; Debug total size
;txa
;clc
;adc #$30
;jsr WriteCharacter ; prints size
;sec
;sbc #$30
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

; Debug string num
;adc #$30
;jsr WriteCharacter
;sbc #$30

  rts

next_char .macro
  iny
  lda (lineptr),y
;jsr WriteCharacter
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

; Debug string length (as offset from ASCII character '0')
;clc
;adc #$30
;jsr WriteCharacter
;sec
;sbc #$30

  rts

