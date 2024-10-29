`define CYCLE_TIME 10.0

`include "../00_TESTBED/pseudo_DRAM.v"

module PATTERN(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    in_pic_no,
    in_mode,
    in_ratio_mode,
    out_valid,
    out_data
);

//======================================
//      INPUT & OUTPUT
//======================================
output reg       clk, rst_n;
output reg       in_valid;

output reg [3:0] in_pic_no;
output reg       in_mode;
output reg [1:0] in_ratio_mode;

input out_valid;
input [7:0] out_data;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
// -------------------------------------
// [Mode]
//      0 : generate the simple dram.dat
//      1 : generate the regular dram.dat
//      2 : validate design
integer   MODE = 2;
// -------------------------------------
integer   SEED = 5487;
parameter DEBUG = 1;
parameter DRAMDAT_TO_GENERATED = "../00_TESTBED/DRAM/dram.dat";
parameter DRAMDAT_FROM_DRAM = `d_DRAM_p_r;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 20000;
parameter OUTNUM = 1;

// PATTERN CONTROL
integer pat;
integer exe_lat;
integer tot_lat;

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
// Debugging file
parameter IMAGE_ORIGINAL_FILE = "image_original.txt";
parameter IMAGE_ADJUSTED_FILE = "image_adjusted.txt";
parameter AUTO_FOCUS_FILE = "auto_focus.txt";
parameter AUTO_EXPOSURE_FILE = "auto_exposure.txt";
// Input
parameter NUM_OF_MODE = 2;
parameter NUM_OF_RATIO = 4;
// Image
parameter NUM_OF_PIC = 16;
parameter NUM_OF_CHANNEL = 3; // (R, G, B)
parameter SIZE_OF_PIC = 32;
parameter NUM_OF_CONTRASTS = 3;
parameter START_OF_DRAM_ADDRESS = 65536;
parameter BITS_OF_PIXEL = 8;
// Data
reg[BITS_OF_PIXEL-1:0] _image[NUM_OF_PIC-1:0][NUM_OF_CHANNEL-1:0][SIZE_OF_PIC-1:0][SIZE_OF_PIC-1:0];
reg[BITS_OF_PIXEL-1:0] _originalImage[NUM_OF_CHANNEL-1:0][SIZE_OF_PIC-1:0][SIZE_OF_PIC-1:0];
parameter real _grayscaleRatio[NUM_OF_CHANNEL-1:0] = {0.25, 0.5, 0.25};
integer _noPic;
integer _mode;
parameter real _ratio[NUM_OF_RATIO-1:0] = {2, 1, 0.5, 0.25};
integer _ratioMode;
// Mode 0
parameter integer _constrast[NUM_OF_CONTRASTS-1:0] = {6, 4, 2}; // Contrast
parameter MAX_SIZE_OF_CONTRASTS = _constrast[NUM_OF_CONTRASTS-1];
integer _focusWindow[NUM_OF_CONTRASTS-1:0][NUM_OF_CHANNEL-1:0][MAX_SIZE_OF_CONTRASTS-1:0][MAX_SIZE_OF_CONTRASTS-1:0];
integer _focusGrayWindow[NUM_OF_CONTRASTS-1:0][MAX_SIZE_OF_CONTRASTS-1:0][MAX_SIZE_OF_CONTRASTS-1:0];
integer _focusDiffHorizontal[NUM_OF_CONTRASTS-1:0];
integer _focusDiffVertical[NUM_OF_CONTRASTS-1:0];
integer _focusNormalizedDiff[NUM_OF_CONTRASTS-1:0];
integer _maxContrast;
// Mode 1
parameter ERROR_MARGIN = 2;
integer _exposureGrayscale;
//
integer _yourOutput;

//
// Load
//
task load_pic_from_dram;
    integer file;
    integer status;
    integer val;
    integer _cnt;
    integer _pic;
    integer _ch;
    integer _row;
    integer _col;
begin
    file = $fopen(DRAMDAT_FROM_DRAM, "r");
    if (file == 0) begin
        $display("[ERROR] [FILE] The file (%0s) can't be opened", DRAMDAT_FROM_DRAM);
        $finish;
    end
    _cnt = 0;
    _pic = 0;
    _ch  = 0;
    _row = 0;
    _col = 0;
    while(!$feof(file))begin
        // Address
        status = $fscanf(file, "@%h", val);
        // Pixel
        status = $fscanf(file, "%2h", val);
        if (status == 1) begin
            _image[_pic][_ch][_row][_col] = val;
            _cnt = _cnt + 1;
        end
        _pic = (_cnt/(SIZE_OF_PIC*SIZE_OF_PIC*NUM_OF_CHANNEL))%NUM_OF_PIC;
        _ch  = (_cnt/(SIZE_OF_PIC*SIZE_OF_PIC))%NUM_OF_CHANNEL;
        _row = (_cnt/SIZE_OF_PIC)%SIZE_OF_PIC;
        _col = _cnt%SIZE_OF_PIC;
    end
    $fclose(file);
end endtask

//
// Setter
//
task record_original_image;
    integer _ch;
    integer _row;
    integer _col;
begin
    for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
        for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
            for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                _originalImage[_ch][_row][_col] = _image[_noPic][_ch][_row][_col];
            end
        end
    end
end endtask

//
// Operation
//
task auto_focus;
    integer _crst;
    integer _ch;
    integer _row;
    integer _col;

    integer temp;
    parameter PIC_MID = SIZE_OF_PIC/2;
begin
    for(_crst=0 ; _crst<NUM_OF_CONTRASTS ; _crst=_crst+1) begin
        //
        // Clear window
        //
        for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
            for(_row=0 ; _row<MAX_SIZE_OF_CONTRASTS ; _row=_row+1) begin
                for(_col=0 ; _col<MAX_SIZE_OF_CONTRASTS ; _col=_col+1) begin
                    _focusWindow[_crst][_ch][_row][_col] = 0;
                end
            end
        end
        for(_row=0 ; _row<MAX_SIZE_OF_CONTRASTS ; _row=_row+1) begin
            for(_col=0 ; _col<MAX_SIZE_OF_CONTRASTS ; _col=_col+1) begin
                _focusGrayWindow[_crst][_row][_col] = 0;
            end
        end
        //
        // Set window
        //
        for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
            for(_row=0 ; _row<_constrast[_crst] ; _row=_row+1) begin
                for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
                    _focusWindow[_crst][_ch][_row][_col] = 
                        _originalImage[_ch][PIC_MID-_constrast[_crst]/2+1+_row][PIC_MID-_constrast[_crst]/2+1+_col];
                end
            end
        end
        for(_row=0 ; _row<_constrast[_crst] ; _row=_row+1) begin
            for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
                for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
                    _focusGrayWindow[_crst][_row][_col] =
                        _focusGrayWindow[_crst][_row][_col] +
                        _focusWindow[_crst][_ch][_row][_col] * _grayscaleRatio[_ch];
                end
            end
        end
        //
        // Difference on vertical & horizontal direction
        //
        _focusDiffHorizontal[_crst] = 0;
        _focusDiffVertical[_crst] = 0;
        _focusNormalizedDiff[_crst] = 0;
        // Col difference
        for(_row=0 ; _row<_constrast[_crst] ; _row=_row+1) begin
            for(_col=0 ; _col<_constrast[_crst]-1 ; _col=_col+1) begin
                temp =
                    (_focusGrayWindow[_crst][_row][_col]   - _focusGrayWindow[_crst][_row][_col+1]) > 0 ?
                    (_focusGrayWindow[_crst][_row][_col]   - _focusGrayWindow[_crst][_row][_col+1]) :
                    (_focusGrayWindow[_crst][_row][_col+1] - _focusGrayWindow[_crst][_row][_col]);
                _focusDiffVertical[_crst] = 
                    _focusDiffVertical[_crst] + temp;
            end
        end
        // Row difference
        for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
            for(_row=0 ; _row<_constrast[_crst]-1 ; _row=_row+1) begin
                temp =
                    (_focusGrayWindow[_crst][_row+1][_col] - _focusGrayWindow[_crst][_row][_col]) > 0 ?
                    (_focusGrayWindow[_crst][_row+1][_col] - _focusGrayWindow[_crst][_row][_col]) :
                    (_focusGrayWindow[_crst][_row][_col]   - _focusGrayWindow[_crst][_row+1][_col]);
                _focusDiffHorizontal[_crst] = 
                    _focusDiffHorizontal[_crst] + temp;
            end
        end
        //
        // Normalize difference
        //
        _focusNormalizedDiff[_crst] = 
            (_focusDiffVertical[_crst] + _focusDiffHorizontal[_crst]) / (_constrast[_crst]*_constrast[_crst]);
    end
    //
    // Find max contrast
    //
    _maxContrast = -1;
    temp = -1;
    for(_crst=0 ; _crst<NUM_OF_CONTRASTS ; _crst=_crst+1) begin
        if(_focusNormalizedDiff[_crst] > temp) begin
            _maxContrast = _crst;
            temp = _focusNormalizedDiff[_crst];
        end
    end
end endtask

task auto_exposure;
    integer _ch;
    integer _row;
    integer _col;
    integer temp;
begin
    //
    // Adjust
    //
    for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
        for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
            for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                temp = _originalImage[_ch][_row][_col] * _ratio[_ratioMode];
                _image[_noPic][_ch][_row][_col] = 
                    (temp >= (2**BITS_OF_PIXEL - 1)) ? 
                        (2**BITS_OF_PIXEL - 1) : temp;
            end
        end
    end
    //
    // Average grayscale
    //
    _exposureGrayscale = 0;
    for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
            for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
                _exposureGrayscale = _exposureGrayscale +
                    _image[_noPic][_ch][_row][_col] * _grayscaleRatio[_ch];
            end
        end
    end
    _exposureGrayscale = _exposureGrayscale/(SIZE_OF_PIC*SIZE_OF_PIC);
end endtask

//
// Utility
//
function isErr;
    input integer in1;
    input integer in2;
    integer abs;
begin
    if(_mode!==1) begin
        $display("[ERROR] [MODE] The mode should be 1. (Auto exposure)");
        $finish;
    end
    abs = (in1 - in2) > 0 ? in1 - in2 : in2 - in1;
    isErr = (abs >= ERROR_MARGIN) ? 1 : 0;
end endfunction

//
// Dump
//
parameter DUMP_OPT_PIXEL = 12;
parameter DUMP_SIZE_PIXEL = 4;
dumper #(.DUMP_ELEMENT_SIZE(DUMP_OPT_PIXEL)) optDumper();
dumper #(.DUMP_ELEMENT_SIZE(DUMP_SIZE_PIXEL)) pixelDumper();

task clear_dump_file;
    integer file;
begin
    file = $fopen(IMAGE_ORIGINAL_FILE, "w");
    $fclose(file);
    file = $fopen(IMAGE_ADJUSTED_FILE, "w");
    $fclose(file);
    file = $fopen(AUTO_FOCUS_FILE, "w");
    $fclose(file);
    file = $fopen(AUTO_EXPOSURE_FILE, "w");
    $fclose(file);
end endtask

task dump_original_image;
    integer file;
    integer _ch;
    integer _row;
    integer _col;

    reg[DUMP_OPT_PIXEL*8:1] _strOpt;
    reg[DUMP_SIZE_PIXEL*8:1] _strPixel;
    
begin
    file = $fopen(IMAGE_ORIGINAL_FILE, "w");
    // Operation
    optDumper.addSeperator(file, 2);
    optDumper.addCell(file, "Pat No.", "s", 1);
    optDumper.addCell(file,    pat, "d", 0);
    optDumper.addLine(file);
    optDumper.addSeperator(file, 2);
    optDumper.addCell(file, "Pic No.", "s", 1);
    optDumper.addCell(file,    _noPic, "d", 0);
    optDumper.addLine(file);
    optDumper.addCell(file, "Mode", "s", 1);
    optDumper.addCell(file,  _mode, "d", 0);
    optDumper.addLine(file);
    if(_mode == 1) begin
        optDumper.addCell(file, "Ratio Mode", "s", 1);
        optDumper.addCell(file,   _ratioMode, "d", 0);
        optDumper.addLine(file);
        optDumper.addCell(file, "Ratio Value", "s", 1);
        $sformat(_strOpt, "%12.3f", _ratio[_ratioMode]);
        optDumper.addCell(file, _strOpt, "s", 0);
        optDumper.addLine(file);
    end
    optDumper.addSeperator(file, 2);
    optDumper.addLine(file);

    // Image
    for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
        // RGB
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        case(_ch)
            'd0:pixelDumper.addCell(file, "R-0", "s", 1);
            'd1:pixelDumper.addCell(file, "G-1", "s", 1);
            'd2:pixelDumper.addCell(file, "B-2", "s", 1);
        endcase
        // Column index
        for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
            pixelDumper.addCell(file, _col, "d", 0);
        end
        optDumper.addLine(file);
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        // Row index & pixel
        for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
            // Row index
            pixelDumper.addCell(file, _row, "d", 1);
            // Pixel
            for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                pixelDumper.addCell(file, _originalImage[_ch][_row][_col], "d", 0);
            end
            optDumper.addLine(file);
        end
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        optDumper.addLine(file);
    end
    $fclose(file);
end endtask

task dump_adjusted_image;
    integer file;
    integer _ch;
    integer _row;
    integer _col;

    reg[DUMP_OPT_PIXEL*8:1] _strOpt;
    reg[DUMP_SIZE_PIXEL*8:1] _strPixel;
    
begin
    file = $fopen(IMAGE_ADJUSTED_FILE, "w");
    // Operation
    optDumper.addSeperator(file, 2);
    optDumper.addCell(file, "Pat No.", "s", 1);
    optDumper.addCell(file,    pat, "d", 0);
    optDumper.addLine(file);
    optDumper.addSeperator(file, 2);
    optDumper.addCell(file, "Pic No.", "s", 1);
    optDumper.addCell(file,    _noPic, "d", 0);
    optDumper.addLine(file);
    optDumper.addCell(file, "Mode", "s", 1);
    optDumper.addCell(file,  _mode, "d", 0);
    optDumper.addLine(file);
    if(_mode == 1) begin
        optDumper.addCell(file, "Ratio Mode", "s", 1);
        optDumper.addCell(file,   _ratioMode, "d", 0);
        optDumper.addLine(file);
        optDumper.addCell(file, "Ratio Value", "s", 1);
        $sformat(_strOpt, "%12.3f", _ratio[_ratioMode]);
        optDumper.addCell(file, _strOpt, "s", 0);
        optDumper.addLine(file);
    end
    optDumper.addSeperator(file, 2);
    optDumper.addLine(file);

    // Image
    for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
        // RGB
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        case(_ch)
            'd0:pixelDumper.addCell(file, "R-0", "s", 1);
            'd1:pixelDumper.addCell(file, "G-1", "s", 1);
            'd2:pixelDumper.addCell(file, "B-2", "s", 1);
        endcase
        // Column index
        for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
            pixelDumper.addCell(file, _col, "d", 0);
        end
        optDumper.addLine(file);
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        // Row index & pixel
        for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
            // Row index
            pixelDumper.addCell(file, _row, "d", 1);
            // Pixel
            for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                // if(_image[_noPic][_ch][_row][_col] !== _originalImage[_ch][_row][_col]) begin
                //     $sformat(_strPixel, "*%3d", _image[_noPic][_ch][_row][_col]);
                // end
                // else begin
                //     $sformat(_strPixel, "%3d", _image[_noPic][_ch][_row][_col]);
                // end
                // pixelDumper.addCell(file, _strPixel, "s", 0);
                pixelDumper.addCell(file, _image[_noPic][_ch][_row][_col], "d", 0);
            end
            optDumper.addLine(file);
        end
        pixelDumper.addSeperator(file, SIZE_OF_PIC+1);
        optDumper.addLine(file);
    end
    $fclose(file);
end endtask

task dump_focus;
    integer file;
    integer _crst;
    integer _ch;
    integer _row;
    integer _col;
    reg[DUMP_SIZE_PIXEL*8:1] _strPixel;
begin
    file = $fopen("auto_focus.txt", "w");
    $fwrite(file, "[ Auto focus ]\n\n");
    for(_crst=0 ; _crst<NUM_OF_CONTRASTS ; _crst=_crst+1) begin
        //
        // Focus size
        //
        $fwrite(file, "[ %1d*%1d ]\n", _constrast[_crst], _constrast[_crst]);
        //
        // Focus window
        //
        $fwrite(file, "[ Focus window ]\n");
        for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
            pixelDumper.addSeperator(file, _constrast[_crst]+1);
            case(_ch)
                'd0:pixelDumper.addCell(file, "R-0", "s", 1);
                'd1:pixelDumper.addCell(file, "G-1", "s", 1);
                'd2:pixelDumper.addCell(file, "B-2", "s", 1);
            endcase
            // Column index
            for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
                pixelDumper.addCell(file, _col, "d", 0);
            end
            optDumper.addLine(file);
            pixelDumper.addSeperator(file, _constrast[_crst]+1);
            // Row index & pixel
            for(_row=0 ; _row<_constrast[_crst] ; _row=_row+1) begin
                // Row index
                pixelDumper.addCell(file, _row, "d", 1);
                // Pixel
                for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
                    pixelDumper.addCell(file, _focusWindow[_crst][_ch][_row][_col], "d", 0);
                end
                optDumper.addLine(file);
            end
            pixelDumper.addSeperator(file, _constrast[_crst]+1);
            optDumper.addLine(file);
        end

        //
        // Focus grayscale
        //
        $fwrite(file, "[ Focus grayscale ]\n");
        // Column index
        pixelDumper.addSeperator(file, _constrast[_crst]+1);
        pixelDumper.addCell(file, "Gray", "s", 1);
        for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
            pixelDumper.addCell(file, _col, "d", 0);
        end
        optDumper.addLine(file);
        pixelDumper.addSeperator(file, _constrast[_crst]+1);
        // Row index & pixel
        for(_row=0 ; _row<_constrast[_crst] ; _row=_row+1) begin
            // Row index
            pixelDumper.addCell(file, _row, "d", 1);
            // Pixel
            for(_col=0 ; _col<_constrast[_crst] ; _col=_col+1) begin
                pixelDumper.addCell(file, _focusGrayWindow[_crst][_row][_col], "d", 0);
            end
            optDumper.addLine(file);
        end
        pixelDumper.addSeperator(file, _constrast[_crst]+1);
        optDumper.addLine(file);

        //
        // Focus difference
        //
        $fwrite(file, "[ Focus horizontal difference ] : %-10d\n", _focusDiffHorizontal[_crst]);
        $fwrite(file, "[ Focus vertical difference   ] : %-10d\n", _focusDiffVertical[_crst]);
        $fwrite(file, "[ Focus normalized difference ] : %-10d\n\n", _focusNormalizedDiff[_crst]);
    end
    $fwrite(file, "[ Max contrast index / value  ] : %-2d / %-2d\n", _maxContrast, _constrast[_maxContrast]);
    $fwrite(file, "[ Your max contrast ] : %-2d\n", _yourOutput);
    $fclose(file);
end endtask

task dump_exposure;
    integer file;
    integer _ch;
    integer _row;
    integer _col;
begin
    file = $fopen(AUTO_EXPOSURE_FILE, "w");
    $fwrite(file, "[ Exposure grayscale ] : %-10d\n", _exposureGrayscale);
    $fwrite(file, "[     Your grayscale ] : %-10d\n", _yourOutput);
    $fclose(file);
end endtask

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
    case(MODE)
        'd0, 'd1: generate_dram_task;
        'd2: validate_design_task;
        default: begin
            $display("[ERROR] [PARAMETER] Mode (%-d) isn't valid...", MODE);
            $finish;
        end
    endcase
end endtask

task generate_dram_task;
    integer file;
    integer _pic;
    integer _ch;
    integer _row;
    integer _col;
begin
    $display("[Info] Start to generate dram.dat");
    file = $fopen(DRAMDAT_TO_GENERATED, "w");
    if (file == 0) begin
        $display("[ERROR] [FILE] The file (%0s) can't be opened", DRAMDAT_TO_GENERATED);
        $finish;
    end
    for(_pic=0 ; _pic<NUM_OF_PIC ; _pic=_pic+1) begin
        $fwrite(file, "@%-5h\n",
            START_OF_DRAM_ADDRESS+_pic*NUM_OF_CHANNEL*SIZE_OF_PIC*SIZE_OF_PIC);
        for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
            for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                    if(MODE == 0) $fwrite(file, "%02h ", {$random(SEED)} % 26); // simple
                    else          $fwrite(file, "%02h ", {$random(SEED)} % 2**BITS_OF_PIXEL); // regular
                end
                $fwrite(file, "\n");
            end
            $fwrite(file, "\n");
        end
    end
    $fclose(file);
    $finish;
end endtask

task validate_design_task; begin
    reset_task;
    load_pic_from_dram;
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
    in_pic_no = 'dx;
    in_mode = 'dx;
    in_ratio_mode = 'dx;

    tot_lat = 0;

    repeat(5) #(CYCLE/2.0) rst_n = 0;
    repeat(5) #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out_data !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

task input_task; begin
    repeat(2) @(negedge clk);
    _noPic = {$random(SEED)} % NUM_OF_PIC;
    _mode = {$random(SEED)} % NUM_OF_MODE;
    _ratioMode = (_mode == 1) ? {$random(SEED)} % NUM_OF_RATIO : 'dx;

    in_valid = 1;
    in_pic_no = _noPic;
    in_mode = _mode;
    in_ratio_mode = (_mode == 1) ? _ratioMode : 'dx;
    @(negedge clk);
    in_valid = 0;
    in_pic_no = 'dx;
    in_mode = 'dx;
    in_ratio_mode = 'dx;
end endtask

task cal_task;
    integer size;
begin
    record_original_image;
    case(_mode)
        'd0: auto_focus;
        'd1: auto_exposure;
        default: begin
            $display("[ERROR] [CAL] The mode (%2d) is no valid", _mode);
            $finish;
        end
    endcase
    if(DEBUG) begin
        clear_dump_file;
        dump_original_image;
        dump_adjusted_image;
        dump_focus;
        dump_exposure;
    end
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out_data !== 0) begin
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
    integer out_lat;
begin
    out_lat = 0;
    while(out_valid===1) begin
        if(out_lat==OUTNUM) begin
            $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUTNUM, $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end

        _yourOutput = out_data;

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    if(out_lat<OUTNUM) begin
        $display("[ERROR] [OUTPUT] Out cycles is less than %3d at %-12d ps", OUTNUM, $time*1000);
        repeat(5) @(negedge clk);
        $finish;
    end

    if(_mode==0) begin
        if(_yourOutput!==_maxContrast) begin
            $display("[ERROR] [OUTPUT] Output is not correct...\n");
            $display("[ERROR] [OUTPUT] Dump debugging file...");
            $display("[ERROR] [OUTPUT]      image_original.txt");
            $display("[ERROR] [OUTPUT]      auto_focus.txt\n");
            $display("[ERROR] [OUTPUT] Your output : %-d", _yourOutput);
            $display("[ERROR] [OUTPUT] Golden max contrast : %-d\n", _maxContrast);
            clear_dump_file;
            dump_original_image;
            dump_focus;
            repeat(5) @(negedge clk);
            $finish;
        end
    end
    else begin
        if(isErr(_yourOutput,_exposureGrayscale)) begin
            $display("[ERROR] [OUTPUT] Output is not correct...\n");
            $display("[ERROR] [OUTPUT] Dump debugging file...");
            $display("[ERROR] [OUTPUT]      image_original.txt -> before auto exposure");
            $display("[ERROR] [OUTPUT]      image_adjusted.txt ->  after auto exposure");
            $display("[ERROR] [OUTPUT]      auto_exposure.txt\n");
            $display("[ERROR] [OUTPUT] Your output : %-d", _yourOutput);
            $display("[ERROR] [OUTPUT] Golden exposure grayscale : %-d\n", _exposureGrayscale);
            clear_dump_file;
            dump_original_image;
            dump_adjusted_image;
            dump_exposure;
            repeat(5) @(negedge clk);
            $finish;
        end
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

endmodule

module dumper #(
    parameter DUMP_ELEMENT_SIZE = 4
);

// Dump
parameter DUMP_NUM_OF_SPACE = 2;
parameter DUMP_NUM_OF_SEP = 2;
parameter SIZE_OF_BUFFER = 256;

task addLine;
    input integer file;
begin
    $fwrite(file, "\n");
end endtask

task addSeperator;
    input integer file;
    input integer _num;
    integer _idx;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line; // 4 = 2 spaces with 2 "+"
begin
    _line = "";
    for(_idx=1 ; _idx<=DUMP_ELEMENT_SIZE+2 ; _idx=_idx+1) begin
        _line = {_line, "-"};
    end
    _line = {_line, "+"};
    $fwrite(file, "+");
    for(_idx=0 ; _idx<_num ; _idx=_idx+1) $fwrite(file, "%0s", _line);
    $fwrite(file, "\n");
end endtask

// TODO
// Only support %d %s
// Should consider the %f ex : %8.3f, %12.1f
task addCell;
    input integer file;
    input reg[DUMP_ELEMENT_SIZE*8:1] _in;
    input reg[8:1] _type;
    input reg _isStart;
    reg[SIZE_OF_BUFFER*8:1] _format;
    reg[DUMP_ELEMENT_SIZE*8:1] _inFormat;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line;
begin
    // Format
    $sformat(_format, "%%%-d", DUMP_ELEMENT_SIZE);
    _format = {_format[(SIZE_OF_BUFFER-1)*8:1], _type};
    $sformat(_inFormat, _format, _in);
    // Output
    _line = _isStart ? "| " : " ";
    _line = {_line, _inFormat};
    _line = {_line, " |"};
    $fwrite(file, "%0s", _line);
end endtask

// task addCellUnformat;
//     input integer file;
//     input reg[DUMP_ELEMENT_SIZE*8:1] _in;
//     input reg _isStart;
//     reg[SIZE_OF_BUFFER*8:1] _format;
//     reg[DUMP_ELEMENT_SIZE*8:1] _inFormat;
//     reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line;
// begin
//     _line = _isStart ? "| " : " ";
//     _line = {_line, _in};
//     _line = {_line, " |"};
//     $fwrite(file, "%0s", _line);
// end endtask

endmodule
