;TK-48 TTY Monitor Program Rel.2

; Terminal Delay (char / Line)
;    HM6116  SRAM   4ms /  20ms
;    X2816B  EEPROM 4ms / 100ms 

	cpu	8048
	page	0

; hardware define
;	TX	P26
;	RX	T0

TX_BIT	EQU	1<<6	;Port.6(TX Port)
TXOUT	MACRO	N
	if N==1
		orl	P2,#(TX_BIT)		;set P26
	endif
	if N==0
		anl	P2,#(~TX_BIT)		;reset P26
	endif
	ENDM
	

LINSIZ	EQU	46	;Input string Line Size
BS	EQU	8	;keycode BS
LF	EQU	10	;CRT LF
CR	EQU	13	;keycode CR
Xon	EQU	17	;tty Flow Control CONTINUE
Xoff	EQU	19	;tty Flow Control STOP

;Internal RAM Area
	org	20h
;gets string working area special RAM Top(only stack 5 levels)
	org	12h
LBUF	ds	LINSIZ

;-----------------------------------------------------------------------
	org	0
init:
	
	; tty stop bit
	TXOUT	1

WARM:
	clr	F0
	cpl	F0		;Local ECHO on
	mov	R0,#(MSG1 # 256)
	call	puts
; RAM size check
RAMCHK:
	mov	R0,#(RAMMSG # 256)
	call	puts
	mov	R1,#3fh		;set ($3F)=1,RAM 64B
	mov	@R1,#1
	mov	R1,#7fh		;set ($7F)=2,RAM 128B
	mov	@R1,#2
	mov	R1,#0ffh	;set ($FF)=3,RAM 256B
	mov	@R1,#3
	mov	R1,#3fh
	mov	a,@R1
	add	a,#(0-3)	;if ($3F)==3, image
	jz	$$n64
	mov	R1,#7fh
	mov	a,@R1
	add	a,#(0-3)	;if ($7F)==3, image
	jz	$$n128
	mov	R0,#(RAM256 # 256)
	call	puts
	jmp	$$end
$$n64	mov	R0,#(RAM64 # 256)
	call	puts
	jmp	$$end
$$n128	mov	R0,#(RAM128 # 256)
	call	puts
$$end	mov	R0,#(CRLF # 256)
	call	puts


PRMPT:	mov	R0,#(PROMPT # 256)
	call	puts
NPRMPT:	call	gets
	mov	a,@R0
	jz	PRMPT
	mov	a,@R0		;':' Jump Intel Hex Loader
	add	a,#(0-':')
	jnz	$$n1
	jmp	hexloadcmd
$$n1
	mov	a,@R0
	add	a,#(0-'i')	;'i' init reset command
	jnz	$$n2
	jmp	init
$$n2
	mov	a,@R0
	add	a,#(0-'r')	;'r' internal ram dump
	jnz	$$n3
	call	ramdumpcmd
	jmp	$$endz
$$n3
	mov	a,@R0
	add	a,#(0-'d')	;'d' external memory dump
	jnz	$$n4
	call	dumpcmd
	jmp	$$endz		;check address = 100H
$$n4
	mov	a,@R0
	add	a,#(0-'f')	;'f' internal ram filled
	jnz	$$n5
	mov	R1,#2		;RAM fulled top address
$$n4a	clr	a
	mov	@R1,a
	inc	R1
	mov	a,#(0-40h)
	add	a,R1
	jnc	$$n4a
	jmp	$$endz
$$n5
	mov	a,@R0
	add	a,#(0-'l')	;'l' local ECHO toggle on/off
	jnz	$$n6
	mov	R0,#(LECHO # 256)
	call	puts
	jf0	$$n5a
	mov	R0,#(MSGON # 256)
	jmp	$$n5b
$$n5a	mov	R0,#(MSGOFF # 256)
$$n5b	call	puts
	cpl	F0
	jmp	$$end
$$n6
	mov	a,@R0
	add	a,#(0-'c')	;'c' check EE-PROM
	jnz	$$n8
	call	eecheckcmd
	jmp	$$end
