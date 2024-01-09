;; RK - Evalbot (Cortex M3 de Texas Instrument)
; programme - Pilotage 2 Moteurs Evalbot par PWM tout en ASM (Evalbot tourne sur lui même)



		AREA    |.text|, CODE, READONLY
		; This register controls the clock gating logic in normal Run mode
SYSCTL_PERIPH_GPIOF EQU		0x400FE108	; SYSCTL_RCGC2_R (p291 datasheet de lm3s9b92.pdf)

; The GPIODATA register is the data register
GPIO_PORTF_BASE		EQU		0x40025000	; GPIO Port F (APB) base: 0x4002.5000 (p416 datasheet de lm3s9B92.pdf)

; configure the corresponding pin to be an output
; all GPIO pins are inputs by default
GPIO_O_DIR   		EQU 	0x00000400  ; GPIO Direction (p417 datasheet de lm3s9B92.pdf)

; The GPIODR2R register is the 2-mA drive control register
; By default, all GPIO pins have 2-mA drive.
GPIO_O_DR2R   		EQU 	0x00000500  ; GPIO 2-mA Drive Select (p428 datasheet de lm3s9B92.pdf)

; Digital enable register
; To use the pin as a digital input or output, the corresponding GPIODEN bit must be set.
GPIO_O_DEN   		EQU 	0x0000051C  ; GPIO Digital Enable (p437 datasheet de lm3s9B92.pdf)

; PIN select
PIN4 				EQU 	0x10
PIN5				EQU		0x20
PIN45				EQU		0x30		; led1 et led2 sur broche 4 et 5 ----> Ajouter 30 pour allumer les deux leds

; Ajouter la configuration de bumper
GPIO_PORTE_BASE		EQU		0x40024000		; GPIO Port E base: 0x4002.4000
GPIO_I_PUR			EQU		0x00000510

BROCHE0             EQU     0x01
BROCHE1             EQU     0x02
BROCHE0_1           EQU     0x03

; blinking frequency
DUREE   			EQU     0x000EFFFF
		ENTRY
		EXPORT	__main
		
		;; The IMPORT command specifies that a symbol is defined in a shared object at runtime.
		IMPORT	MOTEUR_INIT					; initialise les moteurs (configure les pwms + GPIO)
		
		IMPORT	MOTEUR_DROIT_ON				; activer le moteur droit
		IMPORT  MOTEUR_DROIT_OFF			; déactiver le moteur droit
		IMPORT  MOTEUR_DROIT_AVANT			; moteur droit tourne vers l'avant
		IMPORT  MOTEUR_DROIT_ARRIERE		; moteur droit tourne vers l'arrière
		IMPORT  MOTEUR_DROIT_INVERSE		; inverse le sens de rotation du moteur droit
		
		IMPORT	MOTEUR_GAUCHE_ON			; activer le moteur gauche
		IMPORT  MOTEUR_GAUCHE_OFF			; déactiver le moteur gauche
		IMPORT  MOTEUR_GAUCHE_AVANT			; moteur gauche tourne vers l'avant
		IMPORT  MOTEUR_GAUCHE_ARRIERE		; moteur gauche tourne vers l'arrière
		IMPORT  MOTEUR_GAUCHE_INVERSE		; inverse le sens de rotation du moteur gauche


__main	



; ;; Enable the Port F peripheral clock by setting bit 5 (0x20 == 0b100000)		(p291 datasheet de lm3s9B96.pdf)
		; ;;														 (GPIO::FEDCBA)
		ldr r6, = SYSCTL_PERIPH_GPIOF  			;; RCGC2
        mov r0, #0x000038  					;; Enable clock sur GPIO F où sont branchés les leds (0x20 == 0b11 1000)
		; ;;														 									 (GPIO::FEDCBA)
        str r0, [r6]
		
		; ;; "There must be a delay of 3 system clocks before any GPIO reg. access  (p413 datasheet de lm3s9B92.pdf)
		nop	   									;; tres tres important....
		nop	   
		nop	   									;; pas necessaire en simu ou en debbug step by step...
		
		;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^CONFIGURATION LED

        ldr r6, = GPIO_PORTF_BASE+GPIO_O_DIR    ;; 1 Pin du portF en sortie (broche 4 : 00010000)
        ldr r0, = PIN45	
        str r0, [r6]
		
        ldr r6, = GPIO_PORTF_BASE+GPIO_O_DEN	;; Enable Digital Function 
        ldr r0, = PIN45 		
        str r0, [r6]
 
		ldr r6, = GPIO_PORTF_BASE+GPIO_O_DR2R	;; Choix de l'intensité de sortie (2mA)
        ldr r0, = PIN45 			
        str r0, [r6]

		;vvvvvvvvvvvvvvvvvvvvvvvFin configuration LED 
		
		;vvvvvvvvvvvvvvvvvvvvvvvvvvCONFIGURATION Bumper
		ldr r7, = GPIO_PORTE_BASE+GPIO_I_PUR
		ldr r0, = BROCHE0_1
		str r0, [r7]
		
		ldr r7, = GPIO_PORTE_BASE+GPIO_O_DEN
		ldr r0, = BROCHE0_1
		str r0, [r7]

		ldr r3, = GPIO_PORTE_BASE + (BROCHE0<<2)
		ldr r4, = GPIO_PORTE_BASE + (BROCHE1<<2)
		
		;vvvvvvvvvvvvvvvvvvvvvvvFin configuration Bumper

		;; BL Branchement vers un lien (sous programme)

		; Configure les PWM + GPIO
		BL	MOTEUR_INIT	   		   
		
		; Activer les deux moteurs droit et gauche
		BL	MOTEUR_DROIT_ON
		BL	MOTEUR_GAUCHE_ON

