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

 #include "RebootCounter.h"
generic configuration BaconSamplerHighC(volume_id_t VOLUME_ID, bool
circular) {
} implementation {
  components BaconSamplerHighP as BaconSamplerP;

  components SettingsStorageC;

  components MainC;
  components new TimerMilliC();
  
  BaconSamplerP.Boot -> MainC;
  BaconSamplerP.Timer -> TimerMilliC;
  BaconSamplerP.SettingsStorage -> SettingsStorageC;

  components Apds9007C;
  BaconSamplerP.LightRead -> Apds9007C.Read;
  BaconSamplerP.LightControl -> Apds9007C.StdControl;

  components BatteryVoltageC;
  BaconSamplerP.BatteryRead -> BatteryVoltageC.Read;
  BaconSamplerP.BatteryControl -> BatteryVoltageC.StdControl;

  components new LogStorageC(VOLUME_ID, circular);
  BaconSamplerP.LogWrite -> LogStorageC;
}
