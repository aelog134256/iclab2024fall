/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: PATTERN
// FILE NAME: PATTERN.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / PATTERN
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module PATTERN(
	//OUTPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//INPUT
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//======================================
//      INPUT & OUTPUT
//======================================
output reg        rst_n, clk, in_valid;
output reg [2:0]  tetrominoes;
output reg [2:0]  position;
input             tetris_valid, score_valid, fail;
input      [3:0]  score;
input      [71:0] tetris;

//======================================
//      PARAMETERS & VARIABLES
//======================================
// User modification
integer   SEED = 587;
parameter DEBUG = 0;
parameter MODE = 0;
reg[8:1] NEW_SIGN = "@";
reg[8:1] FULL_SIGN = "#";
reg[8:1] EMPTY_SIGN = "-";
parameter MODE0_IS_RANDOM = 0; // Randonly send the pattern from the input.txt
parameter USER_MODE1_PATNUM = 10; // Only valid when MODE = 1
/*
    MODE 0 : read the input.txt
    MODE 1 : randomize the input
*/
// MODE 0
parameter MODE0_PATNUM = 1000; // based on the input.txt
// MODE 1
parameter MODE1_PATNUM = USER_MODE1_PATNUM;

parameter ROUNDNUM = 16;
parameter HEIGHT = 12;
parameter WIDTH  = 6;
parameter NUM_OF_TYPE = 8;
parameter NUM_OF_GRID = 4;

integer   PATNUM = 0;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 1000;
parameter OUT_NUM = 1;

integer round;

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
reg                   _board[HEIGHT+3:0][WIDTH-1:0];
reg                   _boardOld[HEIGHT-1:0][WIDTH-1:0]; // Old board
reg                   _boardFall[HEIGHT-1:0][WIDTH-1:0]; // Old board
reg[HEIGHT*WIDTH-1:0] _tetris;
integer               _offsetX[NUM_OF_TYPE-1:0][NUM_OF_GRID-1:0];
integer               _offsetY[NUM_OF_TYPE-1:0][NUM_OF_GRID-1:0];
// MODE 0
integer _mode0_pat;
reg[2:0]              _inputType[MODE0_PATNUM-1:0][ROUNDNUM-1:0];
reg[2:0]              _inputPos [MODE0_PATNUM-1:0][ROUNDNUM-1:0];
// MODE 1
reg[2:0] _curType;
reg[2:0] _curPosition;

integer _score;
integer _fail;

//
//  Display
//
task add_seperated_line; begin
    $display("==============================================================");
end endtask

task show_tetrominoes;
    input integer _type;
begin
    $display("[INFO] type : %-1d", _type);
    case(_type)
        'd0:begin
            $display("[INFO] * *");
            $display("[INFO] * *");
        end
        'd1:begin
            $display("[INFO] *");
            $display("[INFO] *");
            $display("[INFO] *");
            $display("[INFO] *");
        end
        'd2:begin
            $display("[INFO] * * * *");
        end
        'd3:begin
            $display("[INFO] * *");
            $display("[INFO]   *");
            $display("[INFO]   *");
        end
        'd4:begin
            $display("[INFO] * * *");
            $display("[INFO] *    ");
        end
        'd5:begin
            $display("[INFO] *  ");
            $display("[INFO] *  ");
            $display("[INFO] * *");
        end
        'd6:begin
            $display("[INFO] *  ");
            $display("[INFO] * *");
            $display("[INFO]   *");
        end
        'd7:begin
            $display("[INFO]   * *");
            $display("[INFO] * *  ");
        end
        default: begin
            $display("[ERROR] Wrong type");
            $finish;
        end
    endcase
end endtask

task show_input; begin
    add_seperated_line;
    $display("[INFO] Input");
    if(MODE == 0) begin
        $display("[INFO] MODE0 / Round : #%-4d / %-2d", _mode0_pat, round);
    end
    show_tetrominoes(_curType);
    $display("[INFO] position : %-2d", _curPosition);
end endtask

task tetris_to_board;
    input reg[HEIGHT*WIDTH-1:0] _in;
    integer _x;
    integer _y;
begin
    add_seperated_line;
    $display("[INFO] Tetris -> Board");
    for(_y=HEIGHT-1 ; _y>=0 ; _y=_y-1) begin
        $write("|%2d ", _y);
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            if(_in[_y*WIDTH+_x]) $write("%s ", FULL_SIGN);
            else $write("%s ", EMPTY_SIGN);;
        end
        $write("\n");
    end
    $write("--- ");
    for(_x=0 ; _x < WIDTH ; _x=_x+1) begin
        $write("%1d ", _x);
    end
    $write("\n");
    add_seperated_line;
end endtask

task show_board;
    integer _x;
    integer _y;
begin
    show_boardOld;
    add_seperated_line;
    $display("[INFO] Current Tetris Board");
    $display("[INFO] Tetris : %-18h", _tetris);
    $display("[INFO] Score  : %-18h", _score);
    $display("[INFO] Fail   : %-18h", _fail);
    $display("[INFO] Sign Setting :");
    $display("[INFO] New / Full / Empty : %s / %s / %s", NEW_SIGN, FULL_SIGN, EMPTY_SIGN);
    for(_y=HEIGHT-1 ; _y>=0 ; _y=_y-1) begin
        $write("|%2d ", _y);
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            if(_board[_y][_x] && _boardOld[_y][_x] === 0) $write("%s ", NEW_SIGN); // For fall
            else if(_board[_y][_x]) $write("%s ", FULL_SIGN); // For fall
            else $write("%s ", EMPTY_SIGN);;
        end
        $write("\n");
    end
    $write("--- ");
    for(_x=0 ; _x < WIDTH ; _x=_x+1) begin
        $write("%1d ", _x);
    end
    $write("\n");
    add_seperated_line;
end endtask

task show_boardOld;
    integer _x;
    integer _y;
begin
    add_seperated_line;
    $display("[INFO] Previous Tetris Board");
    for(_y=HEIGHT-1 ; _y>=0 ; _y=_y-1) begin
        $write("#%2d ", _y);
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            if(_boardOld[_y][_x]) $write("%s ", FULL_SIGN); // For score
            else $write("%s ", EMPTY_SIGN);;
        end
        $write("\n");
    end
    $write("### ");
    for(_x=0 ; _x < WIDTH ; _x=_x+1) begin
        $write("%1d ", _x);
    end
    $write("\n");
    add_seperated_line;
end endtask

//
// Initialization
//
task init_offset; begin
    /*
        * *
        * *
    */
    _offsetX[0][0] = 0; _offsetX[0][1] = 1; _offsetX[0][2] = 0; _offsetX[0][3] = 1; 
    _offsetY[0][0] = 0; _offsetY[0][1] = 0; _offsetY[0][2] = -1; _offsetY[0][3] = -1; 
    /*
        *
        *
        *
        *
    */
    _offsetX[1][0] = 0; _offsetX[1][1] = 0; _offsetX[1][2] = 0; _offsetX[1][3] = 0; 
    _offsetY[1][0] = 0; _offsetY[1][1] = -1; _offsetY[1][2] = -2; _offsetY[1][3] = -3;
    /*
        * * * *
    */
    _offsetX[2][0] = 0; _offsetX[2][1] = 1; _offsetX[2][2] = 2; _offsetX[2][3] = 3; 
    _offsetY[2][0] = 0; _offsetY[2][1] = 0; _offsetY[2][2] = 0; _offsetY[2][3] = 0;
    /*
        * *
          *
          *
    */
    _offsetX[3][0] = 0; _offsetX[3][1] = 1; _offsetX[3][2] = 1; _offsetX[3][3] = 1; 
    _offsetY[3][0] = 0; _offsetY[3][1] = 0; _offsetY[3][2] = -1; _offsetY[3][3] = -2;
    /*
        * * *
        *
    */
    _offsetX[4][0] = 0; _offsetX[4][1] = 1; _offsetX[4][2] = 2; _offsetX[4][3] = 0; 
    _offsetY[4][0] = 0; _offsetY[4][1] = 0; _offsetY[4][2] = 0; _offsetY[4][3] = -1;
    /*
        *
        *
        * *
    */
    _offsetX[5][0] = 0; _offsetX[5][1] = 0; _offsetX[5][2] = 0; _offsetX[5][3] = 1; 
    _offsetY[5][0] = 0; _offsetY[5][1] = -1; _offsetY[5][2] = -2; _offsetY[5][3] = -2;
    /*
        *
        * *
          *
    */
    _offsetX[6][0] = 0; _offsetX[6][1] = 0; _offsetX[6][2] = 1; _offsetX[6][3] = 1; 
    _offsetY[6][0] = 0; _offsetY[6][1] = -1; _offsetY[6][2] = -1; _offsetY[6][3] = -2;
    /*
          * *
        * *
    */
    _offsetX[7][0] = 0; _offsetX[7][1] = 1; _offsetX[7][2] = 1; _offsetX[7][3] = 2; 
    _offsetY[7][0] = 0; _offsetY[7][1] = 0; _offsetY[7][2] = 1; _offsetY[7][3] = 1;
end endtask

//
// Modification
//
task clear_board;
    integer _x;
    integer _y;
begin
    for(_y=0 ; _y<=HEIGHT+3 ; _y=_y+1) begin
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            _board[_y][_x] = 0;
        end
    end
    _score = 0;
    _fail = 0;
    _tetris = 0;
    clear_boardOld;
end endtask

task clear_row;
    input integer _y;
    integer _x;
begin
    for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
        _board[_y][_x] = 0;
    end
end endtask

task shift_board;
    input integer _row;
    integer _x;
    integer _y;
begin
    for(_y=_row ; _y<HEIGHT+3 ; _y=_y+1) begin
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            _board[_y][_x] = _board[_y+1][_x];
        end
    end
    for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
        _board[HEIGHT+3][_x] = 0;
    end
end endtask

task clear_boardOld;
    integer _x;
    integer _y;
begin
    for(_y=0 ; _y<HEIGHT ; _y=_y+1) begin
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            _boardOld[_y][_x] = 0;
        end
    end
end endtask

task set_boardOld;
    integer _x;
    integer _y;
begin
    for(_y=0 ; _y<HEIGHT ; _y=_y+1) begin
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            _boardOld[_y][_x] = _board[_y][_x];
        end
    end
end endtask

task insert_tetrimino;
    input integer _type;
    input integer _x;
    integer _y;
    integer _fallFlag;
    integer _scoreFlag;
    reg[HEIGHT+3:0] _scoreRemove;
    integer i;
begin
    // Record old board
    clear_boardOld;
    set_boardOld;
    // Fall
    _fallFlag = 0;
    _y = (_type == 7) ? HEIGHT : HEIGHT+3; // Only the type 7 should start from HEIGHT-2
    if(DEBUG) begin
        show_tetrominoes(_type);
        $display("[DEBUG] (y, x)  : (%-2d, %-2d)", _y, _x);
    end
    // The tetrominoes start to fall
    for( ; _y>=0 && _fallFlag===0 ; _y=_y-1) begin
        // Show info
        if(DEBUG) begin
            add_seperated_line;
            $display("[DEBUG] (y, x)  : (%-2d, %-2d)", _y, _x);
            $display("[DEBUG] Current Outside/Overlap : (%-1d/%-1d)", isOutside(_x,_y,_type), isOverlap(_x,_y,_type));
            $display("[DEBUG] Next    Outside/Overlap : (%-1d/%-1d)", isOutside(_x,_y-1,_type), isOverlap(_x,_y-1,_type));
        end
        // Check the next postion is valid or not
        // At the bottom of board
        if(isOutside(_x, _y-1, _type) === 2) begin
            for(i=0 ; i<NUM_OF_GRID ; i=i+1) begin
                _board[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
                _boardFall[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
            end
            _fallFlag = 1;
        end
        // Overlap with other tetrominoes
        else if(isOverlap(_x, _y-1, _type) === 1 && isOutside(_x, _y, _type) === 0) begin
            for(i=0 ; i<NUM_OF_GRID ; i=i+1) begin
                _board[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
                _boardFall[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
            end
            _fallFlag = 1;
        end
        else if(isOverlap(_x, _y-1, _type) === 1  && isOutside(_x, _y, _type) === 1) begin
            for(i=0 ; i<NUM_OF_GRID ; i=i+1) begin
                _board[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
                _boardFall[(_y + _offsetY[_type][i])][(_x + _offsetX[_type][i])] = 1;
            end
            _fallFlag = 1;
        end
    end
    // Show board
    if(DEBUG) begin
        add_seperated_line;
        $display("[DEBUG] Insertion - Fall");
        $display("[DEBUG] Fall flag  : %d", _fallFlag);
        $display("[DEBUG] Score flag : %d", _scoreFlag);
        add_seperated_line;
        show_board;
    end

    // Calculation
    _scoreRemove = 0;
    for(_y=0 ; _y<=HEIGHT+3 ; _y=_y+1) begin
        _scoreFlag = 1;
        for(i=0 ; i<WIDTH ; i=i+1) begin
            _scoreFlag = (_board[_y][i] !== 1) ? 0 : _scoreFlag;
        end
        if(_scoreFlag === 1) begin
            clear_row(_y);
            _scoreRemove[_y] = 1;
            _score = _score + 1;
        end
    end
    while(_scoreRemove !== 0) begin
        for(_y=0 ; _y<=HEIGHT+3 ; _y=_y+1) begin
            if(_scoreRemove[_y] === 1) begin
                _scoreRemove[_y] = 0;
                for(i=_y ; i<HEIGHT+3 ; i=i+1) begin
                    _scoreRemove[i] = _scoreRemove[i+1];
                end
                _scoreRemove[HEIGHT+3] = 0;
                shift_board(_y);
            end
        end
    end
    check_fail;

    // Show board
    if(DEBUG) begin
        add_seperated_line;
        $display("[DEBUG] Insertion - Score");
        $display("[DEBUG] Fall flag  : %d", _fallFlag);
        $display("[DEBUG] Score flag : %d", _scoreFlag);
        add_seperated_line;
        show_board;
    end

    // Update tetris
    update_tetris;
end endtask

task update_tetris;
    integer _x;
    integer _y;
begin
    for(_y=HEIGHT-1 ; _y>=0 ; _y=_y-1) begin
        for(_x=WIDTH-1 ; _x>=0 ; _x=_x-1) begin
            // _tetris = _tetris << 1;
            // _tetris[0] = _board[_y][_x];
            _tetris = {_tetris[HEIGHT*WIDTH-2:0],  _board[_y][_x]};
        end
    end
end endtask

//
// Utility
//
task check_fail;
    integer _x;
    integer _y;
begin
    _fail = 0;
    for(_y=HEIGHT ; _y<=HEIGHT+3 ; _y=_y+1) begin
        for(_x=0 ; _x<WIDTH ; _x=_x+1) begin
            _fail = _fail | _board[_y][_x];
        end
    end
end endtask

/*
    0 : inside
    1 : outside (above)
    2 : outside (below)
*/
function [1:0] isOutside;
    input integer _left;
    input integer _top;
    input integer _type;
    integer i;
begin
    isOutside = 0;
    if(_type >= NUM_OF_TYPE) begin
        $display("[ERROR] Wrong type");
        $finish;
    end
    else begin
        for(i=0 ; i<NUM_OF_GRID && isOutside===0 ; i=i+1) begin
            // Horizontal direction should be always in the range
            // isOutside |= ((_left + _offsetX[_type][i])<0);
            // isOutside |= ((_left + _offsetX[_type][i])>=WIDTH);
            if((_top + _offsetY[_type][i])<0)
                isOutside = 2;
            else if((_top + _offsetY[_type][i])>=HEIGHT)
                isOutside = 1;
        end
        // if(DEBUG) begin
        //     $write("[DEBUG] Outside check : ");
        //     for(i=0 ; i<NUM_OF_GRID && isOutside===0 ; i=i+1) begin
        //         $write("(%2d)", _top + _offsetY[_type][i]);
        //     end
        //     $write("\n");
        // end
    end
end endfunction

/*
    x : outside(above or below)
    1 : overlap
    0 : non-overlap
*/
function [0:0] isOverlap;
    input integer _left;
    input integer _top;
    input integer _type;
    integer i;
begin
    isOverlap = 0;
    if(_type >= NUM_OF_TYPE) begin
        $display("[ERROR] Wrong type");
        $finish;
    end
    else begin
        for(i=0 ; i<NUM_OF_GRID ; i=i+1) begin
            if(
                _top + _offsetY[_type][i] >= 0 && _top + _offsetY[_type][i] < HEIGHT &&
                _left + _offsetX[_type][i] >= 0 && _left + _offsetX[_type][i] < WIDTH
            )
                isOverlap |= _board[(_top + _offsetY[_type][i])][(_left + _offsetX[_type][i])];
        end
    end
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
    preprocessing_task;
    reset_task;
    for(pat=0 ; pat<PATNUM ; pat=pat+1) begin
        preprocessing_pat;
        for(round=0 ; round<ROUNDNUM && _fail==0 ; round=round+1) begin
            input_task;
            cal_task;
            wait_task;
            check_task;
            // Print Pass Info and accumulate the total latency
            if(MODE == 0)
                $display("%0sPASS PATTERN NO.%4d / NO.%4d from input.txt / round : %2d/%2d, %0sCycles: %3d%0s",txt_blue_prefix, pat, _mode0_pat, round, ROUNDNUM-1, txt_green_prefix, exe_lat, reset_color);
            else
                $display("%0sPASS PATTERN NO.%4d / round : %2d/%2d, %0sCycles: %3d%0s",txt_blue_prefix, pat, round, ROUNDNUM-1, txt_green_prefix, exe_lat, reset_color);
        end
    end
    postprocessing_task;
    pass_task;
end endtask

task preprocessing_task;
    integer i;
    integer j;
    integer status;
begin
    if(MODE == 0) begin
        file = $fopen("../00_TESTBED/input.txt", "r");
        status = $fscanf(file, "%d", PATNUM);
        $display("[INFO] MODE 0 -> Change the number of pattern from the inupt.txt");
        if(PATNUM != MODE0_PATNUM) begin
            $display("[ERROR] PATNUM from input.txt is not consistent with MODE0_PATNUM");
            $display("[ERROR] It may cause the pattern error. Please change the MODE0_PATNUM based on the input.txt");
            $finish;
        end
        while(!$feof(file)) begin
            status = $fscanf(file, "\n");
            status = $fscanf(file, "%d", i);
            if(i<MODE0_PATNUM) begin
                for(j=0 ; j<ROUNDNUM ; j=j+1) begin
                    status = $fscanf(file, "%d   %d", _inputType[i][j], _inputPos[i][j]);
                end
            end
        end
    end
    else begin
        PATNUM = MODE1_PATNUM;
        $display("[INFO] MODE 1 -> Change the number of pattern based on PATNUM");
    end
    $display("[INFO] Total number of pattern : %10d", PATNUM);
    init_offset;
end endtask

task preprocessing_pat; begin
    clear_board;
    if(DEBUG) begin
        add_seperated_line;
        $display("[INFO] Initialization pattern #%d", pat);
        add_seperated_line;
        show_board;
    end
end endtask

task postprocessing_task; begin
    if(MODE == 0) begin
        $fclose(file);
    end
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    tetrominoes = 'dx;
    position = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(100);
    if(
        score_valid !== 0 || score !== 0 ||
        tetris_valid !== 0 || tetris !== 0 ||
        fail !== 0
    ) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) rst_n = 1;
    #(CYCLE/2.0) release clk;
end endtask

task input_task;
    integer _mode1Pos;
begin
    repeat(({$random(SEED)} % 4 + 1)) @(negedge clk);
    if(MODE == 0) begin
        _mode0_pat = pat;
        if(MODE0_IS_RANDOM) begin
            _mode0_pat = ({$random(SEED)} % MODE0_PATNUM);
        end
        _curType     = _inputType[_mode0_pat][round];
        _curPosition = _inputPos[_mode0_pat][round];
    end
    else begin
        _curType = ({$random(SEED)} % NUM_OF_TYPE);
        if(
            _curType == 0 ||
            _curType == 3 ||
            _curType == 5 ||
            _curType == 6
        ) begin
            _mode1Pos = 5;
        end
        else if(_curType == 1) begin
            _mode1Pos = WIDTH;
        end
        else if(_curType == 4 || _curType == 7) begin
            _mode1Pos = 4;
        end
        else begin
            _mode1Pos = 3;
        end
        _curPosition = ({$random(SEED)} % _mode1Pos);
    end
    in_valid = 1;
    tetrominoes = _curType;
    position = _curPosition;
    @(negedge clk);
    in_valid = 0;
    tetrominoes = 'dx;
    position = 'dx;
end endtask

task cal_task; begin
    insert_tetrimino(_curType, _curPosition);
end endtask

task wait_task; begin
    exe_lat = -1;
    while(score_valid !== 1 && tetris_valid !== 1) begin
        if(fail !== 0 || score !== 0 || tetris !== 0) begin
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
    if(tetris_valid === 1 && score_valid !== 1) begin
        $display("[ERROR] [WAIT] The tetris_valid should be exactly the same cycle with the score_valid at %-12d ps", $time*1000);
        repeat(5) @(negedge clk);
        $finish;
    end
end endtask

task check_task; begin
    out_lat = 0;
    while(score_valid === 1) begin
        if(out_lat == OUT_NUM) begin
            $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUT_NUM, $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end

        //
        // Check
        //
        // tetris_to_board('he197c30c10c309b8e2);
        if(score !== _score) begin
            show_input;
            show_board;
            $display("[ERROR] [OUTPUT] Score is not correct");
            $display("[ERROR] [OUTPUT] Your / Gold : %-2d / %-2d", score, _score);
            repeat(5) @(negedge clk);
            $finish;
        end
        if(_fail === 1 || round === ROUNDNUM-1) begin
            if(tetris_valid !== 1) begin
                $display("[ERROR] [OUTPUT] Tetris_valid should be high");
                repeat(5) @(negedge clk);
                $finish;
            end
            else begin
                if(tetris !== _tetris) begin
                    show_input;
                    show_board;
                    $display("[ERROR] [OUTPUT] Tetris is not correct");
                    $display("[ERROR] [OUTPUT] Your / Gold : %-2d / %-2d", tetris, _tetris);
                    $display("[ERROR] [OUTPUT] Your board :");
                    tetris_to_board(tetris);
                    repeat(5) @(negedge clk);
                    $finish;
                end
                if(fail !== _fail) begin
                    show_input;
                    show_board;
                    $display("[ERROR] [OUTPUT] Fail is not correct");
                    $display("[ERROR] [OUTPUT] Your / Gold : %-2d / %-2d", fail, _fail);
                    repeat(5) @(negedge clk);
                    $finish;
                end
            end
        end
        out_lat = out_lat + 1;
        @(negedge clk);
    end
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