$$n8
	mov	a,@R0
	add	a,#(0-'1')	;'1' Port-1 OUT/IN-command
	jnz	$$n9
	inc	R0
	call	str2hex
	jf1	$$n8a	;illegal characters
	outl	P1,a
	jmp	$$n8b
$$n8a	in	a,P1	;print P2
	call	hexout
$$n8b	jmp	$$end
$$n9
	mov	a,@R0
	add	a,#(0-'2')	;'2' Port-2 OUT/IN-Command
	jnz	$$none
	inc	R0
	call	str2hex
	jf1	$$n9a	;illegal characters
	outl	P2,a
	jmp	$$n9b
$$n9a	in	a,P2	;print P2
	call	hexout
$$n9b	jmp	$$end

$$none
	mov	a,#'?'
	call	putc
$$end	mov	R0,#(CRLF # 256)
	call	puts
$$endz	jmp	PRMPT

dumpcmd:
	mov	R0,#0	;high addr counter
	mov	R1,#0	;low addr counter
$$top	mov	a,R0
	call	hexout	;display addr.high
	mov	a,R1
	call	hexout	;display addr.low
	mov	a,#':'
	call	putc
$$line	mov	a,R0
	orl	a,#TX_BIT	;TX Port not change
	outl	P2,a	;set high addr
	movx	a,@R1	;get ramdata low addr
	call	hexout	;display ram data
	mov	a,#' '
	call	putc
	inc	R1	;inc low addr
	mov	a,R1
	anl	a,#0fh	;check align 16 bytes
	jnz	$$line
	mov	a,#'\r'	;CRLF
	call	putc
	mov	a,#'\n'
	call	putc
	mov	a,R1
	jnz	$$top	;check align 256 bytes
	inc	r0	;inc high addr
	mov	a,r0
	anl	a,#08	;check address 08xx
	jz	$$top
	ret

	align	256
;-----------------------------------------------------------------------
ramdumpcmd:
	mov	R1,#0
$$n2a	clr	a		;display 00 + address
	call	hexout
	mov	a,R1
	call	hexout
	mov	a,#':'
	call	putc
$$n2d	mov	a,@R1
	call	hexout		;display ram data
	mov	a,#' '
	call	putc
	inc	R1
	mov	a,R1
	anl	a,#0fh		;check Align 16
	jnz	$$n2d
	mov	a,#CR
	call	putc
	mov	a,#LF
	call	putc
	mov	a,R1
	jnz	$$n2a		;check address = 100H
	ret

hexloadcmd:
	inc	R0
	call	getbyte
	jc	$$err
	jz	$$err
	mov	R2,a	;save nBytes
	call	getbyte
	orl	a,#(TX_BIT)	;keep stop bit
	outl	P2,a	;save High Addr.
	call	getbyte
	mov	R1,a	;save Low Addr.
	call	getbyte
	jnz	$$err	;check Record Type.
$$loop	call	getbyte
	movx	@R1,a
	mov	R7,a	;tempolary save 
$$ee	movx	a,@R1
	xrl	a,R7
	jnz	$$ee	;wait EEPROM write timming.
	inc	R1
	djnz	R2,$$loop
	mov	a,#'+'
	call	putc
	jmp	NPRMPT
$$err	jmp	PRMPT

; @input	R0:Stringz Top ROM address(only same bank aka.256)
; @broken	Acc,R0,R5,R6,R7
puts:	mov	a,R0	;10steps(untile loop)
	movp	a,@a
	jz	$$end
	call	putc
	inc	R0
	jmp	puts
$$end	ret

MSG1:	db	"\e[32m"	;Green
	db	"TK-48 TTY MONITOR ",DATE
	db	"\e[0m"		;Default Color
CRLF:	db	"\r\n"
	db	0
RAMMSG:	db	"Baud Rate:9600. Internal RAM Size:",0
RAM64:	db	"64 Byte",0
RAM128:	db	"128 Byte",0
RAM256:	db	"256 Byte",0
PROMPT:	db	"mon>",0
WMSG1:	db	"Inc. 7F0 - 7FF...",0
WMSG2:	db	"Done",0
LECHO:	db	"Local ECHO ",0
MSGON:	db	"On",0
MSGOFF:	db	"Off",0

