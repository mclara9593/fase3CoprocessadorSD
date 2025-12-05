#ifndef API_FPGA_H
#define API_FPGA_H


#include <stdint.h>


extern int init_memory(void);
extern void cleanup_memory(void);


extern void escrever_pixel_end(int addr, int data);
extern int ler_pixel_fpga(int addr);


extern void funcao_enviar_1(void);
extern void funcao_enviar_2(void);
extern void funcao_enviar_4(void);
extern void funcao_enviar_8(void);


extern void set_zoom_2x(void);
extern void set_zoom_4x(void);
extern void set_zoom_8x(void);


extern void funcao_apagar_tudo(void);
extern void carregar_imagem(void);


#endif


