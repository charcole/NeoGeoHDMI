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
reg [23:0] packetHeader2;
reg [7:0]  bchHdr;
reg [55:0] subpacket [3:0];
reg [55:0] subpacket2[3:0];
reg [7:0]  bchCode [3:0];
reg [4:0]  dataOffset;
reg [4:0]  dataOffset2;
reg [191:0] channelStatus;
reg [7:0] channelStatusIdx;
reg tercDataDelayed;
reg videoGuardBandDelayed;
reg dataGuardBandDelayed;
reg [24:0] samplesNeeded;
reg [15:0] audioTimer;
reg [9:0] audioSamples;
reg [15:0] sample;
reg sampleDir;

reg [15:0] samplex;
reg [15:0] sampley;
reg [4:0] sineSign;
reg [1:0] sinePhase;

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
 packetHeader2=0;
 bchHdr=0;
 subpacket[0]=0;
 subpacket[1]=0;
 subpacket[2]=0;
 subpacket[3]=0;
 subpacket2[0]=0;
 subpacket2[1]=0;
 subpacket2[2]=0;
 subpacket2[3]=0;
 bchCode[0]=0;
 bchCode[1]=0;
 bchCode[2]=0;
 bchCode[3]=0;
 dataOffset=0;
 dataOffset2=0;
 channelStatus=0;
 channelStatusIdx=0;
 tercDataDelayed=0;
 videoGuardBandDelayed=0;
 dataGuardBandDelayed=0;
 samplesNeeded=0;
 audioTimer=0;
 sample=0;
 sampleDir=0;
 samplex=0;
 sampley=0;
 sineSign=0;
 sinePhase=0;
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

`define DATA_START		(`DISPLAY_WIDTH+`H_FRONT_PORCH+4)
`define DATA_PREAMBLE	8
`define DATA_GUARDBAND	2
`define DATA_SIZE			32
`define VIDEO_PREAMBLE	8
`define VIDEO_GUARDBAND	2
`define CTL_END			(`FULL_WIDTH-`VIDEO_PREAMBLE-`VIDEO_GUARDBAND)

function [7:0] ECCcode;
	input [7:0] code;
	input bita;
	input mask;
	begin
		ECCcode = (code<<1) ^ (((code[7]^bita) && mask)?(1+(1<<6)+(1<<7)):0);
	end
endfunction

function ECC;
	input [7:0] code;
	input bita;
	input mask;
	begin
		ECC = mask?bita:code[7];
	end
endfunction

task ECCu;
	inout [7:0] code;
	input bita;
	input mask;
	begin
		code <= ECCcode(code, bita, mask);
	end
endtask

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
	input [7:0] code;
	input bita;
	input bitb;
	input mask;
	begin
		ECC2b = mask?bitb:(code[6]^(((code[7]^bita) && mask)?1'b1:1'b0));
	end
endfunction

task ECC2u;
	inout [7:0] code;
	input bita;
	input bitb;
	input mask;
	begin
		code <= ECCcode(ECCcode(code, bita, mask), bitb, mask);
	end
endtask

localparam [191:0] CSB = 192'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_C2_03_00_40_04;

always @(posedge pixclk)
begin
	if (audioTimer==749) begin
		audioTimer<=0;
		
		if (sineSign==30) begin
			samplex<='h7ff8;
			sampley<=0;
			sineSign<=0;
			sinePhase<=sinePhase+1;
		end else begin
			sineSign<=sineSign+1;
			samplex<=(samplex*'h7fd5-sampley*'h67b)>>15;
			sampley<=(samplex*'h67b+sampley*'h7fd5)>>15;
		end
		
		case (sinePhase)
			0: sample<=sampley;
			1: sample<=samplex;
			2: sample<=-sampley;
			3: sample<=-samplex;
		endcase
		
		samplesNeeded<=samplesNeeded+1;
	end else begin
		audioTimer<=audioTimer+1;
	end

	if (CounterX>=`DATA_START)
	begin
		if (CounterX<(`DATA_START+`DATA_PREAMBLE))
		begin
			preamble<='b0101;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND))
		begin
			tercData<=1;
			dataGuardBand<=1;
			dataChannel0<={1'b1, 1'b1, vSync, hSync};
			preamble<=0;
			if (audioSamples[4:0]==0) begin
				packetHeader<=24'h000001;	// audio clock regeneration packet (N=0x1000 CTS=0x6270)
				subpacket[0]<=56'h001000c05d0000;	// N=0x1000 CTS=0x5dc0
				subpacket[1]<=56'h001000c05d0000;
				subpacket[2]<=56'h001000c05d0000;
				subpacket[3]<=56'h001000c05d0000;
			end else begin
				if (!CounterY[0]) begin
					packetHeader<=24'h0D0282;	// infoframe AVI packet
					subpacket[0]<=56'h0000010019107b;
					subpacket[1]<=56'h0501000005bf00;
					subpacket[2]<=56'h00000000000000;
					subpacket[3]<=56'h00000000000000;
				end else begin
					packetHeader<=24'h0A0184;	// infoframe audio packet
					subpacket[0]<=56'h0000000000115f;
					subpacket[1]<=56'h00000000000000;
					subpacket[2]<=56'h00000000000000;
					subpacket[3]<=56'h00000000000000;
				end
			end
			
			if (packetHeader2==0 || audioSamples[4:0]!=0) begin
				if (samplesNeeded>0) begin
					if (packetHeader2==0) begin
						packetHeader2<=24'h000102|(channelStatusIdx==0?24'h100000:24'h0);	// audio sample
						/*
						case (audioSamples[7:6])
							0: subpacket2[0]<=56'h00110000110000|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							1: subpacket2[0]<=56'h00100100100100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							2: subpacket2[0]<=56'h00010100010100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							3: subpacket2[0]<=56'h00100100100100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
						endcase
						*/
						subpacket2[0]<=((sample<<8)|(sample<<32)|((^sample)?56'h88000000000000:56'h0))^(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
						subpacket2[1]<=56'h99000000000000;
						subpacket2[2]<=56'h99000000000000;
						subpacket2[3]<=56'h99000000000000;
					end else begin
						packetHeader2<=packetHeader2|24'h000200|(channelStatusIdx==0?24'h200000:24'h0);
						/*case (audioSamples[7:6])
							0: subpacket2[1]<=56'h00110000110000|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							1: subpacket2[1]<=56'h00100100100100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							2: subpacket2[1]<=56'h00010100010100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
							3: subpacket2[1]<=56'h00100100100100|(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
						endcase*/
						subpacket2[1]<=((sample<<8)|(sample<<32)|((^sample)?56'h88000000000000:56'h0))^(CSB[channelStatusIdx]?56'hCC000000000000:56'h0);
					end
					if (channelStatusIdx<191)
						channelStatusIdx<=channelStatusIdx+1;
					else
						channelStatusIdx<=0;
					samplesNeeded<=samplesNeeded-1+((audioTimer==749)?1:0);
					audioSamples<=audioSamples+1;
				end
			end
			
			bchHdr<=0;
			bchCode[0]<=0;
			bchCode[1]<=0;
			bchCode[2]<=0;
			bchCode[3]<=0;
			dataOffset<=0;
			dataOffset2<=0;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE))
		begin
			dataGuardBand<=0;
			dataChannel0<={dataOffset?1'b1:1'b0, ECC(bchHdr, packetHeader[0], dataOffset<24?1'b1:1'b0), vSync, hSync};
			dataChannel1<={
				ECC2a(bchCode[3], subpacket[3][0], subpacket[3][1], (dataOffset<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[2], subpacket[2][0], subpacket[2][1], (dataOffset<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[1], subpacket[1][0], subpacket[1][1], (dataOffset<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[0], subpacket[0][0], subpacket[0][1], (dataOffset<5'd28)?1'b1:1'b0)
				};
			dataChannel2<={
				ECC2b(bchCode[3], subpacket[3][0], subpacket[3][1], ((dataOffset<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[2], subpacket[2][0], subpacket[2][1], ((dataOffset<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[1], subpacket[1][0], subpacket[1][1], ((dataOffset<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[0], subpacket[0][0], subpacket[0][1], ((dataOffset<5'd28)?1'b1:1'b0))
				};
			ECCu(bchHdr, packetHeader[0], dataOffset<24?1'b1:1'b0);
			ECC2u(bchCode[3], subpacket[3][0], subpacket[3][1], dataOffset<28?1'b1:1'b0);
			ECC2u(bchCode[2], subpacket[2][0], subpacket[2][1], dataOffset<28?1'b1:1'b0);
			ECC2u(bchCode[1], subpacket[1][0], subpacket[1][1], dataOffset<28?1'b1:1'b0);
			ECC2u(bchCode[0], subpacket[0][0], subpacket[0][1], dataOffset<28?1'b1:1'b0);
			packetHeader<=packetHeader[23:1];
			subpacket[0]<=subpacket[0][55:2];
			subpacket[1]<=subpacket[1][55:2];
			subpacket[2]<=subpacket[2][55:2];
			subpacket[3]<=subpacket[3][55:2];
			dataOffset<=dataOffset+5'b1;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_SIZE))
		begin
			dataChannel0<={1'b1, ECC(bchHdr, packetHeader2[0], dataOffset2<24?1'b1:1'b0), vSync, hSync};
			dataChannel1<={
				ECC2a(bchCode[3], subpacket2[3][0], subpacket2[3][1], (dataOffset2<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[2], subpacket2[2][0], subpacket2[2][1], (dataOffset2<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[1], subpacket2[1][0], subpacket2[1][1], (dataOffset2<5'd28)?1'b1:1'b0),
				ECC2a(bchCode[0], subpacket2[0][0], subpacket2[0][1], (dataOffset2<5'd28)?1'b1:1'b0)
				};
			dataChannel2<={
				ECC2b(bchCode[3], subpacket2[3][0], subpacket2[3][1], ((dataOffset2<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[2], subpacket2[2][0], subpacket2[2][1], ((dataOffset2<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[1], subpacket2[1][0], subpacket2[1][1], ((dataOffset2<5'd28)?1'b1:1'b0)),
				ECC2b(bchCode[0], subpacket2[0][0], subpacket2[0][1], ((dataOffset2<5'd28)?1'b1:1'b0))
				};
			ECCu(bchHdr, packetHeader2[0], dataOffset2<24?1'b1:1'b0);
			ECC2u(bchCode[3], subpacket2[3][0], subpacket2[3][1], dataOffset2<28?1'b1:1'b0);
			ECC2u(bchCode[2], subpacket2[2][0], subpacket2[2][1], dataOffset2<28?1'b1:1'b0);
			ECC2u(bchCode[1], subpacket2[1][0], subpacket2[1][1], dataOffset2<28?1'b1:1'b0);
			ECC2u(bchCode[0], subpacket2[0][0], subpacket2[0][1], dataOffset2<28?1'b1:1'b0);
			packetHeader2<=packetHeader2[23:1];
			subpacket2[0]<=subpacket2[0][55:2];
			subpacket2[1]<=subpacket2[1][55:2];
			subpacket2[2]<=subpacket2[2][55:2];
			subpacket2[3]<=subpacket2[3][55:2];
			dataOffset2<=dataOffset2+1;
		end
		else if (CounterX<(`DATA_START+`DATA_PREAMBLE+`DATA_GUARDBAND+`DATA_SIZE+`DATA_SIZE+`DATA_GUARDBAND))
		begin
			dataGuardBand<=1;
			dataChannel0<={1'b1, 1'b1, vSync, hSync};	
		end
		else
		begin
			tercData<=0;
			dataGuardBand<=0;
		end
	end
	
	if (CounterX>=(`CTL_END+`VIDEO_PREAMBLE))
	begin
		preamble<=0;
		videoGuardBand<=1;
	end
	else if (CounterX>=(`CTL_END))
	begin
		preamble<='b0001;
	end
	else
	begin
		videoGuardBand<=0;
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
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(preamble[3:2]), .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(preamble[1:0]), .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

wire [9:0] TERC4_red, TERC4_green, TERC4_blue;
TERC4_encoder encode_R4(.clk(pixclk), .data(dataChannel2), .TERC(TERC4_red));
TERC4_encoder encode_G4(.clk(pixclk), .data(dataChannel1), .TERC(TERC4_green));
TERC4_encoder encode_B4(.clk(pixclk), .data(dataChannel0), .TERC(TERC4_blue));

always @(posedge pixclk)
begin
	tercDataDelayed<=tercData;	// To account for delay through encoder
	videoGuardBandDelayed<=videoGuardBand;
	dataGuardBandDelayed<=dataGuardBand;
end

wire [9:0] redSource = videoGuardBandDelayed ? 10'b1011001100 : (dataGuardBandDelayed ? 10'b0100110011 : (tercDataDelayed ? TERC4_red : TMDS_red));
wire [9:0] greenSource = (dataGuardBandDelayed || videoGuardBandDelayed) ? 10'b0100110011 : (tercDataDelayed ? TERC4_green : TMDS_green);
wire [9:0] blueSource = videoGuardBandDelayed ? 10'b1011001100 : (tercDataDelayed ? TERC4_blue : TMDS_blue);

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
	case (data)
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

