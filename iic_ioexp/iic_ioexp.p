//by Rosso gianfranco
// gianfranco DOT rosso AT tiscali DOT it

.origin 0
.entrypoint _START

#include "iic_ioexp.hp"

//costants for access to CM_PER (Clock Module Peripheral Registers)
#define CM_PER_BASE			0x44E00000		//base of registers CM_PER
#define CM_PER_I2C1_CLKCTRL	0x48			//offset register CM_PER_I2C1_CLKCTRL


//costants for access to I2C1 module
#define I2C1_BASE			C2				//costant table entry for I2C1
#define I2C_SYSC			0x10			//offset of register I2C_SYSC
#define I2C_STAT_RAW		0x24			//offset of register I2C_STATUS_RAW
#define I2C_SYSS			0x90			//offset of register I2C_SYSS
#define I2C_CNT				0x98			//offset of register I2C_CNT
#define I2C_DATA			0x9C			//offset of register I2C_DATA
#define I2C_CON				0xA4			//offset of register I2C_CON
#define I2C_SA				0xAC			//offset of register I2C_SA
#define I2C_PSC				0xB0			//offset of register I2C_PSC
#define I2C_SCLL			0xB4			//offset of register I2C_SCLL
#define I2C_SCLH			0xB8			//offset of register I2C_SCLH

#define I2C_CMD_ENABLE		0x8400			//module I2C enabled as master
#define I2C_CMD_TX			0x0200			//module I2C trasmission
#define I2C_CMD_RX			0x0000			//module I2C receive
#define I2C_CMD_START		0x0001			//module I2C request START sequence
#define I2C_CMD_STOP		0x0002			//module I2C request STOP seqeunce


//costants for access to I/O expander MCP23017
#define IO_EXP0				0x20			//7bit I2C address of I/O expander 0 (inputs)
#define IO_EXP1				0x22			//7bit I2C address of I/O expander 1 (outputs)

#define IO_EXP_IODIRA		0x00			//address of register IODIRA  
#define IO_EXP_GPIOA		0x12			//address of register GPIOA 

//======================================================================

//macro that wait for end of STOP sequence
.macro I2C_WAIT_BY_STOP
_CHECK:
	LBCO r1.w0, I2C1_BASE, I2C_CON, 2
	QBBS _CHECK, r1.t1
.endm	

//macro that wait for end of bytes transfer
.macro I2C_WAIT_BY_COUNT
_CHECK:
	LBCO r1.w0, I2C1_BASE, I2C_CNT, 2
	QBNE _CHECK, r1.w0, 0
.endm

//macro that wait for a delay [us]
.macro WAIT_NUS
.mparam reg, wait
	MOV reg, wait << 8
_LOAD_1US:	
	MOV reg.b0, 100
	
_LOOP_1US:	
	SUB reg.b0, reg.b0, 1
	QBNE _LOOP_1US, reg.b0, 0
	
	SUB reg.w1, reg.w1, 1
	QBNE _LOAD_1US, reg.w1, 0	
.endm

//======================================================================

_START:
    //ENABLE OCP MASTER PORT (reset bit STANDBY_INIT nel register SYSCFG
    LBCO r0, C4, 4, 4
    CLR r0, r0, 4
    SBCO r0, C4, 4, 4

	//verify that I2C1 module is clocked (enabled)
	MOV	r4, CM_PER_BASE
_I2C1_CLK_ENABLE_CHECK:
	LBBO r3, r4, CM_PER_I2C1_CLKCTRL, 4
	QBEQ _I2C1_CLK_WAIT_ENABLED, r3.b0, 0x02
	MOV r3.b0, 0x02								//module clock isn't already enabled: enable it
	SBBO r3, r4, CM_PER_I2C1_CLKCTRL, 4
	QBA _I2C1_CLK_ENABLE_CHECK

_I2C1_CLK_WAIT_ENABLED:
	LBBO r3, r4, CM_PER_I2C1_CLKCTRL, 4
	QBNE _I2C1_CLK_WAIT_ENABLED, r3.b2, 0x00	//wait for clock enabled


	//------------------------------------------------------------------
	//configuration of I2C1 module
	
	//reset of I2C1 module
	MOV r1.w0, 0x0002	
	SBCO r1.w0, I2C1_BASE, I2C_SYSC, 2
	
	WAIT_NUS r3, 50000
	
	MOV r1.w0, 0x0308					//clock always active, no idle, no autoidle 
	SBCO r1.w0, I2C1_BASE, I2C_SYSC, 2
	
	
	//configure prescaler and SCL H/L time in order to have 400kHz
	MOV r1.b0, 1				//prescaler=1+1 --> ICLK=FCLK/prescaler=48/2=24MHz (nel reference manual recommend 24Mhz) 
	SBCO r1.b0, I2C1_BASE, I2C_PSC, 1
	
	MOV r1.b0, 23				//time SCL L=23+7 --> tLOW=1/ICLK*(SCLL+7)=1/24E6*(23+7)=1.25us
	SBCO r1.b0, I2C1_BASE, I2C_SCLL, 1
	
	MOV r1.b0, 25				//time SCL H=25+5 --> tHIGH=1/ICLK*(SCLH+5)=1/24E6*(25+5)=1.25us
	SBCO r1.b0, I2C1_BASE, I2C_SCLH, 1

	//enable module
	MOV r1.w0, I2C_CMD_ENABLE
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	//wait for module exits reset state
_WAIT_RDONE:
	LBCO r1, I2C1_BASE, I2C_SYSS, 4
	QBBC _WAIT_RDONE, r1.t0	

	//------------------------------------------------------------------
	//init IOEXP 0
	
	//slave address
	MOV r1.w0, IO_EXP0			
	SBCO r1.w0, I2C1_BASE, I2C_SA, 2

	//number of bytes to send
	MOV r1.w0, 3			
	SBCO r1.w0, I2C1_BASE, I2C_CNT, 2

	//fill the FIFO
	MOV r1, IO_EXP_IODIRA | 0x00FFFF00		//all pins as inputs (as POR)
	SBCO r1.b0, I2C1_BASE, I2C_DATA, 1
	SBCO r1.b1, I2C1_BASE, I2C_DATA, 1
	SBCO r1.b2, I2C1_BASE, I2C_DATA, 1

	//wait for Bus Free
