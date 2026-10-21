// Copyright 2025 Leo Moser
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


module OBI_SLAVE #(parameter NoConfigBits = 0)(
    // User design
    output        REQ,
    output        WE,
    output [3: 0] BE,
    output [23:0] ADDR,
    output [31:0] WDATA,

    input         GNT,
    input         RVALID,
    input  [31:0] RDATA,

    // Top
    (* FABulous, EXTERNAL *) input        SLAVE_REQ_top,
    (* FABulous, EXTERNAL *) input        SLAVE_WE_top,
    (* FABulous, EXTERNAL *) input [3: 0] SLAVE_BE_top,
    (* FABulous, EXTERNAL *) input [23:0] SLAVE_ADDR_top,
    (* FABulous, EXTERNAL *) input [31:0] SLAVE_WDATA_top,
    
    (* FABulous, EXTERNAL *) output         SLAVE_GNT_top,
    (* FABulous, EXTERNAL *) output         SLAVE_RVALID_top,
    (* FABulous, EXTERNAL *) output  [31:0] SLAVE_RDATA_top

    // (* FABulous, GLOBAL *) input [NoConfigBits-1:0] ConfigBits
);

    assign REQ   = SLAVE_REQ_top;
    assign WE    = SLAVE_WE_top;
    assign BE    = SLAVE_BE_top;
    assign ADDR  = SLAVE_ADDR_top;
    assign WDATA = SLAVE_WDATA_top;

    assign SLAVE_GNT_top      = GNT;
    assign SLAVE_RVALID_top   = RVALID;
    assign SLAVE_RDATA_top    = RDATA;

endmodule
