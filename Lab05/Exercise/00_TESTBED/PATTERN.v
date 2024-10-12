/*
    @debug method : dump file
        
    @description :
        
    @issue :
        
    @todo :
        
*/

`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif
`ifdef POST
    `define CYCLE_TIME 20.0
`endif

module PATTERN(
    // Output signals
    clk,
	rst_n,
	
	in_valid,
	in_valid2,
	
    image,
	template,
	image_size,
	action,

    // Input signals
	out_valid,
	out_value
);

//======================================
//      INPUT & OUTPUT
//======================================
// Output
output reg       clk, rst_n;
output reg       in_valid;
output reg       in_valid2;

output reg [7:0] image;
output reg [7:0] template;
output reg [1:0] image_size;
output reg [2:0] action;

// Input
input out_valid;
input out_value;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
integer   SIMPLE_PATNUM = 10;
integer   SEED = 54871;
parameter DEBUG = 0;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
integer   SETNUM = 8;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 5000;
parameter OUTBIT = 20;
integer   OUTNUM = -1;

// PATTERN CONTROL
integer stop;
integer set;
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
// Image & Template
parameter NUM_OF_CHANNEL = 3; // red, green, blue
parameter MAX_SIZE_OF_IMAGE = 16;
parameter SIZE_OF_TEMPLATE = 3;
// Action
parameter MIN_SIZE_OF_ACTION = 2;
parameter MAX_SIZE_OF_ACTION = 8;
parameter NUM_OF_FIRST_ACTION_TYPE = 3;
parameter LAST_ACTION_TYPE = 7;
// Operation
parameter SIZE_OF_MAXPOOL_WINDOW = 2;
parameter SIZE_OF_FILTER_WINDOW = 3;
parameter SIZE_OF_PAD_WINDOW = 2;
// Input
reg[7:0] _image[NUM_OF_CHANNEL-1:0][MAX_SIZE_OF_IMAGE-1:0][MAX_SIZE_OF_IMAGE-1:0];
reg[7:0] _template[SIZE_OF_TEMPLATE-1:0][SIZE_OF_TEMPLATE-1:0];
reg[2:0] _actionList[MAX_SIZE_OF_ACTION-1:0];
integer _imageSizeBit;
integer _imageSize;
integer _actionListSize;

// Intermediate output
reg[OUTBIT-1:0] _intermediate[MAX_SIZE_OF_ACTION-1:0][MAX_SIZE_OF_IMAGE-1:0][MAX_SIZE_OF_IMAGE-1:0];
integer _intermediateSize[MAX_SIZE_OF_ACTION-1:0];

// Design output
reg[OUTBIT-1:0] _your[MAX_SIZE_OF_IMAGE-1:0][MAX_SIZE_OF_IMAGE-1:0];
integer _outputSize;

//
// Clear
//
task clear_input;
    integer _channel;
    integer _row;
    integer _col;
begin
    for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
        for(_row=0 ; _row<MAX_SIZE_OF_IMAGE ; _row=_row+1) begin
            for(_col=0 ; _col<MAX_SIZE_OF_IMAGE ; _col=_col+1) begin
                _image[_channel][_row][_col] = 'dx;
            end
        end
    end
    for(_row=0 ; _row<SIZE_OF_TEMPLATE ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_TEMPLATE ; _col=_col+1) begin
            _template[_row][_col] = 'dx;
        end
    end
end endtask

task clear_intermediate;
    integer _actIdx;
    integer _row;
    integer _col;
begin
    for(_actIdx=0 ; _actIdx<MAX_SIZE_OF_ACTION ; _actIdx=_actIdx+1) begin
        // intermediate size
        _intermediateSize[_actIdx] = 0;
        // intermediate figure
        for(_row=0 ; _row<MAX_SIZE_OF_IMAGE ; _row=_row+1) begin
            for(_col=0 ; _col<MAX_SIZE_OF_IMAGE ; _col=_col+1) begin
                _intermediate[_actIdx][_row][_col] = 'dx;
            end
        end
        // action size
        _actionListSize = 0;
        // action
        _actionList[_actIdx] = 'dx;
    end
end endtask

task clear_your_answer;
    integer _row;
    integer _col;
begin
    for(_row=0 ; _row<MAX_SIZE_OF_IMAGE ; _row=_row+1) begin
        for(_col=0 ; _col<MAX_SIZE_OF_IMAGE ; _col=_col+1) begin
            _your[_row][_col] = 'dx;
        end
    end
end endtask

