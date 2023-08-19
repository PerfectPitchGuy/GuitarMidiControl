-- https://hexler.net/touchosc/manual/script-examples
-- 
-- Set up TouchOSC connections similar to this (Morningstar MC6 is my USB MIDI controller):
-- Connection 1 - Send to TouchOSC Bridge, Receive from Morningstar MC6
-- Connection 2 - Send to IAC Driver Bus 1, Receive from <Bridge 1>

-------------------------------------------------------------
-- Set up variables for time related functionality
-------------------------------------------------------------
local now = getMillis()
local delay = 30 -- Midi messages will be sent at a frequencey of once per delay time elapsed in milliseconds set here
local last = 0

-- Global variables for readability
MIDI_CH_1 = 1
MIDI_CH_2 = 2
MIDI_CH_3 = 3
MIDI_CH_4 = 4

-------------------------------------------------------------
-- Initial function, not doing much here
-------------------------------------------------------------
function init()
  print("GuitarControl started at" ,now)
end

-------------------------------------------------------------
-- Function for creating instances of MIDI CC Outputs 
-------------------------------------------------------------
function ccOutMessage(ccNum, defaultVal)
    local instance = {}
    
    instance.ccNum = ccNum
    instance.defaultVal = defaultVal
    instance.currentVal = defaultVal
    
    return instance
end

-------------------------------------------------------------
-- Function to confirm message from foot switch press
-------------------------------------------------------------
function footPressed(message, inChannel, ccNumIn)
  
  local chanOffset = inChannel - 1
  
  if message[1] == (MIDIMessageType.CONTROLCHANGE + chanOffset) and message[2] == ccNumIn then
    return true
  else
    return false
  end
end

-------------------------------------------------------------
-- Function for creating instances of footswitch mappings 
-------------------------------------------------------------
function ccMap(ccNumOut, ccNumOutVal1, ccNumOutVal2)
    local instance = {}
    
    instance.ccNumOut = ccNumOut
    instance.ccNumOutVal1 = ccNumOutVal1
    instance.ccNumOutVal2 = ccNumOutVal2
    instance.ccNumOutGoVal1 = false
    instance.ccNumOutGoVal2 = false

    -- Set booleans to go to Val1/2 based on current val
    function instance:toggleVal(ccNumOutCurrentVal)
      
      -- setting the "go" booleans for MIDI cc value toggling
      if ccNumOutCurrentVal ~= self.ccNumOutVal1 then
        self.ccNumOutGoVal1 = true
        self.ccNumOutGoVal2 = false
      elseif ccNumOutCurrentVal ~= self.ccNumOutVal2 then
        self.ccNumOutGoVal1 = false
        self.ccNumOutGoVal2 = true
      end
    end
    
    -- Return True if footswitch instance is currently incrementing value
    function instance:isUpdating()
      if self.ccNumOutGoVal1==true or self.ccNumOutGoVal2==true then
        return true
      else
        return false
      end
    end
    
    -- increment & send midi messages out
    function instance:updateMidi(ccNumOutCurrentVal)
      --if not at desired value then increment towards it
      if self.ccNumOutGoVal2 and ccNumOutCurrentVal < self.ccNumOutVal2 then
        ccNumOutCurrentVal = ccNumOutCurrentVal+1
        sendMIDI({ MIDIMessageType.CONTROLCHANGE+1, self.ccNumOut, ccNumOutCurrentVal })
      elseif self.ccNumOutGoVal2 and ccNumOutCurrentVal > self.ccNumOutVal2 then
        ccNumOutCurrentVal = ccNumOutCurrentVal-1
        sendMIDI({ MIDIMessageType.CONTROLCHANGE+1, self.ccNumOut, ccNumOutCurrentVal })
      elseif self.ccNumOutGoVal1 and ccNumOutCurrentVal < self.ccNumOutVal1 then
        ccNumOutCurrentVal = ccNumOutCurrentVal+1
        sendMIDI({ MIDIMessageType.CONTROLCHANGE+1, self.ccNumOut, ccNumOutCurrentVal })
      elseif self.ccNumOutGoVal1 and ccNumOutCurrentVal > self.ccNumOutVal1 then
        ccNumOutCurrentVal = ccNumOutCurrentVal-1
        sendMIDI({ MIDIMessageType.CONTROLCHANGE+1, self.ccNumOut, ccNumOutCurrentVal })
      else
        -- stop incrementing because desired value reached
        self.ccNumOutGoVal2 = false
        self.ccNumOutGoVal1 = false
      end
      
      --print(self.ccNumOutGoVal2, self.ccNumOutGoVal1, ccNumOutCurrentVal)
      return ccNumOutCurrentVal
    end
    
    return instance
