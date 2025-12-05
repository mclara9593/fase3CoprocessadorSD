#define _BSD_SOURCE
#define _XOPEN_SOURCE 600
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <termios.h>     
#include <sys/select.h>  
#include <linux/input.h> 
#include <time.h>
#include <sys/time.h>
#include "api.h"

// ================= CONSTANTES =================
#define FPGA_WIDTH  160
#define FPGA_HEIGHT 120
#define TOTAL_PIXELS (FPGA_WIDTH * FPGA_HEIGHT)

// Definições de UI e Mouse (Do Segundo Código)
#define MOUSE_DEV "/dev/input/mice"
#define CURSOR_HOME  "\033[H"
#define TERM_CYAN    "\033[36m"
#define HIDE_CURSOR  "\033[?25l"
#define SHOW_CURSOR  "\033[?25h"

// Cores e Limpeza
#define TERM_RESET   "\033[0m"
#define TERM_RED     "\033[31m"
#define TERM_GREEN   "\033[32m"
#define TERM_YELLOW  "\033[33m"
#define CLEAR_SCREEN "\033[2J\033[H"

typedef struct {
   uint8_t blue; uint8_t green; uint8_t red; uint8_t reserved;
} ColorPaletteEntry;

// --- Estrutura para Gestão de Imagem na RAM (Necessária para o Mouse) ---
typedef struct {
   uint8_t *clean_gray;    // Backup da imagem limpa (fundo original)
   uint8_t *original_gray; // Imagem de trabalho (onde aplicamos a lupa)
   uint8_t *display_gray;  // Buffer de display
   int loaded;            
} ImageSystem;

// Variáveis Globais de UI/Sistema
ImageSystem sys = {NULL, NULL, NULL, 0};
struct termios orig_termios;

// ================= UTILITÁRIOS DE INPUT =================
int ler_inteiro() {
   char buffer[64];
   if (fgets(buffer, sizeof(buffer), stdin) != NULL) return atoi(buffer);
   return -1;
}

char ler_char() {
   char buffer[64];
   if (fgets(buffer, sizeof(buffer), stdin) != NULL) return buffer[0];
   return 0;
}

// ================= FUNÇÕES AUXILIARES BMP =================
static void write_int(unsigned char* buffer, int offset, uint32_t value) {
   buffer[offset] = value & 0xFF;
   buffer[offset+1] = (value >> 8) & 0xFF;
   buffer[offset+2] = (value >> 16) & 0xFF;
   buffer[offset+3] = (value >> 24) & 0xFF;
}
static void write_short(unsigned char* buffer, int offset, uint16_t value) {
   buffer[offset] = value & 0xFF;
   buffer[offset+1] = (value >> 8) & 0xFF;
}
static uint32_t read_int(const unsigned char* buffer, int offset) {
   return buffer[offset] | (buffer[offset+1] << 8) | (buffer[offset+2] << 16) | (buffer[offset+3] << 24);
}
static uint16_t read_short(const unsigned char* buffer, int offset) {
   return buffer[offset] | (buffer[offset+1] << 8);
}

// Função auxiliar para salvar buffer genérico em BMP
void salvar_buffer_bmp_disco(const char *filename, unsigned char *buffer, int width, int height) {
    FILE *f = fopen(filename, "wb");
    if (!f) return;

    int total_pixels = width * height;
    int file_size = 54 + 1024 + total_pixels;
    int data_offset = 54 + 1024;
    unsigned char bmp_header[54] = {0};
    
    bmp_header[0] = 'B'; bmp_header[1] = 'M';
    write_int(bmp_header, 2, file_size);     
    write_int(bmp_header, 10, data_offset);  
    write_int(bmp_header, 14, 40);           
    write_int(bmp_header, 18, width);   
    write_int(bmp_header, 22, height);  
    write_short(bmp_header, 26, 1);          
    write_short(bmp_header, 28, 8);          
    write_int(bmp_header, 38, 2835);         
    write_int(bmp_header, 42, 2835);         
    write_int(bmp_header, 46, 256);          
    write_int(bmp_header, 50, 256);          
    fwrite(bmp_header, 1, 54, f);

    unsigned char palette[1024];
    for(int i=0; i<256; i++) {
        palette[i*4+0]=i; palette[i*4+1]=i; palette[i*4+2]=i; palette[i*4+3]=0;
    }
    fwrite(palette, 1, 1024, f);

    for (int y = height - 1; y >= 0; y--) {
        fwrite(&buffer[y * width], 1, width, f);
    }
    fclose(f);
}

