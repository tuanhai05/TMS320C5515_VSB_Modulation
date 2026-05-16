/*****************************************************************************/
/* FILENAME: main.c                                                          */
/* DESCRIPTION: VSB Modulation and Demodulation on TMS320C5515 DSP          */
/* INPUT: 4 Tones Multi-sinusoidal Message (300, 500, 700, 900 Hz)          */
/* OUTPUT:                                                                   */
/* - Left codec channel: Demodulated (recovered) signal                    */
/* - Right codec channel: Original message signal                          */
/* - graph_input: Stores original message signal                           */
/* - graph_modulated: Stores VSB modulated signal                          */
/* - graph_output: Stores demodulated signal                               */
/* OLED Display: "VSB MODULATION - GROUP: 6"                                 */
/*****************************************************************************/

#include "stdio.h"
#include "usbstk5515.h"
#include "usbstk5515_i2c.h"
#include "aic3204.h"
#include "sinewaves.h"
#include "PLL.h"
#include <math.h>

#define PI 3.14159265358979323846
#define SAMPLES_PER_SECOND 48000
#define GAIN_IN_dB 5

/* 4 Tones Message signal parameters */
#define FREQ_1 300
#define FREQ_2 500
#define FREQ_3 700
#define FREQ_4 900

/* Amplitude scaling to prevent 16-bit signed integer overflow */
#define TONE_AMP 4000.0

/* Carrier frequency */
#define CARRIER_FREQ_HZ     10000

#define Amp  1
#define GRAPH_N  1000

/* Graph buffers for CCS visualization (3-stage analysis) */
#pragma DATA_SECTION(graph_input, ".bss")
volatile Int16 graph_input[GRAPH_N];      /* 1. Original Message Signal */

#pragma DATA_SECTION(graph_modulated, ".bss")
volatile Int16 graph_modulated[GRAPH_N];  /* 2. Modulated VSB High-Frequency Signal */

#pragma DATA_SECTION(graph_output, ".bss")
volatile Int16 graph_output[GRAPH_N];     /* 3. Demodulated Recovered Signal */

volatile Uint16 graph_index = 0;
volatile Uint16 graph_ready = 0;

/* Codec variables */
Int16 left_output;
Int16 right_output;

/* Working variables */
Int16 sine_msg;
Int16 vsb_output;
Int16 demod_signal;

/* Time variables for signal generation */
static float t = 0.0;
static float dt = 1.0 / 48000.0;

/* ======================================================================== */
/* FILTER COEFFICIENTS (Q15 Fixed-Point Format)                             */
/* ======================================================================== */

/* 1. VSB Band-Pass Filter (49-tap BPF) */
Int16 BP[49] = {
      56,   -46,   -39,   -39,   -82,    85,   311,      7,  -590,  -308,
     793,    816,  -773, -1442,   419,  2005,   282, -2297, -1219,  2156,
    2169,  -1540, -2880,   560,  3142,   560, -2880, -1540,  2169,  2156,
   -1219,  -2297,   282,  2005,   419, -1442,  -773,   816,   793,  -308,
    -590,      7,   311,    85,   -82,   -39,   -39,   -46,    56
};
Int16 Temp[49] = {0};

/* 2. Demodulation Low-Pass Filter (97-tap LPF from MATLAB float matrix) */
#define LPF_LBL 97
Int16 LPF_COEFF[97] = {
    0,     3,     7,    10,    16,    20,    26,    33,    36,    43,
   46,    46,    43,    39,    29,    16,     0,   -23,   -49,   -79,
 -111,  -144,  -177,  -210,  -233,  -252,  -262,  -259,  -242,  -210,
 -157,   -88,     0,   108,   233,   377,   531,   698,   872,  1045,
 1222,  1389,  1547,  1688,  1812,  1910,  1986,  2028,  2045,  2028,
 1986,  1910,  1812,  1688,  1547,  1389,  1222,  1045,   872,   698,
  531,   377,   233,   108,     0,   -88,  -157,  -210,  -242,  -259,
 -262,  -252,  -233,  -210,  -177,  -144,  -111,   -79,   -49,   -23,
    0,    16,    29,    39,    43,    46,    46,    43,    36,    33,
   26,    20,    16,    10,     7,     3,     0
};
Int16 LPF_Temp[97] = {0};

