
 #include "AM.h"
 #include "router.h"
module RouterP{
  uses interface Boot;
  uses interface SplitControl;
  provides interface Get<am_addr_t>;
  uses interface Receive as ReceiveData;
  uses interface AMPacket;

  uses interface Pool<message_t>;
  uses interface LogWrite;
} implementation {

  event void Boot.booted(){
    call SplitControl.start();
  }

  command am_addr_t Get.get(){
    return AM_BROADCAST_ADDR;
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
  
  message_t* toAppend;
  void* toAppendPl;
  uint8_t toAppendLen;
  
  //TODO: replace with pool/queue
  tunneled_msg_t tunneled_internal;
  tunneled_msg_t* tunneled = &tunneled_internal;

  task void append(){
    tunneled->recordType = RECORD_TYPE_TUNNELED;
    tunneled->src = call AMPacket.source(toAppend);
    tunneled->amId = call AMPacket.type(toAppend);
    //ugh
    memcpy(tunneled->data, toAppendPl, toAppendLen);
    call LogWrite.append(tunneled, 
      sizeof(tunneled_msg_t));
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error){
    call Pool.put(toAppend);
    toAppend = NULL;
  }

  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.eraseDone(error_t error){}

  event message_t* ReceiveData.receive(message_t* msg, 
      void* pl, uint8_t len){
    if (toAppend == NULL){
      message_t* ret = call Pool.get();
      if (ret){
        toAppend = msg;
        toAppendPl = pl;
        toAppendLen = len;
        post append();
        return ret;
      }else {
        return msg;
      }
    } else {
      //still handling last packet
      return msg;
    }
  }
}
