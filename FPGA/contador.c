/*
Desenvolva um programa em C para o HPS da DE1-SoC que funcione de forma contínua, lendo
o estado das chaves da placa e exibindo, por meio dos LEDs vermelhos, a quantidade total de
chaves que estão ligadas. 

A exibição deve ser feita de forma progressiva: se nenhuma chave estiver
ativada, 

Os LEDs devem acender sequencialmente, da direita para a esquerda, indicando a quantidade de chaves ativas.
*/

#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include "./hps_0.h"

#define LW_BRIDGE_BASE 0xFF200000
#define LW_BRIDGE_SPAM 0x00005000

int main(void)
{
    volatile int * LEDR_ptr; // virtual address pointer to red LEDs
    int fd;                  // used to open /dev/mem
    void *LW_virtual;        // physical addresses for light-weight bridge

    // Open /dev/mem to give access to physical addresses
    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf ("ERROR: could not open \"/dev/mem\"...\n");
        return (-1);
    }

    // Get a mapping from physical addresses to virtual addresses
    LW_virtual = mmap (NULL, LW_BRIDGE_SPAM, (PROT_READ | PROT_WRITE),
    MAP_SHARED, fd, LW_BRIDGE_BASE);
    
    if (LW_virtual == MAP_FAILED) {
        printf ("ERROR: mmap() failed...\n");
        close (fd);
        return (-1);
    }

    // Set virtual address pointer to I/O port
    LEDR_ptr = (int *) (LW_virtual + PIO_LED_BASE);
    
    *LEDR_ptr = *LEDR_ptr - 1; // Sub 1 to the I/O register

    // Close the previously-opened virtual address mapping
    if (munmap (LW_virtual, LW_BRIDGE_SPAM) != 0) {
        printf ("ERROR: munmap() failed.\n");
        return (-1);
    }
    
    // Close /dev/mem to give access to physical addresses
    close (fd);
    
    return 0;
}