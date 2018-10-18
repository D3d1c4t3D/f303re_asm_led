;*******************************************************************************
;* File: 	led_example.s
;* Date: 	24. 4. 2017
;* Author:	Jan Svetlik
;* Course: 	A3B38MMP - Department of Measurement
;* Brief:	A simple example of using GPIO
;* -----------------------------------------------------------------------------
;* This example shows simple usage of GPIO pin as an input for reading user
;* button state. This button is used to switch between two periods of blinking
;* the LED driven by another GPIO pin.
;* A very simple technique is use to make the antideglitch protection while
;* reading the button state. This is not needed as the user button is bypassed
;* with ceramic capacitor, but it serves as a demonstration of SW based anti-
;* deglitch.
;* In this example the HSE in bypass mode is used as the system clock source.
;* The HSE is fed with clock signal of requency 8MHz from the ST-Link/V2
;* programmer available on the Nucleo kit.
;*******************************************************************************
	area STM32F3xx, code, readonly
	get f303xe_asm_periph/stm32f303xe.s

; Definition of some usefull constants goes here
DELAY_TIME EQU 50000
USER_BUTTON_PIN EQU 13
USER_BUTTON_MSK EQU (1 :SHL: USER_BUTTON_PIN)
LED_PIN EQU 5
LED_MSK EQU (1 :SHL: LED_PIN)
DELAY_1 EQU 10
DELAY_2 EQU 5

; Export of important modifiers to be used in other modules e.g. in the
; startup_stm32f30x.s
	export __main
;	export SystemInit
	export __use_two_region_memory
		
__use_two_region_memory
__main

	ENTRY
	
;********************************************
;* Function:	MAIN
;* Brief:		This procedure contains the main loop for the program
;* Input:		None
;* Output:		None
;********************************************
;* At the system reset, the prefetch buffer is enabled and the system clock
;* is switched on the HSI oscillator.
;* When using PLL as the clock source, be ware of the SYSCLK frequency as
;* there are rules for setting the Flash controller latency for accessing
;* the Flash memory. This mainly applies when setting the SYSCLK to high
;* frequencies.
;********************************************
MAIN
	BL RCC_INIT
	BL GPIO_INIT
	
	; Preload registers that are going to be used for counting delays and saving
	; last state of the button.
	LDR R3, =DELAY_1			; number of main cycles to wait before togling
								; the LED
	MOV R5, R3					; freezed value of R3
	LDR R6, =0					; this register is used to store the last state
								; of the push button
	
	; Main loop with period approximately 25 Hz.
LOOP
	; Wait approximately 40 ms, the R4 is used for passing an argument to
	; DELAY_TIME procedure.
	LDR R4, =DELAY_TIME
	BL DELAY

	; Read the value of the pin PC13 on which the USER push button is connected.
	LDR R0, =GPIOC_IDR
	LDR R1, [R0]
	; Test whether the button is pressed
	TST R1, #(USER_BUTTON_MSK)
	BNE BTN_RELEASED	; If the logic value at PC13 is '1', button is released
	
	; If the button is pressed, check the previous state
	TST R6, #(USER_BUTTON_MSK)
	BEQ CONTINUE		; If the button was previously pressed, do nothing
	
	; This label is not needed here but is used for code transparency. Here we
	; continue, when the button is pressed and the previos state was released.
BTN_PRESSED
	; Store the actual button state for the next iteration
	BIC R6, #(USER_BUTTON_MSK)
	; Switch between the two LED periods. Compare the actual value of register
	; R5, which is holding the current DELAY value, with DELAY_1 value.
	CMP R5, #(DELAY_1)
	ITE EQ	; Conditional execution If -> Then -> Else. Flag EQ indicates if the
			; result was zero, eg. the compared values were the same.
	LDREQ R5, =DELAY_2	; Then: load R5 with the new value of DELAY, eg. DELAY_2
	LDRNE R5, =DELAY_1	; Else: load R5 with the new value of DELAY, eg. DELAY_1
	B CONTINUE
	
	; NOTE to the conditional execution: there can be up to 4 conditional
	; instructions. The composition can be for example ITTE this means
	; If -> {Then, Then} -> Else. Or in case ITTEE it would mean
	; If -> {Then, Then} -> {Else, Else}.

	; If button is released, update the state of the button for next iteration.