// ================= UTILITÁRIOS TERMINAL (DO SEGUNDO CÓDIGO) =================
void reset_terminal_mode() {
   printf(SHOW_CURSOR);
   tcsetattr(0, TCSANOW, &orig_termios);
}

void set_conio_terminal_mode() {
   struct termios new_termios;
   tcgetattr(0, &orig_termios);
   memcpy(&new_termios, &orig_termios, sizeof(new_termios));
   // atexit(reset_terminal_mode); // Opcional, mantendo controle manual
   cfmakeraw(&new_termios);
   tcsetattr(0, TCSANOW, &new_termios);
   printf(HIDE_CURSOR);
}

int kbhit() {
   struct timeval tv = { 0L, 0L };
   fd_set fds;
   FD_ZERO(&fds);
   FD_SET(0, &fds);
   return select(1, &fds, NULL, NULL, &tv);
}

int getch() {
   int r;
   unsigned char c;
   if ((r = read(0, &c, sizeof(c))) < 0) return r;
   else return c;
}

// ================= LÓGICA DE BUFFER E IMAGEM (ADAPTADA) =================
void resetar_buffer_display() {
   if (!sys.loaded) return;
   memcpy(sys.display_gray, sys.original_gray, TOTAL_PIXELS);
}

void atualizar_tela_completa() {
   if (!sys.loaded) return;
   for(int i=0; i < TOTAL_PIXELS; i++) {
       // Adaptado: write_pixel_c -> escrever_pixel_end
       escrever_pixel_end(i, sys.display_gray[i]);
   }
}

// === SALVAR BUFFER DA RAM EM BMP ===
void salvar_imagem_completa_ram(const char *filename) {
   if (!sys.loaded) return;

   int width = FPGA_WIDTH;
   int height = FPGA_HEIGHT;
  
   // Cabeçalho BMP
   int row_padded = (width + 3) & (~3);
   int data_size = row_padded * height;
   int file_size = 54 + 1024 + data_size;
   int data_offset = 54 + 1024;

   unsigned char header[54] = {0};
   header[0] = 'B'; header[1] = 'M';
   write_int(header, 2, file_size);
   write_int(header, 10, data_offset);
   write_int(header, 14, 40);
   write_int(header, 18, width);
   write_int(header, 22, height);
   write_short(header, 26, 1);
   write_short(header, 28, 8);
   write_int(header, 46, 256);

   FILE *f = fopen(filename, "wb");
   if (!f) return;

   fwrite(header, 1, 54, f);

   unsigned char palette[1024];
   for(int i=0; i<256; i++) {
       palette[i*4+0]=i; palette[i*4+1]=i; palette[i*4+2]=i; palette[i*4+3]=0;
   }
   fwrite(palette, 1, 1024, f);

   unsigned char *padding = calloc(1, 4);
   int pad_size = row_padded - width;

   // Salva o buffer atual (sys.original_gray já contém a sobreposição)
   for (int y = height - 1; y >= 0; y--) {
       for (int x = 0; x < width; x++) {
           fputc(sys.original_gray[y * width + x], f);
       }
       if (pad_size > 0) fwrite(padding, 1, pad_size, f);
   }
   free(padding); fclose(f);
}

