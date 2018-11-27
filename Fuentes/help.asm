section .data

  help_msg db "Error. Argumento invalido", 0xa
           db 0x9,"Uso: metricas [-h] | [archivo_entrada | archivo_salida]", 0xa
           db "Metricas es un programa encargado de contar la cantidad de letras, palabras, lineas y parrafos de una secuencia.",0xa
           db "Segun el tipo y cantidad de los argumentos de entrada, varia la funcionalidad del mismo, siendo...",0xa,0xa

           db "1) Sin argumentos, leemos de teclado hasta que el usuario ingrese",0xa
           db "ctrl+D, y el resultado del analisis sera mostrado por pantalla",0xa,0xa

           db "2) Un solo argumento es interpretado como el archivo de entrada",0xa
           db "que sera analizado y el resultado sera mostrado por pantalla",0xa,0xa

           db "3) Dos argumentos de entrada indican los archivos de entrada y",0xa
           db "salida respectivamente, donde el archivo de salida sera el",0xa
           db "destino de escritura del resultado del ananlisis",0xa

  msg_len equ $ - help_msg

section .text
  global print_help

  ; Imprime el mensaje de ayuda especificado en el archivo desc.txt
  ; Aclaracion: El mensaje era demasiado largo para poner el string como constante del codigo
  print_help:
    mov EAX, 4; sys_write
    mov EBX, stdout
    mov ECX, help_msg
    mov EDX, msg_len
    int 0x80

    ; Salimos sin error
    push no_err
    jmp  exit

