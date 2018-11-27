
section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0
  %define input_err   1
  %define output_err  2
  %define unknown_err 3

  %define ro_mode 0
  %define wo_mode 1
  %define rw_mode 2
  %define creat_mode 0100

  %define buff_sz 1000

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
section .text
  global open_file, close_file

  ; Apertura de archivo
  ; Requiere puntero al nombre del archivo en EBX
  ; Requiere modo de apertura en el tope de la pila
  ; Asegura  descriptor de archivo en EAX
  open_file:
    pop EDX   ; Guardamos la direccion de retorno en EDX

    mov EAX, 5; sys_open
    ; Ya tenemos el puntero al nombre del archivo almacenado en EBX
    pop ECX   ; Establecemos el modo de apertura
    int 0x80  ; Interrupcion al SO

    push EDX  ; Reestablecemos la direccion de retorno
    ret       ; Volvemos al punto anterior de ejecucion

  ; Cierre de archivo
  ; Requiere el descriptor del archivo en el tope de la pila
  ; Asegura  archivo cerrado
  close_file:
    mov EAX, 6; sys_close
    pop EBX   ; Descriptor del archivo en tope de pila
    int 0x80
section .data

  description_file db ".desc.txt",0x0; Nombre del archivo que contiene el mensaje de ayuda

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    ; Abrimos el archivo que contiene el mensaje de ayuda
    mov EBX, description_file
    push ro_mode
    call open_file
    mov EBX, EAX  ; Guardamos el descriptor del archivo en EBX

    ; Leemos el mensaje de ayuda
    mov EAX, 3       ; sys_read
    mov ECX, buffer  ;
    mov EDX, buff_sz ;
    int 0x80

    ; Imprimimos el mensaje de ayuda
    mov EDX, EAX
    mov EAX, 4      ; sys_write
    mov EBX, stdout
    mov ECX, buffer
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit
%include "const.asm"
%include "exit.asm"
%include "file.asm"
%include "parser.asm"
%include "toString.asm"
%include "help.asm"

section .text
  global _start

  _start:
    pop EAX; Guardo argc en EAX
    pop EBX; Descarto el puntero a argv[0]

    ; No recibimos ningun argumento de entrada
    ; Leemos de stdin e imprimimos en stdout
    cmp EAX, 1
      je  no_arg

    ; Recibimos dos argumentos de entrada
    ; Leemos del primer archivo e imprimimos el resultado en el segundo
    cmp EAX, 3
      je dos_arg

    ; Recibimos un solo argumento de entrada
    ; Veamos si nos pidieron imprimir la ayuda o procesar un archivo
    cmp EAX, 2
    pop EBX; Recuperamos el puntero a argv[1]

    ; Verificamos el formato del arg de entrada (Help, archivo o error)
    mov dl, BYTE [EBX]
    cmp dl, 0x2d; Comparamos el primer caracter del argumento con '-'
      ; Si el argumento no inicia con '-', es un archivo
      jne un_arg

    ; Si estamos aca, el argumento inicia con '-'
    mov dl, BYTE [EBX+1]
    cmp dl, 0x68; Comparamos el segundo caracter del argumento con 'h'
      push unknown_err; Ponemos un codigo de error desconocido en el tope de la pila
      jne exit

    mov dl, BYTE [EBX+2]
    cmp dl, 0x0; Verificamos si el argumento termino, o hay algo mas
      je  print_help
      jne exit

;############################
;     Rutinas Auxiliares    #
;############################
  ; Establecimiento de archivos sin argumentos de entrada
  no_arg:
    mov [in_file], BYTE stdin
    mov [out_file], BYTE stdout

    jmp parse


  ; Establecimiento de archivos con un solo argumento
  ; Requiere puntero al nombre del archivo en EBX
  un_arg:
    push ro_mode
    call open_file                ; Abrimos el archivo en solo lectura
    mov [in_file], EAX         ; Guardamos el descriptor del archivo de entrada
    mov [out_file], BYTE stdout; Establecemos la salida como stdout

    jmp parse


  ; Establecimiento de archivos con dos argumentos de entrada
  dos_arg:
    pop  EBX; Recupero el puntero al nombre del primer archivo
    push ro_mode
    call open_file
    mov  [in_file], EAX

    pop  EBX; Recupero el puntero  al nombre del segundo archivo
    push rw_mode
    call open_file
    mov  [out_file], EAX

    jmp parse
section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 4; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 4; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 4; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 4; Reservo 4 bytes para el contador de parrafos

  soy_palabra resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

section .text
  global parse, parse_stdin

  ; Cuenta la cantidad de caracteres, blancos, lineas y parrafos del archivo de entrada
  ; Requiere descriptor de archivo de entrada en input_file
  ; Requiere descriptor de archivo de salida en output_file
  parse:
    ; Inicializo los contadores en cero
    mov [cnt_letra],   BYTE 0
    mov [cnt_palabra], BYTE 0
    mov [cnt_linea],   BYTE 0
    mov [cnt_parrafo], BYTE 0

    ; Pongo los flags en False (0)
    mov [soy_palabra], BYTE false
    mov [soy_parrafo], BYTE false

    leer:
      ; Leo una porcion del archivo y la almaceno en el buffer
      mov EAX, 3            ; sys_read
      mov EBX, [in_file]    ; Descriptor del archivo a leer
      mov ECX, buffer       ; Buffer para almacenar los caracteres leidos
      mov EDX, buff_sz      ; Cantidad de caracteres que entran en el buffer
      int 0x80              ; Interrupcion al SO

      cmp EAX, 0            ; Si ya no lei caracteres, llegue al fin de archivo
        je toString         ; Imprimo los resultados del analisis del archivo

      push EAX              ; Guardo la cantidad de caracteres leidos en la pila
      mov  EAX, 0           ; Pongo el offset del buffer en cero

    analizar_buffer:
      ; Cuento la cantidad de caracteres, blancos y \n del buffer
      ; Utilizamos el registro EAX como offset dentro del buffer
      ; Utilizamos el registro ECX como auxiliar para los contadores
      mov DL, [buffer+EAX] ; Guardo el i-esimo caracter del buffer en DL

      ; Analizo por fin de linea
      cmp DL, 0x0   ; Llegue al fin de archivo?
        je toString

      ; Si el caracter es menor que 'A', no es una letra
      cmp DL, 0x41
        jl no_es_letra

      ; Si el caracter es menor o igual a 'Z', entonces es una letra
      cmp DL, 0x5A
        jle es_letra

      ; Si el caracter es menor a 'a', no es una letra
      cmp DL, 0x61
        jl no_es_letra

      ; Si el caracter es menor o igual a 'z', es una letra
      cmp DL, 0x7A
        jle es_letra

      jmp no_es_letra

    ; Reviso si tengo que seguir analizando el buffer actual, o leer otra porcion del archivo
    continuar:
      add EAX, 1            ; Incremento el offset del buffer en 1
      pop EDX               ; Recupero la cantidad de caracteres leidos del archivo
      cmp EDX, EAX          ; Comparo offset y cant leidos
      push EDX              ; Guardo (de nuevo) cantidad de caracteres leidos
        je  leer            ; Si EDX == EAX, ya lei el buffer entero, entonces tengo que leer otra porcion del archivo
        jg  analizar_buffer ; Sino, si cant_leidos > offset, sigo analiando el buffer que ya tengo leido



  ; Llego aca cuando lei una letra
  es_letra:
    ; Incrementamos el contador de letras
    mov ECX, [cnt_letra]
    add ECX, 1
    mov [cnt_letra], ECX

    ; Verificamos si hay que incrementar el contador de palabras
    jmp comprobar_si_sumo_palabra

  ; Verificamos si hay que incrementar el contador de palabras
  ; Llego aca con una letra leida
  comprobar_si_sumo_palabra:
    ; Si aun estoy en una palabra, no incremento el contador
    cmp [soy_palabra], BYTE true
      je comprobar_si_sumo_parrafo

    ; Incrementamos el contador de palabras
    mov ECX, [cnt_palabra]
    add ECX, 1
    mov [cnt_palabra], ECX

    ; Empezamos a leer otra palabra, por lo que ponemos el flag en true
    mov [soy_palabra], BYTE true
    jmp comprobar_si_sumo_parrafo

  ; Verificamos si hay que incrementar el contador de parrafos
  ; Llego aca con una letra leida
  comprobar_si_sumo_parrafo:
    ; Si aun estoy dentro de un parrafo, no debo incrementar el contador
    cmp [soy_parrafo], BYTE true
      je continuar

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp continuar


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp continuar

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp continuar
section .data

	;Estos son textos para imprimir al final
	letras db "Letras: "
	letras_len equ $- letras

	palabras db " Palabras: "
	palabras_len equ $- palabras

	lineas db " Lineas: "
	lineas_len equ $- lineas

	parrafos db " Parrafos: "
	parrafos_len equ $- parrafos

	entr db 0xa

