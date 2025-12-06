/**********************************************************************************
* * Módulo: media_de_blocos
*
* Descrição: 
* Este módulo implementa um algoritmo de redução de imagem (zoom out) por um 
* fator fixo de 2x. Ele processa a imagem de entrada em blocos de 2x2 pixels
* e calcula a média dos quatro pixels de cada bloco. O resultado da média 
* se torna um único pixel na imagem de saída, que terá metade da largura e 
* metade da altura da imagem original. Um buffer de linha (`line_buffer`) é 
* usado para armazenar a linha anterior e permitir o acesso ao bloco 2x2.
* A operação é controlada por uma máquina de estados.
*
**********************************************************************************/
module media_de_blocos (
    input  wire clk,
    input  wire resetn,
    input  wire start,
    input  wire [9:0] largura_in,
    input  wire [9:0] altura_in,
    input  wire [7:0] pixel_in,
    output reg  [7:0] pixel_out,
    output reg  pixel_out_valid,
    output reg  processing_done,
    output wire pixel_in_ready
);

    localparam LARGURA_MAXIMA = 640;
    localparam [1:0] S_IDLE = 2'b00, S_PREENCHE_BUFFER = 2'b01, S_PROCESSA = 2'b10;

    reg [1:0] estado;
    reg [9:0] largura_reg, altura_reg, x_count, y_count;
    reg [7:0] line_buffer [0:LARGURA_MAXIMA-1];
    reg [7:0] pixel_atual_esq, pixel_buffer_esq, pixel_de_cima;
    reg [10:0] soma;

    assign pixel_in_ready = (estado != S_IDLE);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            estado <= S_IDLE;
            largura_reg <= 0;
            altura_reg <= 0;
            x_count <= 0;
            y_count <= 0;
            pixel_out <= 8'd0;
            pixel_out_valid <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            pixel_out_valid <= 1'b0;
            processing_done <= 1'b0;
            case (estado)
                S_IDLE: begin
                    if (start) begin
                        largura_reg <= (largura_in > LARGURA_MAXIMA) ? LARGURA_MAXIMA : largura_in;
                        altura_reg <= altura_in;
                        x_count <= 0;
                        y_count <= 0;
                        estado <= S_PREENCHE_BUFFER;
                    end
                end
                S_PREENCHE_BUFFER: begin
                    line_buffer[x_count] <= pixel_in;
                    if (x_count == largura_reg - 1) begin
                        x_count <= 0;
                        y_count <= 1;
                        estado <= S_PROCESSA;
                    end else begin
                        x_count <= x_count + 1;
                    end
                end
                S_PROCESSA: begin
                    pixel_de_cima <= line_buffer[x_count];
                    line_buffer[x_count] <= pixel_in;
                    if (x_count[0] == 1'b0) begin
                        pixel_atual_esq <= pixel_in;
                        pixel_buffer_esq <= pixel_de_cima;
                    end else begin
                        if (y_count[0] == 1'b1) begin
                            soma = pixel_atual_esq + pixel_in + pixel_buffer_esq + pixel_de_cima;
                            pixel_out <= soma >> 2;
                            pixel_out_valid <= 1'b1;
                        end
                    end
                    if (x_count == largura_reg - 1) begin
                        x_count <= 0;
                        if (y_count == altura_reg - 1) begin
                            y_count <= 0;
                            estado <= S_IDLE;
                            processing_done <= 1'b1;
                        end else begin
                            y_count <= y_count + 1;
                        end
                    end else begin
                        x_count <= x_count + 1;
                    end
                end
                default: estado <= S_IDLE;
            endcase
        end
    end
endmodule