// === LÓGICA DA LUPA / MESCLAÇÃO ===
void aplicar_overlay_bmp(int start_x, int start_y, int dest_w, int dest_h, int zoom_level) {
   if (!sys.loaded) return;

   char *filename;
   float zoom_factor;

   // Configuração dos Níveis de Zoom
   if (zoom_level == 1) {
       filename = "saida.bmp";
       zoom_factor = 2.0f;
   } else if (zoom_level == 2) {
       filename = "saida2x.bmp"; // Segundo nível de zoom
       zoom_factor = 4.0f;
   } else {
       return;
   }

   FILE *f = fopen(filename, "rb");
   if (!f) {
       // Se não achar saida2x.bmp, tenta fallback para saida.bmp no nível 2
       if (zoom_level == 2) {
            f = fopen("saida.bmp", "rb");
            if (f) zoom_factor = 4.0f; 
       }
       if (!f) return;
   }

   unsigned char header[54];
   if (fread(header, 1, 54, f) != 54) { fclose(f); return; }

   uint32_t data_off = read_int(header, 10);
   int src_w = read_int(header, 18);
   int src_h = read_int(header, 22);
   uint16_t bpp = read_short(header, 28);

   ColorPaletteEntry pal[256];
   if (bpp == 8) {
       fseek(f, 54, SEEK_SET);
       fread(pal, sizeof(ColorPaletteEntry), 256, f);
   }

   fseek(f, data_off, SEEK_SET);
   long row_padded = (src_w * bpp / 8 + 3) & ~3;
   unsigned char *src_data = malloc(row_padded * src_h);
   fread(src_data, 1, row_padded * src_h, f);
   fclose(f);

   float scale_x = (float)src_w / (float)FPGA_WIDTH;
   float scale_y = (float)src_h / (float)FPGA_HEIGHT;

   int end_x = start_x + dest_w;
   int end_y = start_y + dest_h;
   if (end_x > FPGA_WIDTH) end_x = FPGA_WIDTH;
   if (end_y > FPGA_HEIGHT) end_y = FPGA_HEIGHT;

   int win_cx = start_x + dest_w / 2;
   int win_cy = start_y + dest_h / 2;

   int src_cx = (int)(win_cx * scale_x);
   int src_cy = (int)(win_cy * scale_y);

   for (int y = start_y; y < end_y; y++) {
       for (int x = start_x; x < end_x; x++) {
          
           int dx = x - win_cx;
           int dy = y - win_cy;

           // Mapeamento com ZOOM Dinâmico
           int target_src_x = src_cx + (int)(dx * (scale_x / zoom_factor));
           int target_src_y = src_cy + (int)(dy * (scale_y / zoom_factor));

           if (target_src_x < 0) target_src_x = 0;
           if (target_src_x >= src_w) target_src_x = src_w - 1;
           if (target_src_y < 0) target_src_y = 0;
           if (target_src_y >= src_h) target_src_y = src_h - 1;

           int real_src_y = (src_h - 1) - target_src_y;

           uint8_t gray = 0;
           if (bpp == 8) {
               uint8_t idx = src_data[real_src_y * row_padded + target_src_x];
               gray = (uint8_t)((pal[idx].red * 77 + pal[idx].green * 151 + pal[idx].blue * 28) >> 8);
           } else {
               long pos = real_src_y * row_padded + (target_src_x * 3);
               gray = (uint8_t)((src_data[pos+2] * 77 + src_data[pos+1] * 151 + src_data[pos] * 28) >> 8);
           }

           int addr = y * FPGA_WIDTH + x;
           sys.original_gray[addr] = gray;
           sys.display_gray[addr] = gray;
           // Adaptado: write_pixel_c -> escrever_pixel_end
           escrever_pixel_end(addr, gray);
       }
   }
   free(src_data);

   char out_name[50];
   sprintf(out_name, "mesclagem_zoom_lv%d_%ld.bmp", zoom_level, time(NULL));
   // salvar_imagem_completa_ram(out_name); // Opcional: Salvar debug
}