//
// Operation
//
task run_action;
    input integer _actIdx;
    input reg[2:0] _actType;
begin
    case(_actType)
        'd0: gray_transf_max_intermediate(_actIdx);
        'd1: gray_transf_avg_intermediate(_actIdx);
        'd2: gray_transf_wght_intermediate(_actIdx);
        'd3: max_pool_intermediate(_actIdx);
        'd4: negative_intermediate(_actIdx);
        'd5: horiz_flip_intermediate(_actIdx);
        'd6: img_filter_intermediate(_actIdx);
        'd7: cross_corr_intermediate(_actIdx);
        default: begin
            $display("[ERROR] [Run Action] Error action type...");
            $finish;
        end
    endcase
end endtask

task gray_transf_max_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
    integer _channel;
    integer _max;
begin
    // size
    _intermediateSize[_actIdx] = _imageSize;
    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            _max = 0;
            for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
                _max =
                    (_max>_image[_channel][_row][_col])
                    ? _max
                    : _image[_channel][_row][_col];
            end
            _intermediate[_actIdx][_row][_col] =_max;
        end
    end
end endtask

task gray_transf_avg_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
begin
    // size
    _intermediateSize[_actIdx] = _imageSize;
    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            _intermediate[_actIdx][_row][_col] =
                $floor(
                    (_image[0][_row][_col]+
                    _image[1][_row][_col]+
                    _image[2][_row][_col])/3
                );
        end
    end
end endtask

task gray_transf_wght_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
begin
    // size
    _intermediateSize[_actIdx] = _imageSize;
    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            _intermediate[_actIdx][_row][_col] =
                _image[0][_row][_col]/4+
                _image[1][_row][_col]/2+
                _image[2][_row][_col]/4;
        end
    end
end endtask

task max_pool_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
    integer _pool_row;
    integer _pool_col;
    integer _tmp;
begin
    if(_intermediateSize[_actIdx-1]===4) begin
        // size
        _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1];
        // intermediate figure
        for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
            for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
                _intermediate[_actIdx][_row][_col] = 
                    _intermediate[_actIdx-1][_row][_col];
            end
        end
    end
    else begin
        // size
        _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1]/SIZE_OF_MAXPOOL_WINDOW;
        // intermediate figure
        for(_row=0 ; _row<_intermediateSize[_actIdx-1] ; _row=_row+SIZE_OF_MAXPOOL_WINDOW) begin
            for(_col=0 ; _col<_intermediateSize[_actIdx-1] ; _col=_col+SIZE_OF_MAXPOOL_WINDOW) begin
                _tmp = _intermediate[_actIdx-1][_row][_col];
                for(_pool_row=0 ; _pool_row<SIZE_OF_MAXPOOL_WINDOW ; _pool_row=_pool_row+1) begin
                    for(_pool_col=0 ; _pool_col<SIZE_OF_MAXPOOL_WINDOW ; _pool_col=_pool_col+1) begin
                        _tmp =
                            (_tmp>_intermediate[_actIdx-1][_row+_pool_row][_col+_pool_col])
                            ? _tmp
                            : _intermediate[_actIdx-1][_row+_pool_row][_col+_pool_col];
                    end
                end
                _intermediate[_actIdx][_row/SIZE_OF_MAXPOOL_WINDOW][_col/SIZE_OF_MAXPOOL_WINDOW] = _tmp;
            end
        end
    end
end endtask

task negative_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
begin
    // size
    _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1];
    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            _intermediate[_actIdx][_row][_col] =
                255 - _intermediate[_actIdx-1][_row][_col];
        end
    end
end endtask

task horiz_flip_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
begin
    // size
    _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1];
    // intermediate figure
    for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
        for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
            _intermediate[_actIdx][_row][_col] = _intermediate[_actIdx-1][_row][_intermediateSize[_actIdx]-_col-1];
        end
    end
end endtask

task img_filter_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
    integer _innerRow;
    integer _innerCol;

    integer _sizeOfPad;
    reg[OUTBIT-1:0] _padding[MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW-1:0][MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW-1:0];
    reg[OUTBIT-1:0] _temp[SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW-1:0];
