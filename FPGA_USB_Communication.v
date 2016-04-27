///////////////////////////////////////////////////////////////////////////////////////////////////
// Company: <NanJing University>
//
// File: FPGA_USB_Communication.v
// File history:
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: FT600Q and ProAsic3 communication through 245 protocol with 
// FSM, and trans 16 of 16bit data.
// <USB3.0 Data Acquisition System for Phase-OTDR>
//
// Targeted device: <Family::ProASIC3> <Die::A3P250> <Package::208 PQFP>
// Author: <YangHuan> yanghuandf@foxmail.com
//
/////////////////////////////////////////////////////////////////////////////////////////////////// 

//`timescale <time_units> / <precision>

module DAQ_TEST( 
//CLK
input MAIN_CLK,
input AUX_CLK,
input RESET_EXT,
output[2:0] AD9553_OM,
output AD9553_SELREFB,
output AD9553_RESETB,

//TRGOUT
output TRGOUT_0,
output TRGOUT_1,
output ADC_OR, 
//SDRAM0
output SDRAM0_CKE,
output SDRAM0_RAS,
output SDRAM0_CAS,
output SDRAM0_WE,
output SDRAM0_DQM,
output[12:0] SDRAM0_SA,
output[1:0] SDRAM0_BA,
output SDRAM0_CS,
inout[15:0] SDRAM0_DATA,
output SDRAM0_CLK,
//USB3.0
inout[15:0] USB_DATA,
input USB_CLK,
inout[1:0] USB_BE,
input  USB_RXF_N,
input  USB_TXE_N,
output USB_WR_N,
output USB_SIWU_N,
output USB_RD_N,
output USB_OE_N,
output USB_RESET_N,
output USB_WAKEUP_N,
output[1:0] USB_GPIO
);
//Declaration
wire SDRAM_CLK;
reg READ_WRITE_TRANS;//0 for READ,1 for WRITE ;READ First
wire INTERNAL_RESET_N;




//Clock segment
assign ADC_OR=READ_WRITE_TRANS;
assign AD9553_SELREFB=0;
assign AD9553_RESETB=1;
assign AD9553_OM[2:0]=3'b101;
//assign SDRAM_CLK=MAIN_CLK;
reg[9:0]RESET_COUNTER=10'b0;


assign INTERNAL_RESET_N=~((RESET_COUNTER[9:0]>=500) && (RESET_COUNTER[9:0]<1000));

always @ (negedge MAIN_CLK or negedge  RESET_EXT)
    begin
    if(!RESET_EXT)
        begin
        RESET_COUNTER[9:0]<=10'b0;
        end
    else
        begin
            if (RESET_COUNTER[9:0]>1010)RESET_COUNTER[9:0]<=1020;
                else RESET_COUNTER[9:0]<=RESET_COUNTER[9:0]+1'b1;      
        end
    end
//End clock segment



