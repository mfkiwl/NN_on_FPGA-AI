`timescale 1ns / 1ps

    module final_code(
    input clk,
    input rst,
    output [7:0] dout,
    output [7:0] dummy,
    output [11:0] wout
    );
    wire clk1;
    reg en1;                                                   // enable for invec reading
    reg [9:0] addr_q;                                          // row of invec
    wire [9:0] addr_d;
    reg [14:0] finaladdr_q;                                    // addr to BROM IP
    wire [14:0] finaladdr_d;
    reg [7:0] dout;                                            // data out from BROM IP 
    wire [7:0] dout;
    reg [6:0] j_q;                                             // col of invec
    wire [6:0] j_d;
    reg signed [16:0] invec [0:783][0:39];
    
    /* Declaring weight variables */
    reg signed [15:0] weight [0:783];
    reg en_w;
    wire clk2;
    reg [11:0] wout;
    wire [11:0] wout;
    /*----------------------------*/
    
    /*Declaring variables for matrix mul betn weight and invec*/
    reg en2;
    reg signed [31:0] z [0:39];             //forward propagation
    wire [9:0] i_d;                         //row
    reg [9:0] i_q;
    wire [6:0] c_d;                         //column
    reg [6:0] c_q;
    /*--------------------------------------------------------*/
    
    /*Declaring variables for sigmoid block*/
    reg en3;
    reg signed [9:0] ycap [0:39];
    wire [10:0] sig_in;                     //In and Out of sigmoid block
    wire [7:0] sig_out;
    wire [31:0] z_neg;                      //Incase we need to neg of z
    reg [6:0] sig_counter_q;                //counter for indexing of z
    wire [6:0] sig_counter_d;
    /*-------------------------------------*/
    
    /* Processing invec reading */
    assign clk1 = clk & en1;
    assign finaladdr_d = j_q * 784 + addr_q;
    assign addr_d = (addr_q == 783)? 0 : (addr_q + 1);
    assign j_d = (addr_q == 783)? (j_q + 1) : (j_q);
    /*--------------------------*/
    
    /* Processing weight reading */
    assign clk2 = clk & en_w;
    /*---------------------------*/
    
    /*Forward Propagation Matrix Multiplication*/
    assign i_d = (en2 == 1)? ((i_q == 783)? 0: (i_q + 1)):(0);
    assign c_d = (en2 == 1)? ((i_q == 783)? (c_q + 1): (c_q)):(0);
    /*-----------------------------------------*/
    
    /*Application of Sigmoid block in forward Propagation*/
    assign sig_counter_d = (en3 == 1)? (sig_counter_q + 1) : (0);
    assign z_neg = -z[sig_counter_q];
    assign sig_in = (z[sig_counter_q] > 0)? (z[sig_counter_q] [18:8]) : (z_neg[18:8]);
    sigmoid u1(.in(sig_in), .out(sig_out));
    /*---------------------------------------------------*/
    
    // We can use addr_q to read the weight column, then turn OFF en_w to stop the reading
    /*---------------------------*/
    /*
    always @( * )
    begin
        assign finaladdr_d = j_q * 784 + addr_q;
        if(addr_q == 783)
            begin
            addr_d = 0;
            j_d = j_q + 1;
            end
        else
            begin
            addr_d = addr_q + 1;
            j_d = j_q;
            end
    end   
    */
    always @(posedge clk or posedge rst)
    begin
        if(rst)
            begin
            /*initialising reading block*/
            addr_q <= 0;
            j_q <= 0;
            finaladdr_q <= 0;
            en1 <= 1;                   //Turning ON invec reading
            en_w <= 1;                  //Turning ON weight reading
            /*--------------------------*/
            
            /*Initialising forward propagation*/
            en2 <= 0;                   //Other enables turned OFF
            i_q <= 0;
            c_q <= 0;
            /*--------------------------------*/
            
            /*Initialising sigmoid block*/
            en3 <= 0;
            sig_counter_q <= 0;
            /*--------------------------*/
            end
        else
            begin
            //en1 code
            if(en1 == 1)
                begin
                invec[addr_q][j_q] <= {{1'b0},{dout},{8{1'b0}}};         //read into invec
                finaladdr_q <= finaladdr_d;         //update next address
                addr_q <= addr_d;                   
                j_q <= j_d;
                if(finaladdr_q == 31359)            //is reading over? then time to go to next block!
                    begin
                    en1 <= 1'b0;
                    en2 <= 1'b1;
                    end
                else
                    begin
                    en1 <= 1'b1;
                    en2 <= 1'b0;
                    end
                if(en_w == 1)
                    begin
                        weight[addr_q] <= {{wout[11]},{4{1'b0}},{wout[10:0]}};      //Reading weight column
                    end
                if(addr_q == 783)
                    begin
                    en_w <= 0;
                    end
                end
                
            // en 2 code  
            if(en2 == 1)
                begin
                //counter register assignments
                i_q <= i_d;
                c_q <= c_d;
                //input * weight 
                if(i_q == 0)
                    begin
                    z[c_q] <= invec[i_q][c_q] * weight[i_q];
                    end
                else
                    begin
                    z[c_q] <= z[c_q] + invec[i_q][c_q] * weight[i_q];
                    end
                if((i_q == 783) && (c_q == 39))
                    begin
                    en2 <= 0;
                    en3 <= 1;
                    end
                else
                    begin
                    en2 <= 1;
                    en3 <= 0;
                    end
                end
            end
            
            if(en3 == 1)
            begin
            sig_counter_q <= sig_counter_d;
            //performing sigmoid operation
            if((z[sig_counter_q] >= 524288) || (z[sig_counter_q] <= -524288))
                begin
                if(z[sig_counter_q] >= 524288)
                    begin
                    ycap[sig_counter_q] <= {{1'b0},{1'b1},{8{1'b0}}};
                    end
                else
                    begin
                    ycap[sig_counter_q] <= 0;
                    end
                end
            else
                begin
                if(z[sig_counter_q] >= 0)
                    begin
                    ycap[sig_counter_q] <= {{2{1'b0}},sig_out};
                    end
                else
                    begin
                    ycap[sig_counter_q] <= 10'b0100000000 - sig_out;
                    end
                end
            //ending the sigmoid block
            if(sig_counter_q == 39)
                begin
                en3 <= 0;
                end
            else
                begin
                en3 <= 1;
                end
            end
    end
    /* Reading invec from BROM */
    blk_mem_gen_1 your_instance_name (
          .clka(clk1),                      // input wire clka
          .addra(finaladdr_q),              // input wire [14 : 0] addra
          .douta(dout)                      // output wire [7 : 0] douta
        );
    /*-------------------------*/
    
    /* Reading weight from BROM */
    blk_mem_gen_2 your_instance_name2 (
      .clka(clk2),    // input wire clka
      .addra(addr_q),  // input wire [9 : 0] addra
      .douta(wout)  // output wire [11 : 0] douta
    );
    /*--------------------------*/
    
    assign dummy = ((addr_q == 0) &&(j_q == 0))?(invec[0][0]):((addr_q == 0)?(invec[783][j_q-1]):(invec[addr_q-1][j_q]));
endmodule
