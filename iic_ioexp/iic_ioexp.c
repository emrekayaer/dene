/*****************************************************************************
* Include Files                                                              *
*****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <time.h>

// Driver header file
#include <prussdrv.h>
#include <pruss_intc_mapping.h>

/*****************************************************************************
* Explicit External Declarations                                             *
*****************************************************************************/

/*****************************************************************************
* Local Macro Declarations                                                   *
*****************************************************************************/

#define PRU_NUM 	0

#define AM33XX

/*****************************************************************************
* Local Typedef Declarations                                                 *
*****************************************************************************/


/*****************************************************************************
* Local Function Declarations                                                *
*****************************************************************************/

static int LOCAL_Init ();

/*****************************************************************************
* Local Variable Definitions                                                 *
*****************************************************************************/


/*****************************************************************************
* Intertupt Service Routines                                                 *
*****************************************************************************/


/*****************************************************************************
* Global Variable Definitions                                                *
*****************************************************************************/

static void *pruDataMem;
static unsigned char *pruDataMem_byte;

/*****************************************************************************
* Global Function Definitions                                                *
*****************************************************************************/

int getkey() 
{
    int character;
    struct termios orig_term_attr;
    struct termios new_term_attr;

    /* set the terminal to raw mode */
    tcgetattr(fileno(stdin), &orig_term_attr);
    memcpy(&new_term_attr, &orig_term_attr, sizeof(struct termios));
    new_term_attr.c_lflag &= ~(ECHO|ICANON);
    new_term_attr.c_cc[VTIME] = 0;
    new_term_attr.c_cc[VMIN] = 0;
    tcsetattr(fileno(stdin), TCSANOW, &new_term_attr);

    /* read a character from the stdin stream without blocking */
    /*   returns EOF (-1) if no character is available */
    character = fgetc(stdin);

    /* restore the original terminal attributes */
    tcsetattr(fileno(stdin), TCSANOW, &orig_term_attr);

    return character;
}

int main (void)
{
    unsigned int ret;
    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
    int key;
    unsigned pass;
    unsigned short in, out;
    
    printf("\nINFO: initializing PRU subsystem.\r\n");
    /* Initialize the PRU */
    prussdrv_init ();		
    
    /* Open PRU Interrupt */
    ret = prussdrv_open(PRU_EVTOUT_0);
    if (ret)
    {
        printf("prussdrv_open open failed\n");
        return (ret);
    }
    
    /* Get the interrupt initialized */
    prussdrv_pruintc_init(&pruss_intc_initdata);

    /* Initialize example */
    printf("\tINFO: Initializing PRU data.\r\n");
    LOCAL_Init();
    
    /* Execute example on PRU */
    printf("\tINFO: Executing PRU code.\r\n");
    prussdrv_exec_program (PRU_NUM, "./iic_ioexp.bin");

	printf("\tINFO: PRESS [ESC] TO EXIT.\r\n\n");
	do
	{
//		pass = pruDataMem_byte[0] + (pruDataMem_byte[1] << 8) + (pruDataMem_byte[2] << 16) + (pruDataMem_byte[3] << 24);
		pass = *((unsigned*)&pruDataMem_byte[4]);
		in = *((unsigned short*)&pruDataMem_byte[0]); 
		out = in;			//echo inputs to outputs
		*((unsigned short*)&pruDataMem_byte[2]) = out; 
		
		printf("\tINFO: I/O exp update pass %10u | Inputs 0x%04hX -> Outputs 0x%04hX\r", pass, in, out);
		
		key = getkey();
	}
	while (key != 0x1B);

    pruDataMem_byte[8] = 0;		//clear flag to request PRU exit
    
    /* Wait until PRU0 has finished execution */
    printf("\n\n\tINFO: Waiting for HALT command.\r\n");
    prussdrv_pru_wait_event (PRU_EVTOUT_0);
    printf("\tINFO: PRU execution halted.\r\n");
    prussdrv_pru_clear_event (PRU0_ARM_INTERRUPT, PRU_EVTOUT_0);

    /* Disable PRU and close memory mapping*/
    prussdrv_pru_disable (PRU_NUM);
    prussdrv_exit ();

    return(0);

}

/*****************************************************************************
* Local Function Definitions                                                 *
*****************************************************************************/

static int LOCAL_Init ()
{  
    prussdrv_map_prumem (PRUSS0_PRU0_DATARAM, &pruDataMem);
    pruDataMem_byte = (unsigned char*) pruDataMem;

    pruDataMem_byte[0] = 0;		//input status
    pruDataMem_byte[1] = 0;		
    pruDataMem_byte[2] = 0;		//output status
    pruDataMem_byte[3] = 0;
 
    pruDataMem_byte[4] = 0;		//counter of update I/O cycles
    pruDataMem_byte[5] = 0;
    pruDataMem_byte[6] = 0;
    pruDataMem_byte[7] = 0; 
 
    pruDataMem_byte[8] = 1;		//flag for PRU exit request (clear to HALT PRU execution)
   

    return(0);
}
