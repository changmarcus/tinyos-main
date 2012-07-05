configuration CXNetworkC {
  provides interface Send as FloodSend[uint8_t t];
  provides interface Receive as FloodReceive[uint8_t t];

  provides interface Send as ScopedFloodSend[uint8_t t];
  provides interface Receive as ScopedFloodReceive[uint8_t t];

  uses interface CXTransportSchedule[uint8_t tProto];

} implementation {
  components CXTDMAPhysicalC;
  components CXPacketStackC;
  components TDMASchedulerC;

  components CXTDMADispatchC;
  CXTDMADispatchC.SubCXTDMA -> CXTDMAPhysicalC;
  CXTDMADispatchC.CXPacket -> CXPacketStackC.CXPacket;
  CXTDMADispatchC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;

  components CXFloodC;
  CXFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_FLOOD];
  CXFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_FLOOD];
  CXFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXFloodC.CXTransportSchedule = CXTransportSchedule;

  FloodSend = CXFloodC;
  FloodReceive = CXFloodC;

  components CXScopedFloodC;
  CXScopedFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.TaskResource -> CXTDMADispatchC.TaskResource[CX_NP_SCOPEDFLOOD];
  CXScopedFloodC.CXPacket -> CXPacketStackC.CXPacket;
  CXScopedFloodC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXScopedFloodC.AMPacket -> CXPacketStackC.AMPacket;
  CXScopedFloodC.LayerPacket -> CXPacketStackC.CXPacketBody;
  CXScopedFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule;
  CXScopedFloodC.CXTransportSchedule = CXTransportSchedule;

  ScopedFloodSend = CXScopedFloodC;
  ScopedFloodReceive = CXScopedFloodC;

  components CXRoutingTableC;
  CXScopedFloodC.CXRoutingTable -> CXRoutingTableC;

  CXFloodC.CXRoutingTable -> CXRoutingTableC;


}
