

<h3 align="center">Utilização de Coprocessador Gráfico para Redimensionamento de Imagens na Plataforma DE1-SoC</h3>

<p align="center">
  Este projeto implementa um módulo embarcado para sistemas de vigilância e exibição em tempo real. A solução integra um coprocessador gráfico desenvolvido na FPGA da placa DE1-SoC, drivers de dispositivo Linux e uma aplicação em C para manipulação de imagens (Zoom In/Out) controlada via mouse.
</p>

<div align="center">

![Status](https://img.shields.io/badge/Status-Etapa%203%20Concluída-green)
![Language](https://img.shields.io/badge/Linguagem-C%20%7C%20Assembly%20ARM-blue)
![Platform](https://img.shields.io/badge/Hardware-DE1--SoC-orange)

</div>

<div align="center">




[Sobre o projeto](#sobre-o-projeto) • [Requisitos](#requisitos) • [Solução](#solução)• [Arquitetura](#arquitetura-do-sistema) • [ Estrutura e ferramentas](#estrutura-e-ferramentas-utilizadas) • [Instalação](#instalação) •  [Fluxo de Dados](#fluxo-de-dados) • [Testes e Resultados](#testes-resultados) •  [Referências ](#referencias)


</div>

---

## 📄Sobre o Projeto

O presente projeto insere-se no âmbito do desenvolvimento da aplicação principal em linguagem C para o Hard Processor System (HPS) da plataforma DE1-SoC, que corresponde à terceira e crucial etapa do trabalho. Esta aplicação será a interface de usuário definitiva, responsável por carregar a imagem de um arquivo BITMAP, gerenciar a transferência de dados para a FPGA e acionar as operações de zoom.

A inovação desta fase reside na implementação de um controle de redimensionamento dinâmico via mouse. A aplicação C deverá permitir que o usuário utilize o mouse para definir uma região de interesse (janela) sobre a imagem original. A janela ampliada (zoom in), que deverá ser desenhada sobre a imagem original, poderá ter seu nível de ampliação controlado pelas teclas '+' (mais) e '-' (menos), proporcionando uma experiência de usuário mais interativa e precisa. O sucesso desta etapa valida a integração de periféricos complexos (como o mouse) com o módulo de processamento de imagem em tempo real, demonstrando a capacidade da solução embarcada para aplicações avançadas de visualização.

A solução é dividida em camadas de abstração:
1.  *Hardware (FPGA):* Coprocessador gráfico dedicado (CoLenda) e saída VGA.
2.  *Kernel Space (Linux):* Drivers desenvolvidos para gerenciar a comunicação HPS-FPGA, mouse USB e periféricos.
3.  *User Space (Aplicação C):* Software responsável por ler arquivos BMP, capturar eventos de mouse e enviar comandos de renderização.

### Etapas Desenvolvidas

* *Etapa 2 (API Assembly):* Desenvolvimento de uma biblioteca de funções (API) em Assembly para acesso aos registradores da FPGA e controle do coprocessador.
* *Etapa 3 (Aplicação Final):* Aplicação interativa que carrega imagens e permite seleção de região de interesse para zoom.

---

## 🗂️ Requisitos 

O sistema atende aos seguintes requisitos funcionais e de interação:

* *Carregamento de Imagem:* Leitura de arquivos .bmp (8-bits escala de cinza) e transferência para o coprocessador.
* *Interface de Texto:* Exibição das coordenadas (x, y) do mouse em tempo real no terminal.
* *Seleção de Região (Janela):*
    * Uso do mouse para definir dois cantos opostos da janela de ampliação.
    * Seleção confirmada ao pressionar o botão do mouse.
    * A janela selecionada é desenhada sobre a imagem original.
* *Controle de Zoom:*
    * *Tecla +:* Aplica Zoom In na janela selecionada.
    * *Tecla -:* Aplica Zoom Out (limitado à resolução original da imagem).

---
## ⚙️ Arquitetura 

A solução utiliza a arquitetura híbrida da DE1-SoC. O *HPS (ARM Cortex-A9)* executa o Linux e a lógica da aplicação, enquanto a *FPGA* realiza a aceleração gráfica.

<div align="center">
  <figure>  
    <img src="Docs/Imagens/sol-geral.png" alt="Arquitetura do Sistema">
    <figcaption>
      <p align="center"><strong>Figura 1</strong> - Fluxo de dados: Mouse/BMP -> Aplicação -> Driver -> FPGA</p>
    </figcaption>
  </figure>
</div>

### Componentes Principais
1.  *Aplicação C:* Realiza o parsing do BMP, calcula a interpolação dos pixels para o zoom e gerencia a seleção de algoritmos e fatores de zoom.
2.  *Drivers (Kernel Modules):*
    * Driver GPU: Gerencia a fila de instruções para garantir que a escrita na FPGA respeite o tempo de sincronismo de vídeo (V-Sync).
    * Driver Mouse: Captura eventos brutos do USB e converte para coordenadas de tela (640x480).
3.  *Hardware (FPGA):* Processa instruções de desenho de polígonos e renderização de pixels na memória de vídeo, além de seguir executando o processamento de pixels via algoritmos pré-programados nas etapas anteriores.



## 📦 Instalação

<summary><h3>Pré-requisitos</h3></summary>

* Placa de desenvolvimento DE1-SoC com Linux embarcado.
* Conexão via SSH .
* Compilador gcc e utilitário make.
* Arquivo de imagem .bmp (8-bits, resolução compatível).
* Mouse USB conectado à placa.

#### 1. Clonar o repositório
bash
git clone [https://github.com/mclara9593/coprocessadorAPI.git](https://github.com/mclara9593/coprocessadorAPI.git)


#### 2. Compilar o projeto Quartus dentro da pasta "fase2judoreaclara"

#### 3. Lançar projeto para a placa DE1-Soc.

 + Acessar a ferramenta ``programmer`` e clicar em start.

#### 4. Construir o código da terceira etapa. 

 bash
    $ cd cooprocessadorAPI
	$ make

#### 5. Executar interface de usuário.
 bash
   $ sudo ./projeto

## 🛠 Estruturas e ferramentas utilizadas
<details>
<summary><b>Sistema computacional DE1-SoC</b></summary>

### Sistema computacional DE1-SoC

<div align="center">
  <figure>  
    <img src="Docs/Imagens/diagramaDE1SoC_FPGAcademy.png" width="500px">
    <figcaption>
      <p align="center">

[*Figura 2* - Diagrama de Blocos da DE1-SoC](https://fpgacademy.org/index.html)

</p>
    </figcaption>
  </figure>
</div>

O diagrama de blocos do sistema computacional, apresentado na figura 2,  explicita os componentes do Cyclone® V da Intel®, bem como suas 
conexões. O HPS inclui um processador ARM® Cortex-A9 MPCore™ de 2 núcleos com uma distribuição Linux embarcada destinada a 
processamentos de propósito geral,  além da memória DDR3 e dos dispositivos periféricos. Já a FPGA possibilita uma variedade de 
implementações através da programação dos blocos lógicos.

> A comunicação bidirecional entre a o HPS e a FPGA se dá por meio das FPGA bridges. 
> No sentido HPS-FPGA, todos os dispositivos de entrada e saída (E/S) conectados à FPGA são acessíveis ao processador através do mapeamento de memória.
> As informações sobre o *endereçamento original* dos periféricos estão disponíveis na [documentação da placa](https://fpgacademy.org/index.html).
> 

<details>
<summary> <b>Compilador GNU</b> </summary>

### Compilador GNU

O GNU Compiler Collection GCC (Coleção de Compiladores GNU), ou GCC, é um conjunto de compiladores de código aberto desenvolvido pelo 
Projeto GNU que oferecem suporte a uma gama de 
linguagens de programação, incluindo C, C++, Fortran, Ada e Go. Esta ferramenta otimiza a compilação, ou seja a produção de código de 
máquina, nas várias linguagens e arquiteturas de 
processadores suportadas.

</details>
<details>

<summary> <b>VS Code</b> </summary>

### VS Code
O Visual Studio Code, ou VS Code, é um editor de texto gratuito com suporte a várias linguagens de programação, incluindo Python, Java, 
C, C++ e JavaScript. A ferramenta desenvolvida pela Microsoft Corporation dispõe de diversos recursos de depuração, destaque de erros, 
sugestões, personalização dentre outros para auxiliar a codificação.

Saiba mais na [documentação oficial programa](https://code.visualstudio.com/docs#vscode)

</details>
<details>

<summary> <b>Nano</b> </summary>

### Nano
Também, o editor de texto simples Nano, na versão 2.2.6, presente no Linux embarcado do Kit de desenvolvimento DE1-SoC foi utilizado 
para codificação da solução. O Nano é um software leve e que oferece uma interface de linha de comando intuitiva, tornando-o ideal para 
rápida edição de arquivos, scripts e outros documentos de texto.

</details>



### Visão geral da DE1-SoC

Equipado com processador, USB, memória DDR3, Ethernet e uma gama de periféricos, o kit de desenvolvimento DE1-SoC (Figura 1) integra no 
mesmo Cyclone® V da Intel®, sistema em chip (SoC), um hard processor system (HPS) a uma FPGA (Field Programmable Gate Arrays). Este 
design permite uma grande flexibilidade da placa nas mais variadas aplicações. Para o acesso ao sistema operacional Linux embarcado na 
placa, o protocolo de rede SSH (Secure Shell) foi utilizado, estabelecendo uma conexão criptografada para comunicação entre a placa e 
computador host.

<div align="center">
  <figure>  
    <img src="Docs/Imagens/kit_desenvolvimento_DE1-SoC.jpg" width="600px">
    <figcaption>
      <p align="center"> 

[*Figura 1* - Kit de Desenvolvimento DE1-SoC](https://fpgacademy.org/index.html)

</p>
    </figcaption>
  </figure>
</div>

</details>



## 💻 Solução Geral

A solução geral integra três componentes principais — *HPS (C + Linux), **API em Assembly* e *FPGA (Verilog)* — que trabalham em conjunto para permitir que o usuário selecione uma área específica da imagem por meio do *mouse, enviando dois pontos delimitadores que definem uma janela de zoom. A partir desses dados, o coprocessador passa a ler e processar apenas os pixels dentro dessa região, aplicando zoom in ou zoom out conforme solicitado. Para que isso fosse possível, foi necessário modificar a arquitetura inicial do coprocessador, que antes operava com entrada sequencial fixa e agora precisa lidar com **intervalos variáveis de leitura* definidos em tempo real.


### Ponte entre HPS e FPGA

A comunicação entre o software em execução no HPS e os periféricos implementados na FPGA ocorre através da *Lightweight HPS–to–FPGA Bridge (LWH2F)*. Esse barramento é configurado no Platform Designer e mapeado em um endereço físico fixo da memória do HPS, acessado diretamente pelo *User Space* por meio de:

- Abertura do arquivo de dispositivo `/dev/mem`;
- Mapeamento de memória virtual com a chamada `mmap()`;
- Escritas e leituras diretas via instruções `STR` e `LDR` no Assembly, utilizando os endereços virtuais obtidos.

Com isso, os periféricos da FPGA aparecem para o HPS como *endereços de memória*, permitindo interação de alta velocidade sem a necessidade de desenvolver drivers de kernel complexos.

O mapeamento utilizado no projeto é:
* **LW_BRIDGE_BASE:** `0xFF200000` 
* **LW_BRIDGE_SPAN:** `0x00020000` 

A API em Assembly (`api.s`) abstrai esses endereços e gerencia os offsets específicos para escrita e leitura no PIO (Parallel I/O):

- **PIO_OUTPUT_OFFSET (`0x00000000`):** Usado para enviar pacotes de 32 bits para a FPGA. O driver compacta no mesmo registrador os sinais de **Controle** (bits 31-24), **Write Enable** (bit 23), **Dados do Pixel** (bits 22-15) e **Endereço de Memória** (bits 14-0).
- **PIO_INPUT_OFFSET (`0x00000010`):** Usado para ler o retorno da FPGA. O HPS lê deste registrador para obter o valor do pixel armazenado na RAM ou flags de status do coprocessador.

---

### Lógica de Seleção via Mouse

Para viabilizar a interação em tempo real, foi desenvolvido um algoritmo no *User Space* (arquivo `main.c`) que interpreta o protocolo padrão PS/2 do mouse via arquivo de dispositivo do Linux (`/dev/input/mice`). Diferente de um sistema operacional desktop convencional que gerencia janelas automaticamente, a aplicação embarcada realiza a leitura byte-a-byte dos pacotes de movimento ($dx, dy$) e cliques.

A lógica implementada converte o movimento relativo do mouse em coordenadas absolutas de tela, aplicando uma função que garante que o cursor e a janela de seleção permaneçam estritamente dentro dos limites da resolução da FPGA (160x120). Ao clicar e arrastar, a aplicação calcula instantaneamente a geometria do retângulo (origem, largura e altura), permitindo que a renderização da janela de zoom ocorra exatamente sobre a área de interesse do usuário.

### Endereçamento Direto e Sobreposição (Overlay)

Para projetar a janela de zoom sobre a imagem original, o sistema de endereçamento foi modificado . Enquanto nas etapas anteriores a escrita era puramente sequencial, a nova API (`escrever_pixel_end` em `api.s`) permite que o HPS escreva pixels em endereços específicos da RAM da FPGA.kl,ll

O cálculo de endereço segue a equação linear:
$$Endereço_{Fisico} = (Y_{atual} \times Largura_{FPGA}) + X_{atual}$$

Isso permite a técnica de *Overlay*: a aplicação mantém a imagem original em um *buffer* de background e, quando o zoom é ativado, sobrescreve na memória da FPGA apenas os pixels correspondentes à área da janela. Isso cria a ilusão de uma "lupa" flutuante sem a necessidade de processar a imagem inteira a cada quadro.

 ### FSM de Controle de Interação (Software)

 + Antes de permitir que o usuário interaja, o sistema envia a imagem atual para a FPGA processar o Zoom 2x e o Zoom 4x e salva os resultados na memória RAM.

+ Dado que a complexidade de gerenciar eventos de mouse, cliques e renderização condicional é elevada, a arquitetura de controle foi estruturada em uma **Máquina de Estados Finitos (FSM)** implementada na aplicação em C (`modo_mouse_interativo`). Os estados definidos são:

1.  **ESTADO LIVRE (Idle):** O sistema monitora o movimento do mouse apenas para desenhar o cursor. A imagem exibida é a original estática.
2.  **ESTADO DEFININDO JANELA :** Ao detectar o clique do botão esquerdo, o sistema captura a coordenada inicial ($P_1$) e atualiza dinamicamente o retângulo de seleção conforme o mouse se move, fornecendo feedback visual ao usuário.
3.  **ESTADO TRAVADO (Locked/Zoomed):** Ao soltar o botão, a janela é fixada. O sistema entra no modo de processamento, onde captura os pixels da região selecionada, busca os dados ampliados correspondentes e os envia para a FPGA, aplicando o Zoom In ou Zoom Out conforme comandos do teclado (+/-).

 ### Processamento de Pixels com Cache de Hardware

Para otimizar o desempenho e evitar latência durante a movimentação da janela de zoom, foi implementada uma estratégia de **Cache de Zoom Gerado por Hardware**.
Ao iniciar o sistema, a aplicação instrui a FPGA a processar e retornar as versões completas da imagem nos níveis de Zoom 2x e 4x (função `gerar_cache_zooms`). Esses dados são armazenados na memória RAM do HPS.

Quando o usuário define uma janela de zoom:
1.  A aplicação não precisa recalcular a interpolação em tempo real.
2.  Ela recorta a região correspondente diretamente dos buffers de cache (2x ou 4x).
3.  Envia apenas esse recorte para a FPGA via ponte *Lightweight*.

Essa abordagem híbrida aproveita a velocidade da FPGA para gerar os dados iniciais e a flexibilidade do HPS para gerenciar a janela móvel.

 ### Integração com o VGA (Renderização Parcial)

A integração final ocorre no controlador de vídeo (`processo_imagem.v`). Foi introduzido um multiplexador de prioridade no acesso à memória RAM de vídeo. O controlador VGA lê continuamente a memória para enviar o sinal ao monitor. Contudo, quando a aplicação HPS envia um novo pixel da janela de zoom, o hardware prioriza essa escrita.

O resultado visual é a mesclagem perfeita entre o fundo (imagem original lida da ROM/RAM) e a janela de destaque (escrita dinamicamente pelo HPS), permitindo que o usuário visualize o detalhe ampliado contextualizado na imagem global.

 ### Comunicação Dinâmica HPS ↔ Coprocessador

A comunicação evoluiu de um fluxo unidirecional para um sistema de **Feedback de Controle**. O HPS agora não apenas envia dados, mas lê o estado da FPGA (via flags no PIO) para sincronizar as operações. O uso da instrução `mmap` permite que a aplicação C manipule os registradores de controle da FPGA (`SW` virtuais) para alternar instantaneamente entre os modos de operação (visualização normal vs. visualização com zoom), garantindo que a troca de contexto visual seja fluida e livre de artefatos na tela.