section .bss

	;Buffers para los contadores (luego imprimimos estos)
	buffer_letras resb 8  ; Buffer de 16 bytes para el contador de letras
	buffer_palabras resb 8; Buffer de 16 bytes para el contrador de palabras
	buffer_lineas resb 8  ; Buffer de 16 bytes para el contador de lineas
	buffer_parrafos resb 8; Buffer de 16 bytes para el contador de parrafos

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de EAX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en EAX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en EAX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en EAX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en EAX la direccion cant_parrafos
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_parrafos  ;ESI va a mantener la direccion del buffer_parrafos
		call obtener_string	      ;obtengo el string y lo guardo en buffer_parrafos

		;imprimimos todos los buffers
		call imprimir_buffers
		jmp exit

	obtener_string:
		mov EDX, 0 	;Esto es para la division porque se concatena (DX:AX). DX se modifica, por eso lo reseteo en cada iteracion
		mov ECX, 10	;divisor para obtener el mod de los numeros

		;div divide AX por el parametro
		div ECX	; AX queda el resultado, en DX queda el resto

		push EDX ;pusheo el resto a la pila para que me quede en orden al sacarlo

		inc EBX
		cmp EAX, 0 ;si AX es 0 entonces no hay mas digitos
		jne obtener_string

		jmp guardar_en_buffer

	guardar_en_buffer:
		pop EDX	;guardo en DX el digito mas significativo que queda
		add EDX, 0x30 ;lo paso a ASCII

		mov BYTE [ESI], DL ;guardo en el buffer correspondiente el digito

		inc ESI		   ;aumento en 1 la direccion (para seguir concatenando)
		dec EBX		   ; 1 digito menos
		cmp EBX, 0	   ;si no tengo mas digitos entonces termine
		jne guardar_en_buffer

		ret

	imprimir_buffers:
		;imprimimos "Letras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, letras
		mov EDX, letras_len
		int 0x80

		;imprimimos la cantidad de letras
		mov EAX, 4	        ;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_letras
		mov EDX, 8
		int 0x80

		;imprimimos " Palabras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, palabras
		mov EDX, palabras_len
		int 0x80

		;imprimimos la cantidad de palabras
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_palabras
		mov EDX, 8
		int 0x80

		;imprimimos " Lineas:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, lineas
		mov EDX, lineas_len
		int 0x80

		;imprimimos la cantidad de lineas
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_lineas
		mov EDX, 8
		int 0x80

		;imprimimos " Parrafos:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, parrafos
		mov EDX, parrafos_len
		int 0x80

		;imprimimos la cantidad de parrafos
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_parrafos
		mov EDX, 8
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0
  %define input_err   1
  %define output_err  2
  %define unknown_err 3

  %define ro_mode 0
  %define wo_mode 1
  %define rw_mode 2
  %define creat_mode 0100

  %define buff_sz 1000

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
section .text
  global open_file, close_file

  ; Apertura de archivo
  ; Requiere puntero al nombre del archivo en EBX
  ; Requiere modo de apertura en el tope de la pila
  ; Asegura  descriptor de archivo en EAX
  open_file:
    pop EDX   ; Guardamos la direccion de retorno en EDX

    mov EAX, 5; sys_open
    ; Ya tenemos el puntero al nombre del archivo almacenado en EBX
    pop ECX   ; Establecemos el modo de apertura
    int 0x80  ; Interrupcion al SO

    push EDX  ; Reestablecemos la direccion de retorno
    ret       ; Volvemos al punto anterior de ejecucion

  ; Cierre de archivo
  ; Requiere el descriptor del archivo en el tope de la pila
  ; Asegura  archivo cerrado
  close_file:
    mov EAX, 6; sys_close
    pop EBX   ; Descriptor del archivo en tope de pila
    int 0x80
section .data

  description_file db ".desc.txt",0x0; Nombre del archivo que contiene el mensaje de ayuda

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    ; Abrimos el archivo que contiene el mensaje de ayuda
    mov EBX, description_file
    push ro_mode
    call open_file
    mov EBX, EAX  ; Guardamos el descriptor del archivo en EBX

    ; Leemos el mensaje de ayuda
    mov EAX, 3       ; sys_read
    mov ECX, buffer  ;
    mov EDX, buff_sz ;
    int 0x80

    ; Imprimimos el mensaje de ayuda
    mov EDX, EAX
    mov EAX, 4      ; sys_write
    mov EBX, stdout
    mov ECX, buffer
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit
%include "const.asm"
%include "exit.asm"
%include "file.asm"
%include "parser.asm"
%include "toString.asm"
%include "help.asm"

section .text
  global _start

  _start:
    pop EAX; Guardo argc en EAX
    pop EBX; Descarto el puntero a argv[0]

    ; No recibimos ningun argumento de entrada
    ; Leemos de stdin e imprimimos en stdout
    cmp EAX, 1
      je  no_arg

    ; Recibimos dos argumentos de entrada
    ; Leemos del primer archivo e imprimimos el resultado en el segundo
    cmp EAX, 3
      je dos_arg

    ; Recibimos un solo argumento de entrada
    ; Veamos si nos pidieron imprimir la ayuda o procesar un archivo
    cmp EAX, 2
    pop EBX; Recuperamos el puntero a argv[1]

    ; Verificamos el formato del arg de entrada (Help, archivo o error)
    mov dl, BYTE [EBX]
    cmp dl, 0x2d; Comparamos el primer caracter del argumento con '-'
      ; Si el argumento no inicia con '-', es un archivo
      jne un_arg

    ; Si estamos aca, el argumento inicia con '-'
    mov dl, BYTE [EBX+1]
    cmp dl, 0x68; Comparamos el segundo caracter del argumento con 'h'
      push unknown_err; Ponemos un codigo de error desconocido en el tope de la pila
      jne exit

    mov dl, BYTE [EBX+2]
    cmp dl, 0x0; Verificamos si el argumento termino, o hay algo mas
      je  print_help
      jne exit