end

-------------------------------------------------------------
-- Declare all footswitch mappings here
-- Note, my MainStage doesn't like ccNumOut = 0
-------------------------------------------------------------
local reverbFeedback = ccOutMessage(1,64)
local delayFeedback = ccOutMessage(2,64)
local delayReverbVol = ccOutMessage(3,64)
local ampInVol = ccOutMessage(4,73)
local ampOutVol = ccOutMessage(5,59)

local footswitch0 = ccMap(reverbFeedback.ccNum,64,102)  -- reverb feedback, 50%, 78%
local footswitch1 = ccMap(delayFeedback.ccNum,90,102)  -- delay feedback, 40%, 80%
local footswitch2 = ccMap(delayReverbVol.ccNum,0,30)   -- DelayReverb vol dry drier
local footswitch3 = ccMap(delayReverbVol.ccNum,91,80)  -- DelayReverb vol default
local footswitch4 = ccMap(reverbFeedback.ccNum,10,20)  -- Reverb feedback for dry
local footswitch5 = ccMap(delayFeedback.ccNum,64,66)  -- Delay feedback, 0%, 1%
local footswitch6 = ccMap(ampInVol.ccNum,72,86)
local footswitch7 = ccMap(ampOutVol.ccNum,53,49)
local footswitch8 = ccMap(reverbFeedback.ccNum,64,102)
local footswitch9 = ccMap(delayFeedback.ccNum,90,102)
-------------------------------------------------------------
-- MIDI message listener
-------------------------------------------------------------
function onReceiveMIDI(message, connections)
  --print('onReceiveMIDI')
  --print('\t message     =', table.unpack(message))
  --print('\t connections =', table.unpack(connections))
  
  -- If currently updating then don't toggle anything new
  if footswitch0:isUpdating() or 
     footswitch1:isUpdating() or
     footswitch2:isUpdating() or
     footswitch3:isUpdating() or
     footswitch4:isUpdating() or
     footswitch5:isUpdating() or
     footswitch6:isUpdating() or
     footswitch7:isUpdating() or
     footswitch8:isUpdating() or
     footswitch9:isUpdating() then
          -- do nothing
          
  -- Set up footPressed events to trigger one or many footswitch toggles
  elseif footPressed(message, MIDI_CH_1, 0) then
    footswitch0:toggleVal(reverbFeedback.currentVal)
    footswitch1:toggleVal(delayFeedback.currentVal)
    footswitch3:toggleVal(delayReverbVol.currentVal)
  elseif footPressed(message, MIDI_CH_1, 1) then 
    footswitch2:toggleVal(delayReverbVol.currentVal)
    footswitch4:toggleVal(reverbFeedback.currentVal)
    footswitch5:toggleVal(delayFeedback.currentVal)
  elseif footPressed(message, MIDI_CH_1, 2) then 
    footswitch6:toggleVal(ampInVol.currentVal)
    footswitch7:toggleVal(ampOutVol.currentVal)
  else
    --
  end 
end

-------------------------------------------------------------
-- The main process looper
-------------------------------------------------------------
function update()
  
  local now = getMillis()
  
  -- Slow down loop processing to one cycle per delay interval elapsed
  if(now - last > delay) then
    last = now
    
    -- call all our personalised footswitches
    reverbFeedback.currentVal = footswitch0:updateMidi(reverbFeedback.currentVal)
    delayFeedback.currentVal = footswitch1:updateMidi(delayFeedback.currentVal)
    delayReverbVol.currentVal = footswitch2:updateMidi(delayReverbVol.currentVal)
    delayReverbVol.currentVal = footswitch3:updateMidi(delayReverbVol.currentVal)
    reverbFeedback.currentVal = footswitch4:updateMidi(reverbFeedback.currentVal)
    delayFeedback.currentVal = footswitch5:updateMidi(delayFeedback.currentVal)
    ampInVol.currentVal = footswitch6:updateMidi(ampInVol.currentVal)
    ampOutVol.currentVal = footswitch7:updateMidi(ampOutVol.currentVal)
  else
    -- delibrately do nothing
  end
end
