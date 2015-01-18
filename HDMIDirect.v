// (c) fpga4fun.com & KNJN LLC 2013

////////////////////////////////////////////////////////////////////////
module HDMIDirectV(
	input pixclk, clk_TMDS,  // 25MHz + 125MHz
	input [16:0] videobus,
	input [4:0] Rin, Gin, Bin,
	input dak, sha,
	input button,
	input sync,
	output [2:0] TMDSp, TMDSn,
	output TMDSp_clock, TMDSn_clock,
	output [10:0] videoaddressw,
	output videoramenable,
	output videoramclk,
	output videoramoutclk,
	output videowrite,
	output [10:0] videoaddressoutw,
	output [16:0] videobusoutw
);

////////////////////////////////////////////////////////////////////////
reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
reg [10:0] videoaddress;
reg [10:0] videoaddressout;
reg [16:0] videobusout;
reg frame;
reg tercData;
reg [3:0] dataChannel0;
reg [3:0] dataChannel1;
reg [3:0] dataChannel2;
reg [3:0] preamble;
reg dataGuardBand;
reg videoGuardBand;
reg [23:0] packetHeader;
reg [7:0]  bchHdr;
reg [55:0] subpacket [3:0];
reg [7:0]  bchCode [3:0];
reg [4:0]  dataOffset;

initial
begin
 CounterX=0;
 CounterY=0;
 hSync=0;
 vSync=0;
 DrawArea=0;
 videobusout=0;
 videoaddressout=0;
 videoaddressout=0;
 frame=0;
 tercData=0;
 dataChannel0=0;
 dataChannel1=0;
 dataChannel2=0;
 preamble=0;
 dataGuardBand=0;
 videoGuardBand=0;
 packetHeader=0;
 bchHdr=0;
 subpacket[0]=0;
 subpacket[1]=0;
 subpacket[2]=0;
 subpacket[3]=0;
 bchCode[0]=0;
 bchCode[1]=0;
 bchCode[2]=0;
 bchCode[3]=0;
 dataOffset=0;
end

`define DISPLAY_WIDTH 640 //720 //640
`define DISPLAY_HEIGHT 480
`define FULL_WIDTH 768 // 880 //800
`define FULL_HEIGHT 528
`define H_FRONT_PORCH 16 //24 // 16 
`define H_SYNC 96 // 40 //96 
`define V_FRONT_PORCH 10 
`define V_SYNC 2 // 3 //2

assign videoramenable=1'b1;
assign videoramclk=!pixclk;
assign videoramoutclk=!pixclk;
assign videowrite=1'b1;
assign videoaddressoutw=videoaddressout;
assign videobusoutw=videobusout;
assign videoaddressw=videoaddress;

always @(posedge pixclk) DrawArea <= (CounterX<`DISPLAY_WIDTH) && (CounterY<`DISPLAY_HEIGHT);

//always @(posedge pixclk) CounterX <= (CounterX==(`FULL_WIDTH-1)) ? 0 : CounterX+1;
//always @(posedge pixclk) if(CounterX==(`FULL_WIDTH-1)) CounterY <= (CounterY==(`FULL_HEIGHT-1)) ? 0 : CounterY+1;

always @(posedge pixclk) hSync <= (CounterX>=(`DISPLAY_WIDTH+`H_FRONT_PORCH)) && (CounterX<(`DISPLAY_WIDTH+`H_FRONT_PORCH+`H_SYNC));
always @(posedge pixclk) vSync <= (CounterY>=(`DISPLAY_HEIGHT+`V_FRONT_PORCH)) && (CounterY<(`DISPLAY_HEIGHT+`V_FRONT_PORCH+`V_SYNC));