loop	

		BL MOTEUR_DROIT_AVANT
		BL MOTEUR_GAUCHE_AVANT
		mov r3, #PIN45
		ldr r6, = GPIO_PORTF_BASE + (PIN45<<2)
		str r3, [r6]
		
		; Avancement pendant une période (deux WAIT)
		BL	WAIT	; BL (Branchement vers le lien WAIT); possibilité de retour à la suite avec (BX LR)
		BL	WAIT
		
		b loop
		;; Boucle d'attante
		
WAIT	
		PUSH {LR}
		ldr r1, =0x0FFFFF
wait1	
		;---------> Boucle pour tester si un switch à decter quelque chose
		
		;---------> Tester les deux bumpers
		ldr r7, = GPIO_PORTE_BASE + (BROCHE0_1<<3)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ ActionBumperDG
		;---------> Fin test les deux bumpers

		;---------> Tester le bumper Droit
		ldr r7, = GPIO_PORTE_BASE + (BROCHE0<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ ActionBumperD
		;---------> Fin test bumper Droit

		;---------> Tester le bumper Gauche
		ldr r7, = GPIO_PORTE_BASE + (BROCHE1<<2)
		ldr r10,[r7]
		CMP r10,#0x00
		BEQ ActionBumperG
		;---------> Fin test de bumper Gauche
		
		subs r1, #1
        bne wait1
		POP {LR}
		;; retour à la suite du lien de branchement
		BX	LR

ActionBumperD
		;---------> Clignottement coté Droit pour une seul fois
		str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
loopC
        str r2, [r6]    						;; Eteint LED car r2 = 0x00      
        ldr r1, = DUREE 						;; pour la duree de la boucle d'attente1 (wait1)

waitC	subs r1, #1
        bne waitC

        str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
        ldr r1, = DUREE							;; pour la duree de la boucle d'attente2 (wait2)

waitCD   subs r1, #1
        bne waitCD
		;---------> Fin Clignottement coté Droit
		
		;---------> Allume LED Gauche
		mov r2, #1
		ldr r6, = GPIO_PORTF_BASE + (PIN4<<2)
		str r2, [r6]
		BL WAITD
		B loop
		;---------> Fin ActionBumperD
		
ActionBumperG
		;---------> Clignottement coté Gauche pour une seul fois
		str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
loopCG
        str r2, [r6]    						;; Eteint LED car r2 = 0x00      
        ldr r1, = DUREE 						;; pour la duree de la boucle d'attente1 (wait1)

waitCG	subs r1, #1
        bne waitCG

        str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
        ldr r1, = DUREE							;; pour la duree de la boucle d'attente2 (wait2)

waitCG2   subs r1, #1
        bne waitCG2
 
		;---------> Fin Clignottement coté Gauche
		
		;---------> Allume LED Droit
		mov r2, #0
		ldr r6, = GPIO_PORTF_BASE + (PIN5<<2)
		str r2, [r6]
		BL WAITG

		B loop
		;---------> Fin ActionBumperG

ActionBumperDG
		;PUSH {LR}
		;---------> Clignottement coté Gauche pour une seul fois
		str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
loopCDG
        str r2, [r6]    						;; Eteint LED car r2 = 0x00      
        ldr r1, = DUREE 						;; pour la duree de la boucle d'attente1 (wait1)

waitCDG	subs r1, #1
        bne waitCDG

        str r3, [r6]  							;; Allume LED1&2 portF broche 4&5 : 00110000 (contenu de r3)
        ldr r1, = DUREE							;; pour la duree de la boucle d'attente2 (wait2)

waitCCDG   subs r1, #1
        bne waitCCDG
		;---------> Fin Clignottement coté Gauche
		
		BL WAITDG
		B loop
		;BX LR
;---------> FIN ActionBumperDG

WAITDG	
		PUSH {LR}
		ldr r1, =0xFFFFFF
		;;;;;;;; Marche arriere
		BL	MOTEUR_GAUCHE_ARRIERE
		BL MOTEUR_DROIT_ARRIERE
		;;;;;;;;;;
		;;;; Temps pout marche arriere
		ldr r1, =0x0EFFFF
		
waitDDG	subs r1, #1
		
		BEQ ActionBumperG
        bne waitDDG
		POP{LR}
		;; retour à la suite du lien de branchement
		BX	LR
		;---------> Fin waitDG

WAITD	
		PUSH {LR}
		ldr r1, =0x5FFFFF
waitD	
		subs r1, #1
        bne waitD
		;;;;;;;; Tourne à droit
		BL	MOTEUR_GAUCHE_ARRIERE
		BL MOTEUR_DROIT_AVANT
		;;;;;;;;;;
		;;;; Temps pout tourne
		ldr r1, =0x5FFFFF
		
waitDD	subs r1, #1
        bne waitDD
		POP{LR}
		;; retour à la suite du lien de branchement
		BX	LR
		;--------->Fin WAITD
		
WAITG	
		PUSH {LR}
		ldr r1, =0x5FFFFF
waitG	
		subs r1, #1
        bne waitG
		;---------> Tourne à gauche
		BL	MOTEUR_DROIT_ARRIERE
		BL MOTEUR_GAUCHE_AVANT
		;---------> Fin
		ldr r1, =0x5FFFFF
waitGG		subs r1, #1
        bne waitGG
		POP{LR}
		;; retour à la suite du lien de branchement
		BX	LR
		;---------> Fin WAITG	
		
		NOP
        END