from cx.messages import SetSettingsStorageMsg

import cx.constants

class SetPhoenixTargetRefs(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, targetRefs):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(cx.constants.SS_KEY_PHOENIX_TARGET_REFS)
        self.set_len(1)
        self.setUIntElement(self.offsetBits_val(0), 8, targetRefs, 1)

