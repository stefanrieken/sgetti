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
getb:
  ldy #0
  lda (arg1),y
  sta arg1
  sty arg1+1
  txs ; restore stack
  jmp thread_loop
dollar:                 ; convert a number to string; always in a _fleeting_ buffer
  dec argc              ; more args?
  bmi +
  lda $00FF,y
  bne _have_base
+
  lda #10
_have_base:
  sta divisor
  lda #0
  sta divisor+1
  txs
;  txa
;  pha
  jsr convert_num
  lda #<stringbuf
  sta arg1
  lda #>stringbuf
  sta arg1+1
;  pla
;  tax
;  txs
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
;  lda #13               ; so that we can write a newline (may remove this feature later)
;  jsr write_char
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
  jsr stack_y_to_arg1
  lda #0              ; and fall through to 'eval_block'

; Call with
; A = 0: is a block (0 extra items to clean)
; A = 4: is a function (clean parent pointer when done)
eval_block:           ; eval block
  txs                 ; early restore stack as we already have our only arg1
  pha                 ; then push A=block/function marker
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
  pla                 ; A=4: was run as function; clear parent pointer
  beq _done           ; A=0: nothing to clear
  clc                 ; varptr += 4
  adc varptr
  sta varptr
  bcc _done
  inc varptr+1
_done:
  jmp thread_loop     ; continue as usual


loop:
  ; Have arg1 which is (should be!) the block
  txs                    ; Restore stack to rebuild it in different order
  lda ip+1               ; save current ip first
  pha
  lda ip
  pha
  lda arg1+1            ; then save block
  pha
  lda arg1
  pha
_eval:
  #check_brk
  beq _done
  tsx                   ; re-load block from stack
  lda $0101,x           ; while retaining it on stack
  sta ip
  lda $0102,x
  sta ip+1              ; save block to find it back after 'eval'
  jsr thread_loop       ; run the block
  lda arg1              ; is return value 0 == false?
  bne _eval
  cmp arg1+1            ; also 0 in msb?
  bne _eval
_done:
  pla                   ; then block can come off the stack
  pla
  pla                   ; set ip back to own ip
  sta ip
  pla
  sta ip+1
  jmp thread_loop

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

