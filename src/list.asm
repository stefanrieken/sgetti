listp:
  lda #<progmem
  sta primptr            ; store our "instruction pointer" here, for a place
  lda #>progmem
  sta primptr+1
  lda #0
  sta sep             ; store separator in sep
  sta argc               ; store expression depth in argc
list_loop:
  jsr next_list_byte
  tay
; check for end
  lda primptr+1
  cmp prgtop+1           ; cs = idx >= prgtop ; so cc = idx < prgtop
  beq +
  bcs list_done              ; page too far -> done
  bcc _not_done
+
  lda primptr            ; we only get here if page is same
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
  inc argc
  jsr print_sep
  lda #'('
  sta sep              ; because we are going to print a separator
+
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
  jsr reverse_lookup
  jsr print_sep
  jsr print_arg1
list_ws_loop:
  lda #$20
  sta sep
  jmp list_loop
list_done:
  lda #13
  jsr WriteCharacter
  txs
  lda #$0               ; same field is used in parse, so clean up
  sta sep
  jmp thread_loop

next_list_byte:
  ldy #0
  lda (primptr),y
; increment to next
  clc
  inc primptr
  bne +
  inc primptr+1
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
  .text >print_push_result-1, >print_skipw-1, >print_eval-1, >print_done-1
printtable_lsb:
  .text <print_push0-1, <print_push1-1, <print_pushb-1, <print_pushw-1, <print_strb-1, <print_strw-1, <print_refb-1, <print_refw-1
  .text <print_push_result-1, <print_skipw-1, <print_eval-1, <print_done-1

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
print_eval:
  jsr next_list_byte
  lda #0
  sta argc
  lda #';'
  ;bne print_char_in_a
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


_print_next:
; only looks up fixed strings
; pass 1 byte string num in a
reverse_lookup:
  sta tmp
  lda #<fixed_strings
  sta arg1
  lda #>fixed_strings
  sta arg1+1
  ldy #0
  txa
  pha
  ldx #0
_loop:
  txa
  cmp tmp
  beq _done
  lda (arg1),y          ; jump to next string using total size
  clc
  adc arg1
  sta arg1
  bcc +
  inc arg1+1
+
  inx
  bne _loop
_done:
  pla
  tax
  rts