`define DATA_START		`DISPLAY_WIDTH+`H_FRONT_PORCH+4;
`define DATA_PREAMBLE	8
`define DATA_GUARDBAND	2
`define DATA_SIZE		32
`define CTL_GAP			4
`define VIDEO_PREAMBLE	8
`define VIDEO_GUARDBAND	2
// Total time 60 pixels (want it to fit with hsync period) 

function [7:0] ECCcode
	input [7:0] code;
	input bit;
	input mask;
	begin
		ECCcode = (code<<1) ^ (((code[7]^bit) && mask)?(1+(1<<6)+(1<<7)):0);
	end
endfunction

function ECC;
	inout [7:0] code;
	input bit;
	input mask;
	begin
		ECC = mask?bit:code[7];
		code <= ECCcode(code, bit, mask);
	end
endfunction

function ECC2a;
	input [7:0] code;
	input bita;
	input bitb;
	input mask;
	begin
		ECC2a = mask?bita:code[7];
	end
endfunction

function ECC2b;
	inout [7:0] code;
	input bita;
	input bitb;
	input mask;
	begin
		ECC2b = mask?bitb:ECCcode(code, bita, mask)[7];
		code <= ECCcode(ECCcode(code, bita, mask), bitb, mask);
	end
endfunction

always @(posedge pixclk)
begin
	if (CounterX>=('DISPLAY_WIDTH+'DATA_START)
	begin
		if (CounterX<(`DATA_START+`DATA_PREAMBLE)
		begin
			preamble<='b1010;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND)
		begin
			tercData<=1;
			dataGuardBand<=1;
			dataChannel0<={1, 1, vSync, hSync};
			preamble<=0;
			packetHeader<=0;	// null packet
			subpacket[0]<=0;
			subpacket[1]<=0;
			subpacket[2]<=0;
			subpacket[3]<=0;
			bchHdr<=0;
			bchCode[0]<=0;
			bchCode[1]<=0;
			bchCode[2]<=0;
			bchCode[3]<=0;
			dataOffset<=0;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE)
		begin
			dataGuardBand<=0;
			dataChannel0<={dataOffset?1:0, ECC(bchHdr, packetHeader[0], dataOffset<24), vSync, hSync};
			dataChannel1<={
				ECC2a(bchCode[3], subpacket[3][0], subpacket[3][1], dataOffset<28),
				ECC2a(bchCode[2], subpacket[2][0], subpacket[2][1], dataOffset<28),
				ECC2a(bchCode[1], subpacket[1][0], subpacket[1][1], dataOffset<28),
				ECC2a(bchCode[0], subpacket[0][0], subpacket[0][1], dataOffset<28)
				};
			dataChannel2<={
				ECC2b(bchCode[3], subpacket[3][0], subpacket[3][1], dataOffset<28),
				ECC2b(bchCode[2], subpacket[2][0], subpacket[2][1], dataOffset<28),
				ECC2b(bchCode[1], subpacket[1][0], subpacket[1][1], dataOffset<28),
				ECC2b(bchCode[0], subpacket[0][0], subpacket[0][1], dataOffset<28)
				};
			packetHeader<=packetHeader[23:1];
			subpacket[0]<=subpacket[0][55:2];
			subpacket[1]<=subpacket[1][55:2];
			subpacket[2]<=subpacket[2][55:2];
			subpacket[3]<=subpacket[3][55:2];
			dataOffset<=dataOffset+1;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_GUARDBAND)
		begin
			dataGuardBand<=1;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_GUARDBAND+`CTL_GAP)
		begin
			tercData<=0;
			dataGuardBand<=0;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_GUARDBAND+`CTL_GAP+`VIDEO_PREAMBLE)
		begin
			preamble<='b1000;
		end
		else
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_GUARDBAND+`CTL_GAP+`VIDEO_PREAMBLE+`VIDEO_GUARDBAND)
		begin
			preamble<=0;
			videoGuardBand<=1;
		end
		else
		begin
			videoGuardBand<=0;
		end
	end
end

////////////////
//wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
//wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
//wire ndak = !dak;

reg [7:0] red, green, blue;
//always @(posedge pixclk) red <=   CounterY[0]?(((Rin<<1)|ndak)*3+((~sha)?((Rin<<1)|ndak):0)):0;//videobus[23:16];//({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
//always @(posedge pixclk) green <= CounterY[0]?(((Gin<<1)|ndak)*3+((~sha)?((Gin<<1)|ndak):0)):0;//videobus[15:8];//(CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
//always @(posedge pixclk) blue <=  CounterY[0]?(((Bin<<1)|ndak)*3+((~sha)?((Bin<<1)|ndak):0)):0;//videobus[7:0];//CounterY[7:0] | W | A;

always @(posedge pixclk)
begin
	CounterX <= (CounterX==(`FULL_WIDTH-1)) ? 0 : CounterX+1;
	if(CounterX==(`FULL_WIDTH-1)) begin
		if (CounterY==(`FULL_HEIGHT-1)) begin
			CounterY <= 0;
			frame <= !frame;
		end else begin
			CounterY <= CounterY+1;
		end
	end
	if (CounterY>`DISPLAY_HEIGHT && sync) begin
		CounterY <= 0;
	end
	if ((CounterX>>1)+(CounterY[0]?`FULL_WIDTH/2:0)<`DISPLAY_WIDTH) begin
		if (CounterX[0]) begin
			videoaddressout<=(CounterY[1]?`DISPLAY_WIDTH:0)+(CounterY[0]?`FULL_WIDTH/2:0)+(CounterX>>1);
			videobusout[4:0]<=Rin;
			videobusout[9:5]<=Gin;
			videobusout[14:10]<=Bin;
			videobusout[15]<=!dak;
			videobusout[16]<=!sha;
		end
	end else begin
		if (sync)
			CounterX <= 0;
	end
	if (CounterX<`DISPLAY_WIDTH) begin
		videoaddress<=(CounterY[1]?0:`DISPLAY_WIDTH) + CounterX;
		if (CounterY[0]==frame) begin
			red <= ((videobus[4:0]<<1)|videobus[15])*3 + (videobus[16]?((videobus[4:0]<<1)|videobus[15]):0);
			green <= ((videobus[9:5]<<1)|videobus[15])*3 + (videobus[16]?((videobus[9:5]<<1)|videobus[15]):0);
			blue <= ((videobus[14:10]<<1)|videobus[15])*3 + (videobus[16]?((videobus[14:10]<<1)|videobus[15]):0);
		end else begin
			red <= (((videobus[4:0]<<1)|videobus[15])*3 + (videobus[16]?((videobus[4:0]<<1)|videobus[15]):0)) >> 1;
			green <= (((videobus[9:5]<<1)|videobus[15])*3 + (videobus[16]?((videobus[9:5]<<1)|videobus[15]):0)) >> 1;
			blue <= (((videobus[14:10]<<1)|videobus[15])*3 + (videobus[16]?((videobus[14:10]<<1)|videobus[15]):0)) >> 1;
		end
	end
end

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(preamble[1:0]), .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(preamble[3:2]), .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

wire [9:0] TERC4_red, TERC4_green, TERC4_blue;
TERC4_encoder encode_R4(.clk(pixclk), .data(dataChannel2), .TERC4(TERC4_red));
TERC4_encoder encode_G4(.clk(pixclk), .data(dataChannel1), .TERC4(TERC4_green));
TERC4_encoder encode_B4(.clk(pixclk), .data(dataChannel0), .TERC4(TERC4_blue));

wire redSource = videoGuardBand ? : 10'b1011001100 : (dataGuardBand ? 10'b0100110011 : (tercData ? TERC4_red : TMDS_red));
wire greenSource = (dataGuardBand || videoGuardBand) ? 10'b0100110011 : (tercData ? TERC4_green : TMDS_green);
wire blueSource = videoGuardBand ? 10'b1011001100 : (tercData ? TERC4_blue : TMDS_blue);

////////////////////////////////////////////////////////////////////////
reg [3:0] TMDS_mod10;  // modulus 10 counter
reg [9:0] TMDS_shift_red, TMDS_shift_green, TMDS_shift_blue;
//reg TMDS_shift_load;

initial
begin
  TMDS_mod10=0;
  TMDS_shift_red=0;
  TMDS_shift_green=0;
  TMDS_shift_blue=0;
  red=0;
  green=0;
  blue=0;
end

always @(posedge clk_TMDS)
begin
	TMDS_shift_red   <= (TMDS_mod10==4'd0) ? redSource   : TMDS_shift_red  [9:2];
	TMDS_shift_green <= (TMDS_mod10==4'd0) ? greenSource : TMDS_shift_green[9:2];
	TMDS_shift_blue  <= (TMDS_mod10==4'd0) ? blueSource  : TMDS_shift_blue [9:2];	
	TMDS_mod10 <= (TMDS_mod10==4'd8) ? 4'd0 : TMDS_mod10+4'd2;
end

assign TMDSp[2]=clk_TMDS?TMDS_shift_red[0]:TMDS_shift_red[1];
assign TMDSn[2]=~TMDSp[2];
assign TMDSp[1]=clk_TMDS?TMDS_shift_green[0]:TMDS_shift_green[1];
assign TMDSn[1]=!TMDSp[1];
assign TMDSp[0]=clk_TMDS?TMDS_shift_blue[0]:TMDS_shift_blue[1];
assign TMDSn[0]=!TMDSp[0];
assign TMDSp_clock=pixclk;
assign TMDSn_clock=!pixclk;
endmodule


////////////////////////////////////////////////////////////////////////
module TMDS_encoder(
	input clk,
	input [7:0] VD,  // video data (red, green or blue)
	input [1:0] CD,  // control data
	input VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
	output reg [9:0] TMDS
);

wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
wire XNOR = (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
wire [8:0] q_m = {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};

reg [3:0] balance_acc;

initial begin
	balance_acc=0;
end

wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
wire balance_sign_eq = (balance[3] == balance_acc[3]);
wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);

always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
endmodule

////////////////////////////////////////////////////////////////////////

module TERC4_encoder(
	input clk,
	input [3:0] data,
	output reg [9:0] TERC
);

always @(posedge clk)
begin
	case (data):
		4'b0000: TERC <= 10'b1010011100;
		4'b0001: TERC <= 10'b1001100011;
		4'b0010: TERC <= 10'b1011100100;
		4'b0011: TERC <= 10'b1011100010;
		4'b0100: TERC <= 10'b0101110001;
		4'b0101: TERC <= 10'b0100011110;
		4'b0110: TERC <= 10'b0110001110;
		4'b0111: TERC <= 10'b0100111100;
		4'b1000: TERC <= 10'b1011001100;
		4'b1001: TERC <= 10'b0100111001;
		4'b1010: TERC <= 10'b0110011100;
		4'b1011: TERC <= 10'b1011000110;
		4'b1100: TERC <= 10'b1010001110;
		4'b1101: TERC <= 10'b1001110001;
		4'b1110: TERC <= 10'b0101100011;
		4'b1111: TERC <= 10'b1011000011;
	endcase
end

endmodule

////////////////////////////////////////////////////////////////////////

