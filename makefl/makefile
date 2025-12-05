# Configuração de construção.
CC = gcc # Compilador

AS = as # Montador Assembly 

ARCH_FLAGS = -mthumb -march=armv7-a # Arquitetura ARM

CFLAGS = -Wall -Wextra -std=c99 -g $(ARCH_FLAGS) # Flags para o compilador

AFLAGS = -g $(ARCH_FLAGS) # Flags para o montador 

LDFLAGS = $(ARCH_FLAGS) # Flags para o linker 

TARGET = fpga_control

OBJECTS = main.o api.o

#  Regras de construção

# Alvo padrão: 'all' compila o executável.
all: $(TARGET)

# Executável depende de todos os arquivos objeto.
$(TARGET): $(OBJECTS)
	@echo "LNK: Linking $^ to create $(TARGET)..."
	$(CC) $(LDFLAGS) $^ -o $@


# Arquivo objeto main.o depende de 'api.h' 
main.o: main.c api.h
	@echo "CC: Compiling $<..."
	$(CC) $(CFLAGS) -c $< -o $@

# Usa o montador 'as' para gerar o arquivo objeto.
api.o: api.s
	@echo "AS: Assembling $<..."
	$(AS) $(AFLAGS) $< -o $@
