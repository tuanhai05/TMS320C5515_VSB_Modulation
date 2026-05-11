/*****************************************************************************/
/* FILENAME: main.c                                                          */
/* DESCRIPTION: VSB Modulation on TMS320C5515                               */
/* INPUT: Internal sine wave 1000 Hz (no codec input needed)                */
/* OUTPUT: VSB signal on graph_output, original sine on graph_input         */
/*                                                                           */
/* CCS Graph setup (Dual Time):                                              */
/*   DualTimeA: Start Address = graph_input,  16-bit signed, size 512       */
/*   DualTimeB: Start Address = graph_output, 16-bit signed, size 512       */
/*   Set breakpoint at graph_ready=1, press F8 to refresh graph             */
/*****************************************************************************/

#include "stdio.h"
#include "usbstk5515.h"
#include "aic3204.h"
#include "sinewaves.h"
#include "PLL.h"

#define SAMPLES_PER_SECOND  48000
#define GAIN_IN_dB          5

/* Message sine wave parameters */
#define MESSAGE_FREQ_HZ     1000   /* 1 kHz message signal */
#define MESSAGE_AMP         8000   /* amplitude, max 32767 */

/* Carrier frequency */
#define CARRIER_FREQ_HZ     10000  /* 10 kHz carrier */

#define Amp  2
#define LBL  49

/* Graph buffers for CCS visualization */
#define GRAPH_N  512

#pragma DATA_SECTION(graph_input, ".bss")
volatile Int16 graph_input[GRAPH_N];

#pragma DATA_SECTION(graph_output, ".bss")
volatile Int16 graph_output[GRAPH_N];

volatile Uint16 graph_index = 0;
volatile Uint16 graph_ready = 0;

/* Codec variables */
Int16 left_output;
Int16 right_output;

/* Working variables */
Int16 sine_msg;
Int16 vsb_output;

/* Band-pass filter coefficients */
Int16 BP[49] = {
     109,    419,   -226,   -340,    210,    207,    -42,    129,   -347,
    -507,    813,    700,  -1033,   -541,    623,     49,    648,    548,
   -2667,   -927,   4934,    856,  -6726,   -346,   7407,   -346,  -6726,
     856,   4934,   -927,  -2667,    548,    648,     49,    623,   -541,
   -1033,    700,    813,   -507,   -347,    129,    -42,    207,    210,
    -340,   -226,    419,    109
};

Int16 Temp[49] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

/* ======================================================================== */
/* DSB()                                                                     */
/* Multiply input by carrier sinewave to get DSB signal                     */
/* ======================================================================== */
static int DSB(int input1, int fc)
{
    signed long result;
    Int16 carrierwave;

    carrierwave = generate_sinewave_1(fc, 22767);
    result = Amp * (((long)input1 * carrierwave) >> 15);

    return (int)result;
}

/* ======================================================================== */
/* Filter()                                                                  */
/* Apply band-pass filter on DSB signal to get VSB signal                   */
/* ======================================================================== */
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

/* ======================================================================== */
/* main()                                                                    */
/* ======================================================================== */
void main(void)
{
    /* Initialize board */
    USBSTK5515_init();

    /* Initialize PLL */
    pll_frequency_setup(100);

    /* Initialize codec hardware */
    aic3204_hardware_init();
    aic3204_init();
    set_sampling_frequency_and_gain(SAMPLES_PER_SECOND, GAIN_IN_dB);

    puts("\n=== VSB Demo: 1kHz sine input, 10kHz carrier ===");
    puts("DualTimeA: graph_input  (message sine 1kHz)");
    puts("DualTimeB: graph_output (VSB output)");

    while (1)
    {
        /* Sync with I2S clock */
        aic3204_codec_read((Int16*)&left_output, (Int16*)&right_output);

        /* Generate 1 kHz sine as message signal */
        sine_msg = (Int16)generate_sinewave_2(MESSAGE_FREQ_HZ, MESSAGE_AMP);

        /* DSB modulation */
        vsb_output = DSB(sine_msg, CARRIER_FREQ_HZ);

        /* VSB filter */
        vsb_output = Filter(vsb_output);

        /* Output: VSB on left, original message on right */
        aic3204_codec_write(vsb_output, sine_msg);

        /* Save to graph buffers */
        graph_input[graph_index]  = sine_msg;
        graph_output[graph_index] = vsb_output;

        graph_index++;
        if (graph_index >= GRAPH_N)
        {
            graph_index = 0;
            graph_ready = 1;  /* <<< SET BREAKPOINT HERE */
        }
    }
}

/*****************************************************************************/
/* End of main.c                                                             */
/*****************************************************************************/ 