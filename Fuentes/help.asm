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
