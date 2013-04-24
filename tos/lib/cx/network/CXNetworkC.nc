
 #include "CXNetwork.h"
configuration CXNetworkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;
  provides interface Packet;
  provides interface CXNetworkPacket;

} implementation {
  components CXNetworkP;

  components CXNetworkPacketC;
  components CXPacketMetadataC;

  //convenience interfaces
  Packet = CXNetworkPacketC;
  CXNetworkPacket = CXNetworkPacketC;

  components CXLinkC;
  
  SplitControl = CXLinkC;

  CXRequestQueue = CXNetworkP;
  CXNetworkP.SubCXRequestQueue -> CXLinkC;

  CXNetworkP.CXLinkPacket -> CXLinkC;

  CXNetworkP.CXNetworkPacket -> CXNetworkPacketC;

  CXNetworkP.CXPacketMetadata -> CXPacketMetadataC;

  components ActiveMessageC;
  CXNetworkP.AMPacket -> ActiveMessageC;

  components new PoolC(cx_network_metadata_t, CX_NETWORK_POOL_SIZE);
  CXNetworkP.Pool -> PoolC;

  components CXRoutingTableC;
  CXNetworkP.RoutingTable -> CXRoutingTableC;

}