// ================= GERAÇÃO AUTOMÁTICA DE CACHE =================
void gerar_cache_zooms() {
    if (!sys.loaded || !sys.clean_gray) return;
    
    printf(TERM_CYAN "\n>>> GERANDO CACHE DE ZOOM (HARDWARE) <<<\n" TERM_RESET);
    
    // ------------------------------------------
    // 1. ZOOM 2X (320x240) -> saida.bmp
    // ------------------------------------------
    printf("1/2: Processando Zoom 2x (320x240)...\n");
    funcao_apagar_tudo();
    set_zoom_2x();
    usleep(50000); // Estabilizar
    
    // Re-enviar imagem para o hardware escalar
    for(int i=0; i<TOTAL_PIXELS; i++) {
        escrever_pixel_end(i, sys.clean_gray[i]);
    }
    printf("     Aguardando processamento HW...\n");
    usleep(800000); 

    // Ler de volta do hardware
    int w2 = 320, h2 = 240;
    unsigned char *buf2 = malloc(w2 * h2);
    if(buf2) {
        for(int i=0; i<w2*h2; i++) buf2[i] = (unsigned char)ler_pixel_fpga(i);
        salvar_buffer_bmp_disco("saida.bmp", buf2, w2, h2);
        free(buf2);
        printf("     Salvo 'saida.bmp'.\n");
    }

    // ------------------------------------------
    // 2. ZOOM 4X (640x480) -> saida2x.bmp
    // ------------------------------------------
    printf("2/2: Processando Zoom 4x (640x480)...\n");
    funcao_apagar_tudo();
    set_zoom_4x();
    usleep(50000);
    
    // Re-enviar imagem
    for(int i=0; i<TOTAL_PIXELS; i++) {
        escrever_pixel_end(i, sys.clean_gray[i]);
    }
    printf("     Aguardando processamento HW...\n");
    usleep(800000);

    // Ler de volta
    int w4 = 640, h4 = 480;
    unsigned char *buf4 = malloc(w4 * h4);
    if(buf4) {
        for(int i=0; i<w4*h4; i++) buf4[i] = (unsigned char)ler_pixel_fpga(i);
        salvar_buffer_bmp_disco("saida2x.bmp", buf4, w4, h4);
        free(buf4);
        printf("     Salvo 'saida2x.bmp'.\n");
    }

    // ------------------------------------------
    // 3. RESTAURAR ESTADO ORIGINAL
    // ------------------------------------------
    printf("Restaurando visualizacao...\n");
    funcao_apagar_tudo();
    funcao_enviar_1(); // Assume modo normal/replicação
    
    // Re-enviar imagem original para o usuário ver
    for(int i=0; i<TOTAL_PIXELS; i++) {
        escrever_pixel_end(i, sys.clean_gray[i]);
    }
    printf(TERM_GREEN "Cache gerado com sucesso!\n" TERM_RESET);
    funcao_apagar_tudo();
    sleep(1);

}

// ================= UI ASCII =================
void desenhar_ui(int mx, int my, int p1_x, int p1_y, int win_x, int win_y, int win_w, int win_h, int state, int zoom) {
   int map_w = 40;
   int map_h = 15;
   int scale_x = FPGA_WIDTH / map_w;
   int scale_y = FPGA_HEIGHT / map_h;
  
   int grid_mx = mx / scale_x; if (grid_mx >= map_w) grid_mx = map_w - 1;
   int grid_my = my / scale_y; if (grid_my >= map_h) grid_my = map_h - 1;

   int gs_x=0, ge_x=0, gs_y=0, ge_y=0;
  
   if (state == 1) { // Arrastando
        int gx1 = p1_x / scale_x; int gx2 = mx / scale_x;
        int gy1 = p1_y / scale_y; int gy2 = my / scale_y;
        gs_x = (gx1 < gx2) ? gx1 : gx2; ge_x = (gx1 < gx2) ? gx2 : gx1;
        gs_y = (gy1 < gy2) ? gy1 : gy2; ge_y = (gy1 < gy2) ? gy2 : gy1;
   }
   else if (state == 2) { // Travado
       gs_x = win_x / scale_x; gs_y = win_y / scale_y;
       ge_x = (win_x + win_w) / scale_x; ge_y = (win_y + win_h) / scale_y;
   }
   if (ge_x >= map_w) ge_x = map_w - 1; if (ge_y >= map_h) ge_y = map_h - 1;

   printf(CURSOR_HOME);
   printf(TERM_YELLOW "=== MODO LUPA / SOBREPOSICAO ===" TERM_RESET "\r\n");
   printf("Mouse: [%03d, %03d] | Zoom: %dx", mx, my, (zoom==0)?1:(zoom*2));
   if (zoom == 2) printf(" (saida2x)");
   printf("\r\n");
  
   if (state == 0) printf("LIVRE (Clique para Selecionar Area)\r\n");
   else if (state == 1) printf(TERM_CYAN "DEFININDO JANELA...\r\n" TERM_RESET);
   else printf(TERM_RED "TRAVADO! (+)Zoom In | (-)Zoom Out\r\n" TERM_RESET);

   printf(" +"); for(int i=0; i<map_w; i++) putchar('-'); printf("+\r\n");

   for (int y = 0; y < map_h; y++) {
       putchar('|');
       for (int x = 0; x < map_w; x++) {
           char c = ' ';
           if (state != 0 && x >= gs_x && x <= ge_x && y >= gs_y && y <= ge_y) {
               if (state == 1) c = '.'; else c = '#';           
           }
           if (x == grid_mx && y == grid_my) c = '@';
           putchar(c);
       }
       putchar('|'); printf("\r\n");
   }
   printf(" +"); for(int i=0; i<map_w; i++) putchar('-'); printf("+\r\n");
   printf("(Q) Sair | (DIR) Cancelar | (+) APLICAR ZOOM\r\n");
}

