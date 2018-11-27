section .data
  %define false 0
  %define true  1

  %define stdin  0
  %define stdout 1
  %define stderr 2

  %define no_err      0 ; No se produjo error
  %define input_err   1 ; Error en el archivo de entrada
  %define output_err  2 ; Error con el archivo de salida
  %define unknown_err 3 ; Error desconocido

  %define ro_mode    0000 ; Modo solo lectura
  %define wo_mode    0001 ; Modo solo escritura
  %define rw_mode    0002 ; Modo lectura escritura
  %define creat_mode 0200 ; Modo creacion (Si el archivo no existe)

  %define buff_sz 1000 ; Cantidad de bytes del buffer de lectura

section .bss
  in_file  resb 4; Reservamos 4 bytes para el descriptor del archivo de entrada
  out_file resb 4; Reservamos 4 bytes para el descriptor del archivo de salida

  buffer resb 1000; Reservamos 1000 bytes para el buffer de lectura

