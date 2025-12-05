module processo_imagem (
    input  wire [7:0] SW,       // SW[4]=Modo Leitura HPS
    input  wire we,             // Write Enable (apenas para entrada de dados originais)
    input  wire [7:0] data_in,  // HPS Data In (Usado como High Address no modo leitura)
    input  wire [14:0] addr_in, // HPS Address In (Low Address)
    input  wire clk_50,

    // Saída para o PIO de 10 bits do HPS
    output wire [9:0] to_hps_pio, // [7:0]=Pixel Lido da RAM

    output wire hsync,
    output wire vsync,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,
    output wire sync,
    output wire clk,
    output wire blank,
    output wire flag_out
);

    reg clk_25_reg = 0;
    always @(posedge clk_50) begin
        clk_25_reg <= ~clk_25_reg;
    end
    
    // --- Controle SW ---
    // SW[4] = 1: HPS assume o controle de leitura da RAM (Modo Leitura)
    // SW[4] = 0: VGA assume o controle de leitura da RAM (Modo Display)
    wire hps_read_mode = SW[4];

    reg [7:0] sw_prev = 0;          
    reg       auto_reset_flag = 0;  
    reg [3:0] reset_counter = 0;    
    
    wire sw_changed = (sw_prev[6:5] != SW[6:5]) || (sw_prev[3:0] != SW[3:0]); 
    
    always @(posedge clk_25_reg) begin
        sw_prev <= SW; 
        
        if (sw_changed) begin
            auto_reset_flag <= 1'b1;      
            reset_counter <= 4'd15;       
        end else if (reset_counter > 0) begin
            reset_counter <= reset_counter - 1;
            if (reset_counter == 1)
                auto_reset_flag <= 1'b0; 
        end
    end
    
    wire processing_reset = SW[7] || auto_reset_flag; 

    // --- PLL ---
    wire clock_100; 
    wire locked; 
    pll100_0002 pll100_inst (
        .refclk   (clk_50),     
        .rst      (1'b0),
        .outclk_0 (clock_100), 
        .locked   (locked)      
    );

    // --- Sinais VGA ---
    wire [10:0] next_x;
    wire [10:0] next_y;
    reg [10:0] x_delayed;
    reg [10:0] y_delayed;

    always @(posedge clk_25_reg) begin
        x_delayed <= next_x;
        y_delayed <= next_y;
    end
    
    // --- Constantes ---
    localparam IMG_WIDTH_PEQ8  = 20;  localparam IMG_HEIGHT_PEQ8 = 15;
    localparam IMG_WIDTH_PEQ4  = 40;  localparam IMG_HEIGHT_PEQ4 = 30;
    localparam IMG_WIDTH_PEQ   = 80;  localparam IMG_HEIGHT_PEQ  = 60;
    localparam IMG_WIDTH_OR    = 160; localparam IMG_HEIGHT_OR   = 120;
    localparam IMG_WIDTH_GRA   = 320; localparam IMG_HEIGHT_GRA  = 240;      
    localparam IMG_WIDTH_GRA4  = 640; localparam IMG_HEIGHT_GRA4 = 480;
    localparam IMG_TOTAL_PIXELS_OR = IMG_WIDTH_OR * IMG_HEIGHT_OR;

    // --- Sinais Coprocessador ---
    wire        processing_done;
    wire        coproc_pixel_in_ready;
    wire        modo_processamento_ativo = (SW[3:0] != 4'b0000);
    reg         image_loaded = 1; 

    // --- Contador de Leitura da ROM (Entrada) ---
    reg [18:0] rom_addr_counter = 0;

    always @(posedge clk_25_reg or posedge processing_reset) begin
        if (processing_reset) begin
            rom_addr_counter <= 0;
        end else if (modo_processamento_ativo && !processing_done && 
                     rom_addr_counter < IMG_TOTAL_PIXELS_OR && 
                     coproc_pixel_in_ready) begin
            rom_addr_counter <= rom_addr_counter + 1;
        end
    end

    // --- Cálculo de Endereço VGA (Mantido) ---
    reg [18:0] ram_addr_vga_calc;
    wire [18:0] ram_addr_or = (y_delayed < IMG_HEIGHT_OR && x_delayed < IMG_WIDTH_OR) ? (y_delayed * IMG_WIDTH_OR + x_delayed) : 19'd0;
    wire [18:0] ram_addr_gra = (y_delayed < IMG_HEIGHT_GRA && x_delayed < IMG_WIDTH_GRA) ? (y_delayed * IMG_WIDTH_GRA + x_delayed) : 19'd0;
    wire [18:0] ram_addr_gra4 = (y_delayed < IMG_HEIGHT_GRA4 && x_delayed < IMG_WIDTH_GRA4) ? (y_delayed * IMG_WIDTH_GRA4 + x_delayed) : 19'd0;
    wire [18:0] ram_addr_peq = (y_delayed < IMG_HEIGHT_PEQ && x_delayed < IMG_WIDTH_PEQ) ? (y_delayed * IMG_WIDTH_PEQ + x_delayed) : 19'd0;

    always @(*) begin
        ram_addr_vga_calc = ram_addr_or; 
        case (SW[6:5])
            2'b01: begin 
                case (SW[3:0])
                    4'b0001:  ram_addr_vga_calc = ram_addr_gra4;
                    default:  ram_addr_vga_calc = ram_addr_or;
                endcase
            end
            2'b10: begin 
                case (SW[3:0])
                    4'b0001:  ram_addr_vga_calc = ram_addr_gra4; 
                    default:  ram_addr_vga_calc = ram_addr_or;
                endcase
            end
            default: begin 
                case (SW[3:0])
                    4'b0001, 4'b0010:  ram_addr_vga_calc = ram_addr_gra;
                    4'b0100, 4'b1000:  ram_addr_vga_calc = ram_addr_peq;
                    default:           ram_addr_vga_calc = ram_addr_or;
                endcase
            end
        endcase
    end
    
    // --- Lógica de Seleção de Fonte de Entrada (ROM) ---
    wire [7:0] saida_rom;
    wire [18:0] address_rom_read;
    wire [7:0]  entrada_vga;
    reg  process_done_latch = 0;

    assign address_rom_read = modo_processamento_ativo ? rom_addr_counter : ram_addr_or;
    
    // Mux de Entrada da ROM: Se WE=1 (HPS escrevendo input), usa addr_in. 
    wire [18:0] mem_address_final = we ? {4'b0, addr_in} : address_rom_read;
    
    imagem rom_inst_OR (
        .address(mem_address_final),
        .clock(clock_100),
        .data(data_in),          
        .wren(we),               
        .q(saida_rom)
    );

    // --- Coprocessador ---
    wire [7:0] pixel_coproc_out;
    wire       pixel_coproc_valid;
    wire coproc_start_signal = modo_processamento_ativo && !process_done_latch && image_loaded; 
    
    coprocessador coprocessador_inst (
        .clk(clk_25_reg), 
        .resetn(~processing_reset), 
        .start(coproc_start_signal),
        .largura_in(IMG_WIDTH_OR),
        .altura_in(IMG_HEIGHT_OR), 
        .SW(SW[3:0]),        
        .escala(SW[6:5]),    
        .pixel_in(saida_rom),
        .pixel_out(pixel_coproc_out), 
        .pixel_out_valid(pixel_coproc_valid),
        .processing_done(processing_done), 
        .pixel_in_ready(coproc_pixel_in_ready)
    );

    // =================================================================
    // CONTROLE DA RAM DE SAÍDA (RAM 2) E LEITURA HPS
    // =================================================================
    
    reg  [18:0] pixel_write_count = 0;
    
    always @(posedge clk_25_reg or posedge processing_reset) begin
        if (processing_reset) begin
            pixel_write_count  <= 0;
            process_done_latch <= 0;
        end else begin
            if (pixel_coproc_valid && !process_done_latch) begin
                pixel_write_count <= pixel_write_count + 1;
            end
            if (processing_done) begin
                process_done_latch <= 1'b1; 
            end
        end
    end

    // --- Construção do Endereço de Leitura do HPS (19 bits) ---
    // Como addr_in tem 15 bits e data_in tem 8 bits, combinamos eles
    // quando estamos no modo de LEITURA (SW[4]=1) e NÃO estamos escrevendo (we=0).
    // HPS Address = {data_in[3:0], addr_in}
    wire [18:0] hps_read_address_full = {data_in[3:0], addr_in};

    // --- MULTIPLEXADOR DE ENDEREÇO DA RAM (CRÍTICO) ---
    reg [18:0] ram_address_final;

    always @(*) begin
        if (!process_done_latch) begin
            // 1. Prioridade Máxima: Coprocessador escrevendo na RAM
            ram_address_final = pixel_write_count;
        end else if (hps_read_mode) begin
            // 2. Prioridade Média: HPS Lendo (SW[4] ativado)
            // O VGA perderá o acesso aqui, tela ficará preta/glitch
            ram_address_final = hps_read_address_full;
        end else begin
            // 3. Prioridade Padrão: VGA Lendo para display
            ram_address_final = ram_addr_vga_calc;
        end
    end

    wire        escrita_ram = pixel_coproc_valid && !process_done_latch; 
    wire [7:0]  ram_q;
    
    // RAM 2 (Saída Processada)
    ram_pri ram_inst (
        .address(ram_address_final),
        .clock(clock_100),
        .data(pixel_coproc_out),   
        .wren(escrita_ram), 
        .q(ram_q)
    );

    // --- Saída para HPS ---
    // Envia o dado lido da RAM diretamente para o PIO
    // Bits 9 e 8 usados como flags simples (opcional)
    // [7:0] O pixel solicitado pelo endereço hps_read_address_full
    assign to_hps_pio = {1'b0, 1'b0, ram_q};

    // --- MUX VGA ---
    // Se estivermos no modo de leitura HPS, o VGA não deve mostrar lixo
    // Forçamos entrada_vga para 0 (preto) se HPS estiver lendo
    assign entrada_vga = (hps_read_mode) ? 8'd0 : 
                         ((modo_processamento_ativo && process_done_latch) ? ram_q : saida_rom);

    // --- VGA Module ---
    vga_module vga_inst (
        .clock(clk_25_reg), 
        .reset(processing_reset), 
        .color_in(entrada_vga),
        .next_x(next_x),
        .next_y(next_y), 
        .hsync(hsync), 
        .vsync(vsync), 
        .red(red), 
        .green(green),
        .blue(blue), 
        .sync(sync), 
        .clk(clk), 
        .blank(blank)
    );

endmodule