void modo_mouse_interativo() {
   if (!sys.loaded) {
       printf(TERM_RED "Erro: Carregue uma imagem base primeiro (Opcao 1)!\n" TERM_RESET);
       sleep(2); return;
   }

   // --- AUTO-GERAÇÃO DO CACHE DE ZOOM ---
   // Gera automaticamente os arquivos saida.bmp (2x) e saida2x.bmp (4x)
   // usando o hardware da FPGA, para garantir que a lupa tenha dados.
   gerar_cache_zooms();

   int fd = open(MOUSE_DEV, O_RDONLY | O_NONBLOCK);
   if (fd == -1) { printf("Erro mouse.\n"); return; }
   
   printf(CLEAR_SCREEN);
   set_conio_terminal_mode();

   signed char data[3];
   int mx = FPGA_WIDTH/2, my = FPGA_HEIGHT/2;
   int p1_x = -1, p1_y = -1;
   int win_sx = 0, win_sy = 0, win_w = 0, win_h = 0;
   int state = 0;
   int current_zoom = 0; // 0=Original, 1=2x, 2=4x
   int update = 1;

   while (1) {
       if (read(fd, data, 3) > 0) {
           int left = data[0] & 1;
           int right = data[0] & 2;
           mx += data[1]; my -= data[2];
          
           if (mx < 0) mx=0; if (mx >= FPGA_WIDTH) mx=FPGA_WIDTH-1;
           if (my < 0) my=0; if (my >= FPGA_HEIGHT) my=FPGA_HEIGHT-1;
           update = 1;

           if (right) {
               state = 0; current_zoom = 0;
               // Reseta visualização
               if (sys.clean_gray) {
                   memcpy(sys.original_gray, sys.clean_gray, TOTAL_PIXELS);
                   resetar_buffer_display();
                   atualizar_tela_completa();
               }
           }

           if (left) {
               if (state == 0) {
                   if (sys.clean_gray) {
                       memcpy(sys.original_gray, sys.clean_gray, TOTAL_PIXELS);
                       resetar_buffer_display();
                       atualizar_tela_completa();
                   }
                   p1_x = mx; p1_y = my; state = 1;
                   current_zoom = 0;
               }
           } else {
               if (state == 1) {
                   int w = abs(mx - p1_x); int h = abs(my - p1_y);
                   if (w < 1) w = 1; if (h < 1) h = 1;
                  
                   win_sx = (p1_x < mx) ? p1_x : mx;
                   win_sy = (p1_y < my) ? p1_y : my;
                   win_w = w; win_h = h;
                   state = 2; update = 1;
               }
           }
       }

       if (kbhit()) {
           int ch = getch();
           if (ch == 'q') break;
          
           if (state == 2) {
               // (+) AUMENTA ZOOM
               if (ch == '+' || ch == '=') {
                   if (current_zoom < 2) {
                       current_zoom++;
                       if (sys.clean_gray) {
                            memcpy(sys.original_gray, sys.clean_gray, TOTAL_PIXELS);
                       }
                       aplicar_overlay_bmp(win_sx, win_sy, win_w, win_h, current_zoom);
                       update = 1;
                   }
               }
               // (-) DIMINUI ZOOM
               else if (ch == '-' || ch == '_') {
                   if (current_zoom > 0) {
                       current_zoom--;
                       if (sys.clean_gray) {
                            memcpy(sys.original_gray, sys.clean_gray, TOTAL_PIXELS);
                            if (current_zoom == 0) {
                                resetar_buffer_display();
                                atualizar_tela_completa();
                            }
                       }
                       if (current_zoom > 0) {
                           aplicar_overlay_bmp(win_sx, win_sy, win_w, win_h, current_zoom);
                       }
                       update = 1;
                   }
               }
           }
       }

       if (update) {
           desenhar_ui(mx, my, p1_x, p1_y, win_sx, win_sy, win_w, win_h, state, current_zoom);
           update = 0;
       }
       usleep(10000);
   }
   reset_terminal_mode();
   close(fd);
   printf(CLEAR_SCREEN);
   // Restaura estado limpo na FPGA
   funcao_apagar_tudo();
}


