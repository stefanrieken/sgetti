;
; Emit either a byte-sized or word-sized variant of the same command,
; assuming they come in that order, e.g. PUSHB before PUSHW.
; Call with byte variant.
;
; cmd arg is in x; caller's y actively is preserved

emit_optimized_cmd:
  lda arg1+1        ; is msb zero?
  beq emit_byte_cmd ; then emit the byte sized variant

emit_word_cmd:

  clc               ; clear carry to mark we're emitting 2 bytes
  inx               ; cmd+1 for word sized variant; should not change carry
  bcc do_emit_cmd   ; always taken

emit_byte_cmd:
  sec               ; mark 1 byte

do_emit_cmd:
  tya               ; save caller's y
  pha
  txa               ; load command
  ldy #0            ; count program bytes in y
  sta (prgtop),y
  iny

_add_arg:
  lda arg1
  sta (prgtop),y
  iny

  bcs _update_prgtop ; carry set marks 1-byte variant, so skip msb

  lda arg1+1
  sta (prgtop),y
  iny

_update_prgtop:
  tya
  clc
  adc prgtop
  sta prgtop
  bcc _done
  inc prgtop+1
_done:
  pla               ; restore caller's y
  tay
  rts


; Emit a single byte (possibly an expression level primitive)
; value in x
emit_byte:
  tya               ; save caller's y
  pha
  ldy #0
  txa
  sta (prgtop),y
  inc prgtop
  bne _done
  inc prgtop+1
_done:
  pla               ; restore caller's y
  tay
  rts

