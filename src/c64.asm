;
; C64 specific values and functions
;

; Adapted from neo.asm for c64

ReadCharacter=$FFCF     ; CHRIN aka BASIN
;ReadCharacter=$FFE4     ; GETIN operates on keyboard buffer
;ReadCharacter=$0073     ; CHRGET (zp copy of CHARGET); can't get this to work
;ReadCharacter=$E3A2     ; CHARGET
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
buf          = $2E ; Parse buffer (temp char)
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
; Entry point
;

start:

; Set screen to lowercase to get a semblance of readability on c64.
;lda #23
;sta 53272

lda #0
sta buf

lda #<startmsg
sta arg1
lda #>startmsg
sta arg1+1
jsr print_arg1

jmp init

startmsg:
.text 89, 147, 13, "    **** c64 pasta machine  v2 ****"
.text 13, 13,  " 4k ram interpreter  so many bytes free", 13, 13, "ready.", 13, 0

;
; Read / Write functions
;

read_new_line:
  lda buf
  cmp #0
  bne +
  lda #0
  sta buf
+
  rts

read_char:
  lda buf
  beq +
  ldy #0
  sty buf
  rts
+
  jsr ReadCharacter
  cmp #13               ; Echoing newline may only be required for tmce64
  bne +
cr:
  ldy $D3               ; Not on column 0?
  beq +
  lda #13
  jsr WriteCharacter    ; Then we echo newline
+
  rts

FILENO=1                ; TODO no idea what file n
open_file:              ; Name in arg1, r/w (0/1) in A
  sta tmp
  txa
  pha
  tya
  pha
  lda #FILENO           ; Logical file number
  ldx #8                ; Disk device
  ldy tmp               ; Command: seems 1541 wants wants '0'/'1' for read/write here (and so does kernalemu)
  jsr $FFBA             ; SETLFS
  ldy #0
  lda (arg1),y          ; Save string length
  sec
  sbc #2                ; Actual string length, not total admin. length
  pha                   ; Set aside
  lda arg1              ; Set file name as string pointer
  clc
  adc #1                ; Skip size
  tax
  lda arg1+1
  adc #0                ; Overflow into msb
  tay
  pla                   ; Restore string length
  jsr $FFBD             ; SETNAM
  jsr $FFC0             ; OPEN
  bcs _done             ; Well... not if File not found on 1541
  ldx #FILENO           ; File num now in X
  lda tmp               ; Read or Write (0/1)?
  beq +
  jsr $FFC9             ; CHKOUT
  jmp _done
+
  jsr $FFC6             ; CHKIN
  jsr stat_file
  cmp #0                ; error?
  bne +
  clc                   ; if no error, set carry=0 as result
  beq _done
+
  lda #0                ; if error, discard char
  sta buf
  lda #'Q'
  jsr WriteCharacter
  sec
_done
  pla
  tay
  pla
  tax
  rts

close_file:
  txa
  pha
  tya
  pha
  lda #FILENO
  jsr $FFC3             ; CLOSE
  jsr $FFCC             ; CLRCHN - TODO better ways to restore to standard input / output channels?
  pla
  tay
  pla
  tax
  rts

;stat_file=$FFB7         ; READST

stat_file:
  jsr ReadCharacter     ; Have to read to detect timeout=file not found on 1541
  cmp #$FF              ; Or to detect EOF, for which tmce64 tends to return this (from overflow read in d64 file?)
  beq +                 ; We don't need to keep that
  sta buf
+
  jsr $FFB7             ; READST
  rts

next_char .macro
  jsr read_char
.endmacro

unread .macro
  sta buf
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