begin
    // size
    _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1];

    // padding - replication
    _sizeOfPad = _intermediateSize[_actIdx]+SIZE_OF_PAD_WINDOW;
    for(_col=0 ; _col<MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW ; _col=_col+1) begin
        for(_row=0 ; _row<MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW ; _row=_row+1) begin
            _padding[_row][_col] = 0;
        end
    end
    for(_row=0 ; _row<_intermediateSize[_actIdx-1] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx-1] ; _col=_col+1) begin
            _padding[_row+1][_col+1] = _intermediate[_actIdx-1][_row][_col];
        end
    end
    for(_row=1 ; _row<_sizeOfPad-1 ; _row=_row+1) begin
        _padding[_row][0] = _intermediate[_actIdx-1][_row-1][0];
        _padding[_row][_sizeOfPad-1] = _intermediate[_actIdx-1][_row-1][_intermediateSize[_actIdx-1]-1];
    end
    for(_col=1 ; _col<_sizeOfPad-1 ; _col=_col+1) begin
        _padding[0][_col] = _intermediate[_actIdx-1][0][_col-1];
        _padding[_sizeOfPad-1][_col] = _intermediate[_actIdx-1][_intermediateSize[_actIdx-1]-1][_col-1];
    end

    _padding[0][0] = _intermediate[_actIdx-1][0][0];
    _padding[0][_sizeOfPad-1] = _intermediate[_actIdx-1][0][_intermediateSize[_actIdx-1]-1];
    _padding[_sizeOfPad-1][0] = _intermediate[_actIdx-1][_intermediateSize[_actIdx-1]-1][0];
    _padding[_sizeOfPad-1][_sizeOfPad-1] = _intermediate[_actIdx-1][_intermediateSize[_actIdx-1]-1][_intermediateSize[_actIdx-1]-1];

    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            for(_innerRow=0 ; _innerRow<SIZE_OF_FILTER_WINDOW ; _innerRow=_innerRow+1) begin
                for(_innerCol=0 ; _innerCol<SIZE_OF_FILTER_WINDOW ; _innerCol=_innerCol+1) begin
                    _temp[_innerRow*SIZE_OF_FILTER_WINDOW+_innerCol] = _padding[_row+_innerRow][_col+_innerCol];
                end
            end
            _intermediate[_actIdx][_row][_col] = findeMedian(_temp);
        end
    end

end endtask

task cross_corr_intermediate;
    input integer _actIdx;
    integer _row;
    integer _col;
    integer _innerRow;
    integer _innerCol;

    integer _sizeOfPad;
    reg[OUTBIT-1:0] _padding[MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW-1:0][MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW-1:0];
    reg[OUTBIT-1:0] _sum;
begin
    // size
    _intermediateSize[_actIdx] = _intermediateSize[_actIdx-1];

    // padding - zero padding
    _sizeOfPad = _intermediateSize[_actIdx]+SIZE_OF_PAD_WINDOW;
    for(_col=0 ; _col<MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW ; _col=_col+1) begin
        for(_row=0 ; _row<MAX_SIZE_OF_IMAGE+SIZE_OF_PAD_WINDOW ; _row=_row+1) begin
            _padding[_row][_col] = 0;
        end
    end
    for(_row=0 ; _row<_intermediateSize[_actIdx-1] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx-1] ; _col=_col+1) begin
            _padding[_row+1][_col+1] = _intermediate[_actIdx-1][_row][_col];
        end
    end
    
    // intermediate figure
    for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
            _sum = 0;
            for(_innerRow=0 ; _innerRow<SIZE_OF_TEMPLATE ; _innerRow=_innerRow+1) begin
                for(_innerCol=0 ; _innerCol<SIZE_OF_TEMPLATE ; _innerCol=_innerCol+1) begin
                    _sum = _sum 
                        + _padding[_row+_innerRow][_col+_innerCol] * _template[_innerRow][_innerCol];
                end
            end
            _intermediate[_actIdx][_row][_col] = _sum;
        end
    end

end endtask

//
// Generate input
//
task randomize_figure;
    integer _channel;
    integer _row;
    integer _col;
begin
    _imageSizeBit = {$random(SEED)} % 3;
    _imageSize = 2 ** (_imageSizeBit + 2);
    for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
        for(_row=0 ; _row<_imageSize ; _row=_row+1) begin
            for(_col=0 ; _col<_imageSize ; _col=_col+1) begin
                _image[_channel][_row][_col] = (pat<SIMPLE_PATNUM)
                    ? {$random(SEED)} % 10
                    : {$random(SEED)} % 256;
            end
        end
    end
    for(_row=0 ; _row<SIZE_OF_TEMPLATE ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_TEMPLATE ; _col=_col+1) begin
            _template[_row][_col] = (pat<SIMPLE_PATNUM)
                ? {$random(SEED)} % 5
                : {$random(SEED)} % 256;
        end
    end
