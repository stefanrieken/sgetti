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
primptr      = $08 ; Address of current expression level primitive, useful for looping
varptr       = $0A ; Points to 'top' of varstack

; 1 byte
argc         = $0C ; Parse: counts number of defines; eval: counts number of args
tmp          = $0D ; General purpose temp (used by divide, parse, unique_string)
strlen       = $0E ; TODO on neo6502 this is just linebuf[0]
stackbottom  = $0F ; Holds 'bottom' of stack during parse

; Argument / result registers
arg1         = $10 ; First argument (let's count these from 1)
arg2         = $12 ; Second argument
result       = $14 ; Result -- often gets copied back to arg1
result2      = $16 ; Mainly used for remainder 

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

