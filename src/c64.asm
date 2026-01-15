
; Adapted from neo.asm for c64

ReadLine=$FFEB
ReadCharacter=$FFCF
;WriteCharacter = $FFD2
Parameters=$FF04
WaitMessage=$FFF4
SendMessage=$FFF7

*=$0801

.enc "none"


.word (+), 2026
.null $9e, format("%4d", sysaddr)
+
.word 0          ;basic line end

sysaddr:

; We still have to convert between ascii, petscii and screen codes,
; probably by putting a function between the call to CHROUT. For now,
; set screen to lowercase to get a semblance of readability on c64;
; kernalemu doesn't mind.
lda #23
sta 53272

jmp +
WriteCharacter:
  ; 64tass almost supports PETSCII, but I believe not quite if the host does ASCII
  ; the major pest is upper and lowercase are switched, so fix that
  cmp #$41
  bcc _write
  cmp #$7B
  bcs _write
  ; invert upper and lower case
  eor #$20
_write:
  jmp $FFD2
+

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
sep          = $0E ; Separator character (used in list)
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

; Registers for 16-bit utility functions
src          = $18
dst          = $1A
tmp2         = $1C
 
neo6502_breakpoint .macro
.byte 3
.endmacro