// ================= LÓGICA DE SALVAR IMAGEM (ESTÁTICA) =================
void handle_read_mode() {
   int i, y;
   int width = 0, height = 0;
   char opt;
   FILE *f;
   unsigned char bmp_header[54] = {0};
   unsigned char palette[1024];
   unsigned char *full_image_buffer = NULL;

   printf(CLEAR_SCREEN);
   printf("=== SALVAR IMAGEM (FPGA -> BMP) ===\n\n");
   printf("Selecione a resolucao para captura:\n");
   printf("2. Zoom 2x (320x240)\n");
   printf("4. Zoom 4x (640x480)\n");
   printf("8. Zoom 8x (640x480)\n");
   printf("v. Voltar\n");
   printf("> ");
  
   opt = ler_char();

   if (opt == 'v') return;

   // 1. RESET OBRIGATÓRIO (Limpa estados anteriores)
   printf("Resetando sistema... ");
   funcao_apagar_tudo();
   usleep(200000);
   printf("OK.\n");

   // 2. CONFIGURAÇÃO DO ZOOM (Mapeamento Correto)
   if (opt == '2') {
       width = 320; height = 240;
       printf("Configurando HW: Zoom 2x (320x240)...\n");
       funcao_apagar_tudo();
       set_zoom_2x();
   } else if (opt == '4') {
       width = 640; height = 480;
       printf("Configurando HW: Zoom 4x (640x480)...\n");
       funcao_apagar_tudo();
       set_zoom_4x();
   } else if (opt == '8') {
       width = 640; height = 480;
       printf("Configurando HW: Zoom 8x (Fit 640x480)...\n");
       funcao_apagar_tudo();
       set_zoom_8x();
   } else {
       printf("Opcao invalida. Cancelando.\n");
       return;
   }

   // 3. ESTABILIZAÇÃO (Crucial para não 'correr' a imagem)
   printf("Aguardando preenchimento da memoria (1s)...\n");
   usleep(1000000);

   int total_pixels = width * height;
   full_image_buffer = (unsigned char*)malloc(total_pixels);
  
   if (!full_image_buffer) {
       printf(TERM_RED "Erro critico: Sem memoria RAM.\n" TERM_RESET);
       return;
   }

   printf("Lendo %d pixels sequencialmente... ", total_pixels);
   fflush(stdout);

   // 4. LEITURA SEQUENCIAL
   for (i = 0; i < total_pixels; i++) {
       int val = ler_pixel_fpga(i);
       full_image_buffer[i] = (unsigned char)val;
       if (i % (total_pixels/20) == 0) { printf("."); fflush(stdout); }
   }
   printf(" Concluido.\n");

   // 5. GRAVAÇÃO
   // Lógica para nome do arquivo baseada no zoom, para ajudar a lupa
   char *fname = "saida.bmp";
   if (opt == '4' || opt == '8') fname = "saida2x.bmp"; // O sistema de janela espera saida2x para zooms maiores
   
   f = fopen(fname, "wb");
   if (!f) {
       printf(TERM_RED "Erro ao criar arquivo!\n" TERM_RESET);
       free(full_image_buffer);
       return;
   }

   int file_size = 54 + 1024 + total_pixels;
   int data_offset = 54 + 1024;
   bmp_header[0] = 'B'; bmp_header[1] = 'M';
   write_int(bmp_header, 2, file_size);     
   write_int(bmp_header, 10, data_offset);  
   write_int(bmp_header, 14, 40);           
   write_int(bmp_header, 18, width);   
   write_int(bmp_header, 22, height);  
   write_short(bmp_header, 26, 1);          
   write_short(bmp_header, 28, 8);          
   write_int(bmp_header, 38, 2835);         
   write_int(bmp_header, 42, 2835);         
   write_int(bmp_header, 46, 256);          
   write_int(bmp_header, 50, 256);          
   fwrite(bmp_header, 1, 54, f);

   for(i=0; i<256; i++) {
       palette[i*4+0]=i; palette[i*4+1]=i; palette[i*4+2]=i; palette[i*4+3]=0;
   }
   fwrite(palette, 1, 1024, f);

   printf("Gravando BMP (%s)...\n", fname);
   for (y = height - 1; y >= 0; y--) {
       unsigned char *row_ptr = &full_image_buffer[y * width];
       fwrite(row_ptr, 1, width, f);
   }

   fclose(f);
   free(full_image_buffer);

   printf(TERM_GREEN "Imagem salva com sucesso!\n" TERM_RESET);
  
   // Reset final
   funcao_apagar_tudo();
   sleep(1);
}

