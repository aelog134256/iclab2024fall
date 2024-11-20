
// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
`include "../00_TESTBED/stockTradeFlowMgr.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
integer   SEED = 5487;
parameter DEBUG = 1;
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter DRAM_INFO_FILE = "dramInfo.txt";
parameter NUM_OF_TABLE_PER_ROW_OF_DRAM_INFO_FILE = 4;
// -------------------------------------
// [Mode]
//      0 : generate the dram.dat
//      1 : validate design
integer   MODE = 1;
// -------------------------------------
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter DELAY = 1000;
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
logger _logger = new("PATTERN");
stockTradeFlowMgr _stockTradeFlowMgr = new(SEED);

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//             ASSERTION
//======================================
// Reset
assert_rst:
    assert property (
        @(posedge inf.rst_n)
            (inf.rst_n==1'b0) |-> 
            (inf.out_valid == 0 &&
             inf.warn_msg  == 0 &&
             inf.complete  == 0)
    )
    else begin
        _logger.error($sformatf("Output signal should be 0 at %-12d ps  ", $time*1000), 0);
        $fatal;
        // $finish;
    end

// Wait
/*
Code 1:
assert property (
        @(posedge clk)
        ((actionAssertCheck==Index_Check     ) |=> ##[1:10] (inf.out_valid===1)) or
        ((actionAssertCheck==Update          ) |-> ##[1:10] (inf.out_valid===1))
    )

Code 2:
assert property (
        @(posedge clk)
        ((actionAssertCheck==Update          ) |-> ##[1:10] (inf.out_valid===1))
    )

@Issue :
    Code 2 can detect the assertion error. However, the Code 1 can't detect the same error even in the same scenario

@Root cause :
    "or" should check the multiple condition simutaneously.
    When the program is checking the first one, the second one can't be triggered.

@Workaround :
    Seperate the two condition check to 2 properties
*/
Action actionAssertCheck;
sequence index_valid_high_4;
    inf.index_valid ##1 inf.index_valid ##1 inf.index_valid ##1 inf.index_valid;
endsequence
property wait_for_Index_Check;
        @(posedge clk)
            ((actionAssertCheck==Index_Check and index_valid_high_4) |-> ##[1:DELAY] (inf.out_valid===1));
endproperty
property wait_for_Update;
        @(posedge clk)
            ((actionAssertCheck==Update and index_valid_high_4) |-> ##[1:DELAY] (inf.out_valid===1));
endproperty
property wait_for_Check_Valid_Date;
        @(posedge clk)
            ((actionAssertCheck==Check_Valid_Date && inf.data_no_valid)  |-> ##[1:DELAY] inf.out_valid===1);
endproperty

assert_wait:
    assert property (
        wait_for_Index_Check and wait_for_Update and wait_for_Check_Valid_Date
    )
    else begin
        _logger.error($sformatf("The execution latency at %-12d ps is over %5d cycles  ", $time*1000, DELAY), 0);
        repeat(5) @(negedge clk);
        $fatal;
    end

// Output
assert_out_valid:
    assert property (
        @(posedge clk)
            inf.out_valid |-> ##[1:OUTNUM] inf.out_valid === 0
    )
    else
    begin
        _logger.error($sformatf("Out cycles is less than %3d at %-12d ps", OUTNUM, $time*1000));
        repeat(5) @(negedge clk);
        $fatal; 
    end

// TODO:
// assert_out_valid_not_overlap:
//     assert property (
//         @(posedge clk)
//     )
//     else
//     begin
//         _logger.error($sformatf("Out valid can't be overlapped with input valid at %-12d ps", $time*1000));
//         repeat(5) @(negedge clk);
//         $fatal; 
//     end

assert_complete_with_no_warn:
    assert property (
        @(posedge clk)
            (inf.out_valid && inf.complete) |-> (inf.warn_msg===No_Warn)
    )
    else
    begin
        _logger.error($sformatf("Out valid can't be overlapped with input valid at %-12d ps", $time*1000));
        repeat(5) @(negedge clk);
        $fatal; 
    end

//======================================
//              TASKS
//======================================
task exe_task; begin
    case(MODE)
        'd0: generate_dram_task;
        'd1: validate_design_task;
        default: begin
            _logger.error($sformatf("Mode (%-d) isn't valid...", MODE));
        end
    endcase
end endtask

task generate_dram_task; begin
    _stockTradeFlowMgr.getDramMgr().randomizeDramDat(DRAM_p_r);
    $finish;
end endtask

task validate_design_task; begin
    load_dat_from_dram;
    reset_task;
    #10;
    for (pat=0 ; pat<TOTAL_PATNUM ; pat=pat+1) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
    end
    pass_task;
end endtask

task load_dat_from_dram; begin
    _stockTradeFlowMgr.getDramMgr().loadDramFromDat(DRAM_p_r);
    if(DEBUG) begin
        _logger.info($sformatf("Dump the initial dram.dat info file"));
        _stockTradeFlowMgr.getDramMgr().dumpDramToFile(DRAM_INFO_FILE, NUM_OF_TABLE_PER_ROW_OF_DRAM_INFO_FILE);
    end
end endtask

task reset_task; begin
    inf.rst_n = 1;
    inf.sel_action_valid = 0;
    inf.formula_valid = 0;
    inf.mode_valid = 0;
    inf.date_valid = 0;
    inf.data_no_valid = 0;
    inf.index_valid = 0;
    inf.D = 'dx;

    tot_lat = 0;

    #(10) inf.rst_n = 0;
    #(10) inf.rst_n = 1;
end endtask

// Input utility
task send_valid_and_data;
    input string dataTypeName;
    input string indexName;
begin
    Data data;
    if(indexName == "")
        data = _stockTradeFlowMgr.getInputMgr().getInputData(dataTypeName);
    else
        data = _stockTradeFlowMgr.getInputMgr().getInputData(dataTypeName, indexName);
    inf.sel_action_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_act[0]), dataTypeName);
    inf.formula_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_formula[0]), dataTypeName);
    inf.mode_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_mode[0]), dataTypeName);
    inf.date_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_date[0]), dataTypeName);
    inf.data_no_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_data_no[0]), dataTypeName);
    inf.index_valid = _stockTradeFlowMgr.getInputMgr().getValid($typename(inf.D.d_index[0]), dataTypeName);
    inf.D = data;

    @(negedge clk);

    inf.sel_action_valid = 0;
    inf.formula_valid = 0;
    inf.mode_valid = 0;
    inf.date_valid = 0;
    inf.data_no_valid = 0;
    inf.index_valid = 0;
    inf.D = 'dx;
end endtask

task random_gap_cycles; begin
    repeat( ({$random(SEED)} % 4 + 0) ) @(negedge clk);
end endtask

task input_task; begin
    Action inputAction;
    repeat( ({$random(SEED)} % 4 + 1) ) @(negedge clk);
    // Randomize
    _stockTradeFlowMgr.getInputMgr().randomizeInput();
    // Action
    inputAction = _stockTradeFlowMgr.getInputMgr().getAction();
    // Assertion
    actionAssertCheck = inputAction;
    send_valid_and_data($typename(inputAction), "");
    // Other
    case(inputAction)
        Index_Check: begin
            send_valid_and_data($typename(inf.D.d_formula[0]), "");
            send_valid_and_data($typename(inf.D.d_mode[0]), "");
            send_valid_and_data($typename(inf.D.d_date[0]), "");
            send_valid_and_data($typename(inf.D.d_data_no[0]), "");
            send_valid_and_data($typename(inf.D.d_index[0]), "A");
            send_valid_and_data($typename(inf.D.d_index[0]), "B");
            send_valid_and_data($typename(inf.D.d_index[0]), "C");
            send_valid_and_data($typename(inf.D.d_index[0]), "D");
        end
        Update: begin
            send_valid_and_data($typename(inf.D.d_date[0]), "");
            send_valid_and_data($typename(inf.D.d_data_no[0]), "");
            send_valid_and_data($typename(inf.D.d_index[0]), "A");
            send_valid_and_data($typename(inf.D.d_index[0]), "B");
            send_valid_and_data($typename(inf.D.d_index[0]), "C");
            send_valid_and_data($typename(inf.D.d_index[0]), "D");
        end
        Check_Valid_Date: begin
            send_valid_and_data($typename(inf.D.d_date[0]), "");
            send_valid_and_data($typename(inf.D.d_data_no[0]), "");
        end
        default: begin
            _logger.error($sformatf("Action (%s) isn't valid...", inputAction.name()));
        end
    endcase
    // Assertion
    actionAssertCheck = 'dx;
end endtask

task cal_task; begin
    if(DEBUG) begin
        _logger.info($sformatf("Dump the dram.dat info file before operation : %s", {DRAM_INFO_FILE, ".before"}));
        _stockTradeFlowMgr.getDramMgr().dumpDramToFile({DRAM_INFO_FILE, ".before"}, NUM_OF_TABLE_PER_ROW_OF_DRAM_INFO_FILE);
    end
    _stockTradeFlowMgr.getOutputMgr().clear();
    _stockTradeFlowMgr.run();
    if(DEBUG) begin
        _logger.info($sformatf("Dump the dram.dat info file after operation : %s", {DRAM_INFO_FILE, ".after"}));
        _stockTradeFlowMgr.getDramMgr().dumpDramToFile({DRAM_INFO_FILE, ".after"}, NUM_OF_TABLE_PER_ROW_OF_DRAM_INFO_FILE);
    end
end endtask

task wait_task; begin
    exe_lat = -1;
    while(inf.out_valid !== 1) begin
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

task check_task; begin
    // _stockTradeFlowMgr.getInputMgr().getRandMgr().display();

    while(inf.out_valid === 1) begin
        _stockTradeFlowMgr.getOutputMgr().setCurdOutput(inf.warn_msg, inf.complete);
        if(!_stockTradeFlowMgr.getOutputMgr().isCorrect()) begin
            _stockTradeFlowMgr.display();
            _logger.error("Output is not correct...\n");
        end
        @(negedge clk);
    end

    tot_lat = tot_lat + exe_lat;
    $display("%0sPASS PATTERN NO.%4d %0sCycles: %3d%0s",txt_blue_prefix, pat, txt_green_prefix, exe_lat, reset_color);
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

endprogram
