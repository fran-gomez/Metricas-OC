section .data
  tmp_file db "/tmp/.tmp.txt",0x0 ; Nombre del archivo temporal para analizar stdin

section .bss
  cnt_letra   resb 8; Reservo 4 bytes para el contador de caracteres
  cnt_palabra resb 8; Reservo 4 bytes para el contador de palabras
  cnt_linea   resb 8; Reservo 4 bytes para el contador de lineas
  cnt_parrafo resb 8; Reservo 4 bytes para el contador de parrafos

  soy_palabra   resb 1; Flag para controlar si estoy en una sucesion de blancos
  soy_parrafo   resb 1; Flag para controlar si estoy dentro de una secuencia de palabras

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
    no_se_me_ocurre_nada:
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
      je no_se_me_ocurre_nada

    ; Incrementamos el contador
    mov ECX, [cnt_parrafo]
    add ECX, 1
    mov [cnt_parrafo], ECX

    ; Empezamos a leer otro parrafo, por lo que ponemos el flag en true
    mov [soy_parrafo], BYTE true
    jmp no_se_me_ocurre_nada


  ; Llego aca cuando leo un caracter que no es letra mayusc o minusc
  no_es_letra:
    mov [soy_palabra], BYTE false ; Marco que estoy fuera de una palabra

    cmp DL, 0x0A ; Comparo con '\n'; Si lei un salto de linea, incremento el contador de lineas
      je salto_de_linea

    ; Sino, lei cualquier cosa, no la cuento
    jmp no_se_me_ocurre_nada

  ; Llego aca cuando leo un caracter '\n'
  salto_de_linea:
    mov [soy_parrafo], BYTE false ; Marco que estoy fuera de un parrafo

    ; Incremento la cantidad de lineas
    mov ECX, [cnt_linea]
    add ECX, 1
    mov [cnt_linea], ECX

    jmp no_se_me_ocurre_nada

  ; Leo la entrada del usuario (Terminada en enter - '\n'), la pongo en un archivo temporal,
  ; luego, analizo ese archivo temporal e imprimo los resultados por pantalla
  parse_stdin:
    ; Abrimos un archivo temporal para guardar el input del ususario
    mov EAX, 8        ; sys_creat
    mov EBX, tmp_file ; Nombre del archivo temporal
    mov ECX, 0777     ; Modo RWX para todos los usuarios
    int 0x80

    ; Cierro el archivo temporal y lo abro en modo RW
    ; Ya se, es bastante ineficiente, pero no le encontre la vuelta al problema de los permisos

    mov EAX, 5      ; sys_open
    mov ECX, rw_mode
    int 0x80

    ; Leemos el input del usuario, y cuando se lleno el buffer, lo escribimos en el archivo
    mov EAX, 3     ; sys_read
    mov EBX, stdin
    mov ECX, buffer
    mov EDX, buff_sz
    int 0x80

    mov EDX, EAX ; Guardo la cantidad de caracteres leidos
    mov EAX, 4   ; sys_write
    pop EBX      ; Recupero el fd del temporal
    int 0x80

    mov [in_file], EBX
    mov [out_file], BYTE stdout

    ; Tenemos al archivo como in_file, ahora lo analizamos
    jmp parse
