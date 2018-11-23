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

