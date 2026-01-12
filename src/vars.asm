

; The var stack is a list of name/value pairs.
;
; In theory compile time var stack modeling (as done in the Pasta interpreter)
; renders the names redundant through access by offset(s). In practice having
; the names at runtime helps both for debugging and (simpler) access by name.

; We may grow vars top down: it is marginally easier in terms of 6502 math and flags,
; plus we may position var stack opposite to program memory.
; An argument to the contrary is anticipating the TOP_OF+VARS system from Pasta.


; note: 'get' has become redundant since label substitution works,
; so you can save some 20 bytes deleting this
get:
  ; Have name in arg1
  jsr lookup_from_arg1
  ldy #2
  lda (result),y
  sta arg1
  iny
  lda (result),y
  sta arg1+1
  txs
  jmp thread_loop

set:
  ; Have name in arg1; place value in arg2
  jsr stack_y_to_arg2
  jsr lookup_from_arg1  ; pointer in result
  bcs _done             ; lookup failed
_copy:
  ldy #2
  lda arg2
  sta (result),y
  sta arg1              ; also store as return result
  iny
  lda arg2+1
  sta (result),y
  sta arg1+1
_done:
  txs
  jmp thread_loop

define:
  ; Have name in arg1; place value in arg2
  jsr stack_y_to_arg2
  jsr do_define
  txs
  jmp thread_loop

do_define:
  jsr add_slot
_copy:
  tya
  pha
  ldy #3                ; Loop to set arg1,arg2 => name,value
_loop:
  lda arg1, y
  sta (varptr),y
  dey
  bpl _loop
  pla
  tay
  lda arg2              ; set value as result
  sta arg1
  lda arg2+1
  sta arg1+1
  rts

bind:
  ; effectively == define closure val; return closure
  ; Have value in arg1
  jsr add_slot
  ldy #0
  lda #$FF             ; equiv: "(closure)"
  sta (varptr),y
  iny
  sta (varptr),y
  lda arg1              ; set value
  iny
  sta (varptr),y
  lda arg1+1
  iny
  sta (varptr),y
  txs
  ; return slot pointer
  lda varptr
  sta arg1
  lda varptr+1
  sta arg1+1
  jmp thread_loop

funcall:
  tya
  pha
  ; Have closure pointer in arg1
  ; Sanity check if it is a closure by checking for name = 0xFFFF
  ldy #0
  lda (arg1),y
  cmp #$FF
  bne _error
  iny
  lda (arg1),y
  cmp #$FF
  bne _error
  iny
  lda (arg1),y
  sta result
  iny
  lda (arg1),y
  sta result+1
  ; Copy closure's value into arg1 where the eval_block primitive expects it as argument
  lda result
  sta arg1
  lda result+1
  sta arg1+1
  ; TODO pass args to 'funcall fn' to the function, to be picked up by 'args'
  ;
  ; There are 2 general ways to do this:
  ; 1) Keep them on the (arg)stack
  ;    - Stack currently reads "var2 var1 fn funcall (rts addresses)"
  ;    - Must not leave 'fn' and 'funcall' as garbage or later RTS will fail
  ;    - When leaving the stack cleaning to 'args' we MUST always have a call to 'args'
  ;    - No mechanism to detect mismatch between args (or detect 'funcall'?)
  ; 2) Template them on the var stack
  ;    - Let funcall pass its n unnamed args on varstack
  ;    - Let 'args' name these (note: no call to 'args' means no check!)
  ;    - if names < vars, delete excess values (so prefer last-as-last order) OR error
  ;    - if names > vars, add null vars OR error
  
  ; The eval_block primitive should handle the rest for us
  jmp eval_block
_error:
  txs
  jmp syntax_error      ; TODO in practice this prints a double result

add_slot:
  lda varptr
  sec
  sbc #4                ; 16-bit name + 16-bit value = 4 bytes
  sta varptr
  bcs _done
  dec varptr+1
_done:
  rts

; Lookup a variable slot
; Input:
; - y      -> offset from arg1 where variable name is stored
; - arg1+y -> name
; Result:
; - result -> pointer(!) to slot
; Set or clear carry to indicate failure / success
; Affects y
lookup_from_arg1:
  ; Move arg1 to result2 as main 'lookup' is written so as not to affect arg1
  ; Impact on 'get' speed is minimal as as 'get' is not the usual way to lookup a var
  lda arg1
  sta result2
  lda arg1+1
  sta result2+1
lookup:
  lda varptr
  sta result
  lda varptr+1
  sta result+1
_loop:
_check_at_end:
  cmp #>vars_end        ; having result+1 in hand
  bne _compare
  lda result
  cmp #<vars_end
  bne _compare
  sec                   ; Lookup failed; set carry as marker
  rts
_compare:
  ldy #0
  lda (result),y
  cmp result2
  bne _next
  iny
  lda (result),y
  cmp result2+1
  beq _found
_next:
  lda result
  clc
  adc #4                ; 16-bit name + 16-bit value = 4 bytes
  sta result
  lda result+1
  adc #0
  bcs _loop             ; Always taken
_found:
  clc                   ; Found; clear carry as marker
  rts

