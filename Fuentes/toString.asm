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
	buffer_letras resb 6
	buffer_palabras resb 6
	buffer_lineas resb 6
	buffer_parrafos resb 6

section .text
	global toString

    ;Usamos AX para obtener la cantidad de letras/palabras/lineas/parrafos
    ;EBX es un contador que lleva la cuenta de la cantidad de digitos de AX
    ;ESI mantiene la direccion del buffer de letras/palabras/lineas/parrafos
    ;llamamos a obtener_string que:
	    ;1°: guarda cada uno de los digitos de AX en la pila
    	;2°: hace un jmp a guardar_en_buffer
    	;3°: guardar_en_buffer hace pop a cada uno de los digitos en la pila
    	;4°: mientras 'popea' estos digitos les suma 0x30 para obtener el codigo ASCII
    	;5°: los guarda en su correspondiente buffer
    	;6°: una vez guardado en el buffer correspondiente retorna
    	;7°: volvemos a hacer lo mismo con los otros contadores (4 veces en total)
	toString:
		mov EAX, [cnt_letra]	  ;guardo en AX la direccion cant_letras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_letras    ;ESI va a mantener la direccion del buffer_letras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_palabra]	  ;guardo en AX la direccion cant_palabras
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_palabras  ;ESI va a mantener la direccion del buffer_palabras
		call obtener_string	      ;obtengo el string y lo guardo en buffer_letras

		mov EAX, [cnt_linea]	  ;guardo en AX la direccion cant_lineas
		mov EBX, 0 		          ;inicializo el contador para llevar la cuenta de la cantidad de digitos del contador
		mov ESI, buffer_lineas    ;ESI va a mantener la direccion del buffer_lineas
		call obtener_string	      ;obtengo el string y lo guardo en buffer_lineas

		mov EAX, [cnt_parrafo]	  ;guardo en AX la direccion cant_parrafos
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
		mov EDX, 4
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
		mov EDX, 4
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
		mov EDX, 4
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
		mov EDX, 4
		int 0x80

		;imprimimos un enter (no es muy optimo)
		mov EAX, 4	;sys_write
		mov EBX, [out_file]
		mov ECX, entr
		mov EDX, 1
		int 0x80

        push no_err
        jmp exit