end endtask

task randomize_action;
    integer _actIdx;
begin
    _actionListSize = {$random(SEED)} % (MAX_SIZE_OF_ACTION - MIN_SIZE_OF_ACTION + 1) + MIN_SIZE_OF_ACTION;
    _actionList[0] = {$random(SEED)} % NUM_OF_FIRST_ACTION_TYPE;
    for(_actIdx=1 ; _actIdx<_actionListSize ; _actIdx=_actIdx+1)begin
        _actionList[_actIdx] = {$random(SEED)} % (LAST_ACTION_TYPE - NUM_OF_FIRST_ACTION_TYPE) + NUM_OF_FIRST_ACTION_TYPE;
    end
    _actionList[_actionListSize-1] = LAST_ACTION_TYPE;
end endtask

//
// Dump
//
reg[4*8:1] _lineSize4  = "____";
reg[4*8:1] _spaceSize4 = "    ";
reg[9*8:1] _lineSize9  = "_________";
reg[9*8:1] _spaceSize9 = "         ";
task clear_file; begin
    file_out = $fopen("input.txt", "w");
    $fclose(file_out);
    file_out = $fopen("output.txt", "w");
    $fclose(file_out);
end endtask

task dump_input;
    integer _channel;
    integer _row;
    integer _col;
begin
    file_out = $fopen("input.txt", "w");

    $fwrite(file_out, "[PAT NO. %4d]\n\n", pat);
    $fwrite(file_out, "[set # %1d]\n\n", set);

    $fwrite(file_out, "[=======]\n");
    $fwrite(file_out, "[ Image ]\n");
    $fwrite(file_out, "[=======]\n\n");
    $fwrite(file_out, "[image_size / size] : %1d / %2d\n\n", _imageSizeBit, _imageSize);
    $fwrite(file_out, "[0] : R\n");
    $fwrite(file_out, "[1] : G\n");
    $fwrite(file_out, "[2] : B\n\n");

    // [#0] **1 **2 **3
    // _________________
    //   0| **1 **2 **3
    //   1| **1 **2 **3
    //   2| **1 **2 **3

    // [#0] **1 **2 **3
    for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
        $fwrite(file_out, "[%1d] ", _channel);
        for(_col=0 ; _col<_imageSize ; _col=_col+1) $fwrite(file_out, "%3d ",_col);
        $fwrite(file_out, "%0s", _spaceSize4);
    end
    $fwrite(file_out, "\n");
    // _________________
    for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
        $fwrite(file_out, "%0s", _lineSize4);
        for(_col=0 ; _col<_imageSize ; _col=_col+1) $fwrite(file_out, "%0s", _lineSize4);
        $fwrite(file_out, "%0s", _spaceSize4);
    end
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(_row=0 ; _row<_imageSize ; _row=_row+1) begin
        for(_channel=0 ; _channel<NUM_OF_CHANNEL ; _channel=_channel+1) begin
            $fwrite(file_out, "%2d| ",_row);
            for(_col=0 ; _col<_imageSize ; _col=_col+1) begin
                $fwrite(file_out, "%3d ", _image[_channel][_row][_col]);
            end
            $fwrite(file_out, "%0s", _spaceSize4);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fwrite(file_out, "[==========]\n");
    $fwrite(file_out, "[ Template ]\n");
    $fwrite(file_out, "[==========]\n\n");
    
    // [#0] **1 **2 **3
    $fwrite(file_out, "[ ] ");
    for(_col=0 ; _col<SIZE_OF_TEMPLATE ; _col=_col+1) $fwrite(file_out, "%3d ",_col);
    $fwrite(file_out, "%0s", _spaceSize4);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _lineSize4);
    for(_col=0 ; _col<SIZE_OF_TEMPLATE ; _col=_col+1) $fwrite(file_out, "%0s", _lineSize4);
    $fwrite(file_out, "%0s", _spaceSize4);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(_row=0 ; _row<SIZE_OF_TEMPLATE ; _row=_row+1) begin
        $fwrite(file_out, "%2d| ",_row);
        for(_col=0 ; _col<SIZE_OF_TEMPLATE ; _col=_col+1) begin
            $fwrite(file_out, "%3d ", _template[_row][_col]);
        end
        $fwrite(file_out, "%0s", _spaceSize4);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fclose(file_out);
end endtask

function [20*8:1] getActionName;
    input [2:0] _actIn;
