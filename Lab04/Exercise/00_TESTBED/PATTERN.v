//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Yu-Chi Lin (a6121461214.st12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V1.0 (Release Date: 2024-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

/*
    @debug method : dump file
        The file with postfix "_float" means that the file will show the value with float(real) format
        The file with postfix "_hex" means that the file will show the value with hexadecimal format
        file name :
            input_float.txt
            input_hex.txt
            output_float.txt
            output_hex.txt
    @description :
        Use IP to calculate the golden pattern
    @issue :
        1. Lose precision
        2. NaN / Inf
    @todo :
        1. Improve the parameter representation
        2. Consider use the real/float number and compare the result with the version of IP
*/

`define CYCLE_TIME      50.0

module PATTERN(
    //Output Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel_ch1,
    Kernel_ch2,
	Weight,
    Opt,
    //Input Port
    out_valid,
    out
    );

//======================================
//      INPUT & OUTPUT
//======================================
output  logic        clk, rst_n, in_valid;
output  logic[31:0]  Img;
output  logic[31:0]  Kernel_ch1;
output  logic[31:0]  Kernel_ch2;
output  logic[31:0]  Weight;
output  logic        Opt;
input                out_valid;
input   [31:0]       out;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 1000;
integer   SIMPLE_PATNUM = 0;
// Make sure the number should be with decimal point XXX.0
real      MIN_RANGE_OF_INPUT = -0.5;
real      MAX_RANGE_OF_INPUT = 0.5;
parameter PRECISION_OF_RANDOM_EXPONENT = -5; // 2^(PRECISION_OF_RANDOM_EXPONENT) ~ the exponent of MAX_RANGE_OF_INPUT
integer   SEED = 5487;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter DEBUG = 1;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 200;
parameter OUTNUM = 3;

//
// IP
//
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter real_sig_width = 52; // verilog real (double)
parameter real_exp_width = 11; // verilog real (double)
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;

// PATTERN CONTROL
integer stop;
integer pat;
integer exe_lat;
integer out_lat;
integer out_check_idx;
integer tot_lat;
integer input_delay;
integer each_delay;

// FILE CONTROL
integer file;
integer file_out;

// String control
// Should use %0s
reg[9*8:1]  reset_color       = "\033[1;0m";
reg[10*8:1] txt_black_prefix  = "\033[1;30m";
reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";

reg[10*8:1] bkg_black_prefix  = "\033[40;1m";
reg[10*8:1] bkg_red_prefix    = "\033[41;1m";
reg[10*8:1] bkg_green_prefix  = "\033[42;1m";
reg[10*8:1] bkg_yellow_prefix = "\033[43;1m";
reg[10*8:1] bkg_blue_prefix   = "\033[44;1m";
reg[10*8:1] bkg_white_prefix  = "\033[47;1m";

//======================================
//      DATA MODEL
//======================================
parameter NUM_OF_INPUT = 1;
parameter NUM_OF_IMAGE = 3;
parameter SIZE_OF_IMAGE = 5;

parameter NUM_OF_KERNEL_CH = 2;
parameter NUM_OF_KERNEL = 3;
parameter SIZE_OF_KERNEL = 2;

parameter NUM_OF_WEIGHT = 3;
parameter SIZE_OF_WEIGHT = 8;

parameter SIZE_OF_PAD_WINDOW = 2;
parameter SIZE_OF_MAXPOOL_WINDOW = 3;

parameter SIZE_OF_PAD = SIZE_OF_IMAGE + SIZE_OF_PAD_WINDOW; // 7
parameter SIZE_OF_CONV = SIZE_OF_PAD - SIZE_OF_KERNEL + 1; // 6
parameter SIZE_OF_MAXPOOL = SIZE_OF_CONV / SIZE_OF_MAXPOOL_WINDOW; // 2
parameter SIZE_OF_ACTIVATE = SIZE_OF_MAXPOOL; // 2
parameter SIZE_OF_OUTPUT = NUM_OF_WEIGHT; // 3

//
// input
//
reg[inst_sig_width+inst_exp_width:0] _img[NUM_OF_INPUT:1][NUM_OF_IMAGE:1][SIZE_OF_IMAGE-1:0][SIZE_OF_IMAGE-1:0];
reg[inst_sig_width+inst_exp_width:0] _kernel[NUM_OF_KERNEL_CH:1][NUM_OF_KERNEL:1][SIZE_OF_KERNEL-1:0][SIZE_OF_KERNEL-1:0];
reg[inst_sig_width+inst_exp_width:0] _weight[NUM_OF_WEIGHT:1][SIZE_OF_WEIGHT-1:0];
reg _opt;

//
// temporary output
//
reg[inst_sig_width+inst_exp_width:0] _pad     [NUM_OF_INPUT:1]                    [NUM_OF_IMAGE:1][SIZE_OF_PAD-1:0] [SIZE_OF_PAD-1:0];
reg[inst_sig_width+inst_exp_width:0] _conv    [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1][NUM_OF_IMAGE:1][SIZE_OF_CONV-1:0][SIZE_OF_CONV-1:0];
reg[inst_sig_width+inst_exp_width:0] _convSum [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_CONV-1:0][SIZE_OF_CONV-1:0];
reg[inst_sig_width+inst_exp_width:0] _maxPool [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_MAXPOOL-1:0][SIZE_OF_MAXPOOL-1:0];
reg[inst_sig_width+inst_exp_width:0] _activate[NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_ACTIVATE-1:0][SIZE_OF_ACTIVATE-1:0];
reg[inst_sig_width+inst_exp_width:0] _fully   [NUM_OF_INPUT:1][SIZE_OF_OUTPUT-1:0];
reg[inst_sig_width+inst_exp_width:0] _softmax [NUM_OF_INPUT:1][SIZE_OF_OUTPUT-1:0];
reg[inst_sig_width+inst_exp_width:0] _prob                    [SIZE_OF_OUTPUT-1:0];

//
// wire for temporary output
//
wire[inst_sig_width+inst_exp_width:0] _conv_w    [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1][NUM_OF_IMAGE:1][SIZE_OF_CONV-1:0][SIZE_OF_CONV-1:0];
wire[inst_sig_width+inst_exp_width:0] _convSum_w [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_CONV-1:0][SIZE_OF_CONV-1:0];
wire[inst_sig_width+inst_exp_width:0] _maxPool_w [NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_MAXPOOL-1:0][SIZE_OF_MAXPOOL-1:0];
wire[inst_sig_width+inst_exp_width:0] _activate_w[NUM_OF_INPUT:1][NUM_OF_KERNEL_CH:1]                [SIZE_OF_ACTIVATE-1:0][SIZE_OF_ACTIVATE-1:0];
wire[inst_sig_width+inst_exp_width:0] _fully_w   [NUM_OF_INPUT:1][SIZE_OF_OUTPUT-1:0];
wire[inst_sig_width+inst_exp_width:0] _softmax_w [NUM_OF_INPUT:1][SIZE_OF_OUTPUT-1:0];
wire[inst_sig_width+inst_exp_width:0] _prob_w                    [SIZE_OF_OUTPUT-1:0];


//
// Error check
//
// wire [inst_sig_width+inst_exp_width:0] _errRateAllow = 32'h3B03126F; // 0.002
wire [inst_sig_width+inst_exp_width:0] _errRateAllow = 32'h3BA3D70A; // 0.005
real _errAllow = 0.0001;
reg  [inst_sig_width+inst_exp_width:0] _errDiff   [SIZE_OF_OUTPUT-1:0]; // |ans - gold|
wire [inst_sig_width+inst_exp_width:0] _errDiff_w [SIZE_OF_OUTPUT-1:0];
reg  [inst_sig_width+inst_exp_width:0] _errBound  [SIZE_OF_OUTPUT-1:0]; // gold * errRate
wire [inst_sig_width+inst_exp_width:0] _errBound_w[SIZE_OF_OUTPUT-1:0];
wire _errRateFlag[SIZE_OF_OUTPUT-1:0]; // |ans - gold| / gold < errRate
reg _errFlag[SIZE_OF_OUTPUT-1:0]; // convert to float -> |ans - gold| < err
reg _isErr;

//
// Output
//
reg  [inst_sig_width+inst_exp_width:0] _your[SIZE_OF_OUTPUT-1:0];

//
// Dump
//
// Input
/*
    [#0] **1 **2 **3
    _________________
      0| **1 **2 **3
*/
reg[4*8:1] _line1  = "____";
reg[4*8:1] _space1 = "    ";
reg[9*8:1] _line2  = "_________";
reg[9*8:1] _space2 = "         ";
task dump_input;
    input integer isHex;
    integer input_idx;
    integer num_idx;
    integer col_idx;
    integer row_idx;
begin
    if(isHex === 1) file_out = $fopen("input_hex.txt", "w");
    else file_out = $fopen("input_float.txt", "w");

    $fwrite(file_out, "[PAT NO. %4d]\n\n\n", pat);

    $fwrite(file_out, "[ Input Random Setting ]\n\n");
    $fwrite(file_out, "[ Minimum ] : %100.10f\n", MIN_RANGE_OF_INPUT);
    $fwrite(file_out, "[ Maximum ] : %100.10f\n\n", MAX_RANGE_OF_INPUT);

    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Option ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[ opt ] %d\n", _opt);
    if(_opt === 'd0) $fwrite(file_out, "[ sigmoid ] [ Zero        ]\n");
    if(_opt === 'd1) $fwrite(file_out, "[ tanh    ] [ Replication ]\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=======]\n");
    $fwrite(file_out, "[ Input ]\n");
    $fwrite(file_out, "[=======]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        // [#0] **1 **2 **3
        for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
            $fwrite(file_out, "[%1d] ", num_idx);
            for(col_idx=0 ; col_idx<SIZE_OF_IMAGE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(num_idx=0 ; num_idx<NUM_OF_IMAGE ; num_idx=num_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<SIZE_OF_IMAGE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
            for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _img[input_idx][num_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_img[input_idx][num_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Kernel ]\n");
    $fwrite(file_out, "[========]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_KERNEL_CH ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[channel %1d]\n\n", input_idx);
        for(num_idx=1 ; num_idx<=NUM_OF_KERNEL ; num_idx=num_idx+1) begin
            $fwrite(file_out, "[%1d] ", num_idx);
            for(col_idx=0 ; col_idx<SIZE_OF_KERNEL ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(num_idx=0 ; num_idx<NUM_OF_KERNEL ; num_idx=num_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<SIZE_OF_KERNEL ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<SIZE_OF_KERNEL ; row_idx=row_idx+1) begin
            for(num_idx=1 ; num_idx<=NUM_OF_KERNEL ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_KERNEL ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _kernel[input_idx][num_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_kernel[input_idx][num_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Weight ]\n");
    $fwrite(file_out, "[========]\n\n");
    // [#0] **1 **2 **3
    $fwrite(file_out, "[W] ");
    for(col_idx=0 ; col_idx<SIZE_OF_WEIGHT ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _line1);
    for(col_idx=0 ; col_idx<SIZE_OF_WEIGHT ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=1 ; row_idx<=NUM_OF_WEIGHT ; row_idx=row_idx+1) begin
        $fwrite(file_out, "%2d| ",row_idx);
        for(col_idx=0 ; col_idx<SIZE_OF_WEIGHT ; col_idx=col_idx+1) begin
            if(isHex === 1) $fwrite(file_out, "%8h ", _weight[row_idx][col_idx]);
            else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_weight[row_idx][col_idx]));
        end
        $fwrite(file_out, "%0s", _space1);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
end endtask

// Output
task dump_output;
    input integer isHex;
    integer input_idx;
    integer ch_idx;
    integer num_idx;
    integer col_idx;
    integer row_idx;
begin
    if(isHex === 1) file_out = $fopen("output_hex.txt", "w");
    else file_out = $fopen("output_float.txt", "w");

    $fwrite(file_out, "[PAT NO. %4d]\n\n\n", pat);

    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Option ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[ opt ] %d\n", _opt);
    if(_opt === 'd0) $fwrite(file_out, "[ sigmoid ] [ Zero        ]\n");
    if(_opt === 'd1) $fwrite(file_out, "[ tanh    ] [ Replication ]\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=========]\n");
    $fwrite(file_out, "[ Padding ]\n");
    $fwrite(file_out, "[=========]\n\n");

    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        // [#0] **1 **2 **3
        for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
            $fwrite(file_out, "[%1d] ", num_idx);
            for(col_idx=0 ; col_idx<SIZE_OF_PAD ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        // _________________
        for(num_idx=0 ; num_idx<NUM_OF_IMAGE ; num_idx=num_idx+1) begin
            $fwrite(file_out, "%0s", _line1);
            for(col_idx=0 ; col_idx<SIZE_OF_PAD ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
            $fwrite(file_out, "%0s", _space1);
        end
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(row_idx=0 ; row_idx<SIZE_OF_PAD ; row_idx=row_idx+1) begin
            for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_PAD ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _pad[input_idx][num_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_pad[input_idx][num_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=====================]\n");
    $fwrite(file_out, "[ Convolution Partial ]\n");
    $fwrite(file_out, "[=====================]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        for(ch_idx=1 ; ch_idx<=NUM_OF_KERNEL_CH ; ch_idx=ch_idx+1 ) begin
            $fwrite(file_out, "[kernel channel %1d]\n\n", ch_idx);
            // [#0] **1 **2 **3
            for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
                $fwrite(file_out, "[%1d] ", num_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            // _________________
            for(num_idx=0 ; num_idx<NUM_OF_IMAGE ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%0s", _line1);
                for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            //   0| **1 **2 **3
            for(row_idx=0 ; row_idx<SIZE_OF_CONV ; row_idx=row_idx+1) begin
                for(num_idx=1 ; num_idx<=NUM_OF_IMAGE ; num_idx=num_idx+1) begin
                    $fwrite(file_out, "%2d| ",row_idx);
                    for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) begin
                        if(isHex === 1) $fwrite(file_out, "%8h ", _conv[input_idx][ch_idx][num_idx][row_idx][col_idx]);
                        else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_conv[input_idx][ch_idx][num_idx][row_idx][col_idx]));
                    end
                    $fwrite(file_out, "%0s", _space1);
                end
                $fwrite(file_out, "\n");
            end
            $fwrite(file_out, "\n");
        end
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=================]\n");
    $fwrite(file_out, "[ Convolution Sum ]\n");
    $fwrite(file_out, "[=================]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        for(ch_idx=1 ; ch_idx<=NUM_OF_KERNEL_CH ; ch_idx=ch_idx+1 ) begin
            $fwrite(file_out, "[kernel channel %1d]\n\n", ch_idx);
            // [#0] **1 **2 **3
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "[%1d] ", num_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            // _________________
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%0s", _line1);
                for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            //   0| **1 **2 **3
            for(row_idx=0 ; row_idx<SIZE_OF_CONV ; row_idx=row_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_CONV ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _convSum[input_idx][ch_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_convSum[input_idx][ch_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "\n");
            end
            $fwrite(file_out, "\n");
        end
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=============]\n");
    $fwrite(file_out, "[ Max pooling ]\n");
    $fwrite(file_out, "[=============]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        for(ch_idx=1 ; ch_idx<=NUM_OF_KERNEL_CH ; ch_idx=ch_idx+1 ) begin
            $fwrite(file_out, "[kernel channel %1d]\n\n", ch_idx);
            // [#0] **1 **2 **3
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "[%1d] ", num_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_MAXPOOL ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            // _________________
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%0s", _line1);
                for(col_idx=0 ; col_idx<SIZE_OF_MAXPOOL ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            //   0| **1 **2 **3
            for(row_idx=0 ; row_idx<SIZE_OF_MAXPOOL ; row_idx=row_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_MAXPOOL ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _maxPool[input_idx][ch_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_maxPool[input_idx][ch_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "\n");
            end
            $fwrite(file_out, "\n");
        end
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[============]\n");
    $fwrite(file_out, "[ Activation ]\n");
    $fwrite(file_out, "[============]\n\n");
    for(input_idx=1 ; input_idx<=NUM_OF_INPUT ; input_idx=input_idx+1) begin
        $fwrite(file_out, "[ IMAGE #%1d ]\n\n", input_idx);
        for(ch_idx=1 ; ch_idx<=NUM_OF_KERNEL_CH ; ch_idx=ch_idx+1 ) begin
            $fwrite(file_out, "[kernel channel %1d]\n\n", ch_idx);
            // [#0] **1 **2 **3
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "[%1d] ", num_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_ACTIVATE ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            // _________________
            for(num_idx=1 ; num_idx<=1 ; num_idx=num_idx+1) begin
                $fwrite(file_out, "%0s", _line1);
                for(col_idx=0 ; col_idx<SIZE_OF_ACTIVATE ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
                $fwrite(file_out, "%0s", _space1);
            end
            $fwrite(file_out, "\n");
            //   0| **1 **2 **3
            for(row_idx=0 ; row_idx<SIZE_OF_ACTIVATE ; row_idx=row_idx+1) begin
                $fwrite(file_out, "%2d| ",row_idx);
                for(col_idx=0 ; col_idx<SIZE_OF_ACTIVATE ; col_idx=col_idx+1) begin
                    if(isHex === 1) $fwrite(file_out, "%8h ", _activate[input_idx][ch_idx][row_idx][col_idx]);
                    else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_activate[input_idx][ch_idx][row_idx][col_idx]));
                end
                $fwrite(file_out, "\n");
            end
            $fwrite(file_out, "\n");
        end
    end

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[===============]\n");
    $fwrite(file_out, "[ Fully Connect ]\n");
    $fwrite(file_out, "[===============]\n\n");
    // [#0] **1 **2 **3
    $fwrite(file_out, "[W] ");
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _line1);
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=1 ; row_idx<=NUM_OF_INPUT ; row_idx=row_idx+1) begin
        $fwrite(file_out, "%2d| ",row_idx);
        for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) begin
            if(isHex === 1) $fwrite(file_out, "%8h ", _fully[row_idx][col_idx]);
            else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_fully[row_idx][col_idx]));
        end
        $fwrite(file_out, "%0s", _space1);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[=========]\n");
    $fwrite(file_out, "[ Softmax ]\n");
    $fwrite(file_out, "[=========]\n\n");
    // [#0] **1 **2 **3
    $fwrite(file_out, "[W] ");
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _line1);
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=1 ; row_idx<=NUM_OF_INPUT ; row_idx=row_idx+1) begin
        $fwrite(file_out, "%2d| ",row_idx);
        for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) begin
            if(isHex === 1) $fwrite(file_out, "%8h ", _softmax[row_idx][col_idx]);
            else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_softmax[row_idx][col_idx]));
        end
        $fwrite(file_out, "%0s", _space1);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[============]\n");
    $fwrite(file_out, "[ Probabilty ]\n");
    $fwrite(file_out, "[============]\n\n");
    // [#0] **1 **2 **3
    $fwrite(file_out, "[W] ");
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%8d ",col_idx);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _line1);
    for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) $fwrite(file_out, "%0s", _line2);
    $fwrite(file_out, "%0s", _space1);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(row_idx=1 ; row_idx<=NUM_OF_INPUT ; row_idx=row_idx+1) begin
        $fwrite(file_out, "%2d| ",row_idx);
        for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) begin
            if(isHex === 1) $fwrite(file_out, "%8h ", _prob[col_idx]);
            else $fwrite(file_out, "%8.3f ", _floatBitsToReal(_prob[col_idx]));
        end
        $fwrite(file_out, "%0s", _space1);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fwrite(file_out, "\n");
    $fwrite(file_out, "[============]\n");
    $fwrite(file_out, "[ Error Check]\n");
    $fwrite(file_out, "[============]\n\n");
    for(row_idx=0 ; row_idx<5 ; row_idx=row_idx+1) begin
        // Type
        if(row_idx === 0) begin
            $fwrite(file_out, "[Is Error or not] : %d\n", _isErr);
            $fwrite(file_out, "[Output]\n\n");
        end
        else if(row_idx === 1) begin
            $fwrite(file_out, "[Error rate flag] : \n");
            $fwrite(file_out, "[Formula] : |gold - ans| / gold < %1.8f\n\n", _floatBitsToReal(_errRateAllow));
        end
        else if(row_idx === 2) begin
            $fwrite(file_out, "[Error rate] : |gold - ans|\n\n");
        end
        else if(row_idx === 3) begin
            $fwrite(file_out, "[Error rate] : gold * %1.8f\n\n", _floatBitsToReal(_errRateAllow));
        end
        else if(row_idx === 4) begin
            $fwrite(file_out, "[Error flag] : \n");
            $fwrite(file_out, "[Formula] : |float(ans) - float(gold)| < %1.8f\n\n", _errAllow);
        end
        $fwrite(file_out, "%2d| ",row_idx);
        // Value
        for(col_idx=0 ; col_idx<SIZE_OF_OUTPUT ; col_idx=col_idx+1) begin
            if(row_idx === 0) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _your[col_idx]);
                else $fwrite(file_out, "%12.7f ", _floatBitsToReal(_your[col_idx]));
            end
            // Error rate
            else if(row_idx === 1) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _errRateFlag[col_idx]);
                else $fwrite(file_out, "%12.7f ", _floatBitsToReal(_errRateFlag[col_idx]));
            end
            else if(row_idx === 2) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _errDiff[col_idx]);
                else $fwrite(file_out, "%12.7f ", _floatBitsToReal(_errDiff[col_idx]));
            end
            else if(row_idx === 3) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _errBound[col_idx]);
                else $fwrite(file_out, "%12.7f ", _floatBitsToReal(_errBound[col_idx]));
            end
            // Error
            else if(row_idx === 4) begin
                if(isHex === 1) $fwrite(file_out, "%8h ", _errFlag[col_idx]);
                else $fwrite(file_out, "%12.7f ", _floatBitsToReal(_errFlag[col_idx]));
            end
        end
        $fwrite(file_out, "\n\n");
    end
    $fwrite(file_out, "\n");
    
end endtask

//
// Generate input
//
task randomize_input;
    integer _global;
    integer _num;
    integer _row;
    integer _col;
begin
    // Image
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_num=1 ; _num<=NUM_OF_IMAGE ; _num=_num+1) begin
            for(_row=0 ; _row<SIZE_OF_IMAGE ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_IMAGE ; _col=_col+1) begin
                    _img[_global][_num][_row][_col] = _getRandInput(pat);
                end
            end
        end
    end
    // Kernel
    for(_global=1 ; _global<=NUM_OF_KERNEL_CH ; _global=_global+1) begin
        for(_num=1 ; _num<=NUM_OF_KERNEL ; _num=_num+1) begin
            for(_row=0 ; _row<SIZE_OF_KERNEL ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_KERNEL ; _col=_col+1) begin
                    _kernel[_global][_num][_row][_col] = _getRandInput(pat);
                end
            end
        end
    end
    // Weight
    for(_global=1 ; _global<=NUM_OF_WEIGHT ; _global=_global+1) begin
        for(_col=0 ; _col<SIZE_OF_WEIGHT ; _col=_col+1) begin
            _weight[_global][_col] = _getRandInput(pat);
        end
    end
    // Opt
    _opt = {$random(SEED)} % 2;
end endtask

//
// Record
//
task _recordPadding;
    integer _global;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_num=1 ; _num<=NUM_OF_IMAGE ; _num=_num+1) begin
            for(_row=0 ; _row<SIZE_OF_PAD ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_PAD ; _col=_col+1) begin
                    _pad[_global][_num][_row][_col] = 0;
                end
            end
        end
    end

    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_num=1 ; _num<=NUM_OF_IMAGE ; _num=_num+1) begin
            for(_row=0 ; _row<SIZE_OF_IMAGE ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_IMAGE ; _col=_col+1) begin
                    _pad[_global][_num][_row+1][_col+1] = _img[_global][_num][_row][_col];
                end
            end
        end
    end

    if(_opt==='d1) begin
        for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
            for(_num=1 ; _num<=NUM_OF_IMAGE ; _num=_num+1) begin
                for(_row=1 ; _row<=SIZE_OF_PAD-1 ; _row=_row+1) begin
                    _pad[_global][_num][_row][0] = _img[_global][_num][_row-1][0];
                    _pad[_global][_num][_row][SIZE_OF_PAD-1] = _img[_global][_num][_row-1][SIZE_OF_IMAGE-1];
                end
                for(_col=1 ; _col<=SIZE_OF_PAD-1 ; _col=_col+1) begin
                    _pad[_global][_num][0][_col] = _img[_global][_num][0][_col-1];
                    _pad[_global][_num][SIZE_OF_PAD-1][_col] = _img[_global][_num][SIZE_OF_IMAGE-1][_col-1];
                end
                _pad[_global][_num][0][0] = _img[_global][_num][0][0];
                _pad[_global][_num][0][SIZE_OF_PAD-1] = _img[_global][_num][0][SIZE_OF_IMAGE-1];
                _pad[_global][_num][SIZE_OF_PAD-1][0] = _img[_global][_num][SIZE_OF_IMAGE-1][0];
                _pad[_global][_num][SIZE_OF_PAD-1][SIZE_OF_PAD-1] = _img[_global][_num][SIZE_OF_IMAGE-1][SIZE_OF_IMAGE-1];
            end
        end
    end
end endtask

task _recordConvolution;
    integer _global;
    integer _ch;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_ch=1 ; _ch<=NUM_OF_KERNEL_CH ; _ch=_ch+1) begin
            for(_num=1 ; _num<=NUM_OF_IMAGE ; _num=_num+1) begin
                for(_row=0 ; _row<SIZE_OF_CONV ; _row=_row+1) begin
                    for(_col=0 ; _col<SIZE_OF_CONV ; _col=_col+1) begin
                        _conv[_global][_ch][_num][_row][_col] = _conv_w[_global][_ch][_num][_row][_col];
                    end
                end
            end
        end
    end
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_ch=1 ; _ch<=NUM_OF_KERNEL_CH ; _ch=_ch+1) begin
            for(_row=0 ; _row<SIZE_OF_CONV ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_CONV ; _col=_col+1) begin
                    _convSum[_global][_ch][_row][_col] = _convSum_w[_global][_ch][_row][_col];
                end
            end
        end
    end
end endtask

task _recordMaxPool;
    integer _global;
    integer _ch;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_ch=1 ; _ch<=NUM_OF_KERNEL_CH ; _ch=_ch+1) begin
            for(_row=0 ; _row<SIZE_OF_MAXPOOL ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_MAXPOOL ; _col=_col+1) begin
                    _maxPool[_global][_ch][_row][_col] = _maxPool_w[_global][_ch][_row][_col];
                end
            end
        end
    end
end endtask

task _recordActivate;
    integer _global;
    integer _ch;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_ch=1 ; _ch<=NUM_OF_KERNEL_CH ; _ch=_ch+1) begin
            for(_row=0 ; _row<SIZE_OF_ACTIVATE ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_ACTIVATE ; _col=_col+1) begin
                    _activate[_global][_ch][_row][_col] = _activate_w[_global][_ch][_row][_col];
                end
            end
        end
    end
end endtask

task _recordFully;
    integer _global;
    integer _ch;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) begin
            _fully[_global][_col] = _fully_w[_global][_col];
        end
    end
end endtask

task _recordSoftmax;
    integer _global;
    integer _ch;
    integer _num;
    integer _row;
    integer _col;
begin
    for(_global=1 ; _global<=NUM_OF_INPUT ; _global=_global+1) begin
        for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) begin
            _softmax[_global][_col] = _softmax_w[_global][_col];
        end
    end
end endtask

genvar gen_prob,gen_temp;
generate
    for(gen_temp=1 ; gen_temp<=NUM_OF_INPUT ; gen_temp=gen_temp+1) begin : gen_err_block
        for(gen_prob=0 ; gen_prob<SIZE_OF_OUTPUT ; gen_prob=gen_prob+1) begin : gen_err_block
            assign _prob_w[gen_prob] = _softmax[gen_temp][gen_prob];
        end
    end
endgenerate
task _recordProb;
    integer _num;
begin
    for(_num=0 ; _num<SIZE_OF_OUTPUT ; _num=_num+1) begin
        _prob[_num] = _prob_w[_num];
    end
end endtask

task _recordErrAndCheck;
    integer _global;
    integer _num;
    real _diff;
begin
    // Record
    for(_num=0 ; _num<SIZE_OF_OUTPUT ; _num=_num+1) begin
        _errDiff[_num] = _errDiff_w[_num];
        _errBound[_num] = _errBound_w[_num];
    end
    // Check
    for(_num=0 ; _num<SIZE_OF_OUTPUT ; _num=_num+1) begin
        _diff = _floatBitsToReal(_prob[_num]) - _floatBitsToReal(_your[_num]);
        _diff = (_diff > 0) ? _diff : -_diff;
        if(_diff>_errAllow) begin
            _errFlag[_num] = 1;
        end
        else begin
            _errFlag[_num] = 0;
        end
    end
    _isErr = 0;
    for(_num=0 ; _num<SIZE_OF_OUTPUT ; _num=_num+1) begin
        if(_errFlag[_num]) begin
            _isErr = 1;
        end
        // if(_errRateFlag[_num]) begin
        //     _isErr = 1;
        // end
    end
end endtask

//
// Utility
//
function[inst_sig_width+inst_exp_width:0] _getRandInput;
    input integer _pat;

    reg[inst_sig_width+inst_exp_width:0] _minFloatBits;
    reg[inst_sig_width+inst_exp_width:0] _maxFloatBits;
    real _range;
    reg[inst_sig_width+inst_exp_width:0] _rangeFloatBits;
    real _randOut;

    //
    real _expSegement;
    real _fracSegement;
    real _numExpSegement;
    real _numFracSegement;
    real _sumOfSegementProcess;
begin
    _getRandInput = 0;
    if(_pat < SIMPLE_PATNUM) begin
        _getRandInput = 0;
        _getRandInput[inst_sig_width+:inst_exp_width] = {$random(SEED)} % 4 + 126;
        _getRandInput[inst_sig_width+inst_exp_width]  = {$random(SEED)} % 2;
    end
    else begin
        if(MIN_RANGE_OF_INPUT > MAX_RANGE_OF_INPUT) begin
            $display("[ERROR] [PARAMETER] MIN_RANGE_OF_INPUT can't be larger than MAX_RANGE_OF_INPUT");
            $finish;
        end
        if(!_isValidFloatOfReal(MIN_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The minimum of input exceeds the defined range of float");
            $finish;
        end
        if(!_isValidFloatOfReal(MAX_RANGE_OF_INPUT))begin
            $display("[ERROR] [PARAMETER] The maximum of input exceeds the defined range of float");
            $finish;
        end

        _minFloatBits = _realTofloatBits(MIN_RANGE_OF_INPUT);
        _maxFloatBits = _realTofloatBits(MAX_RANGE_OF_INPUT);

        // Randomize 
        _range = MAX_RANGE_OF_INPUT - MIN_RANGE_OF_INPUT;
        _rangeFloatBits = _realTofloatBits(_range);
        if(_rangeFloatBits[inst_sig_width+:inst_exp_width] < (PRECISION_OF_RANDOM_EXPONENT+(2**(inst_exp_width-1)-1))) begin
            $display("[ERROR] [PARAMETER] The PRECISION_OF_RANDOM_EXPONENT is larger than the expoent of your setting range(MAX_RANGE_OF_INPUT-MIN_RANGE_OF_INPUT)");
            $finish;
        end

        // /*
        // Directly calculateion method
        //     @issue : $random only return 32bits value which means that 
        //         we can't random the exponent value in float formula and change back to binary
        // */
        // _getRandInput = 0;
        // _expSegement = 1.0 / 2**(inst_exp_width-1);
        // _fracSegement = 1.0 / 2**(inst_sig_width);
        // _numExpSegement = {$random(SEED)} % (2**(_rangeFloatBits[inst_sig_width+:inst_exp_width])-1) + 1;
        // _numFracSegement = {$random(SEED)} % (2**inst_sig_width);
        // _sumOfSegementProcess = (1.0 + _fracSegement * _numFracSegement) * _expSegement * _numExpSegement;
        // $display("%d", _rangeFloatBits[inst_sig_width+:inst_exp_width]);
        // $display("%d", _rangeFloatBits[inst_sig_width+:inst_exp_width]);
        // $display("%d", (2**inst_sig_width));
        // $display("%d", _numExpSegement);
        // $display("%d", _numFracSegement);
        // $display("%f", _sumOfSegementProcess);
        // _getRandInput = _realTofloatBits(_sumOfSegementProcess);

        // /*
        // Intuitive method
        //     @issue : not even distribution -> workaround : use a parameter to control precision by user
        // */
        // _getRandInput = 0;
        // _getRandInput[inst_sig_width+:inst_exp_width] = {$random(SEED)} % (_rangeFloatBits[inst_sig_width+:inst_exp_width] + 1 - (PRECISION_OF_RANDOM_EXPONENT+(2**(inst_exp_width-1)-1))) + (PRECISION_OF_RANDOM_EXPONENT+(2**(inst_exp_width-1)-1));
        // _getRandInput[(inst_sig_width-1):0] = 
        //     (_getRandInput[inst_sig_width+:inst_exp_width] !== _rangeFloatBits[inst_sig_width+:inst_exp_width]) ? {$random(SEED)} % (2**inst_sig_width)
        //     : _rangeFloatBits[(inst_sig_width-1):0] !== 0 ? {$random(SEED)} % (_rangeFloatBits[(inst_sig_width-1):0])
        //     : 0;

        // Add increment on minimal value
        _randOut = _floatBitsToReal(_getRandInput);
        _randOut = MIN_RANGE_OF_INPUT + _randOut;
        _getRandInput = _realTofloatBits(_randOut);
    end
end
endfunction

function _isValidFloatOfReal;
    input real _in;

    reg[real_sig_width+real_exp_width:0] _realBits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    _isValidFloatOfReal = 1;
    _realBits = $realtobits(_in);
    if(_realBits[real_sig_width+:real_exp_width]+double_shift-float_shift > ((2**inst_exp_width)-1))begin
        $display("[WARNING] [FUNCTION] Exponent of real exceeds the defined range of float ( %d )", _realBits[real_sig_width+:real_exp_width]);
        _isValidFloatOfReal = 0;
    end
end endfunction

function [inst_sig_width+inst_exp_width:0] _realTofloatBits;
    input real _in;

    reg[real_sig_width+real_exp_width:0] _realBits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    _realBits = $realtobits(_in);
    if(!_isValidFloatOfReal(_in))begin
        $display("[ERROR] [FUNCTION] Exponent of real exceeds the defined range of float");
        $finish;
    end
    // sign
    _realTofloatBits[inst_sig_width+inst_exp_width]  = _realBits[real_sig_width+real_exp_width];
    // exponent
    _realTofloatBits[inst_sig_width+:inst_exp_width] = _realBits[real_sig_width+:real_exp_width]+double_shift-float_shift;
    // mantissa
    _realTofloatBits[0+:inst_sig_width]              = _realBits[(real_sig_width-1)-:inst_sig_width];
end endfunction

function real _floatBitsToReal;
    input reg[inst_sig_width+inst_exp_width:0] _in;

    reg[real_sig_width+real_exp_width:0] _realBits;
    integer float_shift = -127;
    integer double_shift = -1023;
begin
    _realBits = 0;
    // sign
    _realBits[real_sig_width+real_exp_width] = _in[inst_sig_width+inst_exp_width];
    // exponent
    _realBits[real_sig_width+:real_exp_width] = _in[inst_sig_width+:inst_exp_width]+float_shift-double_shift;
    // mantissa
    _realBits[(real_sig_width-1)-:inst_sig_width] = _in[0+:inst_sig_width];

    _floatBitsToReal = (_in === 'dx) ? 0.0/0.0 : $bitstoreal(_realBits);

end endfunction

// // Manually calculate the real
// // @deprecated
// function real _floatBitsToReal;
//     input reg[inst_sig_width+inst_exp_width:0] _in;
//     integer _exp;
//     real _frac;
//     real _float;
//     integer _bit;
// begin
//     // Exponent
//     _exp = -127;
//     for(_bit=0 ; _bit<inst_exp_width ; _bit=_bit+1) begin
//         _exp = _exp + (2**_bit)*_in[inst_sig_width+_bit];
//     end
//     // Fraction
//     _frac = 1;
//     for(_bit=0 ; _bit<inst_sig_width ; _bit=_bit+1) begin
//         _frac = _frac + 2.0**(_bit-inst_sig_width)*_in[_bit];
//     end
//     // Float
//     _float = 0;
//     _float = _in[inst_sig_width+inst_exp_width] ? -_frac * (2.0**_exp) : _frac * (2.0**_exp);
//     _floatBitsToReal = (_in === 'dx) ? 0.0/0.0 : _float;
// end
// endfunction

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              CLOCK
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    for(pat=0 ; pat<TOTAL_PATNUM ; pat=pat+1) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        // Print Pass Info and accumulate the total latency
        $display("%0sPASS PATTERN NO.%4d %0sCycles: %3d%0s",txt_blue_prefix, pat, txt_green_prefix, exe_lat, reset_color);
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    Img = 'dx;
    Kernel_ch1 = 'dx;
    Kernel_ch2 = 'dx;
    Weight = 'dx;
    Opt = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) rst_n = 1;
    #(CYCLE/2.0) release clk;
end endtask

task input_task;
    integer _cnt;
begin
    // Randomize inupt
    randomize_input;
    // Record padding result
    _recordPadding;
    // Send input
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
    for(_cnt=0 ; _cnt<NUM_OF_INPUT*NUM_OF_IMAGE*SIZE_OF_IMAGE*SIZE_OF_IMAGE ; _cnt=_cnt+1) begin
        in_valid = 1;
        // Image
        Img = _img[1][_cnt/(SIZE_OF_IMAGE*SIZE_OF_IMAGE)+1][_cnt%(SIZE_OF_IMAGE*SIZE_OF_IMAGE)/SIZE_OF_IMAGE][_cnt%SIZE_OF_IMAGE];
        // Kernel
        if(_cnt<NUM_OF_KERNEL*SIZE_OF_KERNEL*SIZE_OF_KERNEL) begin
            Kernel_ch1 = _kernel[1][_cnt/(SIZE_OF_KERNEL*SIZE_OF_KERNEL)+1][_cnt%(SIZE_OF_KERNEL*SIZE_OF_KERNEL)/SIZE_OF_KERNEL][_cnt%SIZE_OF_KERNEL];
            Kernel_ch2 = _kernel[2][_cnt/(SIZE_OF_KERNEL*SIZE_OF_KERNEL)+1][_cnt%(SIZE_OF_KERNEL*SIZE_OF_KERNEL)/SIZE_OF_KERNEL][_cnt%SIZE_OF_KERNEL];
        end
        else begin
            Kernel_ch1 = 'dx;
            Kernel_ch2 = 'dx;
        end
        // Weight
        if(_cnt<NUM_OF_WEIGHT*SIZE_OF_WEIGHT) begin
            Weight = _weight[_cnt/SIZE_OF_WEIGHT+1][_cnt%SIZE_OF_WEIGHT];
        end
        else begin
            Weight = 'dx;
        end
        // Opt
        if(_cnt === 0) Opt = _opt;
        else Opt = 'dx;

        @(negedge clk);
    end
    in_valid = 0;
    Img = 'dx;
    Kernel_ch1 = 'dx;
    Kernel_ch2 = 'dx;
    Weight = 'dx;
    Opt = 'dx;
end endtask

task cal_task; begin
    _recordConvolution;
    _recordMaxPool;
    _recordActivate;
    _recordFully;
    _recordSoftmax;
    _recordProb;
    if(DEBUG) begin
        dump_input(0);
        dump_input(1);
        dump_output(0);
        dump_output(1);
    end
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out !== 0) begin
            $display("[ERROR] [WAIT] Output signal should be 0 at %-12d ps  ", $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end
        if(exe_lat == DELAY) begin
            $display("[ERROR] [WAIT] The execution latency at %-12d ps is over %5d cycles  ", $time*1000, DELAY);
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

task check_task;
    integer _errIdx;
begin
    out_lat = 0;
    while(out_valid===1) begin
        if(out_lat==OUTNUM) begin
            $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUTNUM, $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end
        _your[out_lat] = out;

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    if(out_lat<OUTNUM) begin
        $display("[ERROR] [OUTPUT] Out cycles is less than %3d at %-12d ps", OUTNUM, $time*1000);
        repeat(5) @(negedge clk);
        $finish;
    end

    //
    // Check
    //
    _recordErrAndCheck;
    if(_isErr!==0) begin
        $display("[ERROR] [OUTPUT] Output err rate is over %1.8f or errr is over %1.8f", _floatBitsToReal(_errRateAllow), _errAllow);
        $display("[ERROR] [OUTPUT] Dump debugging file...\n");
        for(_errIdx=0 ; _errIdx<SIZE_OF_OUTPUT ; _errIdx=_errIdx+1) begin
            $display("[ERROR] [#%1d]", _errIdx);
            $display("[ERROR] Error rate check : %1d", _errRateFlag[_errIdx]);
            $display("[ERROR] Error      check : %1d", _errFlag[_errIdx]);
            $display("[ERROR]    Output : [%8h / %8.4f]",
                _your[_errIdx], _floatBitsToReal(_your[_errIdx]));
            $display("[ERROR]    Golden : [%8h / %8.4f]\n",
                _prob[_errIdx], _floatBitsToReal(_prob[_errIdx]));
        end
        dump_input(0);
        dump_input(1);
        dump_output(0);
        dump_output(1);
        repeat(5) @(negedge clk);
        $finish;
    end

    tot_lat = tot_lat + exe_lat;
end endtask

task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

//======================================
//
//
//      IP Module Initialization
//          Convolution
//          Convolution sum
//          Max pooling
//          Activation
//          Fully connected
//          Softmax
//          Error
//
//
//======================================
//
// Convolution
//
parameter NUM_OF_INPUT_OF_CONV = SIZE_OF_KERNEL*SIZE_OF_KERNEL; // 2 * 2
parameter NUM_OF_INPUT_OF_MAXPOOL = SIZE_OF_MAXPOOL_WINDOW*SIZE_OF_MAXPOOL_WINDOW; // 3 * 3
parameter NUM_OF_INPUT_OF_FULLY = SIZE_OF_ACTIVATE*SIZE_OF_ACTIVATE*NUM_OF_KERNEL_CH; // 2 * 2 * 2
genvar gen_i, gen_j, gen_k;
genvar gen_input, gen_ch, gen_num, gen_row, gen_col, gen_inner;
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin
        for(gen_ch=1 ; gen_ch<=NUM_OF_KERNEL_CH ; gen_ch=gen_ch+1) begin
            for(gen_num=1 ; gen_num<=NUM_OF_IMAGE ; gen_num=gen_num+1) begin
                for(gen_row=0 ; gen_row<SIZE_OF_CONV ; gen_row=gen_row+1) begin
                    for(gen_col=0 ; gen_col<SIZE_OF_CONV ; gen_col=gen_col+1) begin
                        wire [inst_sig_width+inst_exp_width:0] a[NUM_OF_INPUT_OF_CONV-1:0];
                        wire [inst_sig_width+inst_exp_width:0] b[NUM_OF_INPUT_OF_CONV-1:0];
                        wire [inst_sig_width+inst_exp_width:0] convOut;
                        // Input
                        for(gen_i=0 ; gen_i<NUM_OF_INPUT_OF_CONV ; gen_i=gen_i+1) begin
                            assign a[gen_i] = _pad[gen_input][gen_num][gen_row+gen_i/SIZE_OF_KERNEL][gen_col+gen_i%SIZE_OF_KERNEL];
                            assign b[gen_i] = _kernel[gen_ch][gen_num][gen_i/SIZE_OF_KERNEL][gen_i%SIZE_OF_KERNEL];
                        end
                        // IP
                        mac #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch,NUM_OF_INPUT_OF_CONV)
                            c(
                                .in1(a), .in2(b), .out(convOut)
                            );
                        assign _conv_w[gen_input][gen_ch][gen_num][gen_row][gen_col] = convOut;
                    end
                end
            end
        end
    end
endgenerate
//
// Convolution sum
//
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin : gb_input
        for(gen_ch=1 ; gen_ch<=NUM_OF_KERNEL_CH ; gen_ch=gen_ch+1) begin : gb_ch
            for(gen_row=0 ; gen_row<SIZE_OF_CONV ; gen_row=gen_row+1) begin : gb_row
                for(gen_col=0 ; gen_col<SIZE_OF_CONV ; gen_col=gen_col+1) begin : gb_col
                    for(gen_num=2 ; gen_num<=NUM_OF_IMAGE ; gen_num=gen_num+1) begin : gb_num
                        wire [inst_sig_width+inst_exp_width:0] convSumOut;
                        if(gen_num===2) begin
                            DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch)
                                as(
                                    .a(_conv_w[gen_input][gen_ch][gen_num-1][gen_row][gen_col]),
                                    .b(_conv_w[gen_input][gen_ch][gen_num][gen_row][gen_col]),
                                    .op(1'd0), .rnd(3'd0), .z(convSumOut)
                                );
                        end
                        else begin
                            DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch)
                                as(
                                    .a(gb_input[gen_input].gb_ch[gen_ch].gb_row[gen_row].gb_col[gen_col].gb_num[gen_num-1].convSumOut),
                                    .b(_conv_w[gen_input][gen_ch][gen_num][gen_row][gen_col]),
                                    .op(1'd0), .rnd(3'd0), .z(convSumOut)
                                );
                        end
                    end
                    assign _convSum_w[gen_input][gen_ch][gen_row][gen_col] = 
                        gb_input[gen_input].gb_ch[gen_ch].gb_row[gen_row].gb_col[gen_col].gb_num[NUM_OF_IMAGE].convSumOut;
                end
            end
            
        end
    end
endgenerate
//
// Max pooling
//
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin
        for(gen_ch=1 ; gen_ch<=NUM_OF_KERNEL_CH ; gen_ch=gen_ch+1) begin
            for(gen_row=0 ; gen_row<SIZE_OF_MAXPOOL ; gen_row=gen_row+1) begin
                for(gen_col=0 ; gen_col<SIZE_OF_MAXPOOL ; gen_col=gen_col+1) begin
                    wire [inst_sig_width+inst_exp_width:0] _in[NUM_OF_INPUT_OF_MAXPOOL-1:0];
                    wire [inst_sig_width+inst_exp_width:0] _min;
                    wire [inst_sig_width+inst_exp_width:0] _max;
                    // Input
                    for(gen_i=0 ; gen_i<NUM_OF_INPUT_OF_MAXPOOL ; gen_i=gen_i+1) begin
                        assign _in[gen_i] = 
                            _convSum_w[gen_input][gen_ch]
                                [gen_row*SIZE_OF_MAXPOOL_WINDOW+gen_i/SIZE_OF_MAXPOOL_WINDOW]
                                [gen_col*SIZE_OF_MAXPOOL_WINDOW+gen_i%SIZE_OF_MAXPOOL_WINDOW];
                    end
                    // IP
                    findMinAndMax
                    #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch,NUM_OF_INPUT_OF_MAXPOOL)
                        f(
                            .in(_in),.min(_min),.max(_max)
                        );

                    assign _maxPool_w[gen_input][gen_ch][gen_row][gen_col] = _max;
                end
            end
        end
    end
endgenerate

//
// Activation
//
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin
        for(gen_ch=1 ; gen_ch<=NUM_OF_KERNEL_CH ; gen_ch=gen_ch+1) begin
            for(gen_row=0 ; gen_row<SIZE_OF_ACTIVATE ; gen_row=gen_row+1) begin
                for(gen_col=0 ; gen_col<SIZE_OF_ACTIVATE ; gen_col=gen_col+1) begin
                    wire[inst_sig_width+inst_exp_width:0] _sigmoidOut;
                    wire[inst_sig_width+inst_exp_width:0] _tanhOut;
                    sigmoid#(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch)
                        s(
                            .in(_maxPool_w[gen_input][gen_ch][gen_row][gen_col]),
                            .out(_sigmoidOut)
                        );
                    tanh#(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch)
                        t(
                            .in(_maxPool_w[gen_input][gen_ch][gen_row][gen_col]),
                            .out(_tanhOut)
                        );
                    assign _activate_w[gen_input][gen_ch][gen_row][gen_col] = (_opt===0) ? _sigmoidOut : _tanhOut;
                end
            end
        end
    end
endgenerate

//
// Fully connected
//
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin
        for(gen_num=1 ; gen_num<=NUM_OF_WEIGHT ; gen_num=gen_num+1) begin
            wire [inst_sig_width+inst_exp_width:0] a[NUM_OF_INPUT_OF_FULLY-1:0];
            wire [inst_sig_width+inst_exp_width:0] b[NUM_OF_INPUT_OF_FULLY-1:0];
            wire [inst_sig_width+inst_exp_width:0] fullyOut;
            // Input
            for(gen_ch=1 ; gen_ch<=NUM_OF_KERNEL_CH ; gen_ch=gen_ch+1) begin
                for(gen_row=0 ; gen_row<SIZE_OF_ACTIVATE ; gen_row=gen_row+1) begin
                    for(gen_col=0 ; gen_col<SIZE_OF_ACTIVATE ; gen_col=gen_col+1) begin
                        assign a[(gen_ch-1)*SIZE_OF_ACTIVATE*SIZE_OF_ACTIVATE + gen_row*SIZE_OF_ACTIVATE + gen_col]
                            = _activate_w[gen_input][gen_ch][gen_row][gen_col];
                        assign b[(gen_ch-1)*SIZE_OF_ACTIVATE*SIZE_OF_ACTIVATE + gen_row*SIZE_OF_ACTIVATE + gen_col]
                            = _weight[gen_num][(gen_ch-1)*SIZE_OF_ACTIVATE*SIZE_OF_ACTIVATE + gen_row*SIZE_OF_ACTIVATE + gen_col];
                    end
                end
            end
            // IP
            mac #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch,NUM_OF_INPUT_OF_FULLY)
                c(
                    .in1(a), .in2(b), .out(fullyOut)
                );
            assign _fully_w[gen_input][gen_num-1] = fullyOut;
        end
    end
endgenerate

//
// Softmax
//
generate
    for(gen_input=1 ; gen_input<=NUM_OF_INPUT ; gen_input=gen_input+1) begin
        wire[inst_sig_width+inst_exp_width:0] in_z[SIZE_OF_OUTPUT-1:0];
        for(gen_num=0 ; gen_num<SIZE_OF_OUTPUT ; gen_num=gen_num+1) begin
            assign in_z[gen_num] = _fully_w[gen_input][gen_num];
        end
        for(gen_num=0 ; gen_num<SIZE_OF_OUTPUT ; gen_num=gen_num+1) begin
            wire[inst_sig_width+inst_exp_width:0] softmaxOut;
            softmax #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch,SIZE_OF_OUTPUT)
                sm(
                    .in_z(in_z[gen_num]),
                    .in(in_z),
                    .out(softmaxOut)
                );
            assign _softmax_w[gen_input][gen_num] = softmaxOut;
        end
    end
endgenerate

//
// Error
//
generate
    for(gen_num=0 ; gen_num<SIZE_OF_OUTPUT ; gen_num=gen_num+1) begin
        wire [inst_sig_width+inst_exp_width:0] bound;
        wire [inst_sig_width+inst_exp_width:0] error_diff;
        wire [inst_sig_width+inst_exp_width:0] error_diff_pos;

        // gold - ans
        DW_fp_sub
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_S0 (.a(_prob[gen_num]), .b(_your[gen_num]), .z(error_diff), .rnd(3'd0));

        // gold * _errAllow
        DW_fp_mult
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_M0 (.a(_errRateAllow), .b(_prob[gen_num]), .z(bound), .rnd(3'd0));

        // check |gold - ans| > gold * _errAllow
        DW_fp_cmp
        #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
            Err_C0 (.a(error_diff_pos), .b(bound), .agtb(_errRateFlag[gen_num]), .zctr(1'd0));

        assign error_diff_pos = error_diff[inst_sig_width+inst_exp_width] ? {1'b0, error_diff[inst_sig_width+inst_exp_width-1:0]} : error_diff;
        assign _errDiff_w[gen_num] = error_diff_pos;
        assign _errBound_w[gen_num] = bound;
    end
endgenerate


endmodule



//======================================
//
//
//      IP Module Utility
//          Convolution
//          Max pooling : findMinAndMax
//          Activation : sigmoid, tanh
//          Fully connected
//          Softmax
//
//
//======================================
module mac
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 9
)
(
    input  [inst_sig_width+inst_exp_width:0] in1[num_of_input-1:0],
    input  [inst_sig_width+inst_exp_width:0] in2[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] out
);
    initial begin
        if(num_of_input < 2) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 2");
            $finish;
        end
    end
    genvar i;
    generate
        for(i=0 ; i<num_of_input ; i=i+1) begin : gen_conv_mult
            wire [inst_sig_width+inst_exp_width:0] _mult;
            DW_fp_mult#(inst_sig_width, inst_exp_width, inst_ieee_compliance)
                M0 (.a(in1[i]), .b(in2[i]), .rnd(3'd0), .z(_mult));
        end
    endgenerate
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_conv_add
            wire [inst_sig_width+inst_exp_width:0] _add;
            if(i==1) begin
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_conv_mult[0]._mult), .b(gen_conv_mult[1]._mult),
                        .op(1'd0), .rnd(3'd0), .z(_add));
            end
            else begin
                DW_fp_addsub#(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_conv_add[i-1]._add), .b(gen_conv_mult[i]._mult),
                        .op(1'd0), .rnd(3'd0), .z(_add));
            end
        end
        assign out = gen_conv_add[num_of_input-1]._add;
    endgenerate
endmodule

module findMinAndMax
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 4
)
(
    input  [inst_sig_width+inst_exp_width:0] in[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] min, max
);
    initial begin
        if(num_of_input < 2) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 2");
            $finish;
        end
    end
    genvar i;
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_comp
            wire [inst_sig_width+inst_exp_width:0] _min, _max;
            if(i===1) begin
                wire flag;
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    C0 (.a(in[i-1]), .b(in[i]), .agtb(flag), .zctr(1'd0));

                assign _min = flag==1 ? in[i] : in[i-1];
                assign _max = flag==1 ? in[i-1] : in[i];
            end
            else begin
                wire flagMin, flagMax;
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    Cmin (.a(gen_comp[i-1]._min), .b(in[i]), .agtb(flagMin), .zctr(1'd0));
                DW_fp_cmp
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance) 
                    Cmax (.a(gen_comp[i-1]._max), .b(in[i]), .agtb(flagMax), .zctr(1'd0));

                assign _min = flagMin==1 ? in[i] : gen_comp[i-1]._min;
                assign _max = flagMax==1 ? gen_comp[i-1]._max : in[i];
            end
        end
        assign min = gen_comp[num_of_input-1]._min;
        assign max = gen_comp[num_of_input-1]._max;
    endgenerate

endmodule

module sigmoid
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg));
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp));
    
    DW_fp_addsub // 1+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp), .op(1'd0), .rnd(3'd0), .z(deno));
    
    DW_fp_div // 1 / [1+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(float_gain1), .b(deno), .rnd(3'd0), .z(out));
endmodule

module tanh
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] float_gain2 = 32'hBF800000; // Activation -1.0
    wire [inst_sig_width+inst_exp_width:0] x_neg;
    wire [inst_sig_width+inst_exp_width:0] exp_pos;
    wire [inst_sig_width+inst_exp_width:0] exp_neg;
    wire [inst_sig_width+inst_exp_width:0] nume;
    wire [inst_sig_width+inst_exp_width:0] deno;

    DW_fp_mult // -x
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        M0 (.a(in), .b(float_gain2), .rnd(3'd0), .z(x_neg));
    
    DW_fp_exp // exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(x_neg), .z(exp_neg));

    DW_fp_exp // exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E1 (.a(in), .z(exp_pos));

    //

    DW_fp_addsub // exp(x)-exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(exp_pos), .b(exp_neg), .op(1'd1), .rnd(3'd0), .z(nume));

    DW_fp_addsub // exp(x)+exp(-x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A1 (.a(exp_pos), .b(exp_neg), .op(1'd0), .rnd(3'd0), .z(deno));

    DW_fp_div // [exp(x)-exp(-x)] / [exp(x)+exp(-x)]
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(nume), .b(deno), .rnd(3'd0), .z(out));

endmodule

module softmax
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0,
    parameter num_of_input = 3
)
(
    input  [inst_sig_width+inst_exp_width:0] in_z,
    input  [inst_sig_width+inst_exp_width:0] in[num_of_input-1:0],
    output [inst_sig_width+inst_exp_width:0] out
);
    initial begin
        if(num_of_input < 1) begin
            $display("[ERROR] [Parameter] The num_of_input can't be smaller than 1");
            $finish;
        end
    end
    genvar i;
    // exp(x)
    generate
        for(i=0 ; i<num_of_input ; i=i+1) begin : gen_exp
            wire[inst_sig_width+inst_exp_width:0] exp_pos;
            DW_fp_exp 
            #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
                E0 (.a(in[i]), .z(exp_pos));
        end
    endgenerate
    // sigma(exp(x))
    generate
        for(i=1 ; i<num_of_input ; i=i+1) begin : gen_exp_sum
            wire[inst_sig_width+inst_exp_width:0] exp_sum;
            if(i===1) begin
                DW_fp_addsub
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_exp[i-1].exp_pos), .b(gen_exp[i].exp_pos), .op(1'd0), .rnd(3'd0), .z(exp_sum));
            end
            else begin
                DW_fp_addsub 
                #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
                    A0 (.a(gen_exp_sum[i-1].exp_sum), .b(gen_exp[i].exp_pos), .op(1'd0), .rnd(3'd0), .z(exp_sum));
            end
        end
    endgenerate
    // [exp(in_z)-exp(-x)] / sigma(exp(x))
    wire[inst_sig_width+inst_exp_width:0] exp_pos_z;
    wire[inst_sig_width+inst_exp_width:0] res;
    DW_fp_exp 
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E0 (.a(in_z), .z(exp_pos_z));
    DW_fp_div
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0)
        D0 (.a(exp_pos_z), .b(gen_exp_sum[num_of_input-1].exp_sum), .rnd(3'd0), .z(res));
    assign out = res;
endmodule

module softplus
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    wire [inst_sig_width+inst_exp_width:0] float_gain1 = 32'h3F800000; // Activation 1.0
    wire [inst_sig_width+inst_exp_width:0] exp_pos;
    wire [inst_sig_width+inst_exp_width:0] plus;
    wire [7:0] status;
    
    DW_fp_exp // exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        E1 (.a(in), .z(exp_pos));

    DW_fp_addsub // 1+exp(x)
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance)
        A0 (.a(float_gain1), .b(exp_pos), .op(1'd0), .rnd(3'd0), .z(plus));

    DW_fp_ln // ln(1+exp(x))
    #(inst_sig_width,inst_exp_width,inst_ieee_compliance, 0, inst_arch)
        L0 (.a(plus), .status(status), .z(out));

endmodule

module relu
#(  parameter inst_sig_width       = 23,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 0
)
(
    input  [inst_sig_width+inst_exp_width:0] in,
    output [inst_sig_width+inst_exp_width:0] out
);
    assign out = in[inst_sig_width+inst_exp_width] ? 0 : in;
endmodule