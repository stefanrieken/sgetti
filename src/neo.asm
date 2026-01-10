;
; Memory allocation on the neo6502
;

;
; Utility zero page registers
;

; Byte size registers
lineptr      = $02 ; The line being parsed
prgtop       = $04 ; The top of program memory
ip           = $06 ; The instruction pointer
argc         = $08 ; General purpose temp (all kinds of uses in parse; consistently used as arg counter in eval)
tmp          = $09 ; General purpose temp (used by divide, parse, unique_string)

; Word size registers
result2      = $0A 
arg1         = $0C ; First argument (let's count these from 1)
arg2         = $0E ; Second argument
result       = $10 ; Result -- often gets copied back to arg1
primptr      = $12 ; Address of current expression level primitive, useful for looping

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

