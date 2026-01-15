;
; Core primitives
; 

push0:
  lda #0
  pha
  pha
  beq thread_loop
push1:
  ldx #$1
  bne push_byte_in_x
push_byte:
  jsr next_byte ; then fall through:
  tax
push_byte_in_x:
  lda #$00 ; empty msb, then fall through:
push_word_in_x_a:
  pha ; msb
  txa ; lsb is pushed last so that it is pulled first
  pha
  jmp thread_loop
push_word:
  jsr next_byte
  tax ; keep lsb safe in x
  jsr next_byte
  pha ; push msb first
  txa
  pha ; push lsb last
  jmp thread_loop
ref_byte:
  jsr next_byte
  tax
  lda #$00
ref_word:
  ; TODO we can't afford to mess up arg1 here!
  jsr next_byte
  tax
  jsr next_byte
do_ref:
  sta result2+1          ; lookup uses result2 so as not to mess up arg1 / arg2
  stx result2
  jsr lookup
  bcs _error
  ldy #3
  lda (result),y        ; push the result slot's value (might use the same y trick on push_result below...)
  pha
  dey
  lda (result),y
  pha
  jmp thread_loop
_error:
  jsr syntax_error      ; TODO retract emitted values in this line (save prgtop just like stackbottom)
  jmp thread_loop
push_result:
  lda arg1+1            ; result of expression level prims is in arg1
  pha
  lda arg1              ; inject this core prim after a subexpr to push result value
  pha
  jmp thread_loop
skipw:
  jsr next_byte         ; temporarily store target in x, y
  tax
  jsr next_byte
  tay
  lda ip+1              ; push current ip == start of block
  pha
  lda ip
  pha
  stx ip                ; and set ip to target
  sty ip+1              ; for now skip is absolute instead of an offset
  jmp thread_loop
eval:
_calc_fp:
  jsr next_byte         ; load num of 2-byte stack items to eval
  sta argc
  asl argc              ; arg count * 2 bytes
  tsx
  txa
  clc
  adc argc              ; a now holds 'frame pointer', i.e. start of args on stack (stack goes down, so A is higher)
_do_eval:
  tax ; x now holds 'frame pointer'
  tay ; y holds same value, but is walked as argument index
; Fetch first argument (the primitive to call)
  lda $0100,y
  sta primptr+1
  dey
  lda $0100,y
  sta primptr
  dey
  lsr argc              ; restore to num args
  dec argc
  beq +
; Fetch first real arg (if any) as a service to the primitives
  jsr stack_y_to_arg1
+
  jmp(primptr) ; jump to primitive
done:
  jsr next_byte         ; arg is number of defined vars in this scope
  asl a                 ; n defines * 4 bytes per var
  asl a
  sta tmp
  lda varptr
  clc
  adc tmp               ; Reset varstack to n defines before
  sta varptr
  bcc +
  inc varptr+1
+
  rts   ; to exit thread loop by returning to whoever called us


;
; Base primitives
;

return: ; in the Pasta sense of returning the argument value as expression outcome
  txs ; restore stack
  jmp thread_loop
setb: ; 'setb 0x1234 42'
  dey
  lda $0100,y ; setb only uses lsb of value
  dey
  ldy #0
  sta (arg1),y ; and perform set
  ; done, now prepare return value in arg1
  sta arg1     ; return the byte value in arg1
  sty arg1+1
  txs ; restore stack
  jmp thread_loop
print: ; print a unique_string or similarly formatted string
  tya
  pha ; stash arg idx
  jsr print_arg1
  pla ; restore arg idx
  tay
  dec argc              ; more args?
  bmi _done             ; print those as well
  jsr stack_y_to_arg1_no_check  ; don't let this function return for us
  jmp print
_done
  lda #13               ; so that we can write a newline (may remove this feature later)
  jsr WriteCharacter
  txs ; restore stack
  jmp thread_loop

if:
  lda arg1
  ora arg1+1
  bne _then
_else:
  dec argc            ; continue to 'else' block (if any)
  dey
  dey
_then:
  jsr stack_y_to_arg1 ; and fall through to 'eval'
eval_block:           ; eval block
  txs                 ; early restore stack as we already have our only arg1
  lda ip+1            ; save current ip
  pha
  lda ip
  pha
  lda arg1            ; set ip to block
  sta ip
  lda arg1+1
  sta ip+1
  jsr thread_loop     ; eval block in sub thread_loop
  pla                 ; restore own ip
  sta ip
  pla
  sta ip+1
  jmp thread_loop     ; continue as usual

; store word on stack,y into arg1
; and decrement y
stack_y_to_arg1:
  dec argc
  bmi done_via_x
stack_y_to_arg1_no_check:
  lda $0100,y
  sta arg1+1
  dey
  lda $0100,y
  sta arg1
  dey
  rts

; dumbly supply the same function for arg2
; as target is hard to parameterize (while keeping x intact)
stack_y_to_arg2:
  dec argc
  bmi done_via_x
stack_y_to_arg2_no_check:
  lda $0100,y
  sta arg2+1
  dey
  lda $0100,y
  sta arg2
  dey
  rts

done_via_x:
  txs
  jmp thread_loop

