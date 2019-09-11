--
-- DelayedCallBack
--
-- @author TyKonKet
-- @date  08/03/17
DelayedCallBack = {}
local DelayedCallBack_mt = Class(DelayedCallBack)

function DelayedCallBack:new(callBack, callBackSelf)
    local self = setmetatable({}, DelayedCallBack_mt)
    self.callBack = callBack
    self.callBackSelf = callBackSelf
    self.callBackCalled = true
    self.delay = 0
    self.delayCounter = 0
    self.skipOneFrame = false
    return self
end

function DelayedCallBack:update(dt)
    if not self.callBackCalled then
        if not self.skipOneFrame then
            self.delayCounter = self.delayCounter + dt
        end
        if self.delayCounter >= self.delay then
            self:callCallBack()
        end
        if self.skipOneFrame then
            self.delayCounter = self.delayCounter + dt
        end
    end
end

function DelayedCallBack:call(delay, ...)
    self.callBackCalled = false
    self.otherParams = {...}
    if delay == nil or delay == 0 then
        self:callCallBack()
    else
        self.delay = delay
        self.delayCounter = 0
    end
end

function DelayedCallBack:callCallBack()
    if self.callBackSelf ~= nil then
        self.callBack(self.callBackSelf, unpack(self.otherParams))
    else
        self.callBack(unpack(self.otherParams))
    end
    self.callBackCalled = true
end
