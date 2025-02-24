//*********************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de Microcontroladores
// Author : Thomas Solis
// Proyecto: LAB03
// Descripción: Interrupciones,  contador de “decenas”. 
// Hardware: ATmega328p
// Created: 17/02/2025 16:45:54
//*********************************************************************
// Encabezado
//******************************************************************

.include "M328PDEF.inc"
.cseg
.org 0x0000                  
    rjmp    SETUP
.org PCI0addr              
    rjmp    ISR_PCINT0  ; interrupcuion para el cambio en los pines de PuertoB 
.org 0x0020    ; Direccion del vector de interrupcion timer0
    rjmp    TIMER0


//TABLA DE VALORES PARA DISPLAY (0 - 9)
TABLA: 
.DB 0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B


// VARIABLES
.def cont1s = R20        ; contador para 1 segundo 
.def cont_disp1 = R22  ; Unidades de segundos de 0 a 9
.def cont_disp2 = R23  ; Decenas de segundos de 0 a 5
.def contador = R24  ; contador binario de 4 bits 
.def estado_anterior = R25  


// CONFIGURACIÓN DE PUERTOS Y TIMER0
SETUP:
    
    ldi r16, 0b01111111 ; Configurar PD0 - PD6 como salida (para display)
    out DDRD, r16 ; configurar como salidas para controlar los display 

   
    ldi r16, 0b00000011 ; Configurar PB0 y PB1 como salida (selección de displays)
    out DDRB, r16  ; configurar como salidas puerto B 

   
    ldi r16, 0b00001111 ; Configurar PC0-PC3 como salidas (LEDs del contador)
    out DDRC, r16 ; configurar como salidas puerto C

    ; Configurar PB3 y PB4 como entradas con pull-ups internos
    sbi PORTB, PB3
    sbi PORTB, PB4
    cbi DDRB, PB3
    cbi DDRB, PB4

    ; Habilitar interrupciones on-change en PB3 y PB4
    ldi r16, (1 << PCINT3) | (1 << PCINT4)
    sts PCMSK0, r16
    ldi r16, (1 << PCIE0)
    sts PCICR, r16

    ; Habilitar interrupciones globales
    sei

    ; Inicializar contadores
    clr cont_disp1 ; colocar todos los bits del registro en 0 , el cont_disp1 representa las undades de 0 a 9
    clr cont_disp2 ; representa la decenas de 0 a 5 
    clr contador ; contador de 4 bits 
    out PORTC, contador  

    ; Inicializar estado anterior de los botones
    in estado_anterior, PINB

    ; Configurar Timer0 para interrupción cada 1s
    ldi r16, (1 << CS02) | (1 << CS00)
    out TCCR0B, r16
    ldi r16, 99
    out TCNT0, r16
    ldi r16, (1 << TOIE0) ; activa la interrupcion por overflow del timer0 
    sts TIMSK0, r16 ; cada vez que llegue a 255 se genera una interrupcion. 


// Bucle Principal
LOOP:
    call DISPLAY_SEG        
    call DISPLAY_SEG_DECENAS  
    rjmp LOOP    


// INTERRUPCIÓN DEL TIMER0
TIMER0:
    push r16 ; guarda el contenido del registro en r16
    in r16, SREG ; se copia el estado del registro de estado en 16 
    push r16 ; guardar r16 con el estado 

    ldi r16, 99 ; el timer0 compienza desde 99 y contara 255 aneste de genrar otro interrupcion
    out TCNT0, r16 ; guarda 99 en TCNT0 , reinicia el timer0 para que empiece a contar desde 99 otravez 
    sbi TIFR0, TOV0 ;  limpia la bandera de desbordamiento TOV0 en TIFR0 para que la siguiente interrupción se pueda generar.

    inc cont1s ; incrementa que cuenta cada 10ms

    cpi cont1s, 100 ; comparar cont1s conm 100 si es menor des 100  significa que no ha pasado 1 segundo.
    brne END_ISR ; Si cont1s no es igual 100, salta a END_ISR (termina la interrupción sin hacer más cambios).

    clr cont1s ; Reinicia cont1s a 0 después de contar 100 interrupciones de 10ms.
    inc cont_disp1  ; Incrementa cont_disp1, que cuenta las unidades de segundos en el display.

    cpi cont_disp1, 10 ; Compara cont_disp1 con 10 (significa que llegó a 10 segundos).
    brne END_ISR ; Si cont_disp1 < 10, termina la interrupción.
    clr cont_disp1 ; Si cont_disp1 llegó a 10, se reinicia a 0.
    inc cont_disp2 ;  Se incrementa cont_disp2, que cuenta las decenas de segundos.
	
    cpi cont_disp2, 6  ; Compara cont_disp2 con 6 (lo que indica 60 segundos).
    brne END_ISR ; Si cont_disp2 < 6, termina la interrupción.
    clr cont_disp2 ; Si cont_disp2 son iguales a 6, se reinicia el contador a 0.

END_ISR:
    pop r16 ; Restaura el valor original de r16 desde la pila.
    out SREG, r16 ; Restaura el estado del registro SREG, preservando las banderas de estado.
    pop r16 ; Recupera r16 original
    reti ; Retorna de la interrupcion 


