;
; Emit either a byte-sized or word-sized variant of the same command,
; assuming they come in that order, e.g. PUSHB before PUSHW.
; Call with byte variant.

; TODO test all

emit_optimized_cmd:

  ldx arg1+1      ; is msb zero?
  beq emit_byte   ; then emit the byte sized variant

emit_word_cmd:

  clc             ; clear carry to mark we're emitting 2 bytes
  adc #1          ; cmd+1 for word sized variant; should not change carry
  bcc do_emit_cmd ; always taken

emit_byte_cmd:
  sec             ; mark 1 byte

do_emit_cmd:
  sta prgtop,x

  ldx #1          ; count num bytes added

_add_arg:
  lda arg1
  sta prgtop,x
  inx

  bcs _update_prgtop ; carry set marks 1-byte variant, so skip msb

  lda arg1+1
  sta prgtop,x
  inx

_update_prgtop:
  txa
  clc
  adc prgtop
  bcc _done
  inc prgtop+1
_done:
  rts


; Emit a single byte (possibly an expression level primitive)
; value in A
emit_byte:
  sta prgtop
  inc prgtop
  bcc _done
  inc prgtop+1
_done:
  rts

