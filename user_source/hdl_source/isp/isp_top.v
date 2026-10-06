module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    input 			I_edge_key		,	// KEY1: 边缘检测切换按键(低有效, 直连板级I_button[1])
    output [127:0] 	O_tdata			,
    output [19:0]   O_candidate_count,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready
);

wire         m_aixs_tvalid;  //synthesis keep
  wire [127:0] m_aixs_tdata;  //synthesis keep
  wire         m_aixs_tuser;  //synthesis keep
  wire         m_aixs_tlast;  //synthesis keep
  wire         m_aixs_tready;  //synthesis keep

  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep


  wire         awb_O_tlast;  //synthesis keep
  wire         awb_O_tuser;  //synthesis keep
  wire [ 95:0] awb_O_tdata;  //synthesis keep
  wire         awb_O_tvalid;  //synthesis keep
  wire         awb_O_tready;  //synthesis keep

  wire         edge_O_tlast;  //synthesis keep
  wire         edge_O_tuser;  //synthesis keep
  wire [ 95:0] edge_O_tdata;  //synthesis keep
  wire         edge_O_tvalid;  //synthesis keep
  wire         edge_O_tready;  //synthesis keep

  wire         mask_O_tlast;
  wire         mask_O_tuser;
  wire [95:0]   mask_O_tdata;
  wire         mask_O_tvalid;
  wire [3:0]    mask_candidate;

  wire         awb_O_tuser_128;  //synthesis keep
  wire         awb_O_tvalid_128;  //synthesis keep
  wire [127:0] awb_O_tdata_128;  //synthesis keep

  // KEY1 cycles continuously running views: raw -> edge -> color mask -> raw.
  wire S_edge_key_trig;
  reg [1:0] view_mode;  // 0 raw, 1 edge, 2 color mask
  key_remove_shakes u_edge_key_shakes(
      .I_clk          (axi4s_video_aclk),
      .I_rst_n        (I_rst_n),
      .I_key_in       (~I_edge_key),
      .O_key_trig_out (S_edge_key_trig)
  );
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if(!I_rst_n) view_mode <= 2'd0;
      else if(S_edge_key_trig) begin
          if(view_mode == 2'd2) view_mode <= 2'd0;
          else view_mode <= view_mode + 2'd1;
      end
  end

  wire         view_tuser;
  wire         view_tvalid;
  wire [95:0]  view_tdata;
  assign view_tuser  = (view_mode == 2'd1) ? edge_O_tuser  :
                       (view_mode == 2'd2) ? mask_O_tuser  : awb_O_tuser;
  assign view_tvalid = (view_mode == 2'd1) ? edge_O_tvalid :
                       (view_mode == 2'd2) ? mask_O_tvalid : awb_O_tvalid;
  assign view_tdata  = (view_mode == 2'd1) ? edge_O_tdata  :
                       (view_mode == 2'd2) ? mask_O_tdata  : awb_O_tdata;
  assign awb_O_tready = edge_O_tready;
  assign edge_O_tready = O_tready;

 
    assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = awb_O_tlast;
  assign O_tuser  = awb_O_tuser_128;
  assign O_tvalid = awb_O_tvalid_128;

  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;


demosaic #(
    .IMG_HEIGHT          (720 ), // 图像高度
    .IMG_WIDTH           (1280), // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);

data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(720 ),
    .IMG_WIDTH (1280)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

// ---- Red/orange candidate mask and full-frame candidate-pixel counter ----
color_mask_96 #(
    .RED_MIN       (8'd96),
    .GREEN_MIN     (8'd24),
    .RED_GREEN_GAP (8'd18),
    .RED_BLUE_GAP  (8'd10),
    .LUMA_SUM_MIN  (10'd210)
) u_color_mask_96 (
    .I_clk          (axi4s_video_aclk),
    .I_rst_n        (I_rst_n),
    .I_tlast        (awb_O_tlast),
    .I_tuser        (awb_O_tuser),
    .I_tdata        (awb_O_tdata),
    .I_tvalid       (awb_O_tvalid),
    .O_tlast        (mask_O_tlast),
    .O_tuser        (mask_O_tuser),
    .O_tdata        (mask_O_tdata),
    .O_tvalid       (mask_O_tvalid),
    .O_frame_count  (O_candidate_count),
    .O_candidate    (mask_candidate)
);
// ---- 边缘检测 (lab_ex2功能, 与原图通路并行运行) ----
edge_detect_96 #(
    .IMG_WIDTH (1280),
    .IMG_HEIGHT(720),
    .EDGE_TH   (11'd80)
) u_edge_detect_96 (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (awb_O_tlast),
    .I_tuser (awb_O_tuser),
    .I_tdata (awb_O_tdata),
    .I_tvalid(awb_O_tvalid),
    .I_tready(awb_O_tready),
    .O_tlast (edge_O_tlast),
    .O_tuser (edge_O_tuser),
    .O_tdata (edge_O_tdata),
    .O_tvalid(edge_O_tvalid),
    .O_tready(edge_O_tready)
);

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),

        .I_96b_frame_start  ( view_tuser	    ),
        .I_96b_valid        ( view_tvalid 		),
        .I_96b_data         ( view_tdata		),

        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);

endmodule