_WAIT_BB:
	LBCO r1, I2C1_BASE, I2C_STAT_RAW, 4
	QBBS _WAIT_BB, r1.t12

	//write command
	MOV r1.w0, I2C_CMD_ENABLE | I2C_CMD_TX | I2C_CMD_START | I2C_CMD_STOP
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	I2C_WAIT_BY_STOP

	//------------------------------------------------------------------
	//init IOEXP 1
	
	//slave address
	MOV r1.w0, IO_EXP1			
	SBCO r1.w0, I2C1_BASE, I2C_SA, 2

	//number of bytes to send already set (same as before)

	//fill the FIFO
	MOV r1, IO_EXP_IODIRA | 0x00000000		//all pins as outputs
	SBCO r1.b0, I2C1_BASE, I2C_DATA, 1
	SBCO r1.b1, I2C1_BASE, I2C_DATA, 1
	SBCO r1.b2, I2C1_BASE, I2C_DATA, 1

	//write command
	MOV r1.w0, I2C_CMD_ENABLE | I2C_CMD_TX | I2C_CMD_START | I2C_CMD_STOP
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	I2C_WAIT_BY_STOP


	//------------------------------------------------------------------
	//cycle of I/O update

_IO_UPDATE_LOOP:
 
	//------------------------------------------------------------------
	//read inputs
	
	//slave address
	MOV r1.w0, IO_EXP0			
	SBCO r1.w0, I2C1_BASE, I2C_SA, 2

	//number of bytes to send
	MOV r1.w0, 1			
	SBCO r1.w0, I2C1_BASE, I2C_CNT, 2

	//fill the FIFO
	MOV r1, IO_EXP_GPIOA
	SBCO r1.b0, I2C1_BASE, I2C_DATA, 1 
 
 	//write command
	MOV r1.w0, I2C_CMD_ENABLE | I2C_CMD_TX | I2C_CMD_START
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	I2C_WAIT_BY_COUNT
 
 	//number of bytes to receive
	MOV r1.w0, 2			
	SBCO r1.w0, I2C1_BASE, I2C_CNT, 2

 	//read command
	MOV r1.w0, I2C_CMD_ENABLE | I2C_CMD_RX | I2C_CMD_START | I2C_CMD_STOP
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	I2C_WAIT_BY_STOP

	//read received data from FIFO
	LBCO r2.b1, I2C1_BASE, I2C_DATA, 1 
	LBCO r2.b2, I2C1_BASE, I2C_DATA, 1 
	
	SBCO r2.w1, CONST_PRUDRAM, 0, 2			//store status of inputs into the first word of PRU DATA RAM

	//------------------------------------------------------------------
	//write outputs

	//slave address
	MOV r1.w0, IO_EXP1			
	SBCO r1.w0, I2C1_BASE, I2C_SA, 2

	//number of bytes to send
	MOV r1.w0, 3			
	SBCO r1.w0, I2C1_BASE, I2C_CNT, 2

	//fill the FIFO
	MOV r2.b0, IO_EXP_GPIOA
	LBCO r2.w1, CONST_PRUDRAM, 2, 2			//read status of outputs from second word of PRU DATA RAM
	
	SBCO r2.b0, I2C1_BASE, I2C_DATA, 1 
	SBCO r2.b1, I2C1_BASE, I2C_DATA, 1 
	SBCO r2.b2, I2C1_BASE, I2C_DATA, 1 

	//write command
	MOV r1.w0, I2C_CMD_ENABLE | I2C_CMD_TX | I2C_CMD_START | I2C_CMD_STOP
	SBCO r1.w0, I2C1_BASE, I2C_CON, 2

	I2C_WAIT_BY_STOP
	
	//------------------------------------------------------------------
	//update I/O cycle counter
	LBCO r2, CONST_PRUDRAM, 4, 4		//load counter from second DWord of PRU DATA RAM
	ADD r2, r2, 1
	SBCO r2, CONST_PRUDRAM, 4, 4		//store updated counter
	
	//wait for rinfresh I/O every 1ms (about)
	WAIT_NUS r3, 760
	
	//------------------------------------------------------------------
	//exit flag check
    LBCO r2, CONST_PRUDRAM, 8, 1		//load exit flag from PRU DATA RAM
    QBNE _IO_UPDATE_LOOP, r2.b0, 0

_EXIT:
    //send interrupt to host to notify execution halt
    MOV R31.b0, PRU0_ARM_INTERRUPT+16

    HALT
