;
; button_latch.asm
;
; Created: 4/21/2023 12:04:54 PM
; Author : John Nori
;

; stack initialize macro
;
.macro INITSTACK
	ldi R16, high(RAMEND)
	out SPH, R16
	ldi R16, low(RAMEND)
	out SPL, R16
.endmacro

; interreupt vectors
;
.org $00
	jmp MAIN
.org $02
	jmp INT0_ISR_RESET
.org $06
	jmp PCINT0_ISR_OPER

; create a look-up table for decoding
;
.org $100	
LUT_VALUES: .db	0x00, 0x01, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
 
; main routine
;
MAIN:

	; initialize the stack pointer
	;
	INITSTACK

	; configure I/O ports
	;
	ldi R16, $00
	out DDRB, R16 ; set PB0-PB3 as input (operand port)
	ldi R16, (1 << PB3) | (1 << PB2) | (1 << PB1) | (1 << PB0)
	out PORTB, R16 ; activate PORTB pullups
	ldi R16, $00
	out DDRD, R16 ; set PD2 input (reset port)
	ldi R16, (1 << PD2)
	out PORTD, R16 ; activate PORTD pullups
	ldi R16, (1 << PC6) | (1 << PC5) | (1<< PC4) | (1 << PC3) | (1 << PC2) | (1 << PC1) | (1 << PC0)
	out DDRC, R16 ; set PC0-PC3 as output (output port)
	ldi R16, $00
	out PORTC, R16

	; enable the external and hardware interrupts
	;
	ldi R16, (1 << INT0)
	out EIMSK, R16 ; unmask INT0 (reset signals)
	ldi R16, (1 << ISC01)
	sts EICRA, R16 ; falling-edge triggered
	ldi R16, (1 << PCINT3) | (1 << PCINT2) | (1 << PCINT1) | (1 << PCINT0)
	sts	PCMSK0, R16 ; unmask the pin change interrupts on operand port (PORTB)
	ldi R16, (1 << PCIE0)
	sts PCICR, R16 ; enable pin change interrupts on operand port (PORTB)

	; enable global interrupts
	;
	sei

	HERE: rjmp HERE ; forever loop

; INT0_ISR_RESET
;
INT0_ISR_RESET:

	; reset all outputs and the ADD flag (T flag in SREG)
	;
	ldi R16, $00
	out PORTC, R16
	clt ; clear T flag in SREG (ADD flag) 

	; return
	;
	reti

; PCINT0_ISR_OPER
;
PCINT0_ISR_OPER:

	; read in the status of the operand port (PORTB)
	;
	in R16, PINB
	;com R16
	andi R16, 0x0f

	; do not decode if none of buttons are currently pressed
	;
	cpi R16, 0b00000001
	breq UPDATE_OUTPUT
	cpi R16, 0b00000010
	breq UPDATE_OUTPUT
	cpi R16, 0b00000100
	breq UPDATE_OUTPUT
	cpi R16, 0b00001000
	breq UPDATE_OUTPUT
	rjmp RETURN_PCINT0_ISR

	; use look-up table to decode button input
	;
	UPDATE_OUTPUT:
		ldi ZH, high(LUT_VALUES << 1)
		ldi ZL, low(LUT_VALUES << 1)
		add ZL, R16
		lpm R17, Z
	
		; send proper data out to PORTC (output port)
		;
		brts OUT_SHIFT
		out PORTC, R17
		set ; set the T flag (ADD flag)
		rjmp RETURN_PCINT0_ISR
		OUT_SHIFT: 
			swap R17 ; swap nibbles
			lsr R17 ; shift data into position
			in R16, PORTC
			or R17, R16 ; maintain the data already on the output port
			out PORTC, R17 
			clt ; clear the T flag (ADD flag)

	; return
	;
	RETURN_PCINT0_ISR: reti