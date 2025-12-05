/**********************************************************************************
* * Módulo: coprocessador
*
* Descrição: 
* Este módulo atua como um coprocessador de imagem, funcionando como um wrapper 
* que seleciona e gerencia a execução de diferentes algoritmos de 
* redimensionamento de imagem (zoom in e zoom out). Com base nas entradas de 
* controle (SW), ele instancia e direciona o fluxo de dados para um dos 
* seguintes submódulos: replicação de pixel, vizinho mais próximo (in/out) 
* ou média de blocos. Ele multiplexa as saídas do algoritmo selecionado e 
* gerencia os sinais de controle de fluxo (handshake) com o módulo principal.
*
**********************************************************************************/
module coprocessador (
    input  wire clk,
    input  wire resetn,
    input  wire start,
    input  wire [9:0] largura_in,
    input  wire [9:0] altura_in,
    input  wire [3:0] SW,
    input  wire [7:0] pixel_in,
    input  wire [1:0] escala,
    output reg  [7:0] pixel_out,
    output reg  pixel_out_valid,
    output reg  processing_done,
    output wire pixel_in_ready
);

    wire [7:0] out_algoritmo_re;
    wire       out_algoritmo_valid_re;
    wire       done_algoritmo_re;
    wire       ready_algoritmo_re; 

    wire [7:0] out_algoritmo_mb;
    wire       out_algoritmo_valid_mb;
    wire       done_algoritmo_mb;
    wire       ready_algoritmo_mb; 

    wire [7:0] out_algoritmo_vi;
    wire       out_algoritmo_valid_vi;
    wire       done_algoritmo_vi;
    wire       ready_algoritmo_vi; 

    wire [7:0] out_algoritmo_vo;
    wire       out_algoritmo_valid_vo;
    wire       done_algoritmo_vo;
    wire       ready_algoritmo_vo; 

    reg ready_out_reg;
    assign pixel_in_ready = ready_out_reg;

    replicacao_pixel replicacao_pixel_inst (
        .clk(clk), 
        .resetn(resetn), 
        .start(start), 
        .largura_in(largura_in), 
        .altura_in(altura_in),
        .pixel_in(pixel_in), 
        .pixel_out(out_algoritmo_re), 
        .pixel_out_valid(out_algoritmo_valid_re),
        .processing_done(done_algoritmo_re), 
        .escala(escala),
        .pixel_in_ready(ready_algoritmo_re)
    );
    
    media_de_blocos media_de_blocos_inst ( 
        .clk(clk), 
        .resetn(resetn), 
        .start(start), 
        .largura_in(largura_in), 
        .altura_in(altura_in),
        .pixel_in(pixel_in), .pixel_out(out_algoritmo_mb), 
		  .pixel_out_valid(out_algoritmo_valid_mb),
        .processing_done(done_algoritmo_mb), 
        .pixel_in_ready(ready_algoritmo_mb) 
    );
    
    vizinho_proximo_in vizinho_proximo_in_inst (
        .clk(clk), 
        .resetn(resetn), 
        .start(start), 
        .largura_in(largura_in), 
        .altura_in(altura_in),
        .pixel_in(pixel_in), 
        .pixel_out(out_algoritmo_vi), 
        .pixel_out_valid(out_algoritmo_valid_vi),
        .processing_done(done_algoritmo_vi), 
        .pixel_in_ready(ready_algoritmo_vi)
    );
    
    vizinho_proximo_out vizinho_proximo_out_inst (
        .clk(clk), 
        .resetn(resetn), 
        .start(start), 
        .largura_in(largura_in), 
        .altura_in(altura_in),
        .pixel_in(pixel_in), 
        .pixel_out(out_algoritmo_vo), 
        .pixel_out_valid(out_algoritmo_valid_vo),
        .processing_done(done_algoritmo_vo), 
        .pixel_in_ready(ready_algoritmo_vo)
    );

    always @(*) begin
        case (SW)
            4'b0001: begin
                pixel_out       = out_algoritmo_re;
                pixel_out_valid = out_algoritmo_valid_re;
                processing_done = done_algoritmo_re;
                ready_out_reg   = ready_algoritmo_re;
            end
            4'b0010: begin
                pixel_out       = out_algoritmo_vi;
                pixel_out_valid = out_algoritmo_valid_vi;
                processing_done = done_algoritmo_vi;
                ready_out_reg   = ready_algoritmo_vi;
            end
            4'b0100: begin
                pixel_out       = out_algoritmo_vo;
                pixel_out_valid = out_algoritmo_valid_vo;
                processing_done = done_algoritmo_vo;
                ready_out_reg   = ready_algoritmo_vo;
            end
            4'b1000: begin
                pixel_out       = out_algoritmo_mb;
                pixel_out_valid = out_algoritmo_valid_mb;
                processing_done = done_algoritmo_mb;
                ready_out_reg   = ready_algoritmo_mb;
            end
            default: begin
                pixel_out       = pixel_in;
                pixel_out_valid = 1'b1; 
                processing_done = 1'b0; 
                ready_out_reg   = 1'b0; 
            end
        endcase
    end
endmodule