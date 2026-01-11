; UNIQUE_STRING
; Arguments
; - A,Y contain string pointer, then we set:
; - arg1 = string to add
; - arg2 = used to index over string mem
; - tmp  = 0x20 if it's a label (must be a known string) or '"' not (may add new string)
; Returns
; - arg1 pointing to unique string
; - result as the unique string index
; - carry set on error
;
; Affects Y
; Affects X (this can easily be changed to a tmp address)

unique_string:
    sta arg1            ; (if) arg1 is passed in A/Y, store its value in zero page so we can use it
    sty arg1+1
    lda #<fixed_strings ; copy 16-bit pointer to start of strings
    sta arg2+0          ; for use as counter
    lda #>fixed_strings ; copy 16-bit pointer to start of strings
    sta arg2+1
    ldx #0              ; use x to indicate whether we've switched from fixed to dynamic string 
    stx result
    stx result+1
_compare_string:
    ldy #0
    lda (arg2),y  ; load current string size
    beq _switch_to_stringmem  ; if string size is zero, we're at and of our search
    dey                 ; set y to #$FF to compare both size and value
_compare_chars:
    iny
    lda (arg2),y        ; compares both size indicator and content
    beq _success        ; zero terminator reached; since size is same, string is same!
    cmp (arg1),y
    beq _compare_chars  ; so far so same
_next_ustring:
    inc result
    bne +
    inc result+1
+
    ldy #0
    lda (arg2),y ; size of string in A
    clc
    adc arg2     ; add size of string to arg2 LSB
    sta arg2
    lda #0
    adc arg2+1   ; process carry
    sta arg2+1
    jmp _compare_string ; and continue the comparison process
_switch_to_stringmem:   ; switch from static to dynamic string memory
    txa                 ; keep track of switch in x
    bne _new_ustring    ; already switched
    lda #<stringmem
    sta arg2+0
    lda #>stringmem
    sta arg2+1
    inx                 ; keep track of switch in x
    bne _compare_string
_new_ustring:
    lda tmp
    cmp #'"'
    bne _done           ; if label, it must exist!
    ; transfer from arg1 to arg2; zero terminated
    ldy #$FF
_loop:
    iny
    lda (arg1),y
    sta (arg2),y
    bne _loop           ; if lda value was 0, then done copying string+terminator
    iny
    lda #$0
    sta (arg2),y        ; zero terminate string chain
_success:
    clc                 ; mark success
_done:
    lda arg2            ; return pointer value where it is expected
    sta arg1
    lda arg2+1
    sta arg1+1
    rts                 ; return to user

