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
    jmp parse_stdin


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