begin
    getActionName = "None";
    case(_actIn)
        'd0: getActionName = "Grayscale - max";
        'd1: getActionName = "Grayscale - average";
        'd2: getActionName = "Grayscale - weighted";
        'd3: getActionName = "Max pooling";
        'd4: getActionName = "Negative";
        'd5: getActionName = "Horizontal flip";
        'd6: getActionName = "Image filter";
        'd7: getActionName = "Cross correlation";
        default: begin
            $display("[ERROR] [Run Action] Error action type...");
            $finish;
        end
    endcase
end endfunction

task dump_output;
    integer _actIdx;
    integer _row;
    integer _col;
begin
    file_out = $fopen("output.txt", "w");

    $fwrite(file_out, "[========]\n");
    $fwrite(file_out, "[ Action ]\n");
    $fwrite(file_out, "[========]\n\n");
    $fwrite(file_out, "[Num of action] : %1d\n\n", _actionListSize);
    for(_actIdx=0 ; _actIdx<_actionListSize ; _actIdx=_actIdx+1) begin
        $fwrite(file_out, "[%1d] - %0s\n", _actIdx, getActionName(_actionList[_actIdx]));
    end
    $fwrite(file_out, "\n");

    // [#0] **1 **2 **3
    // _________________
    //   0| **1 **2 **3
    //   1| **1 **2 **3
    //   2| **1 **2 **3

    $fwrite(file_out, "[=====================]\n");
    $fwrite(file_out, "[ Intermediate Output ]\n");
    $fwrite(file_out, "[=====================]\n\n");
    for(_actIdx=0 ; _actIdx<_actionListSize ; _actIdx=_actIdx+1) begin
        $fwrite(file_out, "[action] : %0s\n", getActionName(_actionList[_actIdx]));
        $fwrite(file_out, "[size  ] : %2d\n\n", _intermediateSize[_actIdx]);
        // [#0] **1 **2 **3
        $fwrite(file_out, "[%1d] ", _actIdx);
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) $fwrite(file_out, "%8d ",_col);
        $fwrite(file_out, "%0s", _spaceSize4);
        $fwrite(file_out, "\n");
        // _________________
        $fwrite(file_out, "%0s", _lineSize4);
        for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) $fwrite(file_out, "%0s", _lineSize9);
        $fwrite(file_out, "%0s", _spaceSize4);
        $fwrite(file_out, "\n");
        //   0| **1 **2 **3
        for(_row=0 ; _row<_intermediateSize[_actIdx] ; _row=_row+1) begin
            $fwrite(file_out, "%2d| ",_row);
            for(_col=0 ; _col<_intermediateSize[_actIdx] ; _col=_col+1) begin
                $fwrite(file_out, "%8d ", _intermediate[_actIdx][_row][_col]);
            end
            $fwrite(file_out, "%0s", _spaceSize4);
            $fwrite(file_out, "\n");
        end
        $fwrite(file_out, "\n");
    end

    $fwrite(file_out, "[=============]\n");
    $fwrite(file_out, "[ Your answer ]\n");
    $fwrite(file_out, "[=============]\n\n");
    
    // [#0] **1 **2 **3
    $fwrite(file_out, "[ ] ");
    for(_col=0 ; _col<_outputSize ; _col=_col+1) $fwrite(file_out, "%8d ",_col);
    $fwrite(file_out, "%0s", _spaceSize4);
    $fwrite(file_out, "\n");
    // _________________
    $fwrite(file_out, "%0s", _lineSize4);
    for(_col=0 ; _col<_outputSize ; _col=_col+1) $fwrite(file_out, "%0s", _lineSize9);
    $fwrite(file_out, "%0s", _spaceSize4);
    $fwrite(file_out, "\n");
    //   0| **1 **2 **3
    for(_row=0 ; _row<_outputSize ; _row=_row+1) begin
        $fwrite(file_out, "%2d| ",_row);
        for(_col=0 ; _col<_outputSize ; _col=_col+1) begin
            $fwrite(file_out, "%8d ", _your[_row][_col]);
        end
        $fwrite(file_out, "%0s", _spaceSize4);
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    $fclose(file_out);
end endtask

//
// Utility
//
function[OUTBIT-1:0] findeMedian;
    input[OUTBIT-1:0] in[SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW-1:0];

    integer _idx1, _idx2;
    reg[OUTBIT-1:0] sorted[SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW-1:0];
    reg[OUTBIT-1:0] temp;