/* ======================================================================== */
/* OLED/LCD I2C DISPLAY FUNCTIONS                                           */
/* ======================================================================== */
#define OLED_I2C_ADDR 0x3C
static Int16 OLED_send(Uint16 comdat, Uint16 data) {
    Uint8 cmd[2]; cmd[0] = comdat & 0x00FF; cmd[1] = data & 0x00FF;
    return USBSTK5515_I2C_write(OLED_I2C_ADDR, cmd, 2);
}
static void OLED_init() {
    USBSTK5515_I2C_init(); USBSTK5515_waitusec(100); 
    OLED_send(0x00, 0x00); OLED_send(0x00, 0x10); OLED_send(0x00, 0x40); 
    OLED_send(0x00, 0x81); OLED_send(0x00, 0x7F); OLED_send(0x00, 0xA1); 
    OLED_send(0x00, 0xA6); OLED_send(0x00, 0xA8); OLED_send(0x00, 0xD3); 
    OLED_send(0x00, 0x00); OLED_send(0x00, 0xAF); OLED_send(0x00, 0x2E); 
}
static void OLED_printLetter(Uint16 a, Uint16 b, Uint16 c, Uint16 d, Uint16 e) {
    OLED_send(0x40, a); OLED_send(0x40, b); OLED_send(0x40, c); OLED_send(0x40, d); OLED_send(0x40, e); OLED_send(0x40, 0x00);
}
static void display_VSB_Group() {
    Int16 i;
    OLED_send(0x00, 0x00); OLED_send(0x00, 0x10); OLED_send(0x00, 0xb0+0); for(i=0; i<128; i++) OLED_send(0x40, 0x00); 
    OLED_send(0x00, 0x00); OLED_send(0x00, 0x10); OLED_send(0x00, 0xb0+0); for(i=0; i<10; i++) OLED_send(0x40, 0x00); 
    OLED_printLetter(0x7F,0x30,0x08,0x06,0x7F); OLED_printLetter(0x3E,0x41,0x41,0x41,0x3E); OLED_printLetter(0x00,0x00,0x7F,0x00,0x00);
    OLED_printLetter(0x01,0x01,0x7F,0x01,0x01); OLED_printLetter(0x7E,0x09,0x09,0x09,0x7E); OLED_printLetter(0x40,0x40,0x40,0x40,0x7F);
    OLED_printLetter(0x3F,0x40,0x40,0x40,0x3F); OLED_printLetter(0x3E,0x41,0x41,0x41,0x7F); OLED_printLetter(0x3E,0x41,0x41,0x41,0x3E);
    OLED_printLetter(0x7F,0x02,0x04,0x02,0x7F); for(i=0; i<5; i++) OLED_send(0x40,0x00);
    OLED_printLetter(0x36,0x49,0x49,0x49,0x7F); OLED_printLetter(0x32,0x49,0x49,0x49,0x26); OLED_printLetter(0x1F,0x20,0x40,0x20,0x1F);
    OLED_send(0x00, 0x00); OLED_send(0x00, 0x10); OLED_send(0x00, 0xb0+1); for(i=0; i<128; i++) OLED_send(0x40, 0x00); 
    OLED_send(0x00, 0x00); OLED_send(0x00, 0x10); OLED_send(0x00, 0xb0+1); for(i=0; i<30; i++) OLED_send(0x40, 0x00); 
    OLED_printLetter(0x32,0x49,0x49,0x49,0x3E); OLED_printLetter(0x00,0x00,0x00,0x00,0x22); OLED_printLetter(0x06,0x09,0x09,0x09,0x7F);
    OLED_printLetter(0x3F,0x40,0x40,0x40,0x3F); OLED_printLetter(0x3E,0x41,0x41,0x41,0x3E); OLED_printLetter(0x47,0x29,0x19,0x09,0x7F);
    OLED_printLetter(0x36,0x51,0x51,0x41,0x3E);
}

