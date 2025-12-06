@ ==================================================================
@ api.s - Driver de Hardware FPGA
@ ==================================================================
.syntax unified
.thumb
.text

@ ========== CONSTANTES ==========
.equ LW_BRIDGE_BASE,    0xFF200000    
.equ LW_BRIDGE_SPAN,    0x00020000    
.equ PIO_OUTPUT_OFFSET, 0x00000000
.equ PIO_INPUT_OFFSET,  0x00000010 

@ SYSCALLS
.equ O_RDWR,            0x0002
.equ O_SYNC,            0x00101000
.equ PROT_READ,         0x1
.equ PROT_WRITE,        0x2
.equ MAP_SHARED,        0x01

@ ========== DADOS GLOBAIS ==========
.data
dev_mem_path:        .asciz "/dev/mem"
.align 4
asm_lw_virtual_base: .word 0
asm_mem_fd:          .word -1
asm_pio_state:       .word 0  

@ ==================================================================
@ INIT & CLEANUP
@ ==================================================================
.global init_memory
.type init_memory, %function
init_memory:
    push {r4, r5, lr}
    ldr r0, =dev_mem_path
    ldr r1, =(O_RDWR | O_SYNC)
    bl open
    cmp r0, #0
    blt init_error
    mov r4, r0
    ldr r1, =asm_mem_fd
    str r0, [r1]
    mov r0, #0
    ldr r1, =LW_BRIDGE_SPAN
    ldr r2, =(PROT_READ | PROT_WRITE)
    ldr r3, =MAP_SHARED
    ldr r5, =LW_BRIDGE_BASE
    push {r4, r5}
    bl mmap
    add sp, sp, #8
    cmn r0, #1
    beq init_error_mmap
    ldr r1, =asm_lw_virtual_base
    str r0, [r1]
    mov r0, #0
    b init_exit
init_error_mmap:
    ldr r0, =asm_mem_fd
    ldr r0, [r0]
    bl close
init_error:
    mov r0, #-1
init_exit:
    pop {r4, r5, lr}
    bx lr
.size init_memory, .-init_memory

.global cleanup_memory
.type cleanup_memory, %function
cleanup_memory:
    push {lr}
    ldr r0, =asm_lw_virtual_base
    ldr r0, [r0]
    ldr r1, =LW_BRIDGE_SPAN
    bl munmap
    ldr r0, =asm_mem_fd
    ldr r0, [r0]
    bl close
    pop {lr}
    bx lr
.size cleanup_memory, .-cleanup_memory

@ --- HELPER: ATUALIZA ESTADO ---
update_sw_state:
    push {r1, r2, lr}
    ldr r1, =asm_pio_state
    str r0, [r1]          
    ldr r1, =asm_lw_virtual_base
    ldr r1, [r1]
    add r1, r1, #PIO_OUTPUT_OFFSET
    str r0, [r1]          
    pop {r1, r2, lr}
    bx lr

@ ==================================================================
@ ESCREVER PIXEL
@ ==================================================================
.global escrever_pixel_end
.type escrever_pixel_end, %function
escrever_pixel_end:
    push {r4, r5, lr}
    lsl r1, r1, #15
    ldr r2, =0x007F8000
    and r1, r1, r2
    ldr r2, =0x00007FFF
    and r0, r0, r2
    orr r4, r0, r1        
    ldr r2, =asm_pio_state
    ldr r3, [r2]
    orr r4, r4, r3
    ldr r0, =asm_lw_virtual_base
    ldr r0, [r0]
    add r0, r0, #PIO_OUTPUT_OFFSET
    orr r5, r4, #(1 << 23) 
    str r5, [r0]
    str r4, [r0]           
    pop {r4, r5, lr}
    bx lr
.size escrever_pixel_end, .-escrever_pixel_end

@ ==================================================================
@ LER PIXEL (COM DELAYS)
@ ==================================================================
.global ler_pixel_fpga
.type ler_pixel_fpga, %function
ler_pixel_fpga:
    push {r4, r5, r6, lr}
    ldr r2, =0x7FFF
    and r1, r0, r2        
    lsr r2, r0, #15
    and r2, r2, #0xF      
    ldr r3, =asm_pio_state
    ldr r3, [r3]          
    orr r4, r3, r1        
    lsl r2, r2, #15
    orr r4, r4, r2        
    ldr r5, =asm_lw_virtual_base
    ldr r5, [r5]
    str r4, [r5, #PIO_OUTPUT_OFFSET]
    mov r6, #50
delay_addr:
    subs r6, r6, #1
    bne delay_addr
    orr r4, r4, #(1 << 28) 
    str r4, [r5, #PIO_OUTPUT_OFFSET]
    mov r6, #1000
delay_ram:
    subs r6, r6, #1
    bne delay_ram
    ldr r0, [r5, #PIO_INPUT_OFFSET]
    and r0, r0, #0xFF     
    pop {r4, r5, r6, lr}
    bx lr
.size ler_pixel_fpga, .-ler_pixel_fpga

@ ==================================================================
@ ALGORITMOS (SW[3:0])
@ ==================================================================

@ Replicação (SW[0] = Bit 24)
.global funcao_enviar_1
.type funcao_enviar_1, %function
funcao_enviar_1:
    push {lr}
    mov r0, #(1 << 24)
    bl update_sw_state
    pop {lr}
    bx lr

@ Zoom In Base (SW[1] = Bit 25)
.global funcao_enviar_2
.type funcao_enviar_2, %function
funcao_enviar_2:
    push {lr}
    mov r0, #(1 << 25)
    bl update_sw_state
    pop {lr}
    bx lr

@ Zoom Out (SW[2] = Bit 26)
.global funcao_enviar_4
.type funcao_enviar_4, %function
funcao_enviar_4:
    push {lr}
    mov r0, #(1 << 26)
    bl update_sw_state
    pop {lr}
    bx lr

@ Média (SW[3] = Bit 27)
.global funcao_enviar_8
.type funcao_enviar_8, %function
funcao_enviar_8:
    push {lr}
    mov r0, #(1 << 27)
    bl update_sw_state
    pop {lr}
    bx lr

@ ==================================================================
@ ZOOMS (Escala SW[6:5])
@ ==================================================================

@ Zoom 4x: SW[0] (Base) + SW[5] (Scale 4x)
.global set_zoom_4x
.type set_zoom_4x, %function
set_zoom_4x:
    push {lr}
    mov r0, #(1 << 24)    
    orr r0, r0, #(1 << 29) 
    bl update_sw_state
    pop {lr}
    bx lr

@ Zoom 8x: SW[0] (Base) + SW[6] (Scale 8x)
.global set_zoom_8x
.type set_zoom_8x, %function
set_zoom_8x:
    push {lr}
    mov r0, #(1 << 24)    
    orr r0, r0, #(1 << 30) 
    bl update_sw_state
    pop {lr}
    bx lr

@ Zoom 2x: SW[0] (Base) + SW[5] + SW[6]
.global set_zoom_2x
.type set_zoom_2x, %function
set_zoom_2x:
    push {lr}
    mov r0, #(1 << 24)    
    orr r0, r0, #(1 << 29) 
    orr r0, r0, #(1 << 30) 
    bl update_sw_state
    pop {lr}
    bx lr

@ Reset (Limpa tudo)
.global funcao_apagar_tudo
.type funcao_apagar_tudo, %function
funcao_apagar_tudo:
    push {lr}
    mov r0, #0
    bl update_sw_state
    pop {lr}
    bx lr

@ Dummy
.global carregar_imagem
.type carregar_imagem, %function
carregar_imagem:
    push {lr}
    pop {lr}
    bx lr