begin
    for(_idx1=0; _idx1<9; _idx1=_idx1+1) begin
        sorted[_idx1] = in[_idx1];
    end

    for(_idx1=0; _idx1<SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW; _idx1=_idx1+1) begin
        for(_idx2=0; _idx2<SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW-_idx1; _idx2=_idx2+1) begin
            if (sorted[_idx2] > sorted[_idx2+1]) begin
                temp = sorted[_idx2];
                sorted[_idx2] = sorted[_idx2+1];
                sorted[_idx2+1] = temp;
            end
        end
    end
    findeMedian = sorted[SIZE_OF_FILTER_WINDOW*SIZE_OF_FILTER_WINDOW/2];
end endfunction

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
        reset_figure_task;
        input_figure_task;
        for(set=0 ; set<SETNUM ; set=set+1) begin
            reset_intermediate_task;
            input_action_task;
            cal_task;
            wait_task;
            check_task;
            // Print Pass Info and accumulate the total latency
            $display("%0sPASS PATTERN NO.%4d / Set #%1d %0sCycles: %3d%0s",txt_blue_prefix, pat, set, txt_green_prefix, exe_lat, reset_color);
        end
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    in_valid2 = 0;
    image = 'dx;
    template = 'dx;
    image_size = 'dx;
    action = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out_value !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) rst_n = 1;
    #(CYCLE/2.0) release clk;
end endtask

task reset_figure_task; begin
    clear_input;
    clear_intermediate;
end endtask

task reset_intermediate_task; begin
    clear_intermediate;
    clear_your_answer;
    clear_file;
end endtask

task input_figure_task;
    integer _cnt;
begin
    randomize_figure;
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
    for(_cnt=0 ; _cnt<NUM_OF_CHANNEL*_imageSize*_imageSize ; _cnt=_cnt+1)begin
        in_valid = 1;

        image = _image[_cnt%NUM_OF_CHANNEL][_cnt/(NUM_OF_CHANNEL*_imageSize)][(_cnt/NUM_OF_CHANNEL)%_imageSize];

        if(_cnt < SIZE_OF_TEMPLATE*SIZE_OF_TEMPLATE) template = _template[_cnt/SIZE_OF_TEMPLATE][_cnt%SIZE_OF_TEMPLATE];
        else template = 'dx;

        if(_cnt===0) image_size = _imageSizeBit;
        else image_size = 'dx;

        @(negedge clk);
    end
    in_valid = 0;
    image = 'dx;
    template = 'dx;
    image_size = 'dx;
end endtask

task input_action_task;
    integer _cnt;
begin
    randomize_action;
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
    for(_cnt=0 ; _cnt<_actionListSize ; _cnt=_cnt+1)begin
        in_valid2 = 1;
        action = _actionList[_cnt];
        @(negedge clk);
    end
    in_valid2 = 0;
    action = 'dx;
end endtask

task cal_task;
    integer _actIdx;
begin
    for(_actIdx=0 ; _actIdx<_actionListSize ; _actIdx=_actIdx+1)begin
        run_action(_actIdx, _actionList[_actIdx]);
    end
    _outputSize = _intermediateSize[_actionListSize-1];
    OUTNUM = OUTBIT * _intermediateSize[_actionListSize-1] * _intermediateSize[_actionListSize-1];

    if(DEBUG) begin
        dump_input;
        dump_output;
    end
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out_value !== 0) begin
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
    integer _row;
    integer _col;
begin
    out_lat = 0;
    while(out_valid===1) begin
        if(out_lat==OUTNUM) begin
            $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUTNUM, $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end
        
        _your[out_lat/OUTBIT/_outputSize][(out_lat/OUTBIT)%_outputSize][OUTBIT-(out_lat%OUTBIT)-1] = out_value;

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
    for(_row=0 ; _row<_outputSize ; _row=_row+1) begin
        for(_col=0 ; _col<_outputSize ; _col=_col+1) begin
            if(_your[_row][_col] !== _intermediate[_actionListSize-1][_row][_col]) begin
                $display("[ERROR] [OUTPUT] Output is not correct...\n");
                $display("[ERROR] [OUTPUT] Dump debugging file...");
                $display("[ERROR] [OUTPUT]      input.tx contains image and template");
                $display("[ERROR] [OUTPUT]      output.tx contains intermediate results and action list\n");
                $display("[ERROR] [OUTPUT] Your pixel is not correct at (%2d, %2d)\n", _row, _col);
                dump_input;
                dump_output;
                repeat(5) @(negedge clk);
                $finish;
            end
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