;############################
;     Rutinas Auxiliares    #
;############################
  ; Establecimiento de archivos sin argumentos de entrada
  no_arg:
    mov [in_file], BYTE stdin
    mov [out_file], BYTE stdout

    jmp parse


  ; Establecimiento de archivos con un solo argumento
  ; Requiere puntero al nombre del archivo en EBX
  un_arg:
    push ro_mode
    call open_file                ; Abrimos el archivo en solo lectura
    mov [in_file], EAX         ; Guardamos el descriptor del archivo de entrada
    mov [out_file], BYTE stdout; Establecemos la salida como stdout

    jmp parse


  ; Establecimiento de archivos con dos argumentos de entrada
  dos_arg:
    pop  EBX; Recupero el puntero al nombre del primer archivo
    push ro_mode
    call open_file
    mov  [in_file], EAX

    pop  EBX; Recupero el puntero  al nombre del segundo archivo
    push rw_mode
    call open_file
    mov  [out_file], EAX

    jmp parse
section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 4; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 4; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 4; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 4; Reservo 4 bytes para el contador de parrafos

  soy_palabra resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

section .text
  global parse, parse_stdin

  ; Cuenta la cantidad de caracteres, blancos, lineas y parrafos del archivo de entrada
  ; Requiere descriptor de archivo de entrada en input_file
  ; Requiere descriptor de archivo de salida en output_file
  parse:
    ; Inicializo los contadores en cero
    mov [cnt_letra],   BYTE 0
    mov [cnt_palabra], BYTE 0
    mov [cnt_linea],   BYTE 0
    mov [cnt_parrafo], BYTE 0

    ; Pongo los flags en False (0)
    mov [soy_palabra], BYTE false
    mov [soy_parrafo], BYTE false

    leer:
      ; Leo una porcion del archivo y la almaceno en el buffer
      mov EAX, 3            ; sys_read
      mov EBX, [in_file]    ; Descriptor del archivo a leer
      mov ECX, buffer       ; Buffer para almacenar los caracteres leidos
      mov EDX, buff_sz      ; Cantidad de caracteres que entran en el buffer
      int 0x80              ; Interrupcion al SO

      cmp EAX, 0            ; Si ya no lei caracteres, llegue al fin de archivo
        je toString         ; Imprimo los resultados del analisis del archivo

      push EAX              ; Guardo la cantidad de caracteres leidos en la pila
      mov  EAX, 0           ; Pongo el offset del buffer en cero

    analizar_buffer:
      ; Cuento la cantidad de caracteres, blancos y \n del buffer
      ; Utilizamos el registro EAX como offset dentro del buffer
      ; Utilizamos el registro ECX como auxiliar para los contadores
      mov DL, [buffer+EAX] ; Guardo el i-esimo caracter del buffer en DL

      ; Analizo por fin de linea
      cmp DL, 0x0   ; Llegue al fin de archivo?
        je toString

      ; Si el caracter es menor que 'A', no es una letra
      cmp DL, 0x41
        jl no_es_letra

      ; Si el caracter es menor o igual a 'Z', entonces es una letra
      cmp DL, 0x5A
        jle es_letra

      ; Si el caracter es menor a 'a', no es una letra
      cmp DL, 0x61
        jl no_es_letra

      ; Si el caracter es menor o igual a 'z', es una letra
      cmp DL, 0x7A
        jle es_letra

      jmp no_es_letra

    ; Reviso si tengo que seguir analizando el buffer actual, o leer otra porcion del archivo
    continuar:
      add EAX, 1            ; Incremento el offset del buffer en 1
      pop EDX               ; Recupero la cantidad de caracteres leidos del archivo
      cmp EDX, EAX          ; Comparo offset y cant leidos
      push EDX              ; Guardo (de nuevo) cantidad de caracteres leidos
        je  leer            ; Si EDX == EAX, ya lei el buffer entero, entonces tengo que leer otra porcion del archivo
        jg  analizar_buffer ; Sino, si cant_leidos > offset, sigo analiando el buffer que ya tengo leido



  ; Llego aca cuando lei una letra
  es_letra:
    ; Incrementamos el contador de letras
    mov ECX, [cnt_letra]
    add ECX, 1
    mov [cnt_letra], ECX

    ; Verificamos si hay que incrementar el contador de palabras
    jmp comprobar_si_sumo_palabra

  ; Verificamos si hay que incrementar el contador de palabras
  ; Llego aca con una letra leida
  comprobar_si_sumo_palabra:
    ; Si aun estoy en una palabra, no incremento el contador
    cmp [soy_palabra], BYTE true
      je comprobar_si_sumo_parrafo

    ; Incrementamos el contador de palabras
    mov ECX, [cnt_palabra]
    add ECX, 1
    mov [cnt_palabra], ECX

    ; Empezamos a leer otra palabra, por lo que ponemos el flag en true
    mov [soy_palabra], BYTE true
    jmp comprobar_si_sumo_parrafo

  ; Verificamos si hay que incrementar el contador de parrafos
  ; Llego aca con una letra leida
  comprobar_si_sumo_parrafo:
    ; Si aun estoy dentro de un parrafo, no debo incrementar el contador
    cmp [soy_parrafo], BYTE true
      je continuar

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp continuar


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp continuar

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp continuar
section .data

	;Estos son textos para imprimir al final
	letras db "Letras: "
	letras_len equ $- letras

	palabras db " Palabras: "
	palabras_len equ $- palabras

	lineas db " Lineas: "
	lineas_len equ $- lineas

	parrafos db " Parrafos: "
	parrafos_len equ $- parrafos

	entr db 0xa

