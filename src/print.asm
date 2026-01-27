;
; Print functions
;

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
   jsr convert_num
   lda #<stringbuf
   sta arg1
   lda #>stringbuf
   sta arg1+1
   jsr print_arg1
   rts

; Convert a number in arg1 to a tmp string buffer
; Uses A, X and Y

convert_num_base_10:
   lda #10
   sta divisor
   lda #0
   sta divisor+1
convert_num:
   ldx #0               ; digit counter
_more_digits:
   jsr divide
   lda remainder        ; expect a 1 byte remainder (for bases < 256)
   pha
   inx
   lda result           ; move result -> dividend
   sta dividend
   cmp divisor          ; if lsb result >= divisor, carry is set
   ldy result+1         ; if msb result is zero, zero bit is set; carry unaffected
   sty dividend+1
   bcs _more_digits     ; in case of lsb >= divisor
   bne _more_digits     ; in case of msb != 0
   tay                  ; re-trigger status register test for zero
   beq _put             ; don't push a leading zero
   pha
   inx
_put:
   ldy #1
-
   pla
   clc
   adc #$30             ; ascii 0
   cmp #$3A             ; >= 10 (e.g. hex)
   bcc +
   adc #$05             ; difference from $3a to 'a' (minus carry)
+
   sta stringbuf,y
   iny
   dex               ; more digits on stack?
   bne -
   lda #0
   sta stringbuf,y
   iny
   sty stringbuf
   rts

print_repl_result:
  #get_column
  beq +
  lda #13
  jsr WriteCharacter
+
  lda #$5B ; [
  jsr WriteCharacter
  jsr printnum_base_10
  lda #$5D ; ]
  jsr WriteCharacter
  lda #13
  jsr WriteCharacter
  rts


errs:
.text 14, "syntax error", 0
.text 20, "undefined variable", 0
.text 15, "runtime error", 0
.text 20, "arg count mismatch", 0, 0

ERRNO_SYNTAX = 0
ERRNO_VARREF = 1
ERRNO_RT = 2
ERRNO_ARGS = 3

print_errno:
;.byte 3
  sta tmp
  lda #<errs
  sta arg1
  lda #>errs
  sta arg1+1
  jsr string_n_in_tmp_dict_in_arg1
  jsr print_arg1
  lda #13
  jsr WriteCharacter
  rts