//SDRAM_IP
wire SDRAM_CKE,SDRAM_RAS,SDRAM_CAS,SDRAM_WE,SDRAM_OE,SDRAM_DQM,SDRAM_CS;
wire[12:0] SDRAM_SA;
wire[1:0] SDRAM_BA;
wire[15:0] SDRAM_DATAOUT,SDRAM_DATAIN;
assign SDRAM0_CKE=SDRAM_CKE;
assign SDRAM_RAS=SDRAM0_RAS;
assign SDRAM0_CAS=SDRAM_CAS;
assign SDRAM0_WE=SDRAM_WE;
assign SDRAM0_DQM=SDRAM_DQM;
assign SDRAM0_SA[12:0]=SDRAM_SA[12:0];
assign SDRAM0_BA[1:0]=SDRAM_BA[1:0];
assign SDRAM0_CS=SDRAM_CS;
assign SDRAM0_CLK=SDRAM_CLK;
assign SDRAM0_DATA[15:0]=SDRAM_OE?SDRAM_DATAOUT:16'bz;
assign SDRAM_DATAIN[15:0]=SDRAM0_DATA[15:0];
SDRAM_IP SDRAM_IP0(
    // Inputs
    .AUTO_PCH(),//input
    .BL(2'd3),
    .B_SIZE(),//input
    .CL(3'd2),
    .CLK(SDRAM_CLK),//input
    .COLBITS(3'd5),
    .DELAY(16'd20000),
    .MRD(3'd2),
    .RADDR(),//input
    .RAS(4'd5),
    .RC(4'd8),
    .RCD(3'd3),
    .REF(16'd781),
    .REGDIMM(1'd0),
    .RESET_N(INTERNAL_RESET_N),//input
    .RFC(4'd8),
    .ROWBITS(2'd2),
    .RP(3'd3),
    .RRD(2'd3),
    .R_REQ(),//input
    .SD_INIT(),//input
    .WR(2'd2),//tDPL
    .W_REQ(),//input
    // Outputs
    .BA(SDRAM_BA),
    .CAS_N(SDRAM_CAS),
    .CKE(SDRAM_CKE),
    .CS_N(SDRAM_CS),
    .DQM(SDRAM_DQM),
    .D_REQ(),
    .OE(SDRAM_OE),
    .RAS_N(SDRAM_RAS),
    .RW_ACK(),
    .R_VALID(),
    .SA(SDRAM_SA),
    .WE_N(SDRAM_WE),
    .W_VALID()
);
//end SDRAM_IP module

//USB3.0 module
assign USB_SIWU_N=1;
assign USB_RESET_N=1;
assign USB_WAKEUP_N=1;
assign USB_GPIO[1:0]=2'b00;


//FSM state={TXE,RXE,OE,RD,WR}
localparam   M245_IDL = 7'b11111;  
localparam   M245_R1  = 7'b10111;  
localparam   M245_R2  = 7'b10011;  
localparam   M245_R3  = 7'b10001;  //  MT READ
localparam   M245_R4  = 7'b11001;  
localparam   M245_W1  = 7'b01111;  
localparam   M245_W2  = 7'b01110;  //  MT WRITE
localparam   M245_W3  = 7'b11110;  
reg[4:0] current_status;
reg[4:0] next_status;

always @(*)
    begin
    next_status=current_status;
    case(current_status)
        M245_IDL:
            begin
                if(!USB_RXF_N)next_status=M245_R1;
                if(!USB_TXE_N)next_status=M245_W1;
            end
        M245_R1:
            begin
                next_status=M245_R2;
            end
        M245_R2:
            begin
                next_status=M245_R3;
            end
        M245_R3:
            begin
                if(USB_RXF_N)next_status=M245_R4;
            end
        M245_R4:
            begin
                next_status=M245_IDL;
            end
        M245_W1:
            begin
                next_status=M245_W2;
            end
        M245_W2:
            begin
                if(USB_TXE_N)next_status=M245_W3;
            end
        M245_W3:
            begin
                next_status=M245_IDL;
            end
        default:
            begin
            next_status=M245_IDL;    
            end
        endcase
    end


reg[255:0] DATA_IN_OUT;
reg[15:0] USB_DATA_OUT;

always @ (negedge USB_CLK or negedge INTERNAL_RESET_N)
    begin
        if(~INTERNAL_RESET_N)
            begin
            current_status<=M245_IDL;
            READ_WRITE_TRANS<=0;
            USB_DATA_OUT[15:0]<=16'b0;
            end
        else
            begin
            current_status<=next_status;
            if(next_status==M245_R2)READ_WRITE_TRANS<=0;
            if(next_status==M245_W1)READ_WRITE_TRANS<=1;
            if(next_status==M245_W2)
                begin                
                USB_DATA_OUT[15:0]<=DATA_IN_OUT[255:240];           
                end        
            end
    end

always @ (posedge USB_CLK or negedge INTERNAL_RESET_N)
    begin
    if(~INTERNAL_RESET_N)
        begin
        DATA_IN_OUT[255:0]<=256'b0;        
        end
    else
        begin
        if(next_status==M245_R3)
            begin
            DATA_IN_OUT[255:16]<=DATA_IN_OUT[240:0];
            DATA_IN_OUT[15:0]<=USB_DATA[15:0]&{{8{USB_BE[1]}},{8{USB_BE[0]}}};
            end
        if(current_status==M245_W2)
            begin
            DATA_IN_OUT[255:16]<=DATA_IN_OUT[240:0];
            end        
        end
    end

//TRGOUT segment
assign TRGOUT_0=current_status[1];
assign TRGOUT_1=USB_CLK;
//End TRGOUT segmentUSB_CLK

assign USB_OE_N=current_status[2];//USB_OE_REG;
assign USB_RD_N=current_status[1];//USB_RD_REG;
assign USB_WR_N=current_status[0];//USB_WR_REG;
assign USB_BE[1:0]=READ_WRITE_TRANS?2'b11:2'bz;
assign USB_DATA[15:0]=READ_WRITE_TRANS?USB_DATA_OUT[15:0]:16'bz;
//end USB3.0 module
endmodule