; Write Exteral RAM 7F0 - 7FF
eewrite:
	mov	R0,#(WMSG1 # 256)
	call	puts
	mov	a,#((07f0h >> 8) | TX_BIT)
	outl	P2,a
	mov	R1,#(07f0h & 0ffh)
$$n2d	movx	a,@R1
	inc	a
	mov	R2,a	;backup write byte data
	movx	@R1,a	;write eeprom
$$chk	movx	a,@R1	;poling
	xrl	a,R2
	jnz	$$chk
	inc	R1
	mov	a,R1
	anl	a,#0fh	;check align 16
	jnz	$$n2d
	mov	R0,#(WMSG2 # 256)
	call	puts
	ret

; get stringsZ (include local echo) (Control BS,CR)
; @broken	Acc,R0,R4,R5,R6,R7
; @return	store stringsz to LBUF, Acc=first char, R0=LBUF
gets:
;	mov	a,#Xon
;	call	putc
	mov	R0,#LBUF
$$loop	call	getc		;keycode=Acc and R4
	add	a,#(0-CR)	;check CR
	jz	$$end
	mov	a,R4
	add	a,#(0-BS)	;check BS
	jnz	$$n1
	mov	a,R0
	add	a,#(0-LBUF)	;top ?
	jz	$$loop
	dec	R0
	mov	a,#BS
	call	putc
	mov	a,#' '
	call	putc
	mov	a,#BS
	call	putc
	jmp	$$loop
$$n1
	mov	a,R4
	add	a,#(0-' ')	;check >= ' '
	jc	$$nz
	jmp	$$loop
$$nz
	mov	a,R0		; check LBUF over flow
	add	a,#0-(LBUF+LINSIZ-1)
	jnc	$$zz
	mov	a,R4
	call	putc
	mov	a,#BS
	call	putc
	mov	a,#' '
	call	putc
	mov	a,#BS
	call	putc
	jmp	$$loop
$$zz
	mov	a,R4		;save key to LBUF
	mov	@R0,a
	inc	R0
	jf0	$$zz1
	jmp	$$loop
$$zz1
	call	putc		;local echo
	jmp	$$loop
$$end
	clr	a		;zero terminate.
	mov	@R0,a
;	mov	a,#Xoff
;	call	putc
	mov	R0,#(CRLF # 256)
	call	puts
$$fin	mov	R0,#LBUF
	mov	a,@R0
	ret

; 9600baud=104.2us=41.67step(@6MHz) 20.83steps(.5) 62.5steps(1.5)
; serial in
; @broken	Acc,R4,R6,R7
; @return	Acc=R4
getc:
	mov	R4,#0	;init Receive buffer
	mov	R6,#8	;bit counter
;$$stop	jnt0	$$stop	;wait stop bit
$$wait	jt0	$$wait	;wait start bit
	mov	R7,#30	;1.5bit - 2step
	djnz	R7,$
$$loop	jt0	$$bit1	;14steps + 2xN
	mov	a,#0
	jmp	$$cont
$$bit1	mov	a,#1
	nop
	nop
$$cont	orl	a,R4
	rr	a
	mov	R4,a
	nop		;dummy 1 step
	mov	R7,#14	;N
	djnz	R7,$	;1bit - 13step
	djnz	R6,$$loop
	mov	a,R4
	ret

; 9600baud=104.2us=41.67step(@6MHz)
; serial out
; @input	Acc
; @broken	Acc,R5,R6,R7
putc:
	mov	R5,a
	mov	R6,#8	;init bit counter
	TXOUT	0	;start bit
	mov	R7,#19	;delay 1bit-2step
	djnz	R7,$
$$loop	mov	a,R5	;17steps(until loop)
	jb0	$$bit1
	TXOUT	0
	jmp	$$cont
$$bit1	TXOUT	1
	nop
	nop
$$cont	mov	R7,#13	;1bit - 15step
	djnz	R7,$
	nop
	mov	a,R5
	rr	a
	mov	R5,a
	djnz	R6,$$loop
	TXOUT	1	;stop bit
	mov	R7,#18	;1bit-9step
	djnz	R7,$
	ret

