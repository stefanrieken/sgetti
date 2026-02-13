; Currently made to compile for neo6502 with 64tass --nostart
; Run on emulator by writing neo6502-firmware/bin/neo a.out@800 cold

*=$800              ; neo6502 cold start address

; Neo6502 Kernel API convenience macros
; An alternative way to define these is:
;.include '../neo6502-firmware/examples/assembly/neo6502.asm.inc'

ReadLine=$FFEB
ReadCharacter=$FFEE
WriteCharacter = $FFF1
Parameters=$FF04
WaitMessage=$FFF4
SendMessage=$FFF7

KSendMessage=$FC18
KWaitMessage=$FC81

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

lineptr      = $02 ; The line being parsed; also used as 'list ip'
prgtop       = $04 ; The top of program memory
ip           = $06 ; The instruction pointer
primptr      = $08 ; Address of current expression level primitive, useful for looping
varptr       = $0A ; Points to 'top' of varstack

; 1 byte
argc         = $0C ; Parse: counts number of defines; eval: counts number of args
tmp          = $0D ; General purpose temp (used by divide, parse, unique_string)
buf          = $0E ; Only used on neo6502 to flag file i/o vs interactive
varc         = $0F ; Count number of defines during parse
;stackbottom  = $0F ; Holds 'bottom' of stack during parse

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

;
; Entry point
;
start:
  lda #0
  sta buf

  lda #<startmsg
  sta arg1
  lda #>startmsg
  sta arg1+1
  jsr print_arg1

  jmp init

startmsg:
  .text 89, 12, 13, "        **** NEO6502 PASTA MACHINE v 0.1 ****"
  .text 13, 13,  "        4k RAM interpreter so many bytes free", 13, 13, "READY.", 13, 0

;
; Read / Write functions
;

read_new_line:
  lda buf               ; If input is file, we don't read per line
;  bne _reset_y          ; but we do have y hovering between values 0 and 1
  beq +
  ldy #1
  rts
+
  ; Apparently we define where the input comes using x, y.
  ldx #<linebuf
  ldy #>linebuf
  jsr ReadLine
; Line is returned as a length prefixed string pointed to by parameters 0 and 1
; So copy that pointer to zero page so we can follow it
; This is just our own pointer, but using lineptr might give us a better chance
; to implement reading code as text from memory.
  lda Parameters+0
  sta lineptr
  lda Parameters+1
  sta lineptr+1
  ldy #$0
  lda (lineptr),y
  tay
  iny
  lda #13               ; Use CR for EOL to match c64's CHRIN input
  sta (lineptr),y
_reset_y:
  ldy #0                ; Restore char index
  rts

cr:
  ; group 2, function 13: returns x coord in Parameter 0
  jsr KSendMessage
  .byte 2,13
  lda $FF04             ; Parameter 0
  beq +
  lda #13
  jsr WriteCharacter
+
  rts

CHANNEL=1
open_file:
  sta Parameters+3      ; r/w (0/1) passed in a
  ldy #0
  lda (arg1),y          ; Adjust string length prefix to Neo style
  sec
  sbc #2
  sta (arg1),y
  lda #CHANNEL          ; set file channel
  sta Parameters+0
  lda arg1
  sta Parameters+1      ; set file name
  lda arg1+1
  sta Parameters+2
  jsr KSendMessage
  .byte 3,4             ; open file
  ldy #0
  lda (arg1),y          ; Fix mangled string length
  clc
  adc #2
  sta (arg1),y
  lda #1
  sta buf               ; mark file is open
  rts
close_file:
  lda #CHANNEL
  sta Parameters+0
  jsr KSendMessage
  .byte 3,5             ; close file
  lda #0
  sta buf               ; mark file is closed
  rts
stat_file:
  lda #CHANNEL
  sta Parameters+0
  jsr KSendMessage
  .byte 3,22            ; check eof
  lda Parameters+0      ; zero if not eof
  rts

read_char:
  lda buf               ; are we reading from file?
  beq _have_char
  tya
  beq _have_char        ; if y = 0, unread was called
  lda #CHANNEL
  sta Parameters+0
  lda #<linebuf         ; always read into start of buffer
  clc
  adc #1                ; read at offset buffer+1
  sta Parameters+1
  lda #>linebuf
  sta Parameters+2
  lda #1                ; Read 1 char
  sta Parameters+3
  lda #0
  sta Parameters+4
  jsr KSendMessage
  .byte 3,8
  ldy #0                ; reset y, so that char will be at y++=1
_have_char:
  iny
  lda linebuf,y
  cmp #10
  bne +
  lda Parameters+3      ; if nothing read, return zero. Oddly enough the parser can't handle repeated newlines as eof
  beq +
  lda #13               ; Force \r instead of \n (improve: use nl variable throughout code)
+
  rts

write_char = WriteCharacter

next_char .macro
  jsr read_char
.endmacro

unread .macro
  dey
.endmacro

flush .macro
.endmacro

; C64 run/stop check returns Z if pressed
; Don't know if neo6502 has a similar function,
; so for now return a clear Z; uses A.
check_brk .macro
  lda #1
.endmacro
