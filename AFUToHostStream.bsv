package AFUToHostStream;

import Assert::*;
import PAClib::*;
import PSLTypes::*;
import Connectable::*;

import CmdBuf::*;
import WriteBuf::*;

import Cntrs::*;

import CAPIStream::*;



/** Module to sink a stream to host memory, using multiple parallel in-flight tags and a ring buffer.
 * 
 * Issues commands when able on the supplied CmdBufClientPort.
 *
 *
 * The user starts the transfer by providing an address and a size, then is able to push (size) bytes to the host in 1024b chunks.
 *
 * Currently requires cache-aligned ea and size. 
 *
 * TODO: Deal correctly with PAGED response?
 * TODO: Graceful reset logic
 */

module mkAFUToHostStream#(CmdBufClientPort#(2) cmdbuf,PipeOut#(Bit#(1024)) pi)(StreamControl)
    provisos (
        NumAlias#(nt,4));
    
    // Stream counter
    let { eaCounterControl, nextAddress } <- mkStreamCounter;

    // 16-element write buffer with latency 2
    WriteBuf#(2) wbuf <- mkAFUWriteBuf(16);

    mkConnection(cmdbuf.buffer.writedata,wbuf.pslin);

    Cntrs::Count#(UInt#(8)) outstanding <- mkCount(0);

    Wire#(Tuple2#(UInt#(64),UInt#(64))) wStart <- mkWire;

    (* preempts = "doStart, doWriteCommand" *)

    rule doStart if (wStart matches { .ea0, .size });
        eaCounterControl.start(ea0,size);
        outstanding <= 0;
    endrule


    rule doWriteCommand;
        // get next address
        let ea <- nextAddress.get;              // implicit condition: not at end address

        // checkout tag and send command
        let cmd = CmdWithoutTag {
            com: Write_mi,
            cabt: Abort,
            cea: EAddress64 { addr: ea },
            csize: fromInteger(stepBytes) };
        let tag <- cmdbuf.putcmd(cmd);          // implicit condition: able to put a command

        // write data to buffer in tag slot
        wbuf.write(tag,pi.first);
        pi.deq;                                 // implicit condition: input value in the pipe

        // bump write pointer
        outstanding.incr(1);
    endrule

    rule handleResponse;
        let resp <- cmdbuf.response.get;

        case (resp.response) matches
            Done:
                $display($time," Write completion for tag %X",resp.rtag);
   	        Paged:
                $display($time," WARNING: PAGED response ignored for tag %X",resp.rtag);
           
            default:
                action
                    $display($time,"ERROR: Invalid command code received ",fshow(resp));
                    dynamicAssert(False,"Invalid command code received");
                endaction
        endcase

        outstanding.decr(1);
    endrule

    method Action start(UInt#(64) ea0,UInt#(64) size) if (eaCounterControl.done) = wStart._write(tuple2(ea0,size));

    method Bool done = eaCounterControl.done && outstanding == 0;
endmodule

export CAPIStream::*, mkAFUToHostStream;

endpackage
