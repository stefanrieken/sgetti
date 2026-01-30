;
; C64 specific values and functions
;

; Adapted from neo.asm for c64

ReadCharacter=$FFCF
;ReadCharacter=$0073 ; somehow the zp version won't work for us here
WriteCharacter = $FFD2

; Ever since the early PETs, BASIC starts at page+1
; simply due to RUN / GOTO probably pre-incrementing.
; This also causes the odd "38911 BASIC bytes free".

*=$0801

; BASIC header with sys command
.word (+), 2026
.null $9e, format("%4d", start)
+
.word 0          ;basic line end

; 64tass supports encoding "none" and "screen" out of the box.
; Neither of these caters for mapping modern ASCII to PETSCII.
; So we do it here. This only affects compile time characters.

mapscii .encode
.cdef " @", $20 ; Alphanumeric block: unchanged
.cdef "AZ", $C1 ; Switch A-Z -> az
.cdef "az", $41 ; Switch a-z -> A-Z
.cdef "[`", $5B ; Keep [\] and ^_ (last become arrows up and left; on c64 backslash is pound)
; Unfortunately we can't cdef redundant mappings, so tdef these:
.tdef '{', $5B  ; onto '['
.tdef '|', $5C  ; onto backslash or pound (PET / C64)
.tdef '}', $5D  ; onto ']'
.tdef '~', $5D  ; onto arrow up; TODO interferes with '^'

start:

; Set screen to lowercase to get a semblance of readability on c64.
; On Kernalemu you have to SCREAM anyway.
lda #23
sta 53272
lda #0
sta sep

jmp init

;
; Memory allocation on the C64
;

linebuf   = $0200  ; Say where ReadLine puts its results (max 255 bytes / screen width)
stringbuf = $0300  ; Max 256 bytes (including size byte)
stringmem = $3000  ; Where unique strings are placed
progmem   = $4000  ; Compiled program memory
vars_end  = $8000  ; Both top and start of var stack (grows down)

;
; Utility zero page registers
;

lineptr      = $22 ; The line being parsed (unused as such in c64); also used as 'list ip'
prgtop       = $24 ; The top of program memory
ip           = $26 ; The instruction pointer
primptr      = $28 ; Address of current expression level primitive, useful for looping
varptr       = $2A ; Points to 'top' of varstack

; 1 byte
argc         = $2C ; Parse: counts number of defines; eval: counts number of args
tmp          = $2D ; General purpose temp (used by divide, parse, unique_string)
sep          = $2E ; Separator character (used in list); also used in c64 as temp char
varc         = $2F ; Count number of defines during parse
;stackbottom  = $2F ; Holds 'bottom' of stack during parse

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

; No such thing as a breakpoint on c64
neo6502_breakpoint .macro
.endmacro

;
; Read / Write functions
;

read_new_line:
   lda #0
   sta sep
  rts

read_char:
  lda sep
  beq +
  ldy #0
  sty sep
  rts
+
  jsr ReadCharacter
  cmp #13
  bne +
  jsr WriteCharacter
+
  rts

next_char .macro
  jsr read_char
.endmacro

unread .macro
  sta sep
.endmacro

flush .macro
-
  jsr read_char
  cmp #13
  bne -
.endmacro

check_brk .macro
  jsr $FFE1
.endmacro

get_column .macro
  lda $D3
.endmacro
