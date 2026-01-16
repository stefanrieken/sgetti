
; Adapted from neo.asm for c64

ReadCharacter=$FFCF
;ReadCharacter=$0073 ; somehow the zp version won't work for us here
WriteCharacter = $FFD2

; 64tass supports encoding "none" and "screen" out of the box.
; Neither of these caters for mapping modern ASCII to PETSCII.
; So we do it here. This only affects compile time characters.


; According to the Internet, BASIC starts at $0800+1
; simply due to RUN / GOTO probably pre-incrementing.
; This also causes the odd "38911 BASIC bytes free".
*=$0801

; BASIC header with sys command
.word (+), 2026
.null $9e, format("%4d", start)
+
.word 0          ;basic line end

mapscii .encode
.cdef " @", $20 ; Alphanumeric block: unchanged
.cdef "AZ", $C1 ; Uppercase characters to position of lowercase
.cdef "az", $41 ; Lowercase characters to position of uppercase
.cdef "{}", $5B ; not available in PETSCII; fall back to '[]' and pound sign for '|'
.tdef '[', $5B ; retain '[' as-is in spite of also being '{'
.tdef '^', $6E ; not available in PETSCII; fall back to arrow up
.tdef ']', $5D ; retain ']' as-is in spite of also being '}'
.tdef '~', $6F ; not available in PETSCII; fall back to arrow left

start:

; We still have to convert between ascii, petscii and screen codes,
; probably by putting a function between the call to CHROUT. For now,
; set screen to lowercase to get a semblance of readability on c64;
; kernalemu doesn't mind.
lda #23
sta 53272
lda #0
sta sep

jmp init

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

;lineptr      = $22 ; The line being parsed
prgtop       = $24 ; The top of program memory
ip           = $26 ; The instruction pointer
primptr      = $28 ; Address of current expression level primitive, useful for looping
varptr       = $2A ; Points to 'top' of varstack

; 1 byte
argc         = $2C ; Parse: counts number of defines; eval: counts number of args
tmp          = $2D ; General purpose temp (used by divide, parse, unique_string)
sep          = $2E ; Separator character (used in list)
stackbottom  = $2F ; Holds 'bottom' of stack during parse

; Argument / result registers
arg1         = $30 ; First argument (let's count these from 1)
arg2         = $32 ; Second argument
result       = $34 ; Result -- often gets copied back to arg1
result2      = $36 ; Mainly used for remainder

; The same registers when used in division
remainder    = result2; divident is gradually left shifted into remainder & subtracted with corresponding divisor bit
dividend     = arg1
divisor      = arg2
;result      = result

; And when used in multiplication
multiplicand = arg1
multiplier   = arg2
;result      = result

; No such thing as a breakpoint
neo6502_breakpoint .macro
.endmacro

;
; Read / Write functions
;

read_new_line:
  rts

read_char:
  lda sep
  beq +
  ldy #0
  sty sep
  rts
+
  jmp ReadCharacter

next_char .macro
  jsr read_char
.endmacro

unread .macro
  sta sep
.endmacro
