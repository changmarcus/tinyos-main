
 #include "schedule.h"
configuration SlaveSchedulerC{
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface Receive as AnnounceReceive;
  uses interface AMSend as RequestSend;
  uses interface Receive as ResponseReceive;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface SlotStarted;
  provides interface ScheduledSend as DefaultScheduledSend;
  provides interface ScheduledSend as RequestScheduledSend;

} implementation {
  components CXPacketStackC;
  components RandomC;
  components ActiveMessageC;
  components CXRoutingTableC;

  #if STATIC_SCHEDULER == 1
  components SlaveSchedulerStaticP as SlaveSchedulerP;
  #else
  components SlaveSchedulerP;
  #endif

  SlaveSchedulerP.AnnounceReceive = AnnounceReceive;
  SlaveSchedulerP.RequestSend = RequestSend;
  SlaveSchedulerP.ResponseReceive = ResponseReceive;

  SlaveSchedulerP.FrameStarted = FrameStarted;
  SlaveSchedulerP.TDMAPhySchedule = TDMAPhySchedule;

  TDMARoutingSchedule = SlaveSchedulerP.TDMARoutingSchedule;
  SplitControl = SlaveSchedulerP.SplitControl;
  SlaveSchedulerP.SubSplitControl = SubSplitControl;

  SlaveSchedulerP.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  SlaveSchedulerP.CXPacket-> CXPacketStackC.CXPacket;
  SlaveSchedulerP.Random -> RandomC;
  SlaveSchedulerP.PacketAcknowledgements 
    -> ActiveMessageC.PacketAcknowledgements;
  SlaveSchedulerP.AMPacket -> ActiveMessageC;
  SlaveSchedulerP.CXRoutingTable -> CXRoutingTableC;

  SlotStarted = SlaveSchedulerP.SlotStarted;
  DefaultScheduledSend = SlaveSchedulerP.DefaultScheduledSend;
  RequestScheduledSend = SlaveSchedulerP.RequestScheduledSend;


}
