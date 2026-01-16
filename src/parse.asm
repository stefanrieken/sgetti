init:
  lda #0
  sta stringmem
  lda #<progmem
  sta prgtop
  sta ip
  lda #>progmem
  sta prgtop+1
  sta ip+1
  lda #<vars_end
  sta varptr
  lda #>vars_end
  sta varptr+1
  ldx #$FF ; TODO does CHRGET use top of stack?
  txs

repl:
  jsr parse             ; Read
; Add 'done 0' after prgtop to end program by rts;
; Do not increase prgtop so that later code can append by overwriting 'done'
  ldy #0
  lda #PRIM_DONE
  sta (prgtop),y
  iny
  lda #0                ; Don't clear any defines on toplevel
  sta (prgtop),y
  jsr thread_loop       ; Eval
  jsr print_repl_result ; Print
; Due to 'done', ip has moved to prgtop+1; correct this
  lda prgtop
  sta ip
  lda prgtop+1
  sta ip+1
  jmp repl              ; Loop

;
; Parse code
;

parse:
  tsx                   ; Save stack bottom to know if we still have (sub)expression data going
  stx stackbottom

  lda #$FF              ; Count args per subexpr on stack
  pha                   ; Start with -1 so we can start with an increment
  lda #0
  sta argc              ; Count the number of defines

_next_line:
  jsr read_new_line
_next_char:
  #next_char
_have_char:             ; jump here if your last char may be the first of another arg
  tax                   ; char to x
; increment num args
  pla
  clc
  adc #1
  pha
; test for end of line
  txa                   ; restore char to a
  cmp #13               ; carriage return == eol?
  bne _no_eol           ; if not end of line, continue to parsing
; Check if open brackets left
; If not, emit toplevel eval
  pla                   ; pull n args
  sta arg1
  tsx                   ; check stack size to detect open brackets
  txa
  cmp stackbottom
  bne _have_brackets_open
  jmp emit_eval         ; this one RTSes for us