section .bss

	;Buffers para los contadores (luego imprimimos estos)
	buffer_letras resb 8  ; Buffer de 16 bytes para el contador de letras
	buffer_palabras resb 8; Buffer de 16 bytes para el contrador de palabras
	buffer_lineas resb 8  ; Buffer de 16 bytes para el contador de lineas
	buffer_parrafos resb 8; Buffer de 16 bytes para el contador de parrafos

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de EAX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en EAX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en EAX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en EAX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en EAX la direccion cant_parrafos
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_parrafos  ;ESI va a mantener la direccion del buffer_parrafos
		call obtener_string	      ;obtengo el string y lo guardo en buffer_parrafos

		;imprimimos todos los buffers
		call imprimir_buffers
		jmp exit

	obtener_string:
		mov EDX, 0 	;Esto es para la division porque se concatena (DX:AX). DX se modifica, por eso lo reseteo en cada iteracion
		mov ECX, 10	;divisor para obtener el mod de los numeros

		;div divide AX por el parametro
		div ECX	; AX queda el resultado, en DX queda el resto

		push EDX ;pusheo el resto a la pila para que me quede en orden al sacarlo

		inc EBX
		cmp EAX, 0 ;si AX es 0 entonces no hay mas digitos
		jne obtener_string

		jmp guardar_en_buffer

	guardar_en_buffer:
		pop EDX	;guardo en DX el digito mas significativo que queda
		add EDX, 0x30 ;lo paso a ASCII

		mov BYTE [ESI], DL ;guardo en el buffer correspondiente el digito

		inc ESI		   ;aumento en 1 la direccion (para seguir concatenando)
		dec EBX		   ; 1 digito menos
		cmp EBX, 0	   ;si no tengo mas digitos entonces termine
		jne guardar_en_buffer

		ret

	imprimir_buffers:
		;imprimimos "Letras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, letras
		mov EDX, letras_len
		int 0x80

		;imprimimos la cantidad de letras
		mov EAX, 4	        ;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_letras
		mov EDX, 8
		int 0x80

		;imprimimos " Palabras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, palabras
		mov EDX, palabras_len
		int 0x80

		;imprimimos la cantidad de palabras
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_palabras
		mov EDX, 8
		int 0x80

		;imprimimos " Lineas:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, lineas
		mov EDX, lineas_len
		int 0x80

		;imprimimos la cantidad de lineas
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_lineas
		mov EDX, 8
		int 0x80

		;imprimimos " Parrafos:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, parrafos
		mov EDX, parrafos_len
		int 0x80

		;imprimimos la cantidad de parrafos
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_parrafos
		mov EDX, 8
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0
  %define input_err   1
  %define output_err  2
  %define unknown_err 3

  %define ro_mode 0
  %define wo_mode 1
  %define rw_mode 2
  %define creat_mode 0100

  %define buff_sz 1000

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
section .text
  global open_file, close_file

  ; Apertura de archivo
  ; Requiere puntero al nombre del archivo en EBX
  ; Requiere modo de apertura en el tope de la pila
  ; Asegura  descriptor de archivo en EAX
  open_file:
    pop EDX   ; Guardamos la direccion de retorno en EDX

    mov EAX, 5; sys_open
    ; Ya tenemos el puntero al nombre del archivo almacenado en EBX
    pop ECX   ; Establecemos el modo de apertura
    int 0x80  ; Interrupcion al SO

    push EDX  ; Reestablecemos la direccion de retorno
    ret       ; Volvemos al punto anterior de ejecucion

  ; Cierre de archivo
  ; Requiere el descriptor del archivo en el tope de la pila
  ; Asegura  archivo cerrado
  close_file:
    mov EAX, 6; sys_close
    pop EBX   ; Descriptor del archivo en tope de pila
    int 0x80
section .data

  description_file db ".desc.txt",0x0; Nombre del archivo que contiene el mensaje de ayuda

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    ; Abrimos el archivo que contiene el mensaje de ayuda
    mov EBX, description_file
    push ro_mode
    call open_file
    mov EBX, EAX  ; Guardamos el descriptor del archivo en EBX

    ; Leemos el mensaje de ayuda
    mov EAX, 3       ; sys_read
    mov ECX, buffer  ;
    mov EDX, buff_sz ;
    int 0x80

    ; Imprimimos el mensaje de ayuda
    mov EDX, EAX
    mov EAX, 4      ; sys_write
    mov EBX, stdout
    mov ECX, buffer
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit
%include "const.asm"
%include "exit.asm"
%include "file.asm"
%include "parser.asm"
%include "toString.asm"
%include "help.asm"

section .text
  global _start

  _start:
    pop EAX; Guardo argc en EAX
    pop EBX; Descarto el puntero a argv[0]

    ; No recibimos ningun argumento de entrada
    ; Leemos de stdin e imprimimos en stdout
    cmp EAX, 1
      je  no_arg

    ; Recibimos dos argumentos de entrada
    ; Leemos del primer archivo e imprimimos el resultado en el segundo
    cmp EAX, 3
      je dos_arg

    ; Recibimos un solo argumento de entrada
    ; Veamos si nos pidieron imprimir la ayuda o procesar un archivo
    cmp EAX, 2
    pop EBX; Recuperamos el puntero a argv[1]

    ; Verificamos el formato del arg de entrada (Help, archivo o error)
    mov dl, BYTE [EBX]
    cmp dl, 0x2d; Comparamos el primer caracter del argumento con '-'
      ; Si el argumento no inicia con '-', es un archivo
      jne un_arg

    ; Si estamos aca, el argumento inicia con '-'
    mov dl, BYTE [EBX+1]
    cmp dl, 0x68; Comparamos el segundo caracter del argumento con 'h'
      push unknown_err; Ponemos un codigo de error desconocido en el tope de la pila
      jne exit

    mov dl, BYTE [EBX+2]
    cmp dl, 0x0; Verificamos si el argumento termino, o hay algo mas
      je  print_help
      jne exit

;############################
;     Rutinas Auxiliares    #
;############################
  ; Establecimiento de archivos sin argumentos de entrada
  no_arg:
    mov [in_file], BYTE stdin
    mov [out_file], BYTE stdout

    jmp parse


  ; Establecimiento de archivos con un solo argumento
  ; Requiere puntero al nombre del archivo en EBX
  un_arg:
    push ro_mode
    call open_file                ; Abrimos el archivo en solo lectura
    mov [in_file], EAX         ; Guardamos el descriptor del archivo de entrada
    mov [out_file], BYTE stdout; Establecemos la salida como stdout

    jmp parse


  ; Establecimiento de archivos con dos argumentos de entrada
  dos_arg:
    pop  EBX; Recupero el puntero al nombre del primer archivo
    push ro_mode
    call open_file
    mov  [in_file], EAX

    pop  EBX; Recupero el puntero  al nombre del segundo archivo
    push rw_mode
    call open_file
    mov  [out_file], EAX

    jmp parse
section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 4; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 4; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 4; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 4; Reservo 4 bytes para el contador de parrafos

  soy_palabra resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

