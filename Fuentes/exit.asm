section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80
