;**********************************************************************

	list      p=16f818           ; list directive to define processor
	#include <p16f818.inc>        ; processor specific variable definitions

	errorlevel  -302              ; suppress message 302 from list file

	__CONFIG   _CP_OFF & _WRT_ENABLE_OFF & _CPD_OFF & _CCP1_RB2 & _DEBUG_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_IO

	;//VARIABLES

fsr_temp equ 0x79
status_temp equ 0x7D
w_temp equ 0x7E

BITCHECK equ 0x7F
BITCOUNTER equ 0x7B
ROWCHECK equ 0x7C


BOARDPTR equ 0x20 ; [4]
BOARDCPY equ 0x24 ; [4]
STAGEPTR equ 0x28 ; [4]

RAND_XOR equ 0x2D
RAND_SHIFT equ 0x2E
RAND_TEMP equ 0x2F 

RAND_COUNTER=0x30
RAND_STATE=0x31

temp_board equ 0x40
temp_test equ 0x50
 
seed_1 equ 0x5A
seed_2 equ 0x5B
seed_3 equ 0x5C

temp equ 0x60
temp2 equ 0x61
temp3 equ 0x62
KEYA equ 0x63
KEYT equ 0x64

FLIPPEDBITPTR equ 0x70
ROWPTR equ 0x71
RANDPTR equ 0x72  ; [3]
special_check equ 0x7A

FLIPPEDBIT equ b'00001000'

PAR0   equ b'00000101' ; bits in col 1 & 3
PAR1   equ b'00000011' ; bits in col 2 & 3
PAR2   equ b'01011111' ; bits in row 1 & 3
PAR3   equ b'00111111' ; bits in row 2 & 3

INIT_0 equ b'11111000'
INIT_1 equ b'11110100'
INIT_2 equ b'11110010'
INIT_3 equ b'11110001'



	ORG     0x00             ; processor reset vector
	goto	main

irq	ORG	0x004
	movwf	w_temp		; store status reg, W, and PTR reg
	movf	 STATUS,0
	movwf	status_temp
	movf 	FSR,0
	movwf	fsr_temp

	bcf  INTCON,5   ; disable TMR0 interrupt to prevent recursion

	call display_both  ; display boards in irq


	btfss INTCON,2   ;check if overflow
	goto irq_finish 
	bcf  INTCON,2



	irq_finish
	bsf  INTCON,5   ; re-enable TMR0 interrupt
	movf	status_temp,0
	movwf	STATUS
	movf 	fsr_temp,0
	movwf	FSR
	swapf	w_temp,1
	swapf	w_temp,0
	retfie

main
	call init_board
	call init_patterns
	clrf RANDPTR
	clrf RANDPTR+1
	clrf RANDPTR+2
	call init_makerand
start
	call init_board
	call clock_init
	call port_init
	call irq_init
	banksel PORTB
	
	
	
	
start_loop	
	BTFSC PORTA,4  
	goto start_loop  ; wait for user to press select for entropy
	call make_rand   
	

	call format_rands 
	call copy_board


button_loop
	
	btfsc ROWCHECK,3 
	call rowcheck_reset 
	btfss PORTA,4
	call scan_routine
	btfss PORTA,5
	goto set_routine
	btfss PORTA,6
	goto start
	goto button_loop
	
	
scan_routine
	btfsc BITCOUNTER,2
	call end_row
	
	movf BITCHECK,0

	movf BITCOUNTER,1 ;moves file to itself to update status flag
	btfsc STATUS,2   ;if bitcounter is 0
	movf  special_check,0

	xorwf INDF,1
	rlf  BITCHECK    ;goes to next
	incf BITCOUNTER  ;adds, will cause behavior in button_loop if = 4

	movlw b'11000000'
	call delay
	return

set_routine		 ; user hit set, begin the correct check
	movlw BOARDCPY
	movwf FSR
	clrf temp
	clrf KEYT
	
row_loop
	MOVF  temp,0
	IORWF INDF,1
	INCF  FSR
	RRF   temp,1
	BTFSS temp,3
	goto row_loop

	MOVLW b'11110000'
	ANDWF PORTA,1
	MOVLW b'00001111'
	ANDWF RANDPTR+2,0
	MOVWF KEYA
	IORWF PORTA,1

	return


	
	movlw b'00001000'  ;blinks when routine is finished for debug
	xorwf PORTA,1
	return