// ================= MODO ENVIO (WRITE BMP) =================
void handle_image_mode() {
   char filename[256];
   FILE *f;
   unsigned char head[54];
   uint32_t w, h, off;
   uint16_t bpp;
   unsigned char *buf;
   ColorPaletteEntry pal[256];
   int x, y;

   // Reset para garantir estado limpo
   usleep(50000);

   printf("\n" TERM_YELLOW "--- ENVIAR BMP PARA FPGA ---" TERM_RESET "\n");
   printf("Arquivo .bmp: ");
   if (fgets(filename, sizeof(filename), stdin)) {
       filename[strcspn(filename, "\n")] = 0;
   } else return;

   f = fopen(filename, "rb");
   if (!f) { printf(TERM_RED "Erro: Arquivo nao encontrado.\n" TERM_RESET); sleep(1); return; }
   if (fread(head, 1, 54, f) != 54) { fclose(f); return; }

   off = read_int(head, 10);
   w = read_int(head, 18);
   h = read_int(head, 22);
   bpp = read_short(head, 28);
  
   fseek(f, off, SEEK_SET);
   long row = (w * bpp / 8 + 3) & ~3;
   long sz = row * h;
   buf = malloc(sz);
   fread(buf, 1, sz, f);
  
   if (bpp == 8) {
       fseek(f, 54, SEEK_SET);
       fread(pal, sizeof(ColorPaletteEntry), 256, f);
   }
   fclose(f);

   // --- ADIÇÃO PARA MODO JANELA: Preparar buffer na RAM ---
   if (!sys.clean_gray) sys.clean_gray = malloc(TOTAL_PIXELS);
   if (!sys.original_gray) sys.original_gray = malloc(TOTAL_PIXELS);
   if (!sys.display_gray) sys.display_gray = malloc(TOTAL_PIXELS);
   // -----------------------------------------------------

   printf("Enviando %dx%d (%d bpp)...\n", w, h, bpp);
  
   for (y = 0; y < h; y++) {
       int by = h - 1 - y;
       for (x = 0; x < w; x++) {
           uint8_t g = 0;
           if (bpp == 8) {
               uint8_t i = buf[by * row + x];
               g = (uint8_t)((pal[i].red*77 + pal[i].green*151 + pal[i].blue*28)>>8);
           } else {
               long p = by * row + x*3;
               g = (uint8_t)((buf[p+2]*77 + buf[p+1]*151 + buf[p]*28)>>8);
           }
           if (x < FPGA_WIDTH && y < FPGA_HEIGHT) {
               int addr = y * FPGA_WIDTH + x;
               escrever_pixel_end(addr, g);
               
               // --- ADIÇÃO PARA MODO JANELA: Salvar no buffer ---
               if (sys.original_gray) {
                   sys.original_gray[addr] = g;
                   sys.display_gray[addr] = g; // Sync inicial
               }
           }
       }
   }
   
   // Finaliza setup do modo janela
   if (sys.original_gray && sys.clean_gray) {
       sys.loaded = 1;
       memcpy(sys.clean_gray, sys.original_gray, TOTAL_PIXELS);
   }

   free(buf);
   // funcao_apagar_tudo(); // Removido para manter a imagem na tela após envio
   printf(TERM_GREEN "Envio Concluido.\n" TERM_RESET);
   sleep(1);
}

