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
        
        function [stimulus, freqScale] = stimulusForEpoch(obj, epochNum)
            if obj.rampFrequency
                freqScale = 1000.0 / double(epochNum);
            else
                freqScale = 1000.0;
            end
            stimulus = 1000.*sin((1:double(obj.stimSamples)) / freqScale);
        end
        
        
        function stimuli = sampleStimuli(obj)
            stimuli = cell(obj.epochMax, 1);
            for i = 1:obj.epochMax
                stimuli{i} = obj.stimulusForEpoch(i);
            end
        end
        
        
        function prepareEpochGroup(obj)
            obj.openFigure('Response');
            obj.openFigure('Custom', 'Name', 'Foo', ...
                                     'UpdateCallback', @updateFigure);
        end
        
        
        function updateFigure(obj, axesHandle)
            cla(axesHandle)
            set(axesHandle, 'XTick', [], 'YTick', []);
            text(0.5, 0.5, ['Epoch ' num2str(obj.epochNum)], 'FontSize', 48, 'HorizontalAlignment', 'center');
        end
        
        
        function prepareEpoch(obj)
            [stimulus, freqScale] = obj.stimulusForEpoch(obj.epochNum);
            obj.addParameter('freqScale', freqScale);
            obj.addStimulus('test-device', 'test-stimulus', stimulus);
            
            obj.setDeviceBackground('test-device', 0);
            
            obj.recordResponse('test-device');
        end
        
        
        function keepGoing = continueEpochGroup(obj)
            keepGoing = obj.epochNum < obj.epochMax;
        end

    end
end