section .text
  global parse, parse_stdin

  ; Cuenta la cantidad de caracteres, blancos, lineas y parrafos del archivo de entrada
  ; Requiere descriptor de archivo de entrada en input_file
  ; Requiere descriptor de archivo de salida en output_file
  parse:
    ; Inicializo los contadores en cero
    mov [cnt_letra],   BYTE 0
    mov [cnt_palabra], BYTE 0
    mov [cnt_linea],   BYTE 0
    mov [cnt_parrafo], BYTE 0

    ; Pongo los flags en False (0)
    mov [soy_palabra], BYTE false
    mov [soy_parrafo], BYTE false

    leer:
      ; Leo una porcion del archivo y la almaceno en el buffer
      mov EAX, 3            ; sys_read
      mov EBX, [in_file]    ; Descriptor del archivo a leer
      mov ECX, buffer       ; Buffer para almacenar los caracteres leidos
      mov EDX, buff_sz      ; Cantidad de caracteres que entran en el buffer
      int 0x80              ; Interrupcion al SO

      cmp EAX, 0            ; Si ya no lei caracteres, llegue al fin de archivo
        je toString         ; Imprimo los resultados del analisis del archivo

      push EAX              ; Guardo la cantidad de caracteres leidos en la pila
      mov  EAX, 0           ; Pongo el offset del buffer en cero

    analizar_buffer:
      ; Cuento la cantidad de caracteres, blancos y \n del buffer
      ; Utilizamos el registro EAX como offset dentro del buffer
      ; Utilizamos el registro ECX como auxiliar para los contadores
      mov DL, [buffer+EAX] ; Guardo el i-esimo caracter del buffer en DL

      ; Analizo por fin de linea
      cmp DL, 0x0   ; Llegue al fin de archivo?
        je toString

      ; Si el caracter es menor que 'A', no es una letra
      cmp DL, 0x41
        jl no_es_letra

      ; Si el caracter es menor o igual a 'Z', entonces es una letra
      cmp DL, 0x5A
        jle es_letra

      ; Si el caracter es menor a 'a', no es una letra
      cmp DL, 0x61
        jl no_es_letra

      ; Si el caracter es menor o igual a 'z', es una letra
      cmp DL, 0x7A
        jle es_letra

      jmp no_es_letra

    ; Reviso si tengo que seguir analizando el buffer actual, o leer otra porcion del archivo
    continuar:
      add EAX, 1            ; Incremento el offset del buffer en 1
      pop EDX               ; Recupero la cantidad de caracteres leidos del archivo
      cmp EDX, EAX          ; Comparo offset y cant leidos
      push EDX              ; Guardo (de nuevo) cantidad de caracteres leidos
        je  leer            ; Si EDX == EAX, ya lei el buffer entero, entonces tengo que leer otra porcion del archivo
        jg  analizar_buffer ; Sino, si cant_leidos > offset, sigo analiando el buffer que ya tengo leido



  ; Llego aca cuando lei una letra
  es_letra:
    ; Incrementamos el contador de letras
    mov ECX, [cnt_letra]
    add ECX, 1
    mov [cnt_letra], ECX

    ; Verificamos si hay que incrementar el contador de palabras
    jmp comprobar_si_sumo_palabra

  ; Verificamos si hay que incrementar el contador de palabras
  ; Llego aca con una letra leida
  comprobar_si_sumo_palabra:
    ; Si aun estoy en una palabra, no incremento el contador
    cmp [soy_palabra], BYTE true
      je comprobar_si_sumo_parrafo

    ; Incrementamos el contador de palabras
    mov ECX, [cnt_palabra]
    add ECX, 1
    mov [cnt_palabra], ECX

    ; Empezamos a leer otra palabra, por lo que ponemos el flag en true
    mov [soy_palabra], BYTE true
    jmp comprobar_si_sumo_parrafo

  ; Verificamos si hay que incrementar el contador de parrafos
  ; Llego aca con una letra leida
  comprobar_si_sumo_parrafo:
    ; Si aun estoy dentro de un parrafo, no debo incrementar el contador
    cmp [soy_parrafo], BYTE true
      je continuar

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp continuar


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp continuar

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp continuar
section .data

	;Estos son textos para imprimir al final
	letras db "Letras: "
	letras_len equ $- letras

	palabras db " Palabras: "
	palabras_len equ $- palabras

	lineas db " Lineas: "
	lineas_len equ $- lineas

	parrafos db " Parrafos: "
	parrafos_len equ $- parrafos

	entr db 0xa

section .bss

	;Buffers para los contadores (luego imprimimos estos)
	buffer_letras resb 8  ; Buffer de 16 bytes para el contador de letras
	buffer_palabras resb 8; Buffer de 16 bytes para el contrador de palabras
	buffer_lineas resb 8  ; Buffer de 16 bytes para el contador de lineas
	buffer_parrafos resb 8; Buffer de 16 bytes para el contador de parrafos

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de EAX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en EAX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en EAX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en EAX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en EAX la direccion cant_parrafos
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_parrafos  ;ESI va a mantener la direccion del buffer_parrafos
		call obtener_string	      ;obtengo el string y lo guardo en buffer_parrafos

		;imprimimos todos los buffers
		call imprimir_buffers
		jmp exit

	obtener_string:
		mov EDX, 0 	;Esto es para la division porque se concatena (DX:AX). DX se modifica, por eso lo reseteo en cada iteracion
		mov ECX, 10	;divisor para obtener el mod de los numeros

		;div divide AX por el parametro
		div ECX	; AX queda el resultado, en DX queda el resto

		push EDX ;pusheo el resto a la pila para que me quede en orden al sacarlo

		inc EBX
		cmp EAX, 0 ;si AX es 0 entonces no hay mas digitos
		jne obtener_string

		jmp guardar_en_buffer

	guardar_en_buffer:
		pop EDX	;guardo en DX el digito mas significativo que queda
		add EDX, 0x30 ;lo paso a ASCII

		mov BYTE [ESI], DL ;guardo en el buffer correspondiente el digito

		inc ESI		   ;aumento en 1 la direccion (para seguir concatenando)
		dec EBX		   ; 1 digito menos
		cmp EBX, 0	   ;si no tengo mas digitos entonces termine
		jne guardar_en_buffer

		ret

	imprimir_buffers:
		;imprimimos "Letras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, letras
		mov EDX, letras_len
		int 0x80

		;imprimimos la cantidad de letras
		mov EAX, 4	        ;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_letras
		mov EDX, 8
		int 0x80

		;imprimimos " Palabras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, palabras
		mov EDX, palabras_len
		int 0x80

		;imprimimos la cantidad de palabras
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_palabras
		mov EDX, 8
		int 0x80

		;imprimimos " Lineas:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, lineas
		mov EDX, lineas_len
		int 0x80

		;imprimimos la cantidad de lineas
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_lineas
		mov EDX, 8
		int 0x80

		;imprimimos " Parrafos:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, parrafos
		mov EDX, parrafos_len
		int 0x80

		;imprimimos la cantidad de parrafos
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_parrafos
		mov EDX, 8
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0
  %define input_err   1
  %define output_err  2
  %define unknown_err 3

  %define ro_mode 0
  %define wo_mode 1
  %define rw_mode 2
  %define creat_mode 0100

  %define buff_sz 1000

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
section .text
  global open_file, close_file

  ; Apertura de archivo
  ; Requiere puntero al nombre del archivo en EBX
  ; Requiere modo de apertura en el tope de la pila
  ; Asegura  descriptor de archivo en EAX
  open_file:
    pop EDX   ; Guardamos la direccion de retorno en EDX

    mov EAX, 5; sys_open
    ; Ya tenemos el puntero al nombre del archivo almacenado en EBX
    pop ECX   ; Establecemos el modo de apertura
    int 0x80  ; Interrupcion al SO

    push EDX  ; Reestablecemos la direccion de retorno
    ret       ; Volvemos al punto anterior de ejecucion

  ; Cierre de archivo
  ; Requiere el descriptor del archivo en el tope de la pila
  ; Asegura  archivo cerrado
  close_file:
    mov EAX, 6; sys_close
    pop EBX   ; Descriptor del archivo en tope de pila
    int 0x80
