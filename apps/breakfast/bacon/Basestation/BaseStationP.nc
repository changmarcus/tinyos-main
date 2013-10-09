
 #include "AM.h"
 #include "Serial.h"
 #include "basestation.h"
 #include "multiNetwork.h"
 #include "CXMac.h"
 #include "CXRouter.h"
 #include "CXBasestationDebug.h"

module BaseStationP @safe() {
  uses interface Boot;

  uses interface SplitControl as SerialControl;
  uses interface SplitControl as RadioControl;

  //Serial stack: forward snooped packets, one slot in serial AM send queue
  uses interface AMSend as SerialSend[am_id_t id];
  uses interface Receive as SerialSnoop[am_id_t id];
  uses interface Packet as SerialPacket;
  uses interface AMPacket as SerialAMPacket;
  
  //Radio stack
  // - all received/snooped packets will get resent over serial (via
  //   multi-sender)
  // - We need separate amId-parameterized AMSend interfaces for each
  //   network segment, since that is how I've chosen to break up the
  //   layering. Ideally, this would be a 2-dimensional interface, but
  //   that doesn't exist.
  uses interface Receive as RadioReceive[am_id_t id];
  uses interface Receive as RadioSnoop[am_id_t id];

  uses interface AMSend as GlobalSend[am_id_t id];
  uses interface AMSend as RouterSend[am_id_t id];
  uses interface AMSend as SubNetworkSend[am_id_t id];
  uses interface Packet as RadioPacket;
  uses interface AMPacket as RadioAMPacket;
  uses interface CXLinkPacket;

  uses interface ActiveMessageAddress;

  
  //Control interfaces: separated from the am_id agnostic forwarding
  //code.
  uses interface Receive as CXDownloadReceive;
  uses interface AMSend as CtrlAckSend;
  uses interface AMSend as CXDownloadFinishedSend;
  uses interface AMSend as IDResponseSend;

  uses interface CXDownload[uint8_t ns];

  //For simple timestamping: separate from forwarding structures.
  uses interface Receive as StatusReceive;

  uses interface Leds;
  
  //bookkeeping
  uses interface Pool<message_t>;
  uses interface Queue<queue_entry_t> as RadioRXQueue;
  uses interface Queue<queue_entry_t> as SerialRXQueue;
  uses interface Queue<queue_entry_t> as RadioTXQueue;
  uses interface Queue<queue_entry_t> as SerialTXQueue;

  uses interface Timer<TMilli> as FlushTimer;
}

