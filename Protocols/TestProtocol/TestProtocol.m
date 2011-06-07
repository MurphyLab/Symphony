classdef TestProtocol < SymphonyProtocol
    
    properties (Constant)
        identifier = 'org.janelia.research.murphy.test'
        version = 1
        displayName = 'Test'
    end
    
    properties
        epochMax = uint8(4)
        stimSamples = uint32(100)
        rampFrequency = true
    end
    
    methods
        
        function obj = TestProtocol(controller)
            obj = obj@SymphonyProtocol(controller);
        end
        
        
        function prepareEpoch(obj)
            if obj.rampFrequency
                freqScale = 1000 / obj.epochNum;
            else
                freqScale = 1000;
            end
            obj.addParameter('freqScale', freqScale);
            obj.addStimulus('test-device', 'test-stimulus', sin((1:double(obj.stimSamples)) / freqScale));
            
            obj.setDeviceBackground('test-device', 0);
            
            obj.recordResponse('test-device');
        end
        
        
        function stats = responseStatistics(obj)
            r = obj.response();
            
            stats.mean = mean(r);
            stats.var = var(r);
        end
        
        
        function keepGoing = continueEpochGroup(obj)
            keepGoing = obj.epochNum < obj.epochMax;
        end

    end
end