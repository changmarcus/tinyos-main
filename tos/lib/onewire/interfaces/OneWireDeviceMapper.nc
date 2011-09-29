/* Copyright (c) 2010 Johns Hopkins University.
*  All rights reserved.
*
*  Permission to use, copy, modify, and distribute this software and its
*  documentation for any purpose, without fee, and without written
*  agreement is hereby granted, provided that the above copyright
*  notice, the (updated) modification history and the author appear in
*  all copies of this source code.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS `AS IS'
*  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
*  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
*  ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
*  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
*  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, LOSS OF USE, DATA,
*  OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
*  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
*  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
*  THE POSSIBILITY OF SUCH DAMAGE.
*/

/**
 * Provides commands/events for identifying which onewire devices are present.
 * 
 *
 * @author Doug Carlson <carlson@cs.jhu.edu>
 * @modified 6/16/10 initial revision
 */
interface OneWireDeviceMapper {
  /**
   * Request the mapper to refresh its list of attached devices. 
   *
   * @return SUCCESS if the request will be accepted, EBUSY if a refresh is already pending. If SUCCESS is returned, refreshDone will be signalled at some point in the future.
   */
  command error_t refresh();

  /**
   * Indicate completion of a device-list refresh. Note that this may be signalled without an explicit call to the refresh command (i.e. if the device mapper periodically checks the bus, if another user of the deviceMapper calls refresh, etc).
   *
   * @param result  SUCCESS if the refresh completed normally, otherwise FAIL.
   * @param devicesChanged TRUE if the list of attached devices is different from the list of attached devices at the last time that refreshDone was signalled.
   */
  event void refreshDone(error_t result, bool devicesChanged);
  
  /**
   * Return the number of currently-present devices.
   *
   * @return the number of currently-present devices.
   */
  command uint8_t numDevices();

   /**
    * Get the hardware ID of a currently-present device.
    * @param index The index of the device to retrieve. 
    * @return The hardware ID of the device at index. This will be equal to NULL_ONEWIRE_ADDR if an index outside of [0, numDevices()] is provided.
    */
  command onewire_t getDevice(uint8_t index);  
}