/* ======================================================================== */
/* SIGNAL PROCESSING FUNCTIONS                                              */
/* ======================================================================== */

/* VSB Band-Pass Filter Processing */
static int Filter(int input1)
{
    signed long result = 0;
    int k;

    for (k = 47; k >= 0; k--)
    {
        result    = result + (long)BP[k+1] * (long)Temp[k];
        Temp[k+1] = Temp[k];
    }

    result  = result + (long)input1 * (long)BP[0];
    result  = result >> 15;
    Temp[0] = input1;

    return (int)result;
}

/* Low-Pass Filter Processing for Demodulation Stage (97 Taps) */
static int LowPassFilter(int input1)
{
    signed long result = 0;
    int k;

    for (k = LPF_LBL - 2; k >= 0; k--)
    {
        result        = result + (long)LPF_COEFF[k+1] * (long)LPF_Temp[k];
        LPF_Temp[k+1] = LPF_Temp[k];
    }

    result      = result + (long)input1 * (long)LPF_COEFF[0];
    result      = result >> 15;
    LPF_Temp[0] = input1;

    return (int)result;
}

/* ======================================================================== */
/* MAIN EXECUTION LOOP                                                      */
/* ======================================================================== */
void main(void)
{
    float msg_val;
    Int16 carrier;
    signed long dsb_temp;
    signed long demod_temp;

    USBSTK5515_init();
    pll_frequency_setup(100);

    OLED_init();
    display_VSB_Group();

    aic3204_hardware_init();
    aic3204_init();
    set_sampling_frequency_and_gain(SAMPLES_PER_SECOND, GAIN_IN_dB);


    while (1)
    {
        /* Block synchronization with I2S codec clock */
        aic3204_codec_read((Int16*)&left_output, (Int16*)&right_output);

        /* --- STAGE 1: COMPOSITE MESSAGE SIGNAL GENERATION --- */
        msg_val = cos(2 * PI * FREQ_1 * t) +
                  cos(2 * PI * FREQ_2 * t) +
                  cos(2 * PI * FREQ_3 * t) +
                  cos(2 * PI * FREQ_4 * t);
                        
        sine_msg = (Int16)(msg_val * TONE_AMP);

        /* Update discrete time counter */
        t += dt;
        if (t >= 0.01) { 
            t -= 0.01;   
        }

        /* --- STAGE 2: GENERATE CARRIER ONCE PER LOOP --- */
        carrier = generate_sinewave_1(CARRIER_FREQ_HZ, 32768);

        /* --- STAGE 3: VSB MODULATION --- */
        /* Perform DSB up-conversion using the generated carrier sample */
        dsb_temp = ((long)sine_msg * (long)carrier) >> 15;
        /* Apply Band-Pass Filter to shape into VSB */
        vsb_output = Filter((int)dsb_temp);             

        /* --- STAGE 4: COHERENT DEMODULATION --- */
        /* Multiply VSB signal with the EXACT SAME carrier sample */
        demod_temp = ((long)vsb_output * (long)carrier) >> 15;
        /* Pass through the 97-tap LPF to extract the baseband message */
        demod_signal = LowPassFilter((int)demod_temp);      
        
        /* FIX OVERFLOW: Reduce gain scaling from << 3 to << 2 or << 1 */
        demod_signal = (Int16)((float)demod_signal * 2.8);            

        /* --- STAGE 5: HARDWARE CODEC OUTPUT --- */
        aic3204_codec_write(demod_signal, sine_msg);

        /* --- STAGE 6: CCS GRAPH BUFFER LOGGING --- */
        graph_input[graph_index]     = sine_msg;      
        graph_modulated[graph_index] = vsb_output;    
        graph_output[graph_index]    = demod_signal;  

        graph_index++;
        if (graph_index >= GRAPH_N)
        {
            graph_index = 0;
            graph_ready = 1;  /* <<< SET BREAKPOINT HERE TO VIEW ALL 3 GRAPHS */
        }
    }
}
/* EOF */