implementation
{
  uint8_t aux[TOSH_DATA_LENGTH];

  message_t* ackDMsg;
  message_t* ackRMsg;

  uint8_t activeNS;
  bool serialSending;
  bool radioSending;

  event void Boot.booted() {
    uint8_t i;
    call RadioControl.start();
    call SerialControl.start();
    call FlushTimer.startPeriodic(1024);
    
    #ifdef CC430_PIN_DEBUG
    atomic{
      //map SFD to 2.4
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
  
      //disable flash chip
      P2SEL &= ~BIT1;
      P2OUT |=  BIT1;


      P1SEL &= ~(BIT1|BIT2|BIT3|BIT4);
      P1OUT &= ~(BIT1|BIT2|BIT3|BIT4);
      P1DIR |=  (BIT1|BIT2|BIT3|BIT4);

    }
    #endif
  }

  event void RadioControl.startDone(error_t error) {
    if (error != SUCCESS) {
      cdbg(BASESTATION, "RC.sd: %x\r\n", error);
      cflushdbg(BASESTATION);
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error != SUCCESS) {
      cdbg(BASESTATION, "SC.sd: %x\r\n", error);
      cflushdbg(BASESTATION);
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  task void prepareSerial();
  task void txSerial();
  message_t* radioReceive(message_t* msg, void* payload, uint8_t len);
  
  //Forward all radio traffic
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return radioReceive(msg, payload, len);
  }
  
  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return radioReceive(msg, payload, len);
  }

  //record metadata, enqueue radio packet
  message_t* radioReceive(message_t *msg, void *payload, uint8_t len) {
    cdbg(BASESTATION, "RRX %x %u\r\n", 
      call CXLinkPacket.source(msg), 
      call CXLinkPacket.getSn(msg));
    if (call RadioRXQueue.size() >= call RadioRXQueue.maxSize()){
      cdbg(BASESTATION, "Radio full\r\n");
      cflushdbg(BASESTATION);
      return msg;
    } else if (call Pool.empty()){
      cerror(BASESTATION, "Pool empty fwdR\r\n");
      cflusherror(BASESTATION);
      return msg;
    }else{
      queue_entry_t qe;
      qe.msg = msg;
      qe.pl = payload;
      qe.len = len;
      call RadioRXQueue.enqueue(qe);
      post prepareSerial();
      cdbg(BASESTATION, "G fwdR\r\n");
      return call Pool.get();
    }
  }

  //convert enqueued incoming radio packet to enqueued outgoing serial
  //packet
  task void prepareSerial(){
    if (!call RadioRXQueue.empty() 
        && call RadioTXQueue.size() < call RadioTXQueue.maxSize()){
      queue_entry_t qe = call RadioRXQueue.dequeue();
      //stash header contents
      am_addr_t src = call RadioAMPacket.source(qe.msg);
      am_group_t grp = call RadioAMPacket.group(qe.msg);
      am_addr_t addr = call RadioAMPacket.destination(qe.msg);
      am_id_t id = call RadioAMPacket.type(qe.msg);
      //move the payload out of the way
      memmove(aux, 
        call RadioPacket.getPayload(qe.msg, qe.len),
        qe.len);
      //clear header
      call SerialPacket.clear(qe.msg);
      //set up serial header
      call SerialAMPacket.setSource(qe.msg, src);
      call SerialAMPacket.setGroup(qe.msg, grp);
      call SerialAMPacket.setType(qe.msg, id);
      call SerialAMPacket.setDestination(qe.msg, addr);
      //move payload back
      memmove(call SerialPacket.getPayload(qe.msg, qe.len), 
        aux, 
        qe.len);
      call SerialTXQueue.enqueue(qe);
      post txSerial();
    }
  }
  
  //try to send next outgoing serial packet, re-enqueue if it fails.
  task void txSerial(){
    if (! call SerialTXQueue.empty() && !serialSending){
      queue_entry_t qe = call SerialTXQueue.dequeue();
      error_t error = call SerialSend.send[call
      SerialAMPacket.type(qe.msg)](call SerialAMPacket.destination(qe.msg), qe.msg, qe.len);
      if (error == SUCCESS){
        serialSending = TRUE;
      }else{
        cdbg(BASESTATION, "SerialTX: %x\r\n", error);
        call SerialTXQueue.enqueue(qe);
      }
    }
  }
  
  //send next outgoing serial packet 
  event void SerialSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    serialSending = FALSE;
    cdbg(BASESTATION, "P fwdR\r\n");
    call Pool.put(msg);
    post txSerial();
  }
  
  
  task void prepareRadio();
  task void txRadio();

  task void sendIDResponse(){
    message_t* m = call Pool.get();
    if (m != NULL){
      identify_response_t* pl = call SerialPacket.getPayload(m,
        sizeof(identify_response_t));
      call SerialPacket.clear(m);
      pl -> self = call ActiveMessageAddress.amAddress();
      call SerialAMPacket.setSource(m, 
        call ActiveMessageAddress.amAddress());
      call IDResponseSend.send(0, m, sizeof(identify_response_t));
    }else{
      cerror(BASESTATION, "IDRE\r\n");
    }
  }

  event void IDResponseSend.sendDone(message_t* m, error_t error){
    call Pool.put(m);
  }

  event message_t *SerialSnoop.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
    if (id == AM_IDENTIFY_REQUEST){
      post sendIDResponse();
      return msg;
    }
    if (call SerialRXQueue.size() >= call SerialRXQueue.maxSize()){
      cdbg(BASESTATION, "Serial full\r\n");
      cflushdbg(BASESTATION);
      return msg;
    } else {
      message_t* ret = call Pool.get();
      if (ret == NULL){
        cerror(BASESTATION, "Pool empty fwdS\r\n");
        cflusherror(BASESTATION);
        return msg;
      } else{
        queue_entry_t qe;
        qe.msg = msg;
        qe.pl = payload;
        qe.len = len;
        call SerialRXQueue.enqueue(qe);
        post prepareRadio();
        cdbg(BASESTATION, "G fwdS\r\n");
        return ret;
      }
    }
  }

  task void prepareRadio(){
    if (!call SerialRXQueue.empty() 
        && call SerialTXQueue.size() < call SerialTXQueue.maxSize()){
      queue_entry_t qe = call SerialRXQueue.dequeue();
      //stash header contents
      am_addr_t src = call SerialAMPacket.source(qe.msg);
      am_group_t grp = call SerialAMPacket.group(qe.msg);
      am_addr_t addr = call SerialAMPacket.destination(qe.msg);
      am_id_t id = call SerialAMPacket.type(qe.msg);
      //move the payload out of the way
      memmove(aux, 
        call SerialPacket.getPayload(qe.msg, qe.len),
        qe.len);
      //clear header
      call RadioPacket.clear(qe.msg);
      //set up serial header
      call RadioAMPacket.setSource(qe.msg, src);
      call RadioAMPacket.setGroup(qe.msg, grp);
      call RadioAMPacket.setType(qe.msg, id);
      call RadioAMPacket.setDestination(qe.msg, addr);
      //move payload back
      memmove(call RadioPacket.getPayload(qe.msg, qe.len), 
        aux, 
        qe.len);
      call RadioTXQueue.enqueue(qe);
      post txRadio();
    }else{
      if (call SerialTXQueue.size() >= call SerialTXQueue.maxSize()){
        cwarn(BASESTATION, "TX queue full, hold\r\n");
      }
    }
  }

  task void txRadio(){
    if (! call RadioTXQueue.empty() && !radioSending){
      queue_entry_t qe = call RadioTXQueue.dequeue();

      error_t error;
      switch (activeNS){
        case NS_ROUTER:
          error = call RouterSend.send[call RadioAMPacket.type(qe.msg)](call RadioAMPacket.destination(qe.msg), qe.msg, qe.len);
          break;
        case NS_GLOBAL:
          error = call GlobalSend.send[call RadioAMPacket.type(qe.msg)](call RadioAMPacket.destination(qe.msg), qe.msg, qe.len);
          break;
        case NS_SUBNETWORK:
          error = call SubNetworkSend.send[call RadioAMPacket.type(qe.msg)](call RadioAMPacket.destination(qe.msg), qe.msg, qe.len);
          break;
        default:
          error = FAIL;
      } 
      if (error == SUCCESS){
        radioSending = TRUE;
      }else{
        cerror(BASESTATION, "RadioTX: %x\r\n", error);
        call RadioTXQueue.enqueue(qe);
      }
    }
  }

  void radioSendDone(am_id_t id, message_t* msg, error_t error);

  event void GlobalSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    radioSendDone(id, msg, error);
  }

  event void RouterSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    radioSendDone(id, msg, error);
  }

  event void SubNetworkSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    radioSendDone(id, msg, error);
  }

  void radioSendDone(am_id_t id, message_t* msg, error_t error) {
    message_t* ackMsg;
    radioSending = FALSE;
    cdbg(BASESTATION, "RSD %x %u\r\n", id, call RadioAMPacket.destination(msg));
    cdbg(BASESTATION, "P fwdS\r\n");
    call Pool.put(msg);
    cdbg(BASESTATION, "G ackR\r\n");
    ackMsg = call Pool.get();
    if (ackMsg != NULL) {
      ctrl_ack_t* pl = call CtrlAckSend.getPayload(ackMsg,
        sizeof(ctrl_ack_t));
      ackRMsg = ackMsg;
      call SerialPacket.clear(ackMsg);
      pl -> error = error;
      call SerialAMPacket.setSource(ackMsg, 
        call ActiveMessageAddress.amAddress());
      error = call CtrlAckSend.send(0, ackMsg, sizeof(ctrl_ack_t));
      if (error != SUCCESS){
        cerror(BASESTATION, "Couldn't send radio TX ack %x\r\n",
          error);
        cflushdbg(BASESTATION);
        cdbg(BASESTATION, "P ackR!\r\n");
        call Pool.put(ackMsg);
        ackMsg = NULL;
      }
    }else{
      cerror(BASESTATION, "no ack pool\r\n");
    }
  }

  event void CtrlAckSend.sendDone(message_t* msg, error_t error){
    if (msg == ackRMsg){
      cdbg(BASESTATION, "P ackR\r\n");
      ackRMsg = NULL;
    }else if (msg == ackDMsg){
      cdbg(BASESTATION, "P ackD\r\n");
      ackDMsg = NULL;
    }
    call Pool.put(msg);
    post txRadio();
  }

  //Multi-network forwarding logic above
  //CX logic below

  error_t downloadError;
  message_t* downloadMsg;
  cx_download_t* downloadPl;

  task void startDownload();
  task void ackDownload();

  event message_t* CXDownloadReceive.receive(message_t* msg, 
      void* pl, uint8_t len){
    if (!call Pool.empty()){
      downloadPl = pl;
      downloadMsg = msg;
      post startDownload();
      cdbg(BASESTATION, "G cxd\r\n");
      return call Pool.get();
    }else{
      cerror(BASESTATION, "DownloadRX: pool empty\r\n");
      cflusherror(BASESTATION);
    }
    return msg;
  }
  
  task void startDownload(){
    downloadError = call CXDownload.startDownload[downloadPl->networkSegment]();
    if (downloadError == SUCCESS){
      activeNS = downloadPl->networkSegment;
    }
    cdbg(BASESTATION, "P cxd\r\n");
    call Pool.put(downloadMsg);
    post ackDownload();
  }

  task void ackDownload(){
    message_t* ackMsg;
    cdbg(BASESTATION, "G ackD\r\n");
    ackMsg = call Pool.get();
    if (ackMsg != NULL){
      ctrl_ack_t* pl = call CtrlAckSend.getPayload(ackMsg,
        sizeof(ctrl_ack_t));
      error_t error;
      ackDMsg = ackMsg;
      call SerialPacket.clear(ackMsg);
      pl -> error = downloadError;
      call SerialAMPacket.setSource(ackMsg, 
        call ActiveMessageAddress.amAddress());
      error = call CtrlAckSend.send(0, ackMsg, sizeof(ctrl_ack_t));
      if (error != SUCCESS){
        cdbg(BASESTATION, "Couldn't ack download %x\r\n", error);
        cflushdbg(BASESTATION);
        cdbg(BASESTATION, "P ackD!\r\n");
        call Pool.put(ackMsg);
      }
    }
  }
  
  void reportFinished(uint8_t segment);

  event void CXDownload.downloadFinished[uint8_t ns](){
    reportFinished(NS_ROUTER);
  }

  void reportFinished(uint8_t segment){
    message_t* ctrlMsg;
    printfflush();
    cdbg(BASESTATION, "G rf\r\n");
    ctrlMsg = call Pool.get();
    if (ctrlMsg != NULL){
      cx_download_finished_t* pl = call CXDownloadFinishedSend.getPayload(ctrlMsg, sizeof(cx_download_finished_t));
      error_t error;
      call SerialPacket.clear(ctrlMsg);
      pl -> networkSegment = segment;
      call SerialAMPacket.setSource(ctrlMsg, 
        call ActiveMessageAddress.amAddress());
      error = call CXDownloadFinishedSend.send(0, ctrlMsg,
        sizeof(cx_download_finished_t));
      if (error != SUCCESS){
        cdbg(BASESTATION, "P rf!\r\n");
        call Pool.put(ctrlMsg);
      }else{
        cinfo(BASESTATION, "DownloadFinishedSend.send %x pool %u min %u\r\n",
          error, call Pool.size(), call Pool.minFree());
        cflushdbg(BASESTATION);
      }
    }else{
      cerror(BASESTATION, "reportFinished: pool empty\r\n");
      cflusherror(BASESTATION);
    }
    activeNS = NS_INVALID;
  }

  event void CXDownloadFinishedSend.sendDone(message_t* msg, error_t error){
    cdbg(BASESTATION, "P rf\r\n");
    call Pool.put(msg);
  }

  event message_t* StatusReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    cx_status_t buf;
    cx_status_t* amPl;
    memcpy(&buf, pl, sizeof(cx_status_t));
    call RadioAMPacket.setType(msg, AM_CX_STATUS);
    amPl = call RadioPacket.getPayload(msg, sizeof(cx_status_t));
    memcpy(amPl, &buf, sizeof(cx_status_t));
    cdbg(BASESTATION, "SR %u\r\n", call RadioAMPacket.source(msg));
    return radioReceive(msg, amPl, sizeof(cx_status_t));
  }

  default command error_t CXDownload.startDownload[uint8_t ns](){
    return EINVAL;
  }
  
  uint8_t ftCount;
  event void FlushTimer.fired(){
    if ((ftCount % 64) == 0){
      cdbg(BASESTATION, "(keepalive)\r\n");
    }
    ftCount ++;
    printfflush();
  }

  async event void ActiveMessageAddress.changed(){}

}  