rowcheck_reset
	movlw BOARDCPY
	movwf ROWCHECK
	movwf FSR
	return

end_row
	movlw b'00000001'   ;flips last bit of row
	xorwf INDF,1
	incf FSR            ;moves to next
	incf ROWCHECK       ;keeps track of row
	clrf BITCOUNTER     ;resets bit counter
	movlw b'00011000'   ;resets bit check
	movwf BITCHECK
	return
	
new_seed
	movf TMR0,0
	movwf seed_1
	rrf seed_1,1
	rrf seed_1,1
	xorwf seed_1,0
	movwf seed_2
	addlw b'00110011'
	movwf seed_3
	rlf seed_3,1
	return

init_makerand
	call new_seed
	movf RANDPTR,0
	xorwf seed_1,1
	movf RANDPTR+1,0
	xorwf seed_2,1
	movf RANDPTR+2,0
	xorwf seed_3,1
	
	movlw b'00110011'
	movwf temp
	
	movf RANDPTR,0
	xorwf RANDPTR+2,0
	xorwf temp,0
	movwf RANDPTR
	
	addwf RANDPTR+1,0
	movwf RANDPTR+1
	
	rrf RANDPTR+1,0
	xorwf RANDPTR,0
	addwf RANDPTR+2,1
	return
	
clear_board_cpy
	movlw BOARDCPY 
	movwf FSR
	call clr_INDF
	call clr_INDF
	call clr_INDF
	call clr_INDF
	return 

init_board
	movlw BOARDPTR
	movwf FSR
	movlw INIT_1
	call W_to_INDF
	movlw INIT_2
	call W_to_INDF
	movlw INIT_3
	call W_to_INDF
	movlw INIT_4
	call W_to_INDF
	
	call clear_board_cpy
	return
	
make_rand
	call new_seed
	incf temp
	movf RANDPTR,0
	xorwf RANDPTR+2,0
	xorwf temp,0
	movwf RANDPTR
	
	addwf RANDPTR+1,0
	movwf RANDPTR+1
	
	rrf RANDPTR+1,0
	xorwf RANDPTR,0
	addwf RANDPTR+2,1
	return
	
	
	

test0
	movlw BOARDCPY
	addwf temp,0
	movwf FSR
	movlw KEY0
	andwf INDF,0
	movwf temp_test
	movlw temp_board
	addwf temp,0
	movwf FSR
	movf temp_test,0
	movwf INDF
	incf temp
	btfss temp,2
	goto test0

	movlw temp_board
	movwf FSR

	movf INDF,0
	movwf temp_test

test0_loop
	movf INDF,0
	xorwf temp_test,1
	incf FSR
	btfss FSR,2
	goto test0_loop

	movf temp_test,0
	rrf  temp_test
	rrf  temp_test

	xorwf temp_test,1
	btfsc temp_test,0
	bsf   KEYT,3

	clrf temp

test1
	movlw BOARDCPY
	addwf temp,0
	movwf FSR
	movlw PAR1
	andwf INDF,0
	movwf temp_test
	movlw temp_board
	addwf temp,0
	movwf FSR
	movf temp_test,0
	movwf INDF
	incf temp
	btfss temp,2
	goto test1

	movlw temp_board
	movwf FSR

	movf INDF,0
	movwf temp_test

test1_loop
	movf INDF,0
	xorwf temp_test,1
	incf FSR
	btfss FSR,2
	goto test1_loop

	movf temp_test,0
	rrf  temp_test

	xorwf temp_test,1
	btfsc temp_test,0
	bsf   KEYT,2

	clrf temp

test2
	movlw BOARDCPY
	addwf temp,0
	movwf FSR
	movlw PAR2
	andwf INDF,0
	movwf temp_test
	movlw temp_board
	addwf temp,0
	movwf FSR
	movf temp_test,0
	movwf INDF
	incf temp
	btfss temp,2
	goto test2

	movlw temp_board
	movwf FSR

	movf INDF,0
	movwf temp_test

test2_loop
	movf INDF,0
	btfsc INDF,6
	xorwf temp_test,1
	btfsc INDF,4
	incf FSR
	btfss FSR,2
	goto test2_loop

	movf temp_test,0
	rrf  temp_test
	rrf  temp_test

	xorwf temp_test,1

	movf temp_test,0
	rrf  temp_test

	xorwf temp_test,1

	btfsc temp_test,0
	bsf   KEYT,1

	clrf temp