// ================= MENU ALGORITMOS =================
void handle_algo_select() {
   int running = 1;
   char opt;
  
   // Reset ao entrar
   funcao_apagar_tudo();
  
   while (running) {
       printf(CLEAR_SCREEN);
       printf(TERM_YELLOW "--- CONFIGURAR ALGORITMOS (HARDWARE) ---" TERM_RESET "\n");
       printf("1. Replicacao (SW[0])\n");
       printf("2. Zoom In (Vizinho)\n");
       printf("4. Zoom Out (SW[2])\n");
       printf("8. Media (SW[3])\n");
       printf("c. Limpar Tela\n");
       printf("v. Voltar ao Menu Principal\n");
       printf("Escolha: ");
      
       opt = ler_char();

       switch(opt) {
           case '1':
               funcao_apagar_tudo();
               printf("Ativando: Replicacao...\n");
               funcao_enviar_1(); // SW[0]
               break;
           case '2':
               printf("\nFator de Zoom:\n(2) 2x\n(4) 4x\n(8) 8x\n> ");
               char z = ler_char();
              
               funcao_apagar_tudo();

               if (z == '2') set_zoom_2x();
               else if (z == '4') set_zoom_4x();
               else if (z == '8') set_zoom_8x();
               else printf("Invalido.\n");
               
              
               printf("Comando enviado.\n");
               break;
           case '4':
               printf("Ativando: Zoom Out...\n");
               funcao_enviar_4();
               break;
           case '8':
               printf("Ativando: Media...\n");
               funcao_enviar_8();
               break;
           case 'c':
               funcao_apagar_tudo();
               break;
           case 'v':
           case 'q':
               running = 0;
               break;
       }
       if (running && opt != 'v' && opt != 'q') usleep(300000);
   }
   funcao_apagar_tudo();
}

// ================= MAIN =================
int main() {
   int choice = 0;
   int img_loaded = 0;

   if (init_memory() != 0) {
       printf(TERM_RED "Erro: Falha memoria. Use 'sudo'.\n" TERM_RESET);
       return 1;
   }
   printf(TERM_GREEN "Hardware OK.\n" TERM_RESET);
   sleep(1);
  
   funcao_apagar_tudo();

   while (1) {
       printf(CLEAR_SCREEN);
       printf(TERM_YELLOW "=== SISTEMA DE VISAO FPGA ===\n" TERM_RESET);
       printf("1. Enviar Imagem BMP\n");
       printf("2. Aplicar Filtros/Zoom HW\n");
       printf("3. Salvar Imagem da FPGA\n");
       printf("4. Modo Janela (Mouse/Lupa SW)\n");
       printf("0. Sair\n");
       printf("Opcao: ");
      
       choice = ler_inteiro();

       if (choice == 0) break;

       switch (choice) {
           case 1:
               handle_image_mode();
               img_loaded = 1;
               break;
           case 2:
               if (!img_loaded) {
                   printf(TERM_RED "Aviso: Nenhuma imagem carregada.\n" TERM_RESET);
                   sleep(1);
               } else {
                   handle_algo_select();
               }
               break;
           case 3:
               if (!img_loaded) {
                   printf(TERM_RED "Aviso: Nenhuma imagem carregada.\n" TERM_RESET);
                   sleep(1);
               } else {
                   handle_read_mode();
               }
               break;
           case 4:
               // Chama o novo modo
               if (!img_loaded) {
                   printf(TERM_RED "Aviso: Nenhuma imagem carregada.\n" TERM_RESET);
                   sleep(1);
               } else {
                   modo_mouse_interativo();
               }
               break;
           default:
               printf("Opcao invalida.\n"); sleep(1); break;
       }
   }
  
   funcao_apagar_tudo();
   cleanup_memory();
   
   // Limpa buffers do modo janela
   if (sys.clean_gray) free(sys.clean_gray);
   if (sys.original_gray) free(sys.original_gray);
   if (sys.display_gray) free(sys.display_gray);

   return 0;
}