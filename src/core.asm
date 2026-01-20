;
; Core engine instructions
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
  jsr rt_error      ; TODO retract emitted values in this line (save prgtop just like stackbottom)
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


