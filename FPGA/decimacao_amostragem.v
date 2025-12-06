/**********************************************************************************
* * Módulo: decimacao_amostragem
*
* Descrição: 
* Este módulo implementa um algoritmo de redução de imagem por decimação ou 
* amostragem (Nearest Neighbor para zoom out), com um fator de escala fixo 
* de 2x. Ele percorre a imagem de entrada e seleciona apenas um pixel de 
* cada bloco de 2x2, descartando os outros três. A lógica é baseada na 
* amostragem dos pixels que estão nas coordenadas (0,0), (0,2), (2,0), (2,2) etc.
*
**********************************************************************************/
module vizinho_proximo_out (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [9:0]  largura_in,
    input  wire [9:0]  altura_in,
    input  wire [7:0]  pixel_in,
    output reg  [7:0]  pixel_out,
    output reg         pixel_out_valid,
    output reg         processing_done,
    output wire        pixel_in_ready
);

    localparam [1:0] S_IDLE      = 2'b00;
    localparam [1:0] S_PROCESSANDO = 2'b01;
    localparam [1:0] S_FINALIZADO = 2'b10;

    reg [1:0] estado;
    reg [9:0] largura_reg, altura_reg;
    reg [9:0] x_in_count, y_in_count;

    assign pixel_in_ready = (estado == S_PROCESSANDO);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            estado <= S_IDLE;
            x_in_count <= 0;
            y_in_count <= 0;
            pixel_out_valid <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            processing_done <= 1'b0;
            case (estado)
                S_IDLE: begin
                    pixel_out_valid <= 1'b0;
                    if (start) begin
                        largura_reg <= largura_in;
                        altura_reg <= altura_in;
                        x_in_count <= 0;
                        y_in_count <= 0;
                        estado <= S_PROCESSANDO;
                    end
                end
                S_PROCESSANDO: begin
                    pixel_out_valid <= 1'b0;
                    
                    if (x_in_count[0] == 1'b0 && y_in_count[0] == 1'b0) begin
                        pixel_out <= pixel_in;
                        pixel_out_valid <= 1'b1;
                    end

                    if (x_in_count == largura_reg - 1) begin
                        x_in_count <= 0;
                        if (y_in_count == altura_reg - 1) begin
                            y_in_count <= 0;
                            processing_done <= 1'b1;
                            estado <= S_IDLE;
                        end else begin
                            y_in_count <= y_in_count + 1;
                        end
                    end else begin
                        x_in_count <= x_in_count + 1;
                    end
                end
                default: begin
                    estado <= S_IDLE;
                    pixel_out_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule