; Use result2 to store old prgtop at zero page
; Should only live during & right after parse
old_prgtop = result2


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
  jsr finalize_parse
  jsr thread_loop       ; Eval
  jsr print_repl_result ; Print
; Due to 'done', ip has moved to prgtop+1; correct this
  lda prgtop
  sta ip
  lda prgtop+1
  sta ip+1
  jmp repl              ; Loop


;
; This should actually be done at all exit points of 'parse'.
; For now solve it like this.
;

finalize_parse:

; Add 'done 0' after prgtop to end program by rts;
; Do not increase prgtop so that later code can append by overwriting 'done'
; We may have parsed an empty statement, or an EVAL 0. In either case it seems it survives evaluation.
; Ideally though, we'd detect this and cleanup the whole toplevel 'keep' / 'scratch' statement.
  ldy #0
  lda #PRIM_DONE
  sta (prgtop),y
  iny
  lda #0                ; Don't clear any defines on toplevel
  sta (prgtop),y

; Finish the 'keep' or 'scratch' statement
  ldy #1
  lda prgtop
  sta (old_prgtop),y
  iny
  lda prgtop+1          ; TODO compute relative address for fully relocatable code! (search for this comment)
  sta (old_prgtop),y
  iny
  lda (old_prgtop),y
  cmp #PRIM_DEFINE      ; Was the line a toplevel 'define' statement? (TODO unify with 'set')
  bne +
  lda #PRIM_KEEP        ; Then mark it as 'keep' for source code listings (TODO scratch any previous defines)
  bne _set
+
  lda #PRIM_SCRATCH     ; Otherwise mark as 'scratch' command line history (alternative: forget line by resetting to old_prgtop)
_set:
  ldy #0
  sta (old_prgtop),y
  rts


;
; Parse code
;

; Non-ZP registers - TODO neither reentrant nor ROM-safe
stackbottom:
.byte 0

parse:
  tsx                   ; Save stack bottom to know if we still have (sub)expression data going
  stx stackbottom

  lda prgtop
  sta old_prgtop
  lda prgtop+1
  sta old_prgtop+1

  clc                   ; Reserve space for either a 'keep' or 'scratch' top level statement
  lda #3
  adc prgtop
  sta prgtop
  bcc +
  inc prgtop+1
+

  lda #$FF              ; Count args per (sub)expr
  sta argc              ; Start with -1 so we can start with an increment
  lda #0
  sta varc              ; Count the number of defines

_next_line:
  jsr read_new_line
