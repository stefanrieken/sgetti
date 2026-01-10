;
; Utility functions on the neo6502

ReadLine=$FFEB
WriteCharacter = $fff1
Parameters=$FF04

;
; Memory allocation on the neo6502
;

linebuf   = $0200  ; Say where ReadLine puts its results (max 255 bytes / screen width)
stringbuf = $0300  ; Max 256 bytes (including size byte)
stringmem = $3000  ; Where unique strings are placed
progmem   = $4000  ; Compiled program memory
vars_end  = $8000  ; Both top and start of var stack (grows down)

;
; Utility zero page registers
;

lineptr      = $02 ; The line being parsed
prgtop       = $04 ; The top of program memory
ip           = $06 ; The instruction pointer
argc         = $08 ; General purpose temp (all kinds of uses in parse; consistently used as arg counter in eval)
tmp          = $09 ; General purpose temp (used by divide, parse, unique_string)
strlen       = $20 ; TODO on neo6502 this is just linebuf[0]
stackbottom  = $21 ; Holds 'bottom' of stack during parse
primptr      = $12 ; Address of current expression level primitive, useful for looping
varptr       = $22 ; Points to 'top' of varstack

; Argument / result registers
result2      = $0A 
arg1         = $0C ; First argument (let's count these from 1)
arg2         = $0E ; Second argument
result       = $10 ; Result -- often gets copied back to arg1

; The same registers when used in division
remainder    = result2; divident is gradually left shifted into remainder & subtracted with corresponding divisor bit
dividend     = arg1
divisor      = arg2
;result      = result

; And when used in multiplication
multiplicand = arg1
multiplier   = arg2
;result      = result


neo6502_breakpoint .macro
.byte 3
.endmacro