_have_brackets_open:
  lda arg1              ; restore last arg count on stack
  sec
  sbc #1                ; we incremented it without parsing an argument; so retract that
  pha
  jmp _next_line        ; and read another line (assuming we're here because end of line!)

_no_eol:

_switch_on_first_char:

_skip_whitespace:
  cmp #$20
  bne _try_sep
  #next_char
  jmp _skip_whitespace

_try_sep:
  cmp #';'
  bne _try_open_sub
  pla       ; pull n args
  sta arg1
  jsr emit_eval
  lda #$FF  ; start new arg count
  pha
  jmp _next_char
_try_open_sub:
  cmp #'('
  bne _try_close_sub
  tax
  #sanity_check
  txa
  pha       ; for bracket matching
  lda #$FF  ; start new arg count
  pha
  jmp _next_char
_try_close_sub:
  cmp #')';
  bne _try_open_blk
  pla       ; pull n args
  sta arg1
  pla
  cmp #'('              ; matching bracket?
  beq _emit_eval
  jmp parse_error
_emit_eval:
  jsr emit_eval
  ldx #PRIM_PUSH_RESULT
  jsr emit_byte
  jmp _next_char
_try_open_blk:
  cmp #'{'
  bne _try_close_blk
  tax                   ; save opening bracket in x
  #sanity_check
  lda argc              ; save current num of defines (so not the one of the block!)
  pha
  lda #0                ; start new defines count for within block
  sta argc
  lda prgtop+1          ; push insertion point (minus one!) on stack
  pha
  lda prgtop
  pha
  txa                   ; save opening bracket
  pha                   ; for bracket matching
  lda #$FF              ; start new arg count
  pha
  ldx #PRIM_SKIPW       ; emit 'skip' instruction
  jsr emit_word_cmd     ; value is now garbage; must be fixed in close
  jmp _next_char
_try_close_blk:
  cmp #'}'
  bne _try_number
  pla                   ; arg count of last expression
  sta tmp
  pla                   ; bracket match
  cmp #'{'
  beq +
  jmp parse_error
+
  pla                   ; get insertion point from stack
  sta arg2
  pla
  sta arg2+1
_insert_target:
  lda tmp               ; arg count of last expression
  sta arg1
  jsr emit_eval
  lda argc              ; number of defines
  sta arg1
  ldx #PRIM_DONE
  jsr emit_byte_cmd
  pla                   ; restore parent number of defines AFTER we have emitted our own
  sta argc
  tya
  pha
  ldy #1                ; pointer is to start of instr, so +1 for word arg
  lda prgtop
  sta (arg2),y
  iny
  lda prgtop+1
  sta (arg2),y
  pla
  tay
  jmp _next_char
_try_number:
  cmp #'0'
  bcc _nan ; < '0'
  cmp #'9'+1
  bcs _nan ; > '9'
; yes!
  sec
  sbc #'0'
  sta multiplicand      ; use multiplicand for 2-byte number result
  ldx #0                ; switch to x to preserve digit a bit longer
  stx multiplicand+1
  ldx #10
  stx tmp               ; default base 10
  cmp #0                ; was given digit zero?
  bne _more_digits      ; if not, don't expect '0x'
  #next_char
  cmp #'x'
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
  bcc _try_uppercase      ; if < 'a'
  sbc #$20                ; adjust to uppercase
_try_uppercase:
  cmp #'A'
  bcc _num_done
  cmp #'Z'+1              ; should realistically be 'F', but hey, we may support other bases some day
  bcs _num_done           ; not even in A-Z
  sec
  sbc #7                  ; make 'A'..'Z' go next to '9'
_done_adjusting:
  sec
  sbc #'0'                ; now make it numeric
  cmp tmp                 ; digit < base?
  bcs _num_done           ; if not, it's not a valid digit
  pha                     ; push digit
  tya                     ; save y reg
  pha
  lda tmp                 ; load base
  ldy #5                  ; max = base 16 = 5 bits
  jsr multiply_by_a_y_bits
  pla                     ; restore y reg
  tay
  pla                     ; and add new digit
  clc
  adc multiplicand
  sta multiplicand
  bcc _more_digits
  inc multiplicand+1
  bcs _more_digits      ; always taken
_num_done:
  #unread               ; last char was not a digit
  #sanity_check
  ldx #PRIM_PUSHB
  jsr emit_optimized_cmd
  jmp _next_char

_nan:

_parse_string:
  cmp #$22              ; '"'
  bne _parse_label      ; if not a string, then a label
  sta tmp               ; store quote to signal string
  #next_char
  jsr parse_string_or_label
  #sanity_check
  ldx #PRIM_STRB
  jsr emit_optimized_cmd
  jmp _next_char        ; discard closing '"' that was already parsed

_parse_label:
  ldx #$20              ; space delimits label
  stx tmp
  jsr parse_string_or_label
  #unread               ; final char was not a label char
  bcs parse_error       ; carry marks no existing label found
  lda result+1
  bne _no_prim          ; a string index with msb>0 will not be a core string
  lda result
  cmp #NUM_FIXED_STRINGS
  bcs _no_prim
_prim:
  adc #MAX_CORE+1       ; assuming valid prim, adjust to jump table offset
  cmp #PRIM_DEFINE
  bne +
  inc argc              ; count number of defines
+
  cmp #PRIM_BIND
  bne +
  inc argc              ; 'bind' also produces a (closure) variable
+
  cmp #PRIM_ARGS
  bne +
  lda argc
  ora #$80               ; set msb to mark that we're parsing 'args'
  sta argc
  lda #PRIM_ARGS        ; and back to the prim value
+
  tax
  jsr emit_byte
  jmp _next_char
_no_prim:
  pla                    ; have non primitive label
  cmp #0                 ; are we at first arg?
  pha
  bne _ref_only          ; then funcall it is
  ldx #PRIM_FUNCALL
  jsr emit_byte
  pla
  clc
  adc #1
  pha
_ref_only
  ldx #PRIM_REFB
  jsr emit_optimized_cmd
  jmp _next_char

;
; Parse string or label
;
; Pass end char in tmp
; Return values as defined by unique_string; final char in a

parse_string_or_label:
  ldx #$1
  sta stringbuf,x
_next_char:
  #next_char
  cmp tmp
  beq _label_done
  cmp #13               ; check against newline
  beq _label_done
  inx
  sta stringbuf,x
  jmp _next_char
_label_done:
  pha                   ; to return final char
  inx
  lda #$0
  sta stringbuf,x
  inx
  stx stringbuf         ; save total size to stat of string
; feed to unique_string
  tya                   ; unique_string affects y
  pha                   ; so save y
  lda #<stringbuf
  ldy #>stringbuf
  jsr unique_string
  pla                   ; restore y
  tay
  pla                   ; final char not used
  rts

parse_error:
  #flush
  jsr syntax_error      ; TODO retract emitted values in this line (save prgtop just like stackbottom)
  ldx stackbottom
  txs
  jmp parse

sanity_check .macro
  pla                   ; Literal or brackets at start of expr? No good!
  bne +
  jmp parse_error
+
  pha
.endmacro
