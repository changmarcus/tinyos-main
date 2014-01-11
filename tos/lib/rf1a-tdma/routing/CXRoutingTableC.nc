/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

 #include "CXRouting.h"
configuration CXRoutingTableC{
  provides interface CXRoutingTable;
} implementation {
  #if CX_FORWARDER_SELECTION == 0
  components new CXRoutingTableP(CX_ROUTING_TABLE_ENTRIES);
  #elif CX_FORWARDER_SELECTION == 1
  components new CXAverageRoutingTableP(CX_ROUTING_TABLE_ENTRIES) 
    as CXRoutingTableP;
  #elif CX_FORWARDER_SELECTION == 2
  components new CXMaxRoutingTableP(CX_ROUTING_TABLE_ENTRIES) 
    as CXRoutingTableP;
  components LocalTimeMilliC;
  CXRoutingTableP.LocalTime -> LocalTimeMilliC;
  #else
  #error Unrecognized CX_FORWARDER_SELECTION option: 0=instant, 1=avg, 2=max
  #endif
//  components new SafeCXRoutingTableP(CX_ROUTING_TABLE_ENTRIES) as CXRoutingTableP;
  components MainC;
  CXRoutingTable = CXRoutingTableP;
  MainC.SoftwareInit -> CXRoutingTableP;
}