section .data

  description_file db ".desc.txt",0x0; Nombre del archivo que contiene el mensaje de ayuda

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    ; Abrimos el archivo que contiene el mensaje de ayuda
    mov EBX, description_file
    push ro_mode
    call open_file
    mov EBX, EAX  ; Guardamos el descriptor del archivo en EBX

    ; Leemos el mensaje de ayuda
    mov EAX, 3       ; sys_read
    mov ECX, buffer  ;
    mov EDX, buff_sz ;
    int 0x80

    ; Imprimimos el mensaje de ayuda
    mov EDX, EAX
    mov EAX, 4      ; sys_write
    mov EBX, stdout
    mov ECX, buffer
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit
%include "const.asm"
%include "exit.asm"
%include "file.asm"
%include "parser.asm"
%include "toString.asm"
%include "help.asm"

section .text
  global _start

  _start:
    pop EAX; Guardo argc en EAX
    pop EBX; Descarto el puntero a argv[0]

    ; No recibimos ningun argumento de entrada
    ; Leemos de stdin e imprimimos en stdout
    cmp EAX, 1
      je  no_arg

    ; Recibimos dos argumentos de entrada
    ; Leemos del primer archivo e imprimimos el resultado en el segundo
    cmp EAX, 3
      je dos_arg

    ; Recibimos un solo argumento de entrada
    ; Veamos si nos pidieron imprimir la ayuda o procesar un archivo
    cmp EAX, 2
    pop EBX; Recuperamos el puntero a argv[1]

    ; Verificamos el formato del arg de entrada (Help, archivo o error)
    mov dl, BYTE [EBX]
    cmp dl, 0x2d; Comparamos el primer caracter del argumento con '-'
      ; Si el argumento no inicia con '-', es un archivo
      jne un_arg

    ; Si estamos aca, el argumento inicia con '-'
    mov dl, BYTE [EBX+1]
    cmp dl, 0x68; Comparamos el segundo caracter del argumento con 'h'
      push unknown_err; Ponemos un codigo de error desconocido en el tope de la pila
      jne exit

    mov dl, BYTE [EBX+2]
    cmp dl, 0x0; Verificamos si el argumento termino, o hay algo mas
      je  print_help
      jne exit

;############################
;     Rutinas Auxiliares    #
;############################
  ; Establecimiento de archivos sin argumentos de entrada
  no_arg:
    mov [in_file], BYTE stdin
    mov [out_file], BYTE stdout

    jmp parse


  ; Establecimiento de archivos con un solo argumento
  ; Requiere puntero al nombre del archivo en EBX
  un_arg:
    push ro_mode
    call open_file                ; Abrimos el archivo en solo lectura
    mov [in_file], EAX         ; Guardamos el descriptor del archivo de entrada
    mov [out_file], BYTE stdout; Establecemos la salida como stdout

    jmp parse


  ; Establecimiento de archivos con dos argumentos de entrada
  dos_arg:
    pop  EBX; Recupero el puntero al nombre del primer archivo
    push ro_mode
    call open_file
    mov  [in_file], EAX

    pop  EBX; Recupero el puntero  al nombre del segundo archivo
    push rw_mode
    call open_file
    mov  [out_file], EAX

    jmp parse
section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 4; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 4; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 4; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 4; Reservo 4 bytes para el contador de parrafos

  soy_palabra resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

section .text
  global parse, parse_stdin

  ; Cuenta la cantidad de caracteres, blancos, lineas y parrafos del archivo de entrada
  ; Requiere descriptor de archivo de entrada en input_file
  ; Requiere descriptor de archivo de salida en output_file
  parse:
    ; Inicializo los contadores en cero
    mov [cnt_letra],   BYTE 0
    mov [cnt_palabra], BYTE 0
    mov [cnt_linea],   BYTE 0
    mov [cnt_parrafo], BYTE 0

    ; Pongo los flags en False (0)
    mov [soy_palabra], BYTE false
    mov [soy_parrafo], BYTE false

    leer:
      ; Leo una porcion del archivo y la almaceno en el buffer
      mov EAX, 3            ; sys_read
      mov EBX, [in_file]    ; Descriptor del archivo a leer
      mov ECX, buffer       ; Buffer para almacenar los caracteres leidos
      mov EDX, buff_sz      ; Cantidad de caracteres que entran en el buffer
      int 0x80              ; Interrupcion al SO

      cmp EAX, 0            ; Si ya no lei caracteres, llegue al fin de archivo
        je toString         ; Imprimo los resultados del analisis del archivo

      push EAX              ; Guardo la cantidad de caracteres leidos en la pila
      mov  EAX, 0           ; Pongo el offset del buffer en cero

    analizar_buffer:
      ; Cuento la cantidad de caracteres, blancos y \n del buffer
      ; Utilizamos el registro EAX como offset dentro del buffer
      ; Utilizamos el registro ECX como auxiliar para los contadores
      mov DL, [buffer+EAX] ; Guardo el i-esimo caracter del buffer en DL

      ; Analizo por fin de linea
      cmp DL, 0x0   ; Llegue al fin de archivo?
        je toString

      ; Si el caracter es menor que 'A', no es una letra
      cmp DL, 0x41
        jl no_es_letra

      ; Si el caracter es menor o igual a 'Z', entonces es una letra
      cmp DL, 0x5A
        jle es_letra

      ; Si el caracter es menor a 'a', no es una letra
      cmp DL, 0x61
        jl no_es_letra

      ; Si el caracter es menor o igual a 'z', es una letra
      cmp DL, 0x7A
        jle es_letra

      jmp no_es_letra

    ; Reviso si tengo que seguir analizando el buffer actual, o leer otra porcion del archivo
    continuar:
      add EAX, 1            ; Incremento el offset del buffer en 1
      pop EDX               ; Recupero la cantidad de caracteres leidos del archivo
      cmp EDX, EAX          ; Comparo offset y cant leidos
      push EDX              ; Guardo (de nuevo) cantidad de caracteres leidos
        je  leer            ; Si EDX == EAX, ya lei el buffer entero, entonces tengo que leer otra porcion del archivo
        jg  analizar_buffer ; Sino, si cant_leidos > offset, sigo analiando el buffer que ya tengo leido



  ; Llego aca cuando lei una letra
  es_letra:
    ; Incrementamos el contador de letras
    mov ECX, [cnt_letra]
    add ECX, 1
    mov [cnt_letra], ECX

    ; Verificamos si hay que incrementar el contador de palabras
    jmp comprobar_si_sumo_palabra

  ; Verificamos si hay que incrementar el contador de palabras
  ; Llego aca con una letra leida
  comprobar_si_sumo_palabra:
    ; Si aun estoy en una palabra, no incremento el contador
    cmp [soy_palabra], BYTE true
      je comprobar_si_sumo_parrafo

    ; Incrementamos el contador de palabras
    mov ECX, [cnt_palabra]
    add ECX, 1
    mov [cnt_palabra], ECX

    ; Empezamos a leer otra palabra, por lo que ponemos el flag en true
    mov [soy_palabra], BYTE true
    jmp comprobar_si_sumo_parrafo

  ; Verificamos si hay que incrementar el contador de parrafos
  ; Llego aca con una letra leida
  comprobar_si_sumo_parrafo:
    ; Si aun estoy dentro de un parrafo, no debo incrementar el contador
    cmp [soy_parrafo], BYTE true
      je continuar

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp continuar


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp continuar

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp continuar
section .data

	;Estos son textos para imprimir al final
	letras db "Letras: "
	letras_len equ $- letras

	palabras db " Palabras: "
	palabras_len equ $- palabras

	lineas db " Lineas: "
	lineas_len equ $- lineas

	parrafos db " Parrafos: "
	parrafos_len equ $- parrafos

	entr db 0xa

