import Tkinter
from Tkinter import *
from math import floor

import copy

from tools.dashboard.DatabaseQuery import DatabaseQuery
from tools.dashboard.SettingsFile import SettingsFile

import tools.cx.constants as constants


class NodeFrame(Frame):

    SETTINGS = "network.settings"
    #DATABASE = "example.db"
    DEFAULT_CHANNEL = "0"
    
    def __init__(self, parent, hub, dbFile, **args):
        Frame.__init__(self, parent, **args)
        
        self.hub = hub
        
        self.tkobjects = {}
        self.sensorTypes = {}
        
        #self.sf = SettingsFile(self.SETTINGS)
        self.db = DatabaseQuery(dbFile)
        
        self.changedVar = BooleanVar()
        self.changedVar.set(False)
        self.changedVar.trace("w", self.settingsChanged)
        
        #self.channels = self.binarySeparation()

        # load settings from database and from settings file
        self.loadSettings()        
        self.membership = {}
        self.requestedLeafs = {}
        
        self.initUI()
        self.saveSettings()
    
    def loadSettings(self):
        #self.offline = self.sf.read()        
        self.settings = self.db.getSettings()
        self.originalSettings = copy.deepcopy(self.settings)

        self.multiplexers = self.db.getMultiplexers()
#         self.site = self.db.getSiteMap()
    
    def saveSettings(self):        
        #self.sf.write(self.offline)
        self.changedVar.set(False)

    def settingsChanged(self, *args):
        if self.changedVar.get():
            pass
            # note: give visual cue that settings have changed
            #print "settings changed"

    def initUI(self):
        self.oldSuperFrame = Frame(self)
        self.oldSuperFrame.grid(column=0, row=0)
        self.redrawAllNodes()
        


    #################################################################################################
    #                                                                                               #
    #   super frame                                                                                 #
    #                                                                                               #
    #   #########################################################################################   #    
    #   #                                                                                       #   #
    #   #   channel frame                                                                       #   #
    #   #                                                                                       #   #
    #   #   #################################################################################   #   #
    #   #   #                                                                               #   #   #   
    #   #   #   leaf frame                                                                  #   #   #   
    #   #   #                                                                               #   #   #   
    #   #   #   #####################   #################################################   #   #   #
    #   #   #   #                   #   #                                               #   #   #   #                    
    #   #   #   #   node frame      #   #   status frame                                #   #   #   #
    #   #   #   #                   #   #                                               #   #   #   #    
    #   #   #   #                   #   #################################################   #   #   #
    #   #   #   #                   #                                                       #   #   #                
    #   #   #   #                   #   #################   #################   #########   #   #   #
    #   #   #   #                   #   #               #   #               #   #       #   #   #   #    
    #   #   #   #                   #   #  plex frame   #   #  plex frame   #   #  ...  #   #   #   #
    #   #   #   #                   #   #               #   #               #   #       #   #   #   #
    #   #   #   #####################   #################   #################   #########   #   #   #
    #   #   #                                                                               #   #   #
    #   #   #################################################################################   #   #
    #   #                                                                                       #   #
    #   #########################################################################################   #
    #                                                                                               #
    #   #########################################################################################   #    
    #   #                                                                                       #   #
    #   #   channel frame                                                                       #   #
    #   #                                                                                       #   #
    #   #   ...                                                                                 #   #
    #   #                                                                                       #   #
    #   #########################################################################################   #
    #                                                                                               #
    #################################################################################################

    def organizeChannels(self):
        channels = {}
        for barcode in self.settings:
            x = self.settings[barcode]
            print x
            (nodeId, sampleInterval, channel, role) = x
            channelMap = channels.get(channel, {})
            channelMap[role] = channelMap.get(role, [])+[barcode]
            channels[channel]  = channelMap
        return channels

    def drawChannelFrames(self):
        channels = self.organizeChannels()
        print "Channel maps", channels

        # draw channels
        # create a frame for each channel
        for rowNumber, channel in enumerate(sorted(channels.iterkeys())):
            # channelFrame : contains routers, leafs, multiplexers for
            #   a channel
            # routerFrame    : contains router widgets
            channelFrame = Frame(self.superFrame, bd=2, relief=RIDGE, padx=1, pady=1)
            channelLabel = Label(channelFrame, text="CHANNEL %d"%(channel))
            channelLabel.grid(column=0, row=0)

            channelMap = channels[channel]
            routersFrame = Frame(channelFrame, bd=1, relief=SUNKEN)
            routersLabel = Label(routersFrame, text="ROUTERS")
            routersLabel.grid(column=0, row=0)
            if constants.ROLE_ROUTER in channelMap:
                for (routerRow, barcode) in enumerate(sorted(channelMap[constants.ROLE_ROUTER])):
                    routerFrame = Frame(routersFrame, bd=1, relief=RIDGE)
                    barcode_text = "%s" % (barcode, )
                    button = Button(routerFrame, text=barcode_text,
                      width=18, justify=LEFT, 
                      command=lambda router=barcode: self.selectRouter(router))
                    # color code button: grey=selected, yellow=modified
                    if barcode in self.selection:
                        colorCode = "grey"
                    elif self.settings[barcode] != self.originalSettings[barcode]:
                        colorCode = "yellow"
                    else:
                        colorCode = self.cget("bg")
                
                    button.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                    button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
                
                    label_text = "Channel:"
                    label = Label(routerFrame, text=label_text)
                    label.configure(background=colorCode)
                    label.grid(column=0, row=1, sticky=N+S+E+W)
                    typeVar = StringVar()        
                    typeVar.set(self.DEFAULT_CHANNEL)
                    typeOption = OptionMenu(routerFrame, typeVar, [self.DEFAULT_CHANNEL])
                    typeOption.configure(width=3, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                    typeOption.grid(column=1, row=1, sticky=N+S+E+W)
        
                    menu = typeOption["menu"]
                    menu.delete(0, "end")
        
                    # populate menu with channels
                    menu.add_command(label=channel, command=Tkinter._setit(typeVar, channel)) 
                    typeVar.set(channel)
                    
                    for key in self.hub.control.channels:
                        menu.add_command(label=key, command=lambda router=barcode, key=key: self.updateRouter(router, key))
                    routerFrame.grid(column=0, row=routerRow+1)
                    self.tkobjects["routerFrame_%s" % barcode] = routerFrame
                    self.tkobjects["routerButton_%s" % barcode] = button
                    self.tkobjects["routerOption_%s" % barcode] = typeOption
                    self.tkobjects["routerOptionVar_%s" % barcode] = typeVar
            leafsFrame = Frame(channelFrame, bd=1, relief=SUNKEN)
            leafsLabel = Label(leafsFrame, text="LEAVES")
            leafsLabel.grid(column=0, row=0)
            if constants.ROLE_LEAF in channelMap:
                for (leafRow, barcode) in enumerate(sorted(channelMap[constants.ROLE_LEAF])):
                    self.membership[barcode] = channel
                    (nodeId, sampleInterval, channel, role) = self.settings[barcode]
                    leafFrame = Frame(leafsFrame, bd=1, relief=SUNKEN)
                    # nodeframe contains the leaf ID, sampling rate
                    nodeFrame = Frame(leafFrame, bd=1, relief=SUNKEN)
                    button_text = "%s\nSampling: %s" % (barcode, sampleInterval)            
                    button = Button(nodeFrame, text=button_text, 
                      width=18, justify=LEFT, 
                      command=lambda leaf=barcode: self.selectNode(leaf))
        
                    # color code button: grey=selected, yellow=modified
                    if barcode in self.selection:
                        colorCode = "grey"
                    elif self.settings[barcode] != self.originalSettings[barcode]:
                        colorCode = "yellow"
                    else:
                        colorCode = self.cget("bg")
                    
                    button.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)            
                    button.grid(column=0, row=0, columnspan=2, sticky=N+S+E+W)
                    
                    label = Label(nodeFrame, text="Channel:", bd=0, relief=SUNKEN)
                    label.configure(background=colorCode)            
                    label.grid(column=0, row=1, sticky=N+S+E+W)

                    typeVar = StringVar()        
                    typeVar.set(channel)
                    typeOption = OptionMenu(nodeFrame, typeVar, [channel])
                    typeOption.configure(width=3, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                    typeOption.grid(column=1, row=1, sticky=N+S+E+W)
        
                    menu = typeOption["menu"]
                    menu.delete(0, "end")
                    # populate menu with channels
                    menu.add_command(label=channel, command=Tkinter._setit(typeVar, channel)) 
                    typeVar.set(channel)
                    for key in self.hub.control.channels:
                        menu.add_command(label=key, 
                        command=lambda leaf=barcode, key=key: self.updateLeaf(leaf, key))


                    if barcode in self.multiplexers:
                        # each node can have multiple multiplexers attached
                        for i, plexid in enumerate(self.multiplexers[leaf]):
        #                     print "plexs: ", i, plex[0]
        #                     plexid = plex[0]
                            print leaf, i, plexid
                            plexFrame = Frame(leafFrame, bd=1, relief=SUNKEN)
                            self.tkobjects["plexFrame_%s" % plexid] = plexFrame
                            
                            # color code button: grey=selected, yellow=modified
                            if plexid in selection:
                                colorCode = "grey"
                            #elif self.leafs[leaf] != self.originalLeafs[leaf]:
                            #    colorCode = "yellow"
                            else:
                                colorCode = self.cget("bg")
                            
                            button = Button(plexFrame, text=plexid, command=lambda plexid=plexid: self.selectPlex(plexid))
                            button.configure(width=18, height=1, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                            button.grid(column=0, row=0, columnspan=8, sticky=N+S+E+W)
                            self.tkobjects["plexButton_%s" % plexid] = button
                            toastMap = self.multiplexers[leaf][plexid]
                            # each multiplexer has 8 channels
                            for sc in toastMap.keys():
                                (sensorType, sensorId) = toastMap[sc]
                                self.sensorTypes[sensorType] = 1
                                
                                label = Label(plexFrame, text=str(sensorType), bd=1, relief=SUNKEN)
                                label.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                                label.grid(column=sc, row=1, sticky=N+S+E+W)
                                self.tkobjects["sensLabel_%s_%d" % (plexid, sc)] = label
                            
                            plexFrame.grid(column=i+1, row=1)
                    leafFrame.grid(column=0, row=leafRow+1)
                    nodeFrame.grid(column=0, row=0, rowspan=2, sticky=N+S+E+W)
                    
                    self.tkobjects["nodeFrame_%s" % barcode] = nodeFrame
                    self.tkobjects["nodeButton_%s" % barcode] = button
                    self.tkobjects["nodeOption_%s" % barcode] = typeOption
                    self.tkobjects["nodeOptionVar_%s" % barcode] = typeVar
                     
            routersFrame.grid(column=0, row=1, sticky=N+S+E+W)
            leafsFrame.grid(column=1, row=1, sticky=N+S+E+W)
            channelFrame.grid(column=0, row=rowNumber, sticky=N+S+E+W)
        # update menu list of available sensor types
        self.hub.control.updateTypes(self.sensorTypes)

    def drawTheRest(self):
        if False:
            # if node has multiplexer(s) attached, draw multiplexer and sensor types
            if leaf in self.multiplexers:
                # each node can have multiple multiplexers attached
                for i, plexid in enumerate(self.multiplexers[leaf]):
#                     print "plexs: ", i, plex[0]
#                     plexid = plex[0]
                    print leaf, i, plexid
                    plexFrame = Frame(leafFrame, bd=1, relief=SUNKEN)
                    self.tkobjects["plexFrame_%s" % plexid] = plexFrame
                    
                    # color code button: grey=selected, yellow=modified
                    if plexid in selection:
                        colorCode = "grey"
                    #elif self.leafs[leaf] != self.originalLeafs[leaf]:
                    #    colorCode = "yellow"
                    else:
                        colorCode = self.cget("bg")
                    
                    button = Button(plexFrame, text=plexid, command=lambda plexid=plexid: self.selectPlex(plexid))
                    button.configure(width=18, height=1, background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                    button.grid(column=0, row=0, columnspan=8, sticky=N+S+E+W)
                    self.tkobjects["plexButton_%s" % plexid] = button
                    toastMap = self.multiplexers[leaf][plexid]
                    # each multiplexer has 8 channels
                    for sc in toastMap.keys():
                        (sensorType, sensorId) = toastMap[sc]
                        self.sensorTypes[sensorType] = 1
                        
                        label = Label(plexFrame, text=str(sensorType), bd=1, relief=SUNKEN)
                        label.configure(background=colorCode, activebackground=colorCode, highlightbackground=colorCode)
                        label.grid(column=sc, row=1, sticky=N+S+E+W)
                        self.tkobjects["sensLabel_%s_%d" % (plexid, sc)] = label
                    
                    plexFrame.grid(column=i+1, row=1)
                
            # draw leaf frame and store it in TK objects
            leafFrame.grid(column=1, row=rowNumber, sticky=N+S+E+W)
            self.tkobjects["leafFrame_%s" % leaf] = leafFrame

    
    def redrawAllNodes(self):
        siteChannels = {}
        siteLeafs = {}
        siteRow = {}
        
        if self.hub.display is None:
            self.selection = []
        else:
            self.selection = self.hub.display.nodes
        
        print "selection: ", self.selection
        self.superFrame = Frame(self)
        self.drawChannelFrames()

        # swap frames
        self.superFrame.grid(column=0, row=0)
        self.oldSuperFrame.grid_forget()
        self.oldSuperFrame = self.superFrame


    def selectNode(self, barcode):
        # don't mix router and multiplexer selections with leaf node selections
        if self.hub.display.currentView == "router" or self.hub.display.currentView == "plex":
            self.hub.display.nodes = []

        # control key adds/removes single leaf to/from selection
        if self.hub.controlKey == True:
            if barcode in self.hub.display.nodes:
                self.hub.display.nodes.remove(barcode)
            else:
                self.hub.display.nodes.append(barcode)
                
        # shift key adds/removes range of leaf nodes to/from selection
        elif self.hub.shiftKey == True:
            if barcode in self.hub.display.nodes:
                # deselect all nodes from the same site
                # between the one node clicked on 
                # and the top most selected node
                for leaf in reversed(sorted(self.hub.display.nodes)):
                    if leaf > barcode:
                        self.hub.display.nodes.remove(leaf)
                    else:
                        break
            else:
                # select all nodes from the same site
                # between the one node clicked on 
                # and another selected node
                # with smaller barcode id
                for leaf in reversed(sorted(self.membership.keys())):
                    
                    if leaf >= barcode:
                    # leaf has larger id than the one clicked
                        pass
                    elif self.membership[leaf] == self.membership[barcode] and leaf not in self.hub.display.nodes:
                        self.hub.display.nodes.append(leaf)
                    elif self.membership[leaf] == self.membership[barcode] and leaf in self.hub.display.nodes:
                    # this is the first leaf with smaller barcode id, 
                    # from the same site, that has already been selected
                    # break for loop
                        break
                    else:
                    # leaf is not from same site, skip
                        pass
                    
                # add self
                self.hub.display.nodes.append(barcode)
            
        # default, select single leaf node
        else:
            self.hub.display.nodes = [barcode]
        
        self.hub.display.updateNode()
        self.redrawAllNodes()

    def selectRouter(self, barcode):
        self.hub.display.nodes = [barcode]
        self.hub.display.updateRouter(barcode)
        self.redrawAllNodes()
    
    def selectPlex(self, barcode):
        self.hub.display.nodes = [barcode]
        self.hub.display.infoPlex(barcode)
        self.redrawAllNodes()


    def updateRouter(self, barcode, channel):
        typeVar = self.tkobjects["routerOptionVar_%s" % barcode] 
        typeVar.set(channel)

        (nodeId, sampleInterval, oldChannel, role) = self.settings[barcode]
        self.settings[barcode] = (nodeId, sampleInterval, channel, role)
        
        #@Marcus: what is the purpose of this? is it meant to reassign
        # all children of the router at the same time?
#         for leaf in self.leafs:
#             interval, leafChannel = self.leafs[leaf]
#             
#             if leafChannel == oldChannel:
#                 self.leafs[leaf] = (interval, channel)

        self.redrawAllNodes()

    def updateLeaf(self, leaf, channel):
        typeVar = self.tkobjects["nodeOptionVar_%s" % leaf]
        typeVar.set(channel)
        (nodeId, sampleInterval, oldChannel, role) = self.settings[leaf]
#         router, newChannel = self.routers[site]
#         interval, oldChannel = self.settings[leaf]
        self.settings[leaf] = (nodeId, sampleInterval, channel, role)
        
        self.membership[leaf] = channel
        
        self.hub.display.redrawAll()
        self.redrawAllNodes()

