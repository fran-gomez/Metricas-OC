section .text
  global exit

  ; Rutina de terminacion del programa
  ; Requiere codigo de terminacion en el tope de la pila
  exit:
    mov EAX, 1; sys_exit
    pop EBX   ; Codigo de terminacion
    int 0x80

; Rutinas de redireccion de error
; Ponemos el codigo de salida correspondiente, y llamamos a la rutina de salida
  no_error:
    push no_err
    jmp  exit

  input_error:
    push input_err
    jmp  exit

  output_error:
    push output_err
    jmp  exit

  unknown_error:
    push unknown_err
    jmp  exit