test3
	movlw BOARDCPY
	addwf temp,0
	movwf FSR
	movlw PAR3
	andwf INDF,0
	movwf temp_test
	movlw temp_board
	addwf temp,0
	movwf FSR
	movf temp_test,0
	movwf INDF
	incf temp
	btfss temp,2
	goto test3

	movlw temp_board
	movwf FSR

	movf INDF,0
	movwf temp_test

test3_loop
	movf INDF,0
	xorwf temp_test,1
	incf FSR
	btfss FSR,2
	goto test3_loop

	movf temp_test,0
	rrf  temp_test
	rrf  temp_test

	xorwf temp_test,1

	movf temp_test,0
	rrf  temp_test

	xorwf temp_test,1

	btfsc temp_test,0
	bsf   KEYT,0

	clrf temp

	movf KEYT,0
	xorwf KEYA,0

	btfsc STATUS,2
	goto stage_win

	goto stage_loss


WIN_1  equ b'01001000'
WIN_2  equ b'10000100'
WIN_3  equ b'01000010'
WIN_4  equ b'00010001' 

LOSS_1 equ b'10011000'
LOSS_2 equ b'01101100'
LOSS_3 equ b'01101010'
LOSS_4 equ b'10011001'



W_to_INDF
	movwf INDF
	incf FSR
	return

clr_INDF
	clrf INDF
	incf FSR
	return

stage_win
	movlw STAGEPTR 
	movwf FSR

	movlw WIN_1
	call W_to_INDF	
	movlw WIN_2
	call W_to_INDF
	movlw WIN_3
	call W_to_INDF
	movlw WIN_4
	call W_to_INDF
	goto end_game

stage_loss
	movlw STAGEPTR 
	movwf FSR

	movlw LOSS_1
	call W_to_INDF
	movlw LOSS_2
	call W_to_INDF
	movlw LOSS_3
	call W_to_INDF
	movlw LOSS_4
	call W_to_INDF
	goto end_game



end_game
	movlw STAGEPTR
	movwf FSR
	movf INDF,0
	movwf BOARDCPY
	incf FSR
	movf INDF,0
	movwf BOARDCPY+1
	incf FSR
	movf INDF,0
	movwf BOARDCPY+2
	incf FSR
	movf INDF,0
	movwf BOARDCPY+3

	call and_compliment

	clrf RAND_STATE
	movf RANDPTR,0
	movwf RAND_TEMP

	banksel PORTA
	movf PORTA,0
	xorwf, RAND_TEMP,0
	
end_loop
	clrf RAND_COUNTER
	bsf RAND_COUNTER,2

	movf RANDPTR,0
	addwf RAND_STATE,0
	movwf FSR
	movf INDF, 0
	xorwf, RAND_TEMP,1

	btfss RAND_STATE,0
	goto right_loop
	goto left_loop

right_loop

	rrf RAND_TEMP,0
	movwf PORTA
	movwf RAND_TEMP,1

	movlw 0xF8
	call delay
	decfsz RAND_COUNTER

	goto right_loop
	bsf RAND_STATE,0
	swapf RAND_TEMP,1
	goto end_loop

left_loop

	rlf RAND_TEMP,0
	movwf PORTA
	movwf RAND_TEMP,1

	movlw 0xF8
	call delay
	decfsz RAND_COUNTER

	goto left_loop 
	bcf RAND_STATE,0
	swapf RAND_TEMP,1
	goto end_loop


and_compliment     ;BOARDCPY will now contain its compliment
	banksel PORTB
	movf BOARDCPY,0
	movwf FSR
	bcf RAND_STATE
	bsf RAND_STATE,2 ; = 4
comp_loop
	movf INDF, 0
	movwf w_temp 
	comf w_temp,0       ; Complement
	andwl b'11110000',0 ; Mask
	movwf w_temp		; w_temp<= ~(&0xF0)

	movf FSR,0
	movf fsr_temp,1

	addwf RAND_STATE
	movwf FSR,			; FSR+4 (BOARDPTR)
	movf w_temp,0
	iorwf INDF,1 		; stored  *(FSR+4)

	movf fsr_temp,0

	movwf FSR
	incf  FSR
	btfss FSR,2
	goto comp_loop
	return
	




