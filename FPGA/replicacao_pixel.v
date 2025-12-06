/**********************************************************************************
* * Módulo: replicacao_pixel
*
* Descrição: 
* Este módulo implementa o algoritmo de ampliação de imagem por replicação 
* de pixels (vizinho mais próximo). Ele opera com uma máquina de estados que:
* 1. (S_IDLE) Aguarda o sinal de início.
* 2. (S_RECEBENDO) Recebe uma linha da imagem de entrada e a expande 
* horizontalmente em um buffer interno, de acordo com o fator de escala.
* 3. (S_ENVIANDO) Envia a linha expandida múltiplas vezes para efetuar a 
* expansão vertical.
* O módulo gerencia o controle de fluxo e sinaliza a conclusão do processo.
*
**********************************************************************************/
module replicacao_pixel (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [1:0]  escala,
    input  wire [9:0]  largura_in,
    input  wire [9:0]  altura_in,
    input  wire [7:0]  pixel_in,
    output reg  [7:0]  pixel_out,
    output reg         pixel_out_valid,
    output reg         processing_done,
    output wire        pixel_in_ready
);

    localparam LARGURA_VGA = 640;
    localparam ALTURA_VGA  = 480;
    localparam LARGURA_SAIDA_MAXIMA = LARGURA_VGA;

    localparam [1:0] S_IDLE      = 2'b00,
                     S_RECEBENDO = 2'b01,
                     S_ENVIANDO  = 2'b10;

    reg [1:0] estado;
    reg [9:0] largura_reg, altura_reg, x_in_count, y_in_count;
    reg [11:0] x_out_count;
    reg [3:0]  row_out_count;
    reg [7:0] linha_expandida [0:LARGURA_SAIDA_MAXIMA-1];
    reg [3:0] fator;
    reg [11:0] largura_expandida;

    integer i;

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
            pixel_out <= 0;
            pixel_out_valid <= 0;
            processing_done <= 0;
            fator <= 2;
            largura_expandida <= 0;
        end else begin
            processing_done <= 0;
            case (estado)
                S_IDLE: begin
                    pixel_out_valid <= 0;
                    if (start) begin
                        case (escala)
                            2'b01: fator <= 4;
                            2'b10: fator <= 8;
                            default: fator <= 2;
                        endcase
                        largura_reg <= largura_in;
                        altura_reg  <= altura_in;
                        y_in_count <= 0;
                        x_in_count <= 0;
                        x_out_count <= 0;
                        row_out_count <= 0;
                        estado <= S_RECEBENDO;
                    end
                end
                S_RECEBENDO: begin
                    pixel_out_valid <= 0;
                    for (i=0; i<8; i=i+1) begin
                        if (i < fator && (x_in_count*fator+i) < LARGURA_VGA) begin
                            linha_expandida[x_in_count*fator+i] <= pixel_in;
                        end
                    end
                    if (x_in_count == largura_reg - 1) begin
                        largura_expandida <= (largura_reg * fator > LARGURA_VGA) ? LARGURA_VGA : largura_reg * fator;
                        x_in_count <= 0;
                        estado <= S_ENVIANDO;
                    end else begin
                        x_in_count <= x_in_count + 1;
                    end
                end
                S_ENVIANDO: begin
                    pixel_out_valid <= 1;
                    pixel_out <= linha_expandida[x_out_count];
                    if (x_out_count == largura_expandida - 1) begin
                        x_out_count <= 0;
                        if (row_out_count == fator-1) begin
                            row_out_count <= 0;
                            if (y_in_count == altura_reg - 1 || ((y_in_count+1)*fator >= ALTURA_VGA)) begin
                                processing_done <= 1;
                                estado <= S_IDLE;
                            end else begin
                                y_in_count <= y_in_count + 1;
                                estado <= S_RECEBENDO;
                            end
                        end else begin
                            row_out_count <= row_out_count + 1;
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