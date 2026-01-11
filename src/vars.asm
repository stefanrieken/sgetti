

; The var stack is a list of name/value pairs.
;
; In theory compile time var stack modeling (as done in the Pasta interpreter)
; renders the names redundant through access by offset(s). In practice having
; the names at runtime helps both for debugging and (simpler) access by name.

; We may grow vars top down: it is marginally easier in terms of 6502 math and flags,
; plus we may position var stack opposite to program memory.
; An argument to the contrary is anticipating the TOP_OF+VARS system from Pasta.


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
_add_slot:
  lda varptr
  sec
  sbc #4                ; 16-bit name + 16-bit value = 4 bytes
  sta varptr
  bcs _copy
  dec varptr+1
_copy:
  ldy #3                ; Loop to set arg1,arg2 => name,value
_loop:
  lda arg1, y
  sta (varptr),y
  dey
  bpl _loop
  lda arg2              ; set value as result
  sta arg1
  lda arg2+1
  sta arg1+1
  txs
  jmp thread_loop

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
  bcc _loop
  inc result+1
  bcs _loop             ; Always taken
_found:
  clc                   ; Found; clear carry as marker
  rts