BTN_RELEASED
	ORR R6, #(USER_BUTTON_MSK)

	; The rest of loop is here.
CONTINUE
	; Count down the number of main loop cycles before toggling the LED
	SUBS R3, #1
	BNE LOOP
	MOV R3, R5					; the current period is persisted in R5
	
	; Toggle the output pin that drives the LED e.g. PA5.
	LDR R0, =GPIOA_ODR
	LDR R1, [R0]
	EOR R1, #(LED_MSK)
	STR R1, [R0]

	; Never-ending story
	B LOOP
	
;********************************************
;* Function:	DELAY
;* Brief:		This procedure provides software based delay
;* Input:		R4 = number of cycles to wait
;* Output:		None
;********************************************
DELAY
	PUSH {LR}
	
	; Wait until the required number of cycles is count down.
D_WAIT
	SUBS R4, #1
	BNE D_WAIT

	POP {PC}

;********************************************
;* Function:	GPIO_INIT
;* Brief:		This procedure initializes GPIO
;* Input:		None
;* Output:		None
;********************************************
GPIO_INIT
	; Enable clock for the GPIOA and GPIOC port in the RCC.
	LDR R0, =RCC_AHBENR
	LDR R1, [R0]
	ORR R1, R1, #(RCC_AHBENR_GPIOAEN :OR: RCC_AHBENR_GPIOCEN)
	STR R1, [R0]
	
	; Configure the PA5 pin as the output
	LDR R0, =GPIOA_MODER
	LDR R1, [R0]
	ORR R1, R1, #GPIO_MODER_MODER5_0
	STR R1, [R0]
	
	BX LR
	
;********************************************
;* Function:	RCC_INIT
;* Brief:		This procedure initializes Reset and Clock Control peripheral
;* Input:		None
;* Output:		None
;********************************************
RCC_INIT
	; Set the HSE clock source to bypass clock from ST-Link.
	LDR R0, =RCC_CR
	LDR R1, [R0]
	ORR R1, #(RCC_CR_HSEBYP)
	STR R1, [R0]
	; Enable the HSE clock source.
	ORR R1, #(RCC_CR_HSEON)
	STR R1, [R0]
	
	; Wait for the HSE to be stable.
HSE_NOT_REDY
	LDR R1, [R0]
	TST R1, #(RCC_CR_HSERDY)
	BEQ HSE_NOT_REDY
	
	; Switch the system clock to HSE clock source.
	LDR R0, =RCC_CFGR
	LDR R1, [R0]
	ORR R1, #(RCC_CFGR_SW_0)
	STR R1, [R0]
	
	; Wait until the clock source is switched to HSE.
SYSCLK_NOT_CHANGED
	LDR R1, [R0]
	AND R1, #(0x03 :SHL: RCC_CFGR_SWS_Pos)
	CMP R1, #(0x01 :SHL: RCC_CFGR_SWS_Pos)
	BNE SYSCLK_NOT_CHANGED
	
	; Optionally turn off the HSI oscillator to save the power.
	LDR R0, =RCC_CR
	LDR R1, [R0]
	BIC R1, #(RCC_CR_HSION)
	STR R1, [R0]	
	
	BX LR

;********************************************
;* Function:	SystemInit
;* Brief:		System initialization procedure. This function is implicitly
;*				generated by IDEs when creating new C project. It can be thrown
;*				away or the clock, GPIO, etc. configuration can be put here.
;* Input:		None
;* Output:		None
;********************************************
;SystemInit
;
;	BX LR

	ALIGN
	
	END