clock_init		; set clock to 8Mhz
	banksel OSCCON
	movlw b'01110000'
	movwf OSCCON
	banksel PORTB
	return

port_init
	banksel TRISB  ; PORT B Direction Config
	clrf    TRISB
	banksel PORTB  ; PORTB itself cleared
	clrf    PORTB
	banksel ADCON1 ;
	movlw	b'00000110'
	movwf	ADCON1
	banksel TRISA
	movlw   b'11110000'
	movwf   TRISA
	banksel PORTA
	clrf	PORTA
	movlw	b'00001000'
	movwf	special_check ; special_check for the edgecase of first bit in row
	movlw	b'00011000'
	movwf	BITCHECK   ; BITCHECK is used to xor and shift left
	clrf	BITCOUNTER ; BITCOUNTER offset into row
	movlw   BOARDCPY
	movwf   ROWCHECK
	return

irq_init
	clrwdt
	banksel OPTION_REG ; Disbable RBO pullup
	movlw b'11010000'  ; Interrupt on RE of TMR0 
	movwf OPTION_REG   ; INC TMR0 on FE of T0CLK

	banksel TMR0
	clrf TMR0

	banksel INTCON
	movlw b'10100000' ; enable and unmask TMR0 IRQ
	movwf INTCON 
	return


format_rands
	MOVLW BOARDPTR
	MOVWF FSR	   ; main board in pointer reg

	MOVLW b'00001111'
	ANDWF RANDPTR,0 ; and with the 4 LSB
	MOVWF INDF		; store in BOARDPTR+ 'i'
	INCF  FSR	
	SWAPF RANDPTR,1	; swap half-bytes

	MOVLW b'00001111' ; repeat
	ANDWF RANDPTR,0
	MOVWF INDF
	INCF FSR


	MOVLW b'00001111'  ;repeat with RAND2
	ANDWF RANDPTR+1,0
	MOVWF INDF
	INCF FSR
	SWAPF RANDPTR+1,1 

	MOVLW b'00001111' 
	ANDWF RANDPTR+1,0
	MOVWF INDF	     ;board is now full with 4x4 random bits


	MOVLW BOARDPTR    ; BOARDPTR loaded
	MOVWF FSR
	MOVLW b'10000000' ; 7th bit loaded in W
	MOVWF temp




copy_board
	movlw BOARDPTR
	movwf FSR

	movf INDF,0
	movwf BOARDCPY
	incf FSR

	movf INDF,0
	movwf BOARDCPY+1
	incf FSR

	movf INDF,0
	movwf BOARDCPY+2
	incf FSR

	movf INDF,0
	movwf BOARDCPY+3

	movlw BOARDCPY
	movwf FSR      ;BOARDCPY is in PTR reg

	return


display_both
	movlw BOARDPTR
	movwf FSR

	clrf temp
	bsf temp,4 ; set temp to 16

board_loop
	movf INDF,0     ; Put *PTR in W
	movwf PORTB     ; Write to LED Array
	incf FSR	    ; Next ROW
	movlw BOARDPTR  ; Prepare to reset board ptr
	btfsc FSR,2		; BOARDPTR is 0x20-0x23, bit 2 is clear until 0x24
	movwf FSR
	movlw b'11111100' ; Call 4, 255 overflow 
	call delay
	incfsz temp       ; Call 239, 4 x 255 overflows
	goto board_loop


	clrf temp  
	bsf temp,6     ;; set temp to 64 for less proportion of blink on the 
	movlw BOARDCPY ;; original state to reduce confusion on what is changed
	movwf FSR

boardcpy_loop
	movf INDF,0
	movwf PORTB
	incf FSR
	movlw BOARDCPY
	btfsc FSR,3    ; BOARDCPY is 0x24-0x27, when 0x28, this is not true
	movwf FSR
	movlw b'11111100'
	call delay
	incfsz temp	; Call 191, 4 x 255 overflows
	goto boardcpy_loop

	return

delay  			; Requires W to be loaded with (255 - iterations)
	clrf temp2
	movwf temp3
increment
	incfsz temp2 
	goto increment
	incfsz temp3  ; one 8 bit overflow
	goto increment ;
	return


done
	END                       ; directive 'end of program'
