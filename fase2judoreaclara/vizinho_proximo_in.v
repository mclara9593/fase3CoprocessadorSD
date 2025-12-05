/**********************************************************************************
* * Módulo: vizinho_proximo_in
*
* Descrição: 
* Este módulo implementa o algoritmo de ampliação de imagem "vizinho mais 
* próximo" (Nearest Neighbor) com um fator de escala fixo de 2x. Ele dobra
* as dimensões da imagem de entrada replicando cada pixel horizontalmente e 
* depois replicando cada linha verticalmente. A operação é controlada por uma 
* máquina de estados que gerencia o recebimento e o envio dos pixels.
*
**********************************************************************************/
module vizinho_proximo_in (
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
    localparam LARGURA_SAIDA_MAXIMA = LARGURA_MAXIMA * 2;
    localparam [1:0] S_IDLE = 2'b00, S_RECEBENDO = 2'b01, S_ENVIANDO = 2'b10;

    reg [1:0] estado;
    reg [9:0] largura_reg, altura_reg, x_in_count, y_in_count;
    reg [10:0] x_out_count;
    reg row_out_count;
    reg [7:0] linha_expandida [0:LARGURA_SAIDA_MAXIMA-1];

    assign pixel_in_ready = (estado == S_RECEBENDO);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            estado <= S_IDLE;
            largura_reg <= 0;
            altura_reg <= 0;
            x_in_count <= 0;
            y_in_count <= 0;
            x_out_count <= 0;
            row_out_count <= 0;
            pixel_out <= 8'd0;
            pixel_out_valid <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            processing_done <= 1'b0;
            case (estado)
                S_IDLE: begin
                    pixel_out_valid <= 1'b0;
                    if (start) begin
                        largura_reg <= (largura_in > LARGURA_MAXIMA) ? LARGURA_MAXIMA : largura_in;
                        altura_reg <= altura_in;
                        y_in_count <= 0;
                        x_in_count <= 0;
                        x_out_count <= 0;
                        row_out_count <= 0;
                        estado <= S_RECEBENDO;
                    end
                end
                S_RECEBENDO: begin
                    pixel_out_valid <= 1'b0;
                    linha_expandida[x_in_count * 2] <= pixel_in;
                    linha_expandida[x_in_count * 2 + 1] <= pixel_in;
                    if (x_in_count == largura_reg - 1) begin
                        x_in_count <= 0;
                        estado <= S_ENVIANDO;
                    end else begin
                        x_in_count <= x_in_count + 1;
                    end
                end
                S_ENVIANDO: begin
                    pixel_out_valid <= 1'b1;
                    pixel_out <= linha_expandida[x_out_count];
                    if (x_out_count == (largura_reg * 2) - 1) begin
                        x_out_count <= 0;
                        if (row_out_count == 1'b1) begin
                            row_out_count <= 1'b0;
                            if (y_in_count == altura_reg - 1) begin
                                processing_done <= 1'b1;
                                estado <= S_IDLE;
                            end else begin
                                y_in_count <= y_in_count + 1;
                                estado <= S_RECEBENDO;
                            end
                        end else begin
                            row_out_count <= 1'b1;
                        end
                    end else begin
                        x_out_count <= x_out_count + 1;
                    end
                end
                default: estado <= S_IDLE;
            endcase
        end
    end
endmodule