_next_char:
  #next_char
  cmp #0                ; This is a kernalemu only quick-fix:
  bne _skip_whitespace  ; The c64 should return '\r' during EOF (I'd still rather READST returned EOF before the fact)
  ldx stackbottom       ; Kernalemu instead returns '0', which we would otherwise just accept as perpetual data.
  txs                   ; While I suspect '\r' to result in an 'eval 0' statement, this rts leaves the statement empty.
  rts                   ; Both these cases want fixing; however for now we rely on them simply surviving 'eval'.
_skip_whitespace:
  cmp #$20
  bne _skip_comment
  #next_char
  jmp _skip_whitespace
_skip_comment:
  cmp #'#'
  bne _have_char
_flush_line:
  #next_char
  cmp #13
  bne _flush_line
  ;jmp _next_line

_have_char:             ; jump here if your last char may be the first of another arg

  inc argc              ; increment n_args. Started at -1 to also count closing char (bracket, eol or sep)
; test for end of line
  cmp #13               ; carriage return == eol?
  bne _no_eol           ; if not end of line, continue to parsing
; Check if empty expr or open brackets left
; If not, emit toplevel eval
  lda argc
  beq _continue_expr    ; continue empty expression
  tsx                   ; check stack size to detect open brackets
  txa
  cmp stackbottom       ; continue expr if still brackets open
  bne _continue_expr
  jmp emit_eval         ; this one RTSes for us
_continue_expr:
  dec argc
  jmp _next_line        ; and read another line (assuming we're here because end of line!)

_no_eol:
_switch_on_first_char:

_try_sep:
  cmp #';'
  bne _try_open_sub
  jsr emit_eval
  lda #$FF  ; start new arg count
  sta argc
  jmp _next_char
_try_open_sub:
  cmp #'('
  bne _try_close_sub
  tax
  #sanity_check
  lda argc
  pha
  txa
  pha       ; for bracket matching
  lda #$FF  ; start new arg count
  sta argc
  jmp _next_char
_try_close_sub:
  cmp #')';
  bne _try_open_blk
  pla
  cmp #'('              ; matching bracket?
  beq _emit_eval
  jmp parse_error
_emit_eval:
  jsr emit_eval
  ldx #PRIM_PUSH_RESULT
  jsr emit_byte
  pla                   ; restore parent n args
  sta argc
  jmp _next_char
_try_open_blk:
  cmp #'{'
  bne _try_close_blk
  tax                   ; save opening bracket in x
  #sanity_check
  lda varc              ; save current num of defines (so not the one of the block!)
  pha
  lda #0                ; start new defines count for within block
  sta varc
  lda argc
  pha
  lda #$FF              ; start new arg count
  sta argc
  lda prgtop+1          ; push insertion point (minus one!) on stack
  pha
  lda prgtop
  pha
  txa                   ; save opening bracket
  pha                   ; for bracket matching
  ldx #PRIM_SKIPW       ; emit 'skip' instruction
  jsr emit_word_cmd     ; value is now garbage; must be fixed in close
  jmp _next_char
_try_close_blk:
  cmp #'}'
  bne _try_number
  pla                   ; bracket match
  cmp #'{'
  beq +
  jmp parse_error
+
  pla                   ; get insertion point from stack
  sta arg2
  pla
  sta arg2+1
  jsr emit_eval         ; first finish off final expr
  lda varc              ; number of defines
  sta arg1
  ldx #PRIM_DONE
  jsr emit_byte_cmd
  pla                   ; restore parent number of args AFTER we have emitted our own
  sta argc
  pla                   ; restore parent number of defines AFTER we have emitted our own
  sta varc
_insert_target:
  tya
  pha
  ldy #1                ; pointer is to start of instr, so +1 for word arg
  lda prgtop            ; TODO compute relative address for fully relocatable code! (search for this comment
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
  cmp #$61                ; 'a' (ASCII) or 'A' (PETSCII)
  bcc _try_other_case     ; if < 'a'
  sbc #$20                ; adjust to uppercase
_try_other_case:
  cmp #$41                ; 'A' (ASCII) or 'a' (PETSCII)
  bcc _num_done
  cmp #$5A+1              ; 'Z'; should realistically be 'F', but hey, we may support other bases some day
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

_try_string:
  cmp #$22              ; '"'
  bne _parse_label      ; if not a string, then a label
  sta tmp               ; store quote to signal string
;  #next_char
  jsr parse_string
  jsr unique_string_from_buf
  #sanity_check
_emit_str:
  ldx #PRIM_STRB
  jsr emit_optimized_cmd
  jmp _next_char        ; discard closing '"' that was already parsed

_parse_label:
  ldx #$20              ; space delimits label
  stx tmp               ; and unique_string checks for this value in tmp

  jsr parse_label       ; returns last unused char

  ; BEGIN `x:` style slot references
  cmp #' '              ; optional: allow for whitespace between `x` and `:`
  bne +
-
  #next_char
  cmp #' '
  beq -
+
  cmp #':'
  bne +
  sta tmp               ; signal to unique_str that this may be a new string
  jsr unique_string_from_buf
  jmp _emit_str         ; for now, just store slot reference as string ref
+
  ; END `x:` style slot references

  #unread               ; final char was not a label char
  jsr unique_string_from_buf
  bcs varref_error      ; carry marks no existing string was found; should never be so for label refs
  lda result+1
  bne _no_prim          ; a string index with msb>0 will not be a core string
  lda result
  cmp #NUM_FIXED_STRINGS
  bcs _no_prim
_prim:
  adc #MAX_CORE+1       ; assuming valid prim, adjust to jump table offset
  cmp #PRIM_DEFINE
  bne +
  inc varc              ; count number of defines
+
  cmp #PRIM_BIND
  bne +
  inc varc              ; 'bind' also produces a (closure) variable
+
  cmp #PRIM_ARGS
  bne +
  lda varc
  ora #$80               ; set msb to mark that we're parsing 'args'
  sta varc
  lda #PRIM_ARGS        ; and back to the prim value
+
  tax
  jsr emit_byte
  jmp _next_char
_no_prim:                ; have non primitive label
  lda argc
  cmp #0                 ; are we at first arg?
  bne _ref_only          ; then funcall it is
  ldx #PRIM_FUNCALL
  jsr emit_byte
  inc argc
_ref_only
  ldx #PRIM_REFB
  jsr emit_optimized_cmd
  jmp _next_char

varref_error:
  #flush
  lda #ERRNO_VARREF
  bne do_error
parse_error:
  #flush
  lda #ERRNO_SYNTAX
do_error:
  jsr print_errno
  lda old_prgtop
  sta prgtop
  lda old_prgtop+1
  sta prgtop+1
  ldx stackbottom
  txs
  jmp parse


;
; Parse string or label
;
; Pass end char in tmp
; Return values as defined by unique_string; final char in A

parse_string:
  ldx #$0
;  sta stringbuf,x
_next_char:
  #next_char
  cmp tmp
  beq string_or_label_done
  cmp #'\'              ; Allow at least the most common escape characters
  bne _escape_done
  #next_char
  cmp #'n'              ; Giving in and letting \n represent system's newline
  lda #13               ; maybe substitute this for system dependent constant
  bne _escape_done
  lda #$10
_escape_done:
  inx
  sta stringbuf,x
  jmp _next_char

;label_terminators:
;.byte ' ', 13, '{', '}', '(', ')', '"', ';', ':', 0
;string_terminators:
;.byte '"', 0

parse_label:
  ldx #$1
  sta stringbuf,x
_next_char:
  #next_char
  cmp tmp
  beq string_or_label_done
  cmp #13               ; check against newline
  beq string_or_label_done
  cmp #'{'
  beq string_or_label_done
  cmp #'}'
  beq string_or_label_done
  cmp #'('
  beq string_or_label_done
  cmp #')'
  beq string_or_label_done
  cmp #'"'
  beq string_or_label_done
  cmp #';'
  beq string_or_label_done
  cmp #':'
  beq string_or_label_done
  inx
  sta stringbuf,x
  jmp _next_char

string_or_label_done:
  pha                   ; to return final char
  inx
  lda #$0
  sta stringbuf,x
  inx
  stx stringbuf         ; save total size to start of string
  pla                   ; final char not used
  rts

; Throw an error if we parsed something other than a label at the start of an
; expression. This is easier than to restrict parser expectations beforehand,
; as parsing validly as a number, string, etc. actually marks a token invalid
; as a label.
;
; Pasta grammar may be practically context-free, but the 'eval' function will
; break hard if compiled expressions don't start with a primitive.
;
; There may be more useful sanity checks to make:
; - Block functions assume block literals as arguments.
;   We do not test against this yet. Preferred is to enforce this using parse state.
; - Arg naming functions assume strings for names.
;   We do not test against this; if you want chaos you can have it.
;   This may or may not change if we want to list defined vars.
; - Print functions assume string arguments.
;   We do not test against this.
sanity_check .macro
  lda argc              ; Literal or brackets at start of expr? No good!
  bne +
  jmp parse_error
+
.endmacro