section .bss

	;Buffers para los contadores (luego imprimimos estos)
	buffer_letras resb 8  ; Buffer de 16 bytes para el contador de letras
	buffer_palabras resb 8; Buffer de 16 bytes para el contrador de palabras
	buffer_lineas resb 8  ; Buffer de 16 bytes para el contador de lineas
	buffer_parrafos resb 8; Buffer de 16 bytes para el contador de parrafos

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de EAX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en EAX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en EAX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en EAX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en EAX la direccion cant_parrafos
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_parrafos  ;ESI va a mantener la direccion del buffer_parrafos
		call obtener_string	      ;obtengo el string y lo guardo en buffer_parrafos

		;imprimimos todos los buffers
		call imprimir_buffers
		jmp exit

	obtener_string:
		mov EDX, 0 	;Esto es para la division porque se concatena (DX:AX). DX se modifica, por eso lo reseteo en cada iteracion
		mov ECX, 10	;divisor para obtener el mod de los numeros

		;div divide AX por el parametro
		div ECX	; AX queda el resultado, en DX queda el resto

		push EDX ;pusheo el resto a la pila para que me quede en orden al sacarlo

		inc EBX
		cmp EAX, 0 ;si AX es 0 entonces no hay mas digitos
		jne obtener_string

		jmp guardar_en_buffer

	guardar_en_buffer:
		pop EDX	;guardo en DX el digito mas significativo que queda
		add EDX, 0x30 ;lo paso a ASCII

		mov BYTE [ESI], DL ;guardo en el buffer correspondiente el digito

		inc ESI		   ;aumento en 1 la direccion (para seguir concatenando)
		dec EBX		   ; 1 digito menos
		cmp EBX, 0	   ;si no tengo mas digitos entonces termine
		jne guardar_en_buffer

		ret

	imprimir_buffers:
		;imprimimos "Letras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, letras
		mov EDX, letras_len
		int 0x80

		;imprimimos la cantidad de letras
		mov EAX, 4	        ;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_letras
		mov EDX, 8
		int 0x80

		;imprimimos " Palabras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, palabras
		mov EDX, palabras_len
		int 0x80

		;imprimimos la cantidad de palabras
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_palabras
		mov EDX, 8
		int 0x80

		;imprimimos " Lineas:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, lineas
		mov EDX, lineas_len
		int 0x80

		;imprimimos la cantidad de lineas
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_lineas
		mov EDX, 8
		int 0x80

		;imprimimos " Parrafos:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, parrafos
		mov EDX, parrafos_len
		int 0x80

		;imprimimos la cantidad de parrafos
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_parrafos
		mov EDX, 8
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0
  %define input_err   1
  %define output_err  2
  %define unknown_err 3

  %define ro_mode 0
  %define wo_mode 1
  %define rw_mode 2
  %define creat_mode 0100

  %define buff_sz 1000

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
section .text
  global open_file, close_file

  ; Apertura de archivo
  ; Requiere puntero al nombre del archivo en EBX
  ; Requiere modo de apertura en el tope de la pila
  ; Asegura  descriptor de archivo en EAX
  open_file:
    pop EDX   ; Guardamos la direccion de retorno en EDX

    mov EAX, 5; sys_open
    ; Ya tenemos el puntero al nombre del archivo almacenado en EBX
    pop ECX   ; Establecemos el modo de apertura
    int 0x80  ; Interrupcion al SO

    push EDX  ; Reestablecemos la direccion de retorno
    ret       ; Volvemos al punto anterior de ejecucion

  ; Cierre de archivo
  ; Requiere el descriptor del archivo en el tope de la pila
  ; Asegura  archivo cerrado
  close_file:
    mov EAX, 6; sys_close
    pop EBX   ; Descriptor del archivo en tope de pila
    int 0x80
section .data

  description_file db ".desc.txt",0x0; Nombre del archivo que contiene el mensaje de ayuda

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    ; Abrimos el archivo que contiene el mensaje de ayuda
    mov EBX, description_file
    push ro_mode
    call open_file
    mov EBX, EAX  ; Guardamos el descriptor del archivo en EBX

    ; Leemos el mensaje de ayuda
    mov EAX, 3       ; sys_read
    mov ECX, buffer  ;
    mov EDX, buff_sz ;
    int 0x80

    ; Imprimimos el mensaje de ayuda
    mov EDX, EAX
    mov EAX, 4      ; sys_write
    mov EBX, stdout
    mov ECX, buffer
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit
%include "const.asm"
%include "exit.asm"
%include "file.asm"
%include "parser.asm"
%include "toString.asm"
%include "help.asm"

section .text
  global _start

  _start:
    pop EAX; Guardo argc en EAX
    pop EBX; Descarto el puntero a argv[0]

    ; No recibimos ningun argumento de entrada
    ; Leemos de stdin e imprimimos en stdout
    cmp EAX, 1
      je  no_arg

    ; Recibimos dos argumentos de entrada
    ; Leemos del primer archivo e imprimimos el resultado en el segundo
    cmp EAX, 3
      je dos_arg

    ; Recibimos un solo argumento de entrada
    ; Veamos si nos pidieron imprimir la ayuda o procesar un archivo
    cmp EAX, 2
    pop EBX; Recuperamos el puntero a argv[1]

    ; Verificamos el formato del arg de entrada (Help, archivo o error)
    mov dl, BYTE [EBX]
    cmp dl, 0x2d; Comparamos el primer caracter del argumento con '-'
      ; Si el argumento no inicia con '-', es un archivo
      jne un_arg

    ; Si estamos aca, el argumento inicia con '-'
    mov dl, BYTE [EBX+1]
    cmp dl, 0x68; Comparamos el segundo caracter del argumento con 'h'
      push unknown_err; Ponemos un codigo de error desconocido en el tope de la pila
      jne exit

    mov dl, BYTE [EBX+2]
    cmp dl, 0x0; Verificamos si el argumento termino, o hay algo mas
      je  print_help
      jne exit

;############################
;     Rutinas Auxiliares    #
;############################
  ; Establecimiento de archivos sin argumentos de entrada
  no_arg:
    mov [in_file], BYTE stdin
    mov [out_file], BYTE stdout

    jmp parse


  ; Establecimiento de archivos con un solo argumento
  ; Requiere puntero al nombre del archivo en EBX
  un_arg:
    push ro_mode
    call open_file                ; Abrimos el archivo en solo lectura
    mov [in_file], EAX         ; Guardamos el descriptor del archivo de entrada
    mov [out_file], BYTE stdout; Establecemos la salida como stdout

    jmp parse


  ; Establecimiento de archivos con dos argumentos de entrada
  dos_arg:
    pop  EBX; Recupero el puntero al nombre del primer archivo
    push ro_mode
    call open_file
    mov  [in_file], EAX

    pop  EBX; Recupero el puntero  al nombre del segundo archivo
    push rw_mode
    call open_file
    mov  [out_file], EAX

    jmp parse
