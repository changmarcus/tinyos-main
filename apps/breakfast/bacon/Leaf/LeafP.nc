
 #include "AM.h"
module LeafP{
  uses interface Boot;
  uses interface SplitControl;
} implementation {

  event void Boot.booted(){
    call SplitControl.start();
    #ifndef CC430_PIN_DEBUG
    #define CC430_PIN_DEBUG 0
    #endif
    #if CC430_PIN_DEBUG == 1
    atomic{
      uint8_t i;
      //map SFD to 2.4
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
//      P1MAP1 = PM_MCLK;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
//      P1SEL |= BIT1;
//      P1DIR |= BIT1;
      
      //clear p1.1, use as gpio
      P1SEL &= ~BIT1;
      P1DIR |=  BIT1;
      P1OUT &= ~BIT1;

//      for (i=0 ; i < 10; i++){
//        P1OUT ^=BIT1;
//      }
    }
    #endif
  }

  event void SplitControl.startDone(error_t error){
  }

  event void SplitControl.stopDone(error_t error){
  }
}
