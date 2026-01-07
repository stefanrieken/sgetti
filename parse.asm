; Parser. Presently a stand-alone demo.

*=$0800

linebuf=$0200   ; Say where ReadLine puts its results
stringbuf=$0300 ; Max 256 bytes
progmem=$6000   ; Arbitratily chosen

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

_next_char:
  #next_char
_have_char:  ; jump here if your last char may be the first of another arg
  tax
; increment num args
  pla        ; increment num args
  clc
  adc #1
  pha
; test for end of line
  tya       ; TODO do not hold y hostage for full REPL loop
  cmp strlen
  txa
  bcc _no_eol

_eval:
;#neo6502_breakpoint
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
  jsr print_repl_result
  pla
  tay
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

_switch_on_first_char:

_skip_whitespace:
  cmp #$20
  bne _try_sep
  #next_char
  jmp _skip_whitespace
_try_sep:
  cmp #';'
  bne _try_number
  pla       ; pull n args
  sta arg1
  ldx #PRIM_EVAL
  jsr emit_byte_cmd
  lda #$FF  ; start new arg count
  pha
  jmp _next_char
_try_number:
  cmp #'0'
  bcc _nan ; < '0'
  cmp #'9'+1
  bcs _nan ; > '9'
; yes!
  sec
  sbc #'0'
  sta multiplicand   ; use multiplicand for 2-byte number result
  ldx #0             ; switch to x to preserve digit a bit longer
  stx multiplicand+1
  ldx #10
  stx tmp            ; default base 10
  cmp #0             ; was given digit zero?
  bne _more_digits   ; if not, don't expect '0x'
  #next_char
  cmp #'x' ; hex indicator; TODO only trigger on zero and also accept inputs a-f
  bne +
  lda #16
  sta tmp
_more_digits:
  #next_char
+
  cmp #'0'
  bcc _num_done ; < '0'
  cmp #'9'+1
  bcc _done_adjusting
  cmp #'a'
  bcc _try_uppercase  ; if < 'a'
  sbc #$20            ; adjust to uppercase
_try_uppercase:
  cmp #'A'
  bcc _num_done
  cmp #'Z'+1          ; should realistically be 'F', but hey, we may support other bases some day
  bcs _num_done       ; not even in A-Z
  sec
  sbc #7              ; make 'A'..'Z' go next to '9'
_done_adjusting:
  sec
  sbc #'0'            ; now make it numeric
  cmp tmp             ; digit < base?
  bcs _num_done       ; if not, it's not a valid digit
  pha
  lda tmp  ; load base
  ldx #5   ; max = base 16 = 5 bits
  jsr multiply_by_a_x_bits
  pla  ; and add new digit
  clc
  adc multiplicand
  sta multiplicand
  bcc _more_digits
  inc multiplicand
  bcs _more_digits ; always taken
_num_done:
  ldx #PRIM_PUSHB
  jsr emit_optimized_cmd
  dey              ; we kind of messed up the last non-digit char, but this is an easy fix
  jmp _next_char

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
  jmp _next_char ; discard closing '"' that was already parsed

_parse_label:
  ldx #$20        ; space delimits label
  stx tmp
  jsr parse_string_or_label
  txa             ; x contains unique string index
  cmp #NUM_FIXED_STRINGS
  bcc _valid
  jsr syntax_error ; TODO retract emitted values in this line
  jmp parse
_valid:
  adc #MAX_CORE+1 ; assuming valid prim, adjust to jump table offset
;clc
;adc #$30
;jsr WriteCharacter
;sec
;sbc #$30
  tax
  jsr emit_byte
  jmp _next_char ; discard delimiting space

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

; Debug string num
;clc
;adc #$30
;jsr WriteCharacter
;sec
;sbc #$30

  rts

next_char .macro
  iny
  lda (lineptr),y
;jsr WriteCharacter
.endmacro

; Read new line and set Y and strlen accordingly

read_new_line:
  ; Apparently we define where the input comes using x, y.
  ldx #<linebuf
  ldy #>linebuf
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
  clc
  adc #1
  sta strlen
; Debug string length (as offset from ASCII character '0')
;clc
;adc #$30
;jsr WriteCharacter
;sec
;sbc #$30

  rts

