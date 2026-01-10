; UNIQUE_STRING
; - A,Y contain string pointer, then we set:
; - arg1 = string to add
; - arg2 = used to index over string mem
; - returns arg1 pointing to unique string
; - returns nth string in x

unique_string:
    ldx #$0 ; using x as counter
    stx tmp ; use tmp to indicate whether we've switched from fixed to dynamic string mem
    sta arg1      ; (if) arg1 is passed in A/Y, store its value in zero page so we can use it
    sty arg1+1
    ;lda #<stringmem   ; copy 16-bit pointer to start of strings
    lda #<fixed_strings   ; copy 16-bit pointer to start of strings
    sta arg2+0    ; for use as counter
    ;lda #>stringmem
    lda #>fixed_strings   ; copy 16-bit pointer to start of strings
    sta arg2+1
_compare_string:
    ldy #0
    lda (arg2),y  ; load current string size
    beq _switch_to_stringmem  ; if string size is zero, we're at and of our search
    dey               ; set y to #$FF to compare both size and value
_compare_chars:
    iny
    lda (arg2),y   ; compares both size indicator and content
    beq _done          ; zero terminator reached; since size is same, string is same!
    cmp (arg1),y
    beq _compare_chars ; so far so same
_next_ustring:
    inx ; using x as counter
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
    lda tmp             ; keep track of switch in tmp
    bne _new_ustring    ; already switched
    lda #<stringmem
    sta arg2+0
    lda #>stringmem
    sta arg2+1
    inc tmp             ; keep track of switch in tmp
    bne _compare_string
_new_ustring:
    ; transfer from arg1 to arg2; zero terminated
;    inx ; using x as counter
    ldy #$FF
_loop:
    iny
    lda (arg1),y
;jsr WriteCharacter
    sta (arg2),y
    bne _loop        ; if lda value was 0, then done copying string+terminator
    iny
    lda #$0
    sta (arg2),y ; zero terminate string chain
;    iny
;    sta (arg2),y ; zero terminate string chain
_done:
    lda arg2     ; return pointer value where it is expected
    sta arg1
    lda arg2+1
    sta arg1+1
    rts              ; return to user

