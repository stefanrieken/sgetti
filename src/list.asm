;
; List primitives and related commands
;

reset:
  jmp init
load:
  txa
  pha
  lda #0
  jsr open_file
  bcs _done
;  cmp #0
;  bne _done
-
  jsr parse
  jsr finalize_parse
  jsr stat_file
  cmp #0
  beq -
;  jsr thread_loop       ; Can't recursively call thread_loop -- but the appended code will be run anyway :D
_done:
  jsr close_file
  pla
  tax
  txs
  jmp thread_loop
save:
  lda #1                 ; Set to write
  jsr open_file
  jsr do_list
  jsr close_file
  txs
  jmp thread_loop
hist:                    ; list full command history
  nop                    ; 'hist' and 'list' must be different
listp:                   ; only list effective program ('list' is a 64tass keyword)
  jsr do_list
  txs
  jmp thread_loop
do_list:
  lda #<progmem
  sta lineptr            ; store our "instruction pointer" here, for a place
  lda #>progmem
  sta lineptr+1
  lda #0
  sta argc               ; store expression depth in argc
list_loop:
  jsr next_list_byte
  tay
; check for end
  lda lineptr+1
  cmp prgtop+1           ; cs = idx >= prgtop ; so cc = idx < prgtop
  beq +
  bcs list_done              ; page too far -> done
  bcc _not_done
+
  lda lineptr            ; we only get here if page is same
  cmp prgtop             ; cs = idx >= prgtop
  bcs list_done
_not_done:
  tya
  cmp #MAX_CORE+1
  bcs _expr_prim
  lda printtable_msb,y
  pha
  lda printtable_lsb,y
  pha
  rts ; JMP
_expr_prim:
  lda argc              ; Are we a subexpression?
  and #$80
  beq +
  lda #' '
  jsr WriteCharacter
  lda #'('
  jsr WriteCharacter
  jmp _cont
+
  jsr print_ws
_cont:
  tya
  cmp #PRIM_FUNCALL
  bne +
  jmp list_loop
+
  lda argc              ; set subexpr detection bit
  ora #$80
  sta argc
  tya
  sec
  sbc #MAX_CORE+1
  jsr string_n
  jsr print_arg1
  jmp list_loop
list_done:
  lda #13
  jsr WriteCharacter
  rts

print_ws:
  tya
  pha
  lda argc              ; check depth bits
  and #$7F
  tay
  beq +
  lda #' '
-
  jsr WriteCharacter
  dey
  bne -
+
  pla
  tay
  rts

next_list_byte:
  ldy #0
  lda (lineptr),y
; increment to next
  clc
  inc lineptr
  bne +
  inc lineptr+1
+
  rts

printtable_msb:
  .text >print_push0-1, >print_push1-1, >print_pushb-1, >print_pushw-1, >print_strb-1, >print_strw-1, >print_refb-1, >print_refw-1
  .text >print_push_result-1, >print_skipw-1, >print_keep-1, >print_scratch-1, >print_eval-1, >print_done-1
printtable_lsb:
  .text <print_push0-1, <print_push1-1, <print_pushb-1, <print_pushw-1, <print_strb-1, <print_strw-1, <print_refb-1, <print_refw-1
  .text <print_push_result-1, <print_skipw-1, <print_keep-1, <print_scratch-1, <print_eval-1, <print_done-1

print_push0:
  lda #'0'
  beq +
print_push1:
  lda #'1'
  bne +
print_pushb:
  jsr next_list_byte
+
  sta arg1
  lda #0
  beq +
print_pushw:
  jsr next_list_byte
  sta arg1
  jsr next_list_byte
+
  sta arg1+1
  txa
  pha
  lda #' '
  jsr WriteCharacter
  jsr printnum_base_10
  pla
  tax
  jmp list_loop
print_strb:
  jsr next_list_byte
  sta arg1
  lda #0
  beq +
print_strw:
  jsr next_list_byte
  sta arg1
  jsr next_list_byte
+
  sta arg1+1
  lda #' '
  jsr WriteCharacter
  lda #'"'
  jsr WriteCharacter
  jsr print_arg1
  lda #'"'
  jsr WriteCharacter
  jmp list_loop
print_refb:
  lda #0
  sta arg1
  jsr next_list_byte
  bne print_label
print_refw:
  jsr next_list_byte
  sta arg1
  jsr next_list_byte
print_label:
  sta arg1+1
  lda argc              ; if here through 'funcall', subexpr bit was not yet set
  and #$80
  beq +                 ; in that case, don't print leading space
  lda #' '
  jsr WriteCharacter
+
  jsr print_arg1
  lda argc              ; set subexpr detection bit
  ora #$80
  sta argc
  jmp list_loop
print_push_result:
  lda argc              ; set subexpr detection bit
  ora #$80
  sta argc
  lda #')'
  jmp print_char_in_a
print_skipw:
  jsr next_list_byte
  jsr next_list_byte
  lda #' '
  jsr WriteCharacter
  lda argc              ; unset subexpr detection bit
  and #$7F
  sta argc
  inc argc              ; but increment depth
  clc
  lda #'{'
  jsr WriteCharacter
  lda #13
  bne print_char_in_a
print_keep:
  jsr next_list_byte
  jsr next_list_byte
  lda #13               ; Separate toplevel statements by a newline
print_char_in_a:
  jsr WriteCharacter    ; This (also) prints one extra newline at the start. Not necessary?
  jmp list_loop
print_scratch:
  lda primptr           ; Called from 'hist'?
  cmp #<hist            ; Really only need to check lsb
  beq print_keep        ; Then just print everything
  jsr next_list_byte    ; Otherwise skip over scratch item
  pha
  jsr next_list_byte
  sta lineptr+1         ; TODO compute relative address for fully relocatable code! (search for this comment
  pla
  sta lineptr
  jmp list_loop
print_eval:
  jsr next_list_byte
  lda argc             ; clear subexpr detection bit
  and #$7F
  sta argc
  ldy #0                ; peek next instruction
  lda (lineptr),y
  cmp #MAX_CORE+1       ; are we part of an expression sequence?
  bcc +
  lda #';'              ; then print separator
  jsr WriteCharacter
  lda #13               ; (and a newline)
  jsr WriteCharacter
+
  jmp list_loop
print_done:
  jsr next_list_byte
  lda #13
  jsr WriteCharacter
  dec argc
  jsr print_ws
  lda #'}'
  bne print_char_in_a
  jmp list_loop

