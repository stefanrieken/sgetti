; Currently made to compile for neo6502 with 64tass --nostart
; Run on emulator by writing neo6502-firmware/bin/neo a.out@800 cold

*=$800              ; neo6502 cold start address
jmp init

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
sep          = $0E ; Separator character (used in list)
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
; Read / Write functions
;

read_new_line:
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
  ldy #0                ; Restore char index
  rts

next_char .macro
  iny
  lda (lineptr),y
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

get_column .macro
  ; group 2, function 13: returns x coord in Parameter 0
  lda #13
  sta $FF01             ; Set Function
  lda #2
  sta $FF00             ; Set Group to trigger the call
-
  lda $FF00             ; Func is done if group is cleared
  bne -
  lda $FF04             ; Parameter 0
.endmacro