; tohex charactor to hex
; @input	R0(string top pointer, delimiter is zero)
; @broken	R7
; @return	Acc=hexcode, err(CY=1),ok(CY=0)
tohex:
	mov	a,@R0
	add	a,#(0-'0')
	jnc	$$endc		;ignore < '0'
	mov	R7,a	;tempolary save 
	add	a,#(-10)
	jc	$$n1		;next if n>9. over code '9'
	; '0' - '9'
	mov	a,R7
	ret
$$n1	mov	a,@R0
	add	a,#0-('A')
	jnc	$$endc		;ignore < 'A'
	add	a,#10	;'A'->0x0a
	mov	R7,a	;tempolary save 
	add	a,#-16
	jc	$$n2		;next if n>15. over code 'F'
	; 'A' - 'F'
	mov	a,R7
	ret
$$n2	mov	a,@R0
	add	a,#0-('a')
	jnc	$$endc		;ignore < 'a'
	add	a,#10	;'a'->0x0a
	mov	R7,a	;tempolary save 
	add	a,#-16
	jc	$$end
	; 'a' - 'f'
	mov	a,R7
$$end	ret
$$endc	cpl	c
	ret

; get two hex string 
; @input	R0(string top pointer, delimiter is zero)
; @broken	R6,R7
; @return	Acc=R7,R0(Next pointer),err(CY=1),ok(CY=0)
getbyte:
	call	tohex
	jc	$$err
	swap	a
	mov	R6,a
	inc	R0
	call	tohex
	jc	$$err
	add	a,R6
	inc	R0
$$err	ret

	align	256
;-----------------------------------------------------------------------
; get variable length hex string args
; @input	R0(string top pointer, delimiter is zero)
; @broken	R6,R7
; @return	Acc=R7,R0(Next pointer),err(F1=1),ok(F1=0)
str2hex:
	mov	R6,#0		;clear value.
	clr	F1
	cpl	F1		;set err. flag.
	mov	a,@R0
	jz	$$err		;err,if no args.
$$loop	mov	a,@R0
	jz	$$end		;terminate
	add	a,#(0-',')	;COMMA is terminate
	jz	$$end
	mov	a,@R0
	add	a,#(0-' ')
	jz	$$next		;skip SPACE
	call	tohex
	jc	$$err
	mov	R7,a	;tempolary save 
	mov	a,R6	;restore before
	swap	a
	anl	a,#0f0h
	add	a,R7
	mov	R6,a
$$next	inc	R0
	jmp	$$loop
$$end	cpl	F1
	mov	a,R6
$$err	ret

; tty to hex
; @input	Acc
; @broken	R4,R5,R6,R7
; @return	R4=Acc=input value
hexout:
	mov	R4,a		;save Acc
	swap	a
	call	nibhex
	call	putc
	mov	a,R4
	call	nibhex
	call	putc
	mov	a,R4
	ret

; convert nibble to hex ascii code
; @input	Acc 0x00 - 0x0f
; @brlken	Acc
; @return	Acc Ascii '0' - 'F'
nibhex:
	anl	a,#0fh
	add	a,#-10
	jnc	$$okay
	add	a,#('A'-'9'-1)
$$okay	add	a,#'0'+10
	ret

; dump & write & dump to EE-PROM(
eecheckcmd:
	call	eedump
	mov	R0,#(CRLF # 256)
	call	puts
	call	eewrite
	mov	R0,#(CRLF # 256)
	call	puts
	call	eedump
	ret

; Dump Exteral RAM 7F0 - 7FF
eedump:
	mov	a,#(07f0h >> 8)
	call	hexout	;display addr.(high)
	mov	R1,#(07f0h & 0ffh)
	mov	a,R1
	call	hexout	;display addr.(low)
	mov	a,#':'
	call	putc
$$n2d	mov	a,#((07f0h >> 8) | TX_BIT)
	outl	P2,a
	movx	a,@R1
	call	hexout	;display ram data
	mov	a,#' '
	call	putc
	inc	R1
	mov	a,R1
	anl	a,#0fh	;check align 16
	jnz	$$n2d
	ret


