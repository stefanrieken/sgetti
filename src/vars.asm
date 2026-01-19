

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
  bcs rt_error
  ldy #2
  lda (result),y
  sta arg1
  iny
  lda (result),y
  sta arg1+1
  txs
  jmp thread_loop

set:
  ; Have name in arg1    ; place value in arg2
  jsr stack_y_to_arg2
  jsr lookup_from_arg1   ; pointer in result
  bcs _done              ; lookup failed
  jsr copy_var
;_copy:
;  ldy #2
;  lda arg2
;  sta (result),y
;  sta arg1              ; also store as return result
;  iny
;  lda arg2+1
;  sta (result),y
;  sta arg1+1
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
copy_var:
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
  lda arg2              ; set value as result (NOTE: successfully ignored in funcall)
  sta arg1
  lda arg2+1
  sta arg1+1
  rts

bind:
  ; effectively == define closure val; return closure
  jsr add_slot
  ldy #$FF             ; var $FFFF = "(closure)"
  jsr define_special
  txs
  ; return slot pointer
  lda varptr
  sta arg1
  lda varptr+1
  sta arg1+1
  jmp thread_loop

; Add special var like closure = $FFFF
; or parent = $FEFE
; Pass value in arg1, special name in Y
define_special:
  jsr add_slot
  tya                   ; Arg special name to A
  ldy #0
  sta (varptr),y
  iny
  sta (varptr),y
  lda arg1              ; set value
  iny
  sta (varptr),y
  lda arg1+1
  iny
  sta (varptr),y
  rts

rt_error:
  txs
  jmp syntax_error      ; TODO in practice this prints a double result

funcall:
  tya
  pha
  ; Have closure pointer in arg1
  ; Sanity check if it is a closure by checking for name = 0xFFFF
  ldy #0
  lda (arg1),y
  cmp #$FF
  bne rt_error
  iny
  lda (arg1),y
  cmp #$FF
  bne rt_error
_load_func:
  iny
  lda (arg1),y          ; load func from closure var's value
  sta result
  iny
  lda (arg1),y
  sta result+1
  ldy #$FE              ; Add parent pointer as $FEFE (probably easier to check for than $FFFE)
  jsr define_special
  pla
  tay
  ; Pass args to 'funcall fn' to the function, to be picked up by 'args'
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
  ;
  ; Here we implemented option #2.
_pass_args:
  dec argc
  bmi _args_done
  lda #0                ; empty name
  sta arg1
  sta arg1+1
  jsr stack_y_to_arg2_no_check
  jsr do_define
  jmp _pass_args
_args_done:
  lda result            ; function block to arg1
  sta arg1
  lda result+1
  sta arg1+1
  ; The eval_block primitive should handle the rest for us
  lda #4                ; Tell eval_block that this is a function
  jmp eval_block        ; Then it will clear the parent pointer for us

add_slot:
  lda varptr
  sec
  sbc #4                ; 16-bit name + 16-bit value = 4 bytes
  sta varptr
  bcs _done
  dec varptr+1
_done:
  rts

; TODO count arguments to 'args' toward number of defines in parser
args:
  inc argc              ; correct one off
  tya
  pha
  ldy #0
_count_slots:
  lda (varptr),y        ; check for empty name (TODO what if at start of vars?)
  iny
  ora (varptr),y
  bne _compare
  iny
  iny                   ; skip value
  iny
  jmp _count_slots
_compare:
  dey                   ; back to start of last non-empty var
  tya
  lsr a
  lsr a
  cmp argc              ; passed as many args as names?
  bne rt_error
_loop:
  dey                   ; back to name pos
  dey
  dey
  lda arg1+1
  sta (varptr),y
  dey
  lda arg1
  sta (varptr),y
  sty tmp               ; switch y back to arg stack index
  pla
  tay
  dec argc
  beq _done
  jsr stack_y_to_arg1_no_check
  tya
  pha
  ldy tmp
  jmp _loop
_done:
  txs
  jmp thread_loop
 
; Lookup a variable slot
; Input:
; - arg1 or result2 -> name. Call directly from 'lookup' not to affect arg1
; Result:
; - result -> pointer(!) to slot
; - carry: set if not found
; Set or clear carry to indicate failure / success
; Affects y, result2
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
  ldy #0                ; TODO skip parent pointer
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
  sta result+1
  jmp _loop
_found:
  clc                   ; Found; clear carry as marker
  rts

