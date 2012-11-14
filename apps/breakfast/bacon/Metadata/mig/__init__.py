#!/usr/bin/env python

##generated with: 
## grep 'msg{' ctrl_messages.h | awk '{print $3}' | tr -d '{' | sed -re 's,(_|^)([a-z]),\u\2,g'
allS='''ReadIvCmdMsg
ReadIvResponseMsg
ReadMfrIdCmdMsg
ReadMfrIdResponseMsg
ReadBaconBarcodeIdCmdMsg
ReadBaconBarcodeIdResponseMsg
WriteBaconBarcodeIdCmdMsg
WriteBaconBarcodeIdResponseMsg
ReadToastBarcodeIdCmdMsg
ReadToastBarcodeIdResponseMsg
WriteToastBarcodeIdCmdMsg
WriteToastBarcodeIdResponseMsg
ReadToastAssignmentsCmdMsg
ReadToastAssignmentsResponseMsg
WriteToastAssignmentsCmdMsg
WriteToastAssignmentsResponseMsg
ScanBusCmdMsg
ScanBusResponseMsg
PingCmdMsg
PingResponseMsg
ResetBaconCmdMsg
ResetBaconResponseMsg
SetBusPowerCmdMsg
SetBusPowerResponseMsg
ReadBaconTlvCmdMsg
ReadBaconTlvResponseMsg
ReadToastTlvCmdMsg
ReadToastTlvResponseMsg
WriteBaconTlvCmdMsg
WriteBaconTlvResponseMsg
WriteToastTlvCmdMsg
WriteToastTlvResponseMsg
DeleteBaconTlvEntryCmdMsg
DeleteBaconTlvEntryResponseMsg
DeleteToastTlvEntryCmdMsg
DeleteToastTlvEntryResponseMsg
AddBaconTlvEntryCmdMsg
AddBaconTlvEntryResponseMsg
AddToastTlvEntryCmdMsg
AddToastTlvEntryResponseMsg'''
__all__= ['PrintfMsg'] + allS.split()
