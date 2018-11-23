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
