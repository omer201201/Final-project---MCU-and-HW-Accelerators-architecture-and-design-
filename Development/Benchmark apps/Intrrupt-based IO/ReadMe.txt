=======================================================================================
					Description of the application test1:
=======================================================================================
Input:  KEY3, KEY2, KEY1, SW0
Output: PORT_HEX0,PORT_HEX1,PORT_HEX2,PORT_HEX3,PORT_HEX4,PORT_HEX5,PORT_LEDR
RESET:  KEY0
----------------------------------------------------------------------------------------
On RESET:
--------
*)clear (turn off) the six HEXs and red LEDRs[7-0]
*)set the value of delay cycles of the delay routine (SW0=0: short delay, SW0=1: long delay)   

On KEY1 pushing:
---------------
The FSM's state1 is chosen:
print onto HEX5,HEX4 the value of arr1[i] 

On KEY2 pushing:
---------------
The FSM's state2 is chosen:
print onto HEX3,HEX2 the value of arr2[i]

On KEY3 pushing:
---------------
The FSM's state3 is chosen: 
*)print onto HEX1,HEX0 the qoutient value of arr1[i]/arr2[i]
*)print onto LEDRs[7-0] the reminder value of arr1[i]%arr2[i]
*)i=(i<SIZE)?i+1 :0
*)delay
========================================================================================
					Description of the source code test2:
========================================================================================
Input:  KEY3, KEY2, KEY1
Output: PORT_HEX0,PORT_HEX1,PORT_HEX2,PORT_HEX3,PORT_HEX4,PORT_HEX5,PORT_LEDR
RESET:  KEY0
----------------------------------------------------------------------------------------
On RESET:
--------
*)Every 1sec, that is period of SMCLK cycles (value of 0x01312D00 is for SMCLK=20MHz): a0=a0+1
*)The FSM's state0 is chosen: print onto HEX1,HEX0 the value of a0

On KEY1 pushing:
---------------
The FSM's state1 is chosen:
print onto HEX3,HEX2 the value of a0 

On KEY2 pushing:
---------------
The FSM's state2 is chosen:
print onto HEX5,HEX4 the value of a0 

On KEY3 pushing:
---------------
The FSM's state3 is chosen:
print onto LEDRs[7-0] the value of a0 

========================================================================================
					Description of the source code test3:
========================================================================================
Input:  KEY3, KEY2, KEY1
Output: PORT_HEX0,PORT_HEX1,PORT_HEX2,PORT_HEX3,PORT_HEX4,PORT_HEX5,PORT_LEDR
RESET:  KEY0
----------------------------------------------------------------------------------------
On RESET:
--------
*)Every 1sec, that is period of SMCLK cycles (value of 0x01312D00 is for SMCLK=20MHz): a0=a0+1
*)The FSM's state0 is chosen: print onto LEDRs[7-0] the value of a0

On KEY1 pushing:
---------------
*)Every 0.5sec, that is period of SMCLK/2 cycles (value of 0x01312D00/2 is for SMCLK=20MHz): a0=a0+1
*)The FSM's state1 is chosen: print onto HEX1,HEX0 the value of a0

On KEY2 pushing:
---------------
*)Every 0.25sec, that is period of SMCLK/4 cycles (value of 0x01312D00/4 is for SMCLK=20MHz): a0=a0+1
*)The FSM's state2 is chosen: print onto HEX3,HEX2 the value of a0

On KEY3 pushing:
---------------
*)Every 0.125sec, that is period of SMCLK/8 cycles (value of 0x01312D00/8 is for SMCLK=20MHz): a0=a0+1
*)The FSM's state3 is chosen: print onto HEX5,HEX4 the value of a0

=====================================================================================
										Description of the source code test4:
=====================================================================================
Input:  KEY3, KEY2, KEY1
Output: PORT_HEX0,PORT_HEX1,PORT_HEX2,PORT_HEX3,PORT_HEX4,PORT_HEX5,PORT_LEDR,PWM_PIN
RESET:  KEY0
--------------------------------------------------------------------------------------
On RESET:
--------
clear all HEXs

On KEY1 pushing:
---------------
*)The BT timer is configured to compare mode
*)The interrupt interval is updated in a row for each KEY1 pushing from values 1sec,0.5sec,0.25sec,0.125sec  
*)For every interval value: a0=a0+1; print onto HEXsArr the value of a0 

On KEY2 pushing:
---------------
*)The BT timer is configured to output compare mode, PWM output signal=5kHZ
*)The PWM output signal duty-cycle is updated in a row for each KEY2 pushing from values 0.5,0.25,0.125,0.0625  


On KEY3 pushing:
---------------
*)The BT timer is configured to input capture mode
*)at the first KEY3 pushing:
	The application measures the runtime of two arrays division element by element
*)at the second KEY3 pushing:
	The application measures the runtime of two arrays modulu element by element

									
