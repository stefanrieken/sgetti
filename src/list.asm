;
; List primitives
;

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
  sta sep                ; store separator in sep
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
  lda argc
  beq +
  jsr print_sep
  lda #'('
  sta sep              ; because we are going to print a separator
+
  inc argc
  tya
  cmp #PRIM_FUNCALL
  bne +
  jsr print_sep
  lda #$0
  sta sep
  jmp list_loop
  bne +
+
  sec
  sbc #MAX_CORE+1
  jsr string_n
  jsr print_sep
  jsr print_arg1
list_ws_loop:
  lda #$20
  sta sep
  jmp list_loop
list_done:
  lda #13
  jsr WriteCharacter
  lda #$0               ; same field is used in parse, so clean up
  sta sep
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

print_sep:
  lda sep
  beq +
  jsr WriteCharacter
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
+
  jsr print_sep
  jsr WriteCharacter
  jmp list_loop
print_pushb:
  jsr next_list_byte
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
  jsr print_sep
  jsr printnum_base_10
  pla
  tax
  jmp list_loop
print_strb:
  jsr print_sep
  lda #'"'
  jsr WriteCharacter
  lda #0
  sta arg1
  jsr next_list_byte
  jmp print_string
print_strw:
  jsr print_sep
  lda #'"'
  jsr WriteCharacter
  jsr next_list_byte
  sta arg1
  jsr next_list_byte
print_string:
  sta arg1+1
  jsr print_arg1
  lda #'"'
print_char_in_a:
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
  jsr print_sep
  jsr print_arg1
  jmp list_ws_loop
print_push_result:
  lda #' '
  sta sep
  lda #')'
  dec argc
  jmp print_char_in_a
print_skipw:
  jsr next_list_byte
  jsr next_list_byte
  jsr print_sep
  lda #0
  sta sep            ; no space
  sta argc              ; recount depth for brackets (works out ok for normal block usage)
  lda #'{'
  bne print_char_in_a
print_keep:
  jsr next_list_byte
  jsr next_list_byte
  lda #13               ; Separate toplevel statements by a newline
  sta sep
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
  lda #13               ; Separate toplevel statements by a newline
  sta sep
  jmp list_loop
print_eval:
  jsr next_list_byte
  lda #0
  sta argc
  lda #';'
  sta sep
  jmp list_loop
print_done:
  jsr next_list_byte
;  cmp #0
;  bne +
  lda #$20
  sta sep
  lda #'}'
  bne print_char_in_a
+
  jmp list_loop