section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 4; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 4; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 4; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 4; Reservo 4 bytes para el contador de parrafos

  soy_palabra resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

section .text
  global parse, parse_stdin

  ; Cuenta la cantidad de caracteres, blancos, lineas y parrafos del archivo de entrada
  ; Requiere descriptor de archivo de entrada en input_file
  ; Requiere descriptor de archivo de salida en output_file
  parse:
    ; Inicializo los contadores en cero
    mov [cnt_letra],   BYTE 0
    mov [cnt_palabra], BYTE 0
    mov [cnt_linea],   BYTE 0
    mov [cnt_parrafo], BYTE 0

    ; Pongo los flags en False (0)
    mov [soy_palabra], BYTE false
    mov [soy_parrafo], BYTE false

    leer:
      ; Leo una porcion del archivo y la almaceno en el buffer
      mov EAX, 3            ; sys_read
      mov EBX, [in_file]    ; Descriptor del archivo a leer
      mov ECX, buffer       ; Buffer para almacenar los caracteres leidos
      mov EDX, buff_sz      ; Cantidad de caracteres que entran en el buffer
      int 0x80              ; Interrupcion al SO

      cmp EAX, 0            ; Si ya no lei caracteres, llegue al fin de archivo
        je toString         ; Imprimo los resultados del analisis del archivo

      push EAX              ; Guardo la cantidad de caracteres leidos en la pila
      mov  EAX, 0           ; Pongo el offset del buffer en cero

    analizar_buffer:
      ; Cuento la cantidad de caracteres, blancos y \n del buffer
      ; Utilizamos el registro EAX como offset dentro del buffer
      ; Utilizamos el registro ECX como auxiliar para los contadores
      mov DL, [buffer+EAX] ; Guardo el i-esimo caracter del buffer en DL

      ; Analizo por fin de linea
      cmp DL, 0x0   ; Llegue al fin de archivo?
        je toString

      ; Si el caracter es menor que 'A', no es una letra
      cmp DL, 0x41
        jl no_es_letra

      ; Si el caracter es menor o igual a 'Z', entonces es una letra
      cmp DL, 0x5A
        jle es_letra

      ; Si el caracter es menor a 'a', no es una letra
      cmp DL, 0x61
        jl no_es_letra

      ; Si el caracter es menor o igual a 'z', es una letra
      cmp DL, 0x7A
        jle es_letra

      jmp no_es_letra

    ; Reviso si tengo que seguir analizando el buffer actual, o leer otra porcion del archivo
    continuar:
      add EAX, 1            ; Incremento el offset del buffer en 1
      pop EDX               ; Recupero la cantidad de caracteres leidos del archivo
      cmp EDX, EAX          ; Comparo offset y cant leidos
      push EDX              ; Guardo (de nuevo) cantidad de caracteres leidos
        je  leer            ; Si EDX == EAX, ya lei el buffer entero, entonces tengo que leer otra porcion del archivo
        jg  analizar_buffer ; Sino, si cant_leidos > offset, sigo analiando el buffer que ya tengo leido



  ; Llego aca cuando lei una letra
  es_letra:
    ; Incrementamos el contador de letras
    mov ECX, [cnt_letra]
    add ECX, 1
    mov [cnt_letra], ECX

    ; Verificamos si hay que incrementar el contador de palabras
    jmp comprobar_si_sumo_palabra

  ; Verificamos si hay que incrementar el contador de palabras
  ; Llego aca con una letra leida
  comprobar_si_sumo_palabra:
    ; Si aun estoy en una palabra, no incremento el contador
    cmp [soy_palabra], BYTE true
      je comprobar_si_sumo_parrafo

    ; Incrementamos el contador de palabras
    mov ECX, [cnt_palabra]
    add ECX, 1
    mov [cnt_palabra], ECX

    ; Empezamos a leer otra palabra, por lo que ponemos el flag en true
    mov [soy_palabra], BYTE true
    jmp comprobar_si_sumo_parrafo

  ; Verificamos si hay que incrementar el contador de parrafos
  ; Llego aca con una letra leida
  comprobar_si_sumo_parrafo:
    ; Si aun estoy dentro de un parrafo, no debo incrementar el contador
    cmp [soy_parrafo], BYTE true
      je continuar

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp continuar


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp continuar

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp continuar
section .data

	;Estos son textos para imprimir al final
	letras db "Letras: "
	letras_len equ $- letras

	palabras db " Palabras: "
	palabras_len equ $- palabras

	lineas db " Lineas: "
	lineas_len equ $- lineas

	parrafos db " Parrafos: "
	parrafos_len equ $- parrafos

	entr db 0xa

section .bss

	;Buffers para los contadores (luego imprimimos estos)
	buffer_letras resb 8  ; Buffer de 16 bytes para el contador de letras
	buffer_palabras resb 8; Buffer de 16 bytes para el contrador de palabras
	buffer_lineas resb 8  ; Buffer de 16 bytes para el contador de lineas
	buffer_parrafos resb 8; Buffer de 16 bytes para el contador de parrafos

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de EAX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en EAX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en EAX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en EAX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en EAX la direccion cant_parrafos
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_parrafos  ;ESI va a mantener la direccion del buffer_parrafos
		call obtener_string	      ;obtengo el string y lo guardo en buffer_parrafos

		;imprimimos todos los buffers
		call imprimir_buffers
		jmp exit

	obtener_string:
		mov EDX, 0 	;Esto es para la division porque se concatena (DX:AX). DX se modifica, por eso lo reseteo en cada iteracion
		mov ECX, 10	;divisor para obtener el mod de los numeros

		;div divide AX por el parametro
		div ECX	; AX queda el resultado, en DX queda el resto

		push EDX ;pusheo el resto a la pila para que me quede en orden al sacarlo

		inc EBX
		cmp EAX, 0 ;si AX es 0 entonces no hay mas digitos
		jne obtener_string

		jmp guardar_en_buffer

	guardar_en_buffer:
		pop EDX	;guardo en DX el digito mas significativo que queda
		add EDX, 0x30 ;lo paso a ASCII

		mov BYTE [ESI], DL ;guardo en el buffer correspondiente el digito

		inc ESI		   ;aumento en 1 la direccion (para seguir concatenando)
		dec EBX		   ; 1 digito menos
		cmp EBX, 0	   ;si no tengo mas digitos entonces termine
		jne guardar_en_buffer

		ret

	imprimir_buffers:
		;imprimimos "Letras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, letras
		mov EDX, letras_len
		int 0x80

		;imprimimos la cantidad de letras
		mov EAX, 4	        ;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_letras
		mov EDX, 8
		int 0x80

		;imprimimos " Palabras:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, palabras
		mov EDX, palabras_len
		int 0x80

		;imprimimos la cantidad de palabras
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_palabras
		mov EDX, 8
		int 0x80

		;imprimimos " Lineas:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, lineas
		mov EDX, lineas_len
		int 0x80

		;imprimimos la cantidad de lineas
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_lineas
		mov EDX, 8
		int 0x80

		;imprimimos " Parrafos:"
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, parrafos
		mov EDX, parrafos_len
		int 0x80

		;imprimimos la cantidad de parrafos
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, buffer_parrafos
		mov EDX, 8
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
