configuration CXTDMAPhysicalC {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAPhySchedule;
  provides interface FrameStarted;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;
  uses interface Rf1aPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface Packet;

  provides interface Rf1aConfigure;
  uses interface Rf1aConfigure as SubRf1aConfigure[uint8_t sr];

} implementation {
  components CXTDMAPhysicalP;

  SplitControl = CXTDMAPhysicalP;
  CXTDMA = CXTDMAPhysicalP;
  TDMAPhySchedule = CXTDMAPhysicalP;

  HplMsp430Rf1aIf = CXTDMAPhysicalP;
  Resource = CXTDMAPhysicalP;
  Rf1aPhysical = CXTDMAPhysicalP;
  Rf1aPhysicalMetadata = CXTDMAPhysicalP;
  Rf1aStatus = CXTDMAPhysicalP;
  Rf1aPacket = CXTDMAPhysicalP;
  CXPacket = CXTDMAPhysicalP;
  CXPacketMetadata = CXTDMAPhysicalP;
  FrameStarted = CXTDMAPhysicalP;

  CXTDMAPhysicalP.SubRf1aConfigure = SubRf1aConfigure;
  Rf1aConfigure = CXTDMAPhysicalP.Rf1aConfigure;

  components new AlarmMicro32C() as FrameStartAlarm;
  components new AlarmMicro32C() as PrepareFrameStartAlarm;
  //This could be 32khz, not so important
  components new AlarmMicro32C() as FrameWaitAlarm;

  components GDO1CaptureC;

  components Rf1aDumpConfigC;
  CXTDMAPhysicalP.Rf1aDumpConfig -> Rf1aDumpConfigC;

  CXTDMAPhysicalP.FrameStartAlarm -> FrameStartAlarm;
  CXTDMAPhysicalP.PrepareFrameStartAlarm -> PrepareFrameStartAlarm;
  CXTDMAPhysicalP.FrameWaitAlarm -> FrameWaitAlarm;
  CXTDMAPhysicalP.SynchCapture -> GDO1CaptureC;

  components CXRadioStateTimingC;
  CXTDMAPhysicalP.StateTiming -> CXRadioStateTimingC;

  CXTDMAPhysicalP.Packet = Packet;
}
