
 #include "Rf1a.h"
 #include "CXFlood.h"
 #include "FDebug.h"
 #include "SFDebug.h"
 #include "SchedulerDebug.h"
 #include "BreakfastDebug.h"
module CXFloodP{
  provides interface Send[uint8_t t];
  provides interface Receive[uint8_t t];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  //Payload: body of CXPacket (a.k.a. header of AM packet)
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface CXTransportSchedule[uint8_t tProto];
  uses interface TaskResource;
  
  uses interface CXRoutingTable;

} implementation {

  enum{
    ERROR_MASK = 0x80,
    S_ERROR_1 = 0x81,
    S_ERROR_2 = 0x82,
    S_ERROR_3 = 0x83,
    S_ERROR_4 = 0x84,
    S_ERROR_5 = 0x85,
    S_ERROR_6 = 0x86,
    S_ERROR_7 = 0x87,
    S_ERROR_8 = 0x88,
    S_ERROR_9 = 0x89,
    S_ERROR_a = 0x8a,
    S_ERROR_b = 0x8b,
    S_ERROR_c = 0x8c,
    S_ERROR_d = 0x8d,
    S_ERROR_e = 0x8e,
    S_ERROR_f = 0x8f,

    S_IDLE = 0x00,
    S_FWD  = 0x01,
  };

  //provided by Send
  message_t* tx_msg;

  bool txPending;
  bool txSent;
  uint16_t txLeft;
  uint16_t clearLeft;

  am_addr_t lastSrc = 0xff;
  uint32_t lastSn;
  uint8_t lastDepth;
  
  uint8_t state;

  //for debugging completion reporting
  uint16_t ccfn;
  uint8_t cccaller;

  message_t fwd_msg_internal;
  message_t* fwd_msg = &fwd_msg_internal;
  
  bool rxOutstanding;

  bool isOrigin;

  void checkAndCleanup();

  void setState(uint8_t s){
    printf_F_STATE("(%x->%x)\r\n", state, s);
    state = s;
  }

  task void txSuccessTask(){
    txPending = FALSE;
    txSent = FALSE;
    signal Send.sendDone[call CXPacket.getTransportProtocol(tx_msg)](tx_msg, SUCCESS);
  }

  task void txFailTask(){
    txPending = FALSE;
    txSent = FALSE;
    signal Send.sendDone[call CXPacket.getTransportProtocol(tx_msg)](tx_msg, FAIL);
  }

  /**
   * Accept a packet if we're not busy and hold it until the origin
   * frame comes around.
   **/
  command error_t Send.send[uint8_t t](message_t* msg, uint8_t len){
//    printf_TMP("floodsend.send %x\r\n", t);
    if (!txPending){
      uint16_t clearTime = 0xff;
      if ((call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED)){
        clearTime = call CXRoutingTable.distance(TOS_NODE_ID, 
          call CXPacket.destination(msg));
      }
      clearTime = clearTime == 0xff ? call
        TDMARoutingSchedule.maxDepth(): clearTime;
      // have to add 1 here: if we're in the last frame now and the
      // clear time is 1, then we don't have time to send it.
      if (call TDMARoutingSchedule.framesLeftInSlot(call TDMARoutingSchedule.currentFrame()) < clearTime+1){
//          printf_TMP("RETRY\r\n");
        return ERETRY;
      }else{
//          printf_TMP("clear time OK: %u\r\n", clearTime);
        tx_msg = msg;
        txPending = TRUE;
        call CXPacket.init(msg);
        call CXPacket.setType(msg, CX_TYPE_DATA);
//        call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
        //preserve pre-routed flag
        call CXPacket.setNetworkProtocol(msg, 
          (call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED) | CX_NP_FLOOD);
        printf_F_SCHED("fs.s %p %u\r\n", msg, call CXPacket.count(msg));
        return SUCCESS;
      }
    }else{
      return EBUSY;
    }
  }
  
  //TODO: yeah, we're going to have to implement this. should be just
  //clear txPending flag and go to IDLE?
  command error_t Send.cancel[uint8_t t](message_t* msg){
    return FAIL;
  }

  /**
   * Indicate to the TDMA layer what activity we'll be doing during
   * this frame. 
   * - if we're going to initiate a flood, then claim the CX resource
   *   and indicate TX
   * - if we're holding a packet that needs forwarding, indicate TX
   *   (resource should be held already)
   * - otherwise: RX (maybe we'll be in a flood soon)
   */
  event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    printf_F_SCHED("f.ft %u", frameNum);

    if (!txSent && txPending && (call CXTransportSchedule.isOrigin[call CXPacket.getTransportProtocol(tx_msg)](frameNum))){
      error_t error = call TaskResource.immediateRequest(); 
      printf_F_SCHED("o");
      if (SUCCESS == error){
        uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
        uint16_t framesLeft = call TDMARoutingSchedule.framesLeftInSlot(frameNum);
        printf_F_SCHED(" tx\r\n");
        txLeft = (mr < framesLeft)? mr : framesLeft;
        if (call CXPacketMetadata.getRequiresClear(tx_msg)){
          clearLeft = 0xffff;
          //pre-routed: clear when destination reached, if distance
          //known. otherwise, max-depth + 1 (since some nodes at
          //maxDepth will rebroadcast)
          if (call CXPacket.getNetworkProtocol(tx_msg) & CX_NP_PREROUTED){
            clearLeft = call CXRoutingTable.distance(TOS_NODE_ID, 
              call CXPacket.destination(tx_msg));
          }
          if (call TDMARoutingSchedule.maxDepth() < clearLeft){
            clearLeft = call TDMARoutingSchedule.maxDepth() + 1;
          }
        }else{
          clearLeft = 0;
        }
        lastSn = call CXPacket.sn(tx_msg);
        lastSrc = TOS_NODE_ID;
        txSent = TRUE;
        isOrigin = TRUE;
        setState(S_FWD);
        return RF1A_OM_FSTXON;
      } else {
        //if we don't signal sendDone here, the upper layer will never
        //  know what happened.
        post txFailTask();
        printf("!F.ft.RIR %s io %x\r\n", decodeError(error), 
          call TaskResource.isOwner());
        return RF1A_OM_RX;
      }
    }else{
      printf_F_SCHED("n");
    }

    if (txLeft){
      printf_F_SCHED("f\r\n");
      return RF1A_OM_FSTXON;
    } else {
      //finished transmitting, but waiting for it to finish clearing.
      if (clearLeft > 0){
        clearLeft --;
        ccfn = frameNum;
        cccaller = 0;
        checkAndCleanup();
      }
      printf_F_SCHED("r\r\n");
      return RF1A_OM_RX;
    }
  }
 
  //Provide packet for transmission to TDMA/phy layers.
  event bool CXTDMA.getPacket(message_t** msg, 
      uint16_t frameNum){ 
    *msg = isOrigin? tx_msg : fwd_msg;
    return TRUE;
  }

  void doReceive(){
    //do not report self-receptions
    if (call CXPacket.source(fwd_msg) != TOS_NODE_ID){
      uint8_t pll = call LayerPacket.payloadLength(fwd_msg);
      void* pl = call LayerPacket.getPayload(fwd_msg, pll);
      uint8_t tProto = call CXPacket.getTransportProtocol(fwd_msg);
      fwd_msg = signal Receive.receive[tProto](fwd_msg, pl, pll);
    }
    rxOutstanding = FALSE;
  }
  
  task void reportReceive(){
    doReceive();
  }

  //deal with the aftermath of a packet transmission.
  void checkAndCleanup(){
    if (clearLeft + txLeft == 0){
//      printf_TMP("CC.%u@%u", cccaller, ccfn);
      setState(S_IDLE);
      isOrigin = FALSE;
      call TaskResource.release();
      if (txSent){
//        printf_TMP("t\r\n");
        post txSuccessTask();
      } else {
//        printf_TMP("r\r\n");
        post reportReceive();
      }
    }
  }

  //decrement remaining transmissions on this packet and potentially
  //move into cleanup steps
  event error_t CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    if (error != SUCCESS){
      printf("CXFloodP sd!\r\n");
      setState(S_ERROR_1);
    }
    if (txLeft > 0){
      txLeft --;
    }else{
      printf("CXFloodP sent extra?\r\n");
    }
    //also need to decrement clear time!
    if (clearLeft > 0){
      clearLeft --;
    }
    //    printf("sd %p %u %lu \r\n", msg, call CXPacket.count(msg), call CXPacket.getTimestamp(msg));
    ccfn = frameNum;
    cccaller = 1;
    checkAndCleanup();
    return SUCCESS;
  }


  /**
   * Check a received packet from the lower layer for duplicates,
   * decide whether or not it should be forwarded, and provide a clean
   * buffer to the lower layer.
   */
  event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    am_addr_t thisSrc = call CXPacket.source(msg);
    uint32_t thisSn = call CXPacket.sn(msg);
    printf_F_RX("fcr s %u n %lu", thisSrc, thisSn);
    if (state == S_IDLE){
      //new packet
      if (! ((thisSn == lastSn) && (thisSrc == lastSrc))){
//        printf_BF("FU %x %u -> %x %u\r\n", lastSrc, lastSn, thisSrc, thisSn);
        call CXRoutingTable.update(thisSrc, TOS_NODE_ID, 
          call CXPacket.count(msg));
        printf_F_RX("n");

        //check for routed flag: ignore it if the routed flag is
        //set, but we are not on the path.
        if (call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED){
          bool isBetween;
          printf_F_RX("p");
          if ((SUCCESS != call CXRoutingTable.isBetween(thisSrc, 
              call CXPacket.destination(msg), &isBetween)) || !isBetween ){
            uint8_t pll = call LayerPacket.payloadLength(msg);
            void* pl = call LayerPacket.getPayload(msg, pll);
            uint8_t tProto = call CXPacket.getTransportProtocol(msg);

            printf_SF_TESTBED_PR("PRD %u %lu\r\n", thisSrc, thisSn);
            lastSn = thisSn;
            lastSrc = thisSrc;
            printf_F_RX("~b\r\n");

            //no need to forward it, but we should report it up for
            //snooping
            return signal Receive.receive[tProto](msg, pl, pll);
          }else{
            printf_SF_TESTBED_PR("PRK %u %lu\r\n", thisSrc, thisSn);
            printf_F_RX("b");
          }
        }
        if (!rxOutstanding){
          if (SUCCESS == call TaskResource.immediateRequest()){
//            printf_SF_TESTBED("FF\r\n");
            message_t* ret = fwd_msg;
            printf_F_RX("f\r\n");
            lastSn = thisSn;
            lastSrc = thisSrc;
            lastDepth = call CXPacket.count(msg);
            //avoid slot violation w. txLeft 
            // txLeft should be min(sched.maxRetransmit, (nextSlotStart - 1) - frameNum )
            // This will prevent slot violations from happening and
            // doesn't require deep knowledge of the schedule.
            if ( call TDMARoutingSchedule.isSynched()){
              uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
              uint16_t framesLeft = call TDMARoutingSchedule.framesLeftInSlot(frameNum);
              txLeft = (mr < framesLeft)? mr : framesLeft;
            }else{
              txLeft = 0;
            }
            //if it's pre-routed and ends with us, then we don't need
            //to forward it. This lets us shave one frame off the
            //inter-packet spacing.
            if (call CXPacket.isForMe(msg) && 
                (call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED)){
              txLeft = 0;
            }
            fwd_msg = msg;
            rxOutstanding = TRUE;
            setState(S_FWD);
            //to handle the case where retx = 0
            ccfn = frameNum;
            cccaller = 2;
            checkAndCleanup();
            return ret;
  
          //couldn't get the resource, ignore this packet.
          } else {
            printf("!F.r.RIR\r\n");
            return msg;
          }
        }else{
          printf_TESTBED("QD\r\n");
          return msg;
        }
      //duplicate, ignore
      } else {
        printf_F_RX("d\r\n");
        return msg;
      }

    //busy forwarding, ignore it.
    } else {
      printf_F_RX("b\r\n");
      return msg;
    }
  }
  
  command void* Send.getPayload[uint8_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[uint8_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[uint8_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[uint8_t t](message_t* msg, void* payload, uint8_t len){ 
    return msg;
  }

  default command bool CXTransportSchedule.isOrigin[uint8_t tProto](uint16_t frameNum){
    return FALSE;
  }
}