// INTERRUPCIÓN PARA PUSHBUTTONS CONTADOR BINARIO 4 BITS
ISR_PCINT0:
	; Guardar el estado de los registros antes de modificarlos.
    push r16
    in r16, SREG
    push r16

    ; Leer estado actual de botones
    in r18, PINB   ; almacena el estado actual de los botones PB3 y PB4.

    ; Detectar flancos de cambio en PB3 (Incremento)
	; Detecta cambios en cualquier botón, ya que XOR da 1 solo cuando los valores son diferentes.
    eor r18, estado_anterior ; operacion XOR entre r18 (estado actual de los botones) y estado_anterior (estado guardado de la última interrupción
    sbrs r18, PB3    ; Si no hubo cambio en PB3, salta la siguiente instrucción.
    rjmp revisar_PB4    ; Si PB3 no cambió, salta directamente a verificar PB4.

    sbic PINB, PB3  ; Verifica si PB3 está en alto 1.
    rjmp revisar_PB4  ; Si el botón no fue presionado, salta directamente a verificar PB4.

    ; Incrementar contador
    inc contador ; Incrementa en 1 el valor del contador.
    andi contador, 0x0F  ; Asegurar que el contador no exceda 15
    rjmp SALIR_ISR ; Salta directamente a SALIR_ISR para evitar seguir verificando PB4.

revisar_PB4:
    ; Detectar flancos de cambio en PB4 (Decremento)
    sbrs r18, PB4  ; Revisa si hubo un cambio en PB4 usando r18 (resultado del XOR entre el estado actual y el anterior).
    rjmp SALIR_ISR ; Si PB4 no cambió, salta directamente a SALIR_ISR, lo que evita ejecutar la lógica de decremen

    sbic PINB, PB4  ; Lee el estado actual de PB4.
    rjmp SALIR_ISR ; Si PB4 no está en 0 (presionado), salta a SALIR_ISR y evita ejecutar el decremento.

    ; Decrementar contador
    dec contador   ; Decrementa el valor del contador en 1.
    cpi contador, 255  ; Si el contador es 255 (bajo cero), reiniciar a 15
    brne SALIR_ISR ; Si el contador NO es 255, continúa con SALIR_ISR sin hacer más cambios.
    ldi contador, 15 ; Carga 15 en el contador para que cuando baje de 0, pase a 15 (manteniendo un contador cíclico de 4 bits).

SALIR_ISR:
    ; Actualizar estado anterior de los botones
    in estado_anterior, PINB  

    ; Mostrar valor del contador en los LEDs
    out PORTC, contador ; Envía el valor del contador a los LEDs (PC0 - PC3).

    ; Limpiar la bandera de interrupción PCINT0
    ldi r16, (1 << PCIF0) ; Carga en r16 el valor para limpiar la bandera de interrupción PCIF0.
    out PCIFR, r16 ; Esto reinicia la bandera de interrupción y permite nuevas interrupciones

    pop r16 ; Restaura r16 desde la pila.
    out SREG, r16 ; Restaura el estado del SREG para que el programa continue
    pop r16 ; Restaura el valor original de r16 antes de la interrupción.

    reti ; Retorna de la interrupción, permitiendo que el programa principal siga ejecutánd


/// MOSTRAR UNIDADES (PB1)
DISPLAY_SEG:
    cbi PORTB, PB0   ; Apaga el display de decenas asegurándose de que PB0 esté en 0.
    sbi PORTB, PB1  ; Enciende el display de unidades activando PB1.

    mov r18, cont_disp1 ; Copia el valor de cont_disp1 en r18. representa las unidades de segundos (de 0 a 9).
    ldi ZH, HIGH(TABLA << 1) ; Carga en ZH la parte alta de la dirección de TABLA
    ldi ZL, LOW(TABLA << 1) ; Carga en ZL la parte baja de la dirección de TABLA.
    add ZL, r18
    lpm r18, Z; Carga en r18 el patrón de segmentos del número correspondiente desde TABLA.

    out PORTD, r18  ; Envía el patrón de segmentos almacenado en r18 al puerto PORTD

    rcall DELAY ; Llama a una subrutina de retardo (DELAY).
    ret


//// MOSTRAR DECENAS (PB0)
DISPLAY_SEG_DECENAS:
    cbi PORTB, PB1  ; Apaga el display de unidades asegurándose de que PB1 esté en 0.
    sbi PORTB, PB0  ; Enciende el display de decenas activando PB0.

    mov r18, cont_disp2 ; Copia el valor de cont_disp2 en r18. representa las decenas de segundos (de 0 a 5).
    ldi ZH, HIGH(TABLA << 1)
    ldi ZL, LOW(TABLA << 1)
    add ZL, r18
    lpm r18, Z

    out PORTD, r18  

    rcall DELAY
    ret


// RETARDO PARA MULTIPLEXADO
DELAY:
    ldi r18, 255 ; Carga el valor 255 en r18
RET1:
    ldi r19, 255 ; Carga el valor 255 en r19.
RET2:
    dec r19 ; Decrementa r19 en 1.
    brne RET2 ; Si r19 no ha llegado a 0, repite el bucle.
    dec r18 ; Decrementa r18 en 1.
    brne RET1 ; Si r18 no ha llegado a 0, repite el ciclo externo.
    ret
