`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Dust Bunny, a Nexys 3 platformer
// By Laura Lytle & Arturo Verdin
// Based on Demo Code By:  Da Cheng
  //////////////////////////////////////////////////////////////////////////////////
module vga_demo(ClkPort, vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b, Sw0, Sw1, btnU, btnD, btnL, btnR, btnC,
	St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar,
	An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
	LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7);
	input ClkPort, Sw0, btnU, btnD, btnL, btnR, btnC, Sw0, Sw1;
	output St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar;
	output vga_h_sync, vga_v_sync, vga_r, vga_g, vga_b;
	output An0, An1, An2, An3, Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp;
	output LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	reg vga_r, vga_g, vga_b;
	
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/*  LOCAL SIGNALS */
	wire	reset, start, ClkPort, board_clk, clk, button_clk;
	
	BUF BUF1 (board_clk, ClkPort); 	
	BUF BUF2 (reset, Sw0);
	BUF BUF3 (start, Sw1);
	
	reg [27:0]	DIV_CLK;
	always @ (posedge board_clk, posedge reset)  
	begin : CLOCK_DIVIDER
      if (reset)
			DIV_CLK <= 0;
      else
			DIV_CLK <= DIV_CLK + 1'b1;
	end	

	assign	button_clk = DIV_CLK[18];
	assign	clk = DIV_CLK[1];
	
	assign 	{St_ce_bar, St_rp_bar, Mt_ce_bar, Mt_St_oe_bar, Mt_St_we_bar} = {5'b11111};
	
	wire inDisplayArea;
	wire [9:0] CounterX;
	wire [9:0] CounterY;
	
	reg [3:0] pVel; //player velocity: top 2 bits x, bottom 2 bits y
	reg [19:0] pPos; //player position: top 10 bits x, bottom 10 bits y
	reg pDir; //player direction
	reg onGnd,onGnd0,onGnd1,onGnd2,onGnd3,onGnd4,onGnd5;
	reg onVac, onVac1, onVac2,onVac3;
	reg buPrev, fDel, wFlg;
	reg pWrit, R, G, B;
	reg [5:0] xOff, yOff;
	reg [6:0] pNum;
	
	/* used for rendering and enemy movement */
	reg[19:0] vPos; //position of a test vacuum
	reg[19:0] v2Pos;
	reg[19:0] v3Pos;
	reg[6:0] vNum;
	reg[6:0] v2Num;
	reg[6:0] v3Num;
	
	/* used for enemy movement*/
	reg lx;
	reg ly;
	reg l2y;
	
	///////////////IMPORTANT////////////////////
	//Render Order: (i.e. 2 covers 1)
	//	  1. Background (one color as of 4/17)
	//	  2. Land (0 below 1)
	//	  3. Enemies
	//	  4. Player
	////////////////////////////////////////////
		
	//land data structures: bits 0-9:xStart;10-19:xEnd;20-29:yStart;30-39:yEnd;40:isMoving;
	//supports up to 1024x1024, xStart must be >= xEnd
	// yStart must be <= yEnd (rows numbered starting at top)
	//These render in order (ie land 1 will cover land 0)
	
	parameter x_offset = 10'b0000000001;
	parameter y_offset = 10'b0000000001;
	parameter land0 = {10'b0000000000,10'b1111111111,10'b0110000000,10'b1111111111,1'b0};
	parameter land1 = {10'b0101000000,10'b1001100000,10'b0101000000,10'b0101111111,1'b0};
	parameter land2 = {10'b0000111000,10'b0011000000,10'b0100010000,10'b0101111111,1'b0};
	parameter land3 = {10'b0011011000,10'b0101111000,10'b0010011000,10'b0010111000,1'b0};
	parameter land4 = {10'b0111010000,10'b0111100000,10'b0010011000,10'b0010101100,1'b0};
	parameter land5 = {10'b1001000000,10'b1001011000,10'b0000110000,10'b0001001000,1'b0};
	
	
	//8x8 sprites are below in 2-bit color (black, white,
	//red & transparent. Try to make backgrounds other colors.
	//If (bit0 ~& bit1), color the pixel. Black by default.
	//00=black; 01=white; 10=red; 11=transparent;
	parameter pGnd	= {
	2'b11,2'b11,2'b11,2'b01,2'b11,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b11,2'b01,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b01,2'b01,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b11,2'b01,2'b01,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b11,2'b01,2'b00,2'b11,
	2'b11,2'b01,2'b01,2'b01,2'b01,2'b01,2'b01,2'b01,
	2'b01,2'b00,2'b00,2'b00,2'b01,2'b01,2'b01,2'b11,
	2'b11,2'b01,2'b00,2'b00,2'b00,2'b01,2'b11,2'b11};
	
	parameter pJmp = {
	2'b11,2'b11,2'b01,2'b01,2'b01,2'b01,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b11,2'b11,2'b01,2'b00,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b11,2'b01,2'b01,2'b01,
	2'b11,2'b01,2'b01,2'b01,2'b01,2'b01,2'b01,2'b11,
	2'b01,2'b01,2'b01,2'b00,2'b01,2'b01,2'b01,2'b11,
	2'b11,2'b01,2'b00,2'b00,2'b01,2'b01,2'b11,2'b11,
	2'b11,2'b11,2'b00,2'b00,2'b01,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b00,2'b11,2'b11,2'b11,2'b11,2'b11};
	
	
	reg[127:0] vac = {
	2'b11,2'b10,2'b10,2'b10,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b11,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b00,2'b00,
	2'b11,2'b11,2'b11,2'b11,2'b11,2'b00,2'b00,2'b00};
	
	reg[127:0] vac2 = {
	2'b11,2'b10,2'b10,2'b10,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b11,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b00,2'b00,
	2'b11,2'b11,2'b11,2'b11,2'b11,2'b00,2'b00,2'b00};
	
	reg[127:0] vac3 = {
	2'b11,2'b10,2'b10,2'b10,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b11,2'b11,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b11,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b11,2'b11,
	2'b11,2'b11,2'b01,2'b01,2'b00,2'b00,2'b00,2'b00,
	2'b11,2'b11,2'b11,2'b11,2'b11,2'b00,2'b00,2'b00}; 

	hvsync_generator syncgen(.clk(clk), .reset(reset),.vga_h_sync(vga_h_sync), .vga_v_sync(vga_v_sync), .inDisplayArea(inDisplayArea), .CounterX(CounterX), .CounterY(CounterY));
	
	/////////////////////////////////////////////////////////////////
	///////////////		VGA control starts here		/////////////////
	/////////////////////////////////////////////////////////////////
	reg [9:0] position;
	
	/////////////////////////////////////////////////////////////////
	///////////////		Enemy movement starts here	    /////////////
	/////////////////////////////////////////////////////////////////
	
	
	/* moves the first vacuum up and down the screen */
	always @(posedge DIV_CLK[19])
		begin
			if(reset) 
				begin	
				vPos <= {10'b0011101100, 10'b0011111000};
				ly <= 1'b1; //going to move up
				end
			else 
				begin 
				if(ly == 1'b1) //moving up
					begin
					vPos[9:0] <= vPos[9:0] - y_offset;
					
					if(vPos[9:0] <= 10'b0010100000 + 6'b110000)
						ly <= 1'b0; //then move down
					end
				else
					begin
					vPos[9:0] <= vPos[9:0] + y_offset;
					
					if(vPos[9:0] >= 10'b0110000000 - 6'b111110)
						ly <= 1'b1; //move up
					end
				end
		end
		
	/* moves second vacuum left and right */	
	always @(posedge DIV_CLK[19])
		begin
			if(reset) 
				begin	
				v2Pos <= {10'b0011111000, 10'b0001111000};
				lx <= 1'b1; //going to move right
				end
			else 
				begin 
				if(lx == 1'b1) //moving right
					begin
					v2Pos[19:10] <= v2Pos[19:10] + x_offset;
					
					if(v2Pos[19:10] >= 10'b0101111000-16)
						lx <= 1'b0; //then move left
					end
				else
					begin
					v2Pos[19:10] <= v2Pos[19:10] - x_offset;
					
					if(v2Pos[19:10] <= 10'b0011011000-16)
						lx <= 1'b1; //move right
					end
				end
		end
		
	/* moves the third vacuum up and down the screen */
	always @(posedge DIV_CLK[19])
		begin
			if(reset) 
				begin	
				v3Pos <= {10'b1000000000, 10'b0001001000};
				l2y <= 1'b1; //going to move up
				end
			else 
				begin 
				if(l2y == 1'b1) //moving up
					begin
					v3Pos[9:0] <= v3Pos[9:0] - y_offset;
					
					if(v3Pos[9:0] <= 10'b0000011000)
						l2y <= 1'b0; //then move down
					end
				else
					begin
					v3Pos[9:0] <= v3Pos[9:0] + y_offset;
					
					if(v3Pos[9:0] >= 10'b0010000000)
						l2y <= 1'b1; //move up
					end
				end
		end
		
	/////////////////////////////////////////////////////////////////
	///////////////		Enemy movement ends here	    /////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	///////////////		Player movement starts here	    /////////////
	/////////////////////////////////////////////////////////////////
	
	/* controls the player movement */
	always @(posedge DIV_CLK[21])
		begin
			if(reset)begin
				pDir = 0;
				pVel = 0;
				buPrev = 0;
				pPos = {10'b0000001100, 10'b0000001100};
				fDel = DIV_CLK[25];
				wFlg = 0;
				end  
			else begin
				if(onGnd5)
					wFlg = 1;
				
				//vertical motion (3 bits), jumps take 3 ticks, 
				if (pVel[1:0] && ~(DIV_CLK[25] == fDel)) begin
					pVel = pVel - 1;
					fDel = DIV_CLK[25];
				end
				else if(btnU && ~buPrev && onGnd)begin
					pVel = pVel | 4'b0011; 
					buPrev = 1;
					end
				else if (~btnU)
					buPrev = 0;
			
				//horizontal motion, left/right occur 
				if (btnL) begin
					pVel = 4'b1011 & pVel;
					pVel = 4'b1000 | pVel;
					end
				else if (btnR) begin
					pVel = 4'b0111 & pVel;
					pVel = 4'b0100 | pVel;
					end
				else
					pVel = 4'b00011 & pVel;
				
				//TODO: Need to reduce the position update rate
				
				if(pVel) begin //non-zero velocity
					if (pVel[3]) begin //move left
						if (pPos[19:10] > 4'b1010)
							pPos = {pPos[19:10]- 4'b1010, pPos[9:0]};
						else
							pPos = pPos & 20'b00000000001111111111;
					end
					else if (pVel[2]) begin //move right
						if (pPos[19:10] < 10'b1001100000)
							pPos = {pPos[19:10] + 4'b1010, pPos[9:0]};
						else
							pPos = {10'b1001100000, pPos[9:0]};
					end
					
					if ((pVel[1:0] == 2'b01) && ~onGnd) begin //slow fall
						if (pPos[9:0] < 443)
							//pPos = pPos;
							pPos = {pPos[19:10], pPos[9:0] + 4'b0101};
						else
							pPos = pPos | 20'b00000000001111111111;
					end
					else if (pVel[1]) begin
						if (pVel[0]) begin //fast rise (start of jump)
							if(pPos[9:0] > 10)
								//pPos = pPos;
								pPos = {pPos[19:10], pPos[9:0] - 4'b1010};
							else
								pPos = pPos & 20'b11111111110000000000;
						end	
						else begin//slow rise (top of jump)
							if(pPos[9:0] > 5)
								//pPos = pPos;
								pPos = {pPos[19:10], pPos[9:0] - 4'b0101};
							else
								pPos = pPos & 20'b11111111110000000000;
						end
					end
					
				end
				if ((pVel[1:0] == 2'b00) && ~onGnd) begin //fast fall
					if (pPos[9:0] < 438)
						//pPos = pPos;
						pPos = {pPos[19:10], pPos[9:0] + 4'b1010};
					else
						pPos = pPos | 20'b00000000001111111111;
				end
				
				if(onVac) begin
					pPos = {10'b0000001100, 10'b0101001100};
					wFlg = 0;
				end
					
			end
		end
	/////////////////////////////////////////////////////////////////
	///////////////		Player movement ends here	    /////////////
	/////////////////////////////////////////////////////////////////	
		
	/////////////////////////////////////////////////////////////////
	///////////////	 Collision detection starts here	    /////////
	/////////////////////////////////////////////////////////////////	
		
	
	always @ (posedge clk) begin
		//checks if the player is on or just above each land
		onGnd0 <= (((pPos[19:10]+32) > land0[40:31]) && (pPos[19:10] < land0[30:21]) && (pPos[9:0] > (land0[20:11]-32)) && (pPos[9:0] < (land0[20:11]-18)));
		onGnd1 <= (((pPos[19:10]+32) > land1[40:31]) && (pPos[19:10] < land1[30:21]) && (pPos[9:0] > (land1[20:11]-32)) && (pPos[9:0] < (land1[20:11]-18)));
		onGnd2 <= (((pPos[19:10]+32) > land2[40:31]) && (pPos[19:10] < land2[30:21]) && (pPos[9:0] > (land2[20:11]-32)) && (pPos[9:0] < (land2[20:11]-18)));
		onGnd3 <= (((pPos[19:10]+32) > land3[40:31]) && (pPos[19:10] < land3[30:21]) && (pPos[9:0] > (land3[20:11]-32)) && (pPos[9:0] < (land3[20:11]-18)));
		onGnd4 <= (((pPos[19:10]+32) > land4[40:31]) && (pPos[19:10] < land4[30:21]) && (pPos[9:0] > (land4[20:11]-32)) && (pPos[9:0] < (land4[20:11]-18)));
		onGnd5 <= (((pPos[19:10]+32) > land5[40:31]) && (pPos[19:10] < land5[30:21]) && (pPos[9:0] > (land5[20:11]-32)) && (pPos[9:0] < (land5[20:11]-18)));
	
		//checks if player is on any land
		onGnd = onGnd0 || onGnd1 || onGnd2 || onGnd3 || onGnd4 || onGnd5;
	end
	
	always @(posedge clk) begin
		onVac1 <= ((pPos[19:10]+28 >= vPos[19:10]) && (pPos[19:10]+28 <= vPos[19:10] + 64) && (pPos[9:0]+32 >= vPos[9:0]) && (pPos[9:0]+32 <= vPos[9:0]+64));
		onVac2 <= ((pPos[19:10]+28 >= v2Pos[19:10]) && (pPos[19:10]+28 <= v2Pos[19:10] + 64) && (pPos[9:0]+32 >= v2Pos[9:0]) && (pPos[9:0]+32 <= v2Pos[9:0]+64));
		onVac3 <= ((pPos[19:10]+28 >= v3Pos[19:10]) && (pPos[19:10]+28 <= v3Pos[19:10] + 64) && (pPos[9:0]+32 >= v3Pos[9:0]) && (pPos[9:0]+32 <= v3Pos[9:0]+64));
		
		//checks if the player is touching any vacuum
		onVac = onVac1 || onVac2 || onVac3;
	end
	
	/////////////////////////////////////////////////////////////////
	///////////////	 Collision detection ends here	    /////////////
	/////////////////////////////////////////////////////////////////	
	
	/////////////////////////////////////////////////////////////////
	///////////////	 Image rendering starts here	    /////////////
	/////////////////////////////////////////////////////////////////
	
	always @ (posedge clk) begin
		pWrit = 0;
		R = 0;
		G = 0;
		B = 0;
		if((CounterX >= pPos[19:10]) && (CounterX < (pPos[19:10] + 32)) && (CounterY >= pPos[9:0]) && (CounterY < (pPos[9:0] + 32))) begin // if rendering character area
			xOff = CounterX - pPos[19:10];
			yOff = CounterY - pPos[9:0];
			pNum = 126 - (2*((8 * (yOff/4)) + (xOff/4)));
			if (onGnd) begin //pGnd sprite if on land				
				if (~(pGnd[pNum] && pGnd[pNum + 1])) begin //write pixel if character pixel isn't transparent
					pWrit = 1;
					if(pGnd[pNum]) begin
						R = 1;
						G = 1;
						
						if (~wFlg)
							B = 1;
					end
					else if (pGnd[pNum + 1]) begin
						R = 1;
					end
				end	
			end
			else begin //pJmp sprite if not on land
				if (~(pJmp[pNum] && pJmp[pNum + 1])) begin //write pixel if character pixel isn't transparent
					pWrit = 1;
					if(pJmp[pNum]) begin
						R = 1;
						G = 1;
						if (~wFlg)
							B = 1;
					end
					else if (pJmp[pNum + 1]) begin
						R = 1;
					end
				end
			end 
		end
		
		//renders the first vacuum 
		if((CounterX >= vPos[19:10]) && (CounterX < (vPos[19:10] + 32)) && (CounterY >= vPos[9:0]) && (CounterY < (vPos[9:0] + 32))) begin // if rendering character area
			xOff = CounterX - vPos[19:10];
			yOff = CounterY - vPos[9:0];
			vNum = 126 - (2*((8 * (yOff/4)) + (xOff/4)));
							
			if (~(vac[vNum] && vac[vNum + 1])) begin //write pixel if character pixel isn't transparent
				pWrit = 1;
				if(vac[vNum]) begin
					R = 1;
					G = 1;
					B = 1;
				end
				else if (vac[vNum + 1]) begin
					R = 1;
				end
			end	
		end
		
		//renders the second vacuum 
		if((CounterX >= v2Pos[19:10]) && (CounterX < (v2Pos[19:10] + 32)) && (CounterY >= v2Pos[9:0]) && (CounterY < (v2Pos[9:0] + 32))) begin // if rendering character area
			xOff = CounterX - v2Pos[19:10];
			yOff = CounterY - v2Pos[9:0];
			v2Num = 126 - (2*((8 * (yOff/4)) + (xOff/4)));
							
			if (~(vac2[v2Num] && vac2[v2Num + 1])) begin //write pixel if character pixel isn't transparent
				pWrit = 1;
				if(vac2[v2Num]) begin
					R = 1;
					G = 1;
					B = 1;
				end
				else if (vac2[v2Num + 1]) begin
					R = 1;
				end
			end	
		end
		
		//renders the third vacuum 
		if((CounterX >= v3Pos[19:10]) && (CounterX < (v3Pos[19:10] + 32)) && (CounterY >= v3Pos[9:0]) && (CounterY < (v3Pos[9:0] + 32))) begin // if rendering character area
			xOff = CounterX - v3Pos[19:10];
			yOff = CounterY - v3Pos[9:0];
			v3Num = 126 - (2*((8 * (yOff/4)) + (xOff/4)));
							
			if (~(vac3[v3Num] && vac3[v3Num + 1])) begin //write pixel if character pixel isn't transparent
				pWrit = 1;
				if(vac3[v3Num]) begin
					R = 1;
					G = 1;
					B = 1;
				end
				else if (vac3[v3Num + 1]) begin
					R = 1;
				end
			end	
		end
		
		if(~pWrit && (CounterX >= land0[40:31]) && (CounterX <= land0[30:21]) && (CounterY >= land0[20:11]) && (CounterY <= land0[10:1])) begin //if rendering land 0
			if (CounterY < (land0[20:11] + 15)) begin //15 px of green grass on top of land
				G = 1;
			end
			else begin//checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end 
		end
		if(~pWrit && (CounterX >= land1[40:31]) && (CounterX <= land1[30:21]) && (CounterY >= land1[20:11]) && (CounterY <= land1[10:1])) begin //if rendering land 1
			if (CounterY < (land1[20:11] + 15)) begin //15 px of green grass on top of land
				R = 0;
				G = 1;
				B = 0;
			end
			else begin //checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end
		end
		if(~pWrit && (CounterX >= land2[40:31]) && (CounterX <= land2[30:21]) && (CounterY >= land2[20:11]) && (CounterY <= land2[10:1])) begin //if rendering land 2
			if (CounterY < (land2[20:11] + 15)) begin //15 px of green grass on top of land
				R = 0;
				G = 1;
				B = 0;
			end
			else begin //checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end
		end
		if(~pWrit && (CounterX >= land3[40:31]) && (CounterX <= land3[30:21]) && (CounterY >= land3[20:11]) && (CounterY <= land3[10:1])) begin //if rendering land 3
			if (CounterY < (land3[20:11] + 15)) begin //15 px of green grass on top of land
				R = 0;
				G = 1;
				B = 0;
			end
			else begin //checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end
		end
		if(~pWrit && (CounterX >= land4[40:31]) && (CounterX <= land4[30:21]) && (CounterY >= land4[20:11]) && (CounterY <= land4[10:1])) begin //if rendering land 4
			if (CounterY < (land4[20:11] + 15)) begin //15 px of green grass on top of land
				R = 0;
				G = 1;
				B = 0;
			end
			else begin//checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end
		end
		if(~pWrit && (CounterX >= land5[40:31]) && (CounterX <= land5[30:21]) && (CounterY >= land5[20:11]) && (CounterY <= land5[10:1])) begin //if rendering land 5
			if (CounterY < (land5[20:11] + 15)) begin //15 px of green grass on top of land
				R = 1;
				G = 1;
				B = 0;
			end
			else begin //checkered magenta & yellow dirt after top 15px
				if(CounterX[0] ^ CounterY[0]) begin //magenta
					R = 1;
					G = 0;
					B = 1;
				end
				else begin //yellow
					R = 1;
					G = 1;
					B = 0;
				end
			end
		end
		if(~pWrit && ~R && ~G && ~B) begin //if rendering background (i.e. nothing else)
			R = 0;
			G = 1;
			B = 1;
		end
	end
	
	/////////////////////////////////////////////////////////////////
	///////////////	 Image rendering ends here	    ////////////////
	/////////////////////////////////////////////////////////////////
	
	always @(posedge clk)
	begin
		vga_r <= R & inDisplayArea;
		vga_g <= G & inDisplayArea;
		vga_b <= B & inDisplayArea;
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  VGA control ends here 	 ////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control starts here 	 ////////////////
	/////////////////////////////////////////////////////////////////
	`define QI 			2'b00
	`define QGAME_1 	2'b01
	`define QGAME_2 	2'b11
	`define QDONE 		2'b11
	
	reg [3:0] p2_score;
	reg [3:0] p1_score;
	//reg [1:0] state;
	wire LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7;
	
	assign LD0 = (p1_score == 4'b1010);
	assign LD1 = (p2_score == 4'b1010);
	
	assign LD2 = start;
	assign LD4 = reset;
	
	//assign LD3 = (state == `QI);
	//assign LD5 = (state == `QGAME_1);	
	//assign LD6 = (state == `QGAME_2);
	//assign LD7 = (state == `QDONE);
	assign LD3 = 0;
	assign LD5 = 0;
	assign LD6 = 0;
	assign LD7 = 0;
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  LD control ends here 	 	/////////////////
	/////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control starts here 	 ////////////////
	/////////////////////////////////////////////////////////////////
	reg 	[3:0]	SSD;
	wire 	[3:0]	SSD0, SSD1, SSD2, SSD3;
	wire 	[1:0] ssdscan_clk;
	
	assign SSD3 = 4'b1111;
	assign SSD2 = 4'b1111;
	assign SSD1 = 4'b1111;
	assign SSD0 = position[3:0];
	
	// need a scan clk for the seven segment display 
	// 191Hz (50MHz / 2^18) works well
	assign ssdscan_clk = DIV_CLK[19:18];	
	assign An0	= !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 00
	assign An1	= !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 01
	assign An2	= !( (ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 10
	assign An3	= !( (ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 11
	
	always @ (ssdscan_clk, SSD0, SSD1, SSD2, SSD3)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk) 
			2'b00:
					SSD = SSD0;
			2'b01:
					SSD = SSD1;
			2'b11:
					SSD = SSD2;
			2'b11:
					SSD = SSD3;
		endcase 
	end	

	// and finally convert SSD_num to ssd
	reg [6:0]  SSD_CATHODES;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES, 1'b1};
	// Following is Hex-to-SSD conversion
	always @ (SSD) 
	begin : HEX_TO_SSD
		case (SSD)		
			4'b1111: SSD_CATHODES = 7'b1111111 ; //Nothing 
			4'b0000: SSD_CATHODES = 7'b0000001 ; //0
			4'b0001: SSD_CATHODES = 7'b1001111 ; //1
			4'b0010: SSD_CATHODES = 7'b0010010 ; //2
			4'b0011: SSD_CATHODES = 7'b0000110 ; //3
			4'b0100: SSD_CATHODES = 7'b1001100 ; //4
			4'b0101: SSD_CATHODES = 7'b0100100 ; //5
			4'b0110: SSD_CATHODES = 7'b0100000 ; //6
			4'b0111: SSD_CATHODES = 7'b0001111 ; //7
			4'b1000: SSD_CATHODES = 7'b0000000 ; //8
			4'b1001: SSD_CATHODES = 7'b0000100 ; //9
			4'b1010: SSD_CATHODES = 7'b0001000 ; //10 or A
			default: SSD_CATHODES = 7'bXXXXXXX ; // default is not needed as we covered all cases
		endcase
	end
	
	/////////////////////////////////////////////////////////////////
	//////////////  	  SSD control ends here 	 ///////////////////
	/////////////////////////////////////////////////////////////////
endmodule




