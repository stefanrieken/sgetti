stringmem = $3000   ; any place in RAM for now
;wordptr0 = $FB      ; c64: fully unused zero page address
;wordptr1 = $FD      ; c64: fully unused zero page address

; UNIQUE_STRING
; - A,Y contain string pointer, then we set:
; - wordptr0 = string to add
; - wordptr1 = used to index over string mem
; - returns wordptr0 to unique string
; - returns nth string in x

unique_string:
    ldx #$0 ; using x as counter
    sta wordptr0      ; (if) wordptr0 is passed in A/Y, store its value in zero page so we can use it
    sty wordptr0+1
    ;lda #<stringmem   ; copy 16-bit pointer to start of strings
    lda #<fixed_strings   ; copy 16-bit pointer to start of strings
    sta wordptr1+0    ; for use as counter
    ;lda #>stringmem
    lda #>fixed_strings   ; copy 16-bit pointer to start of strings
    sta wordptr1+1
_compare_string:
    ldy #0
    lda (wordptr1),y  ; load current string size
    beq _switch_to_stringmem  ; if string size is zero, we're at and of our search
    dey               ; set y to #$FF to compare both size and value
_compare_chars:
    iny
    lda (wordptr1),y   ; compares both size indicator and content
    beq _done          ; zero terminator reached; since size is same, string is same!
    cmp (wordptr0),y
    beq _compare_chars ; so far so same
_next_ustring:
    inx ; using x as counter
    ldy #0
    lda (wordptr1),y ; size of string in A
    clc
    adc wordptr1     ; add size of string to wordptr1 LSB
    sta wordptr1
    lda #0
    adc wordptr1+1   ; process carry
    sta wordptr1+1
    jmp _compare_string ; and continue the comparison process
_switch_to_stringmem:
    txa
    cmp #NUM_FIXED_STRINGS ; were we at end of fixed or dynamic string mem?
    bne _new_ustring ; if we are not at the exact border, we must be in the latter, so we can append new string

    lda #<stringmem  ; problem is, x doesn't tell us whether we're at end of one or fresh start of other
    cmp wordptr1+0   ; so instead, check if we just switched
    bne _switch      ; and otherwise do it now
    lda #>stringmem
    cmp wordptr1+1
    beq _new_ustring ; yes, we just switched; make new string
_switch:
    sta wordptr1+0
    lda #>stringmem
    sta wordptr1+1
    jmp _compare_string
_hmmmm:              ; we had already switched
_new_ustring:
    ; transfer from wordptr0 to wordptr1; zero terminated
    ldy #$FF
_loop:
    iny
    lda (wordptr0),y
;jsr WriteCharacter
    sta (wordptr1),y
    bne _loop        ; if lda value was 0, then done copying string+terminator
    iny
    lda #$0
    sta (wordptr1),y ; zero terminate string chain
_done:
    lda wordptr1     ; return pointer value where it is expected
    sta wordptr0
    lda wordptr1+1
    sta wordptr0+1
    rts              ; return to user

