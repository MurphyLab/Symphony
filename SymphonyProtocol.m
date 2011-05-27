classdef SymphonyProtocol < handle
    % Create a sub-class of this class to define a protocol.
    %
    % Interesting methods to override:
    % * prepareEpochGroup
    % * prepareEpoch
    % * completeEpoch
    % * continueEpochGroup
    % * completeEpochGroup
    %
    % Useful methods:
    % * addStimulus
    % + setDeviceBackground
    % + recordResponse
    
    properties (Constant, Abstract)
        identifier
        version
    end
    
    
    properties
        controller      % A Symphony.Core.Controller instance.
        epoch = []      % A Symphony.Core.Epoch instance.
        epochNum = 0    % The number of epochs that have been run.
    end
    
    
    methods
        
        function obj = SymphonyProtocol(controller)
            obj = obj@handle();
            
            obj.controller = controller;
        end
        
        
        function prepareEpochGroup(obj) %#ok<MANU>
            % Override this method to perform any actions before the start of the first epoch, e.g. open a figure window, etc.
        end
        
        
        function pn = parameterNames(obj)
            % Return a cell array of strings containing the names of the user-defined parameters.
            % By default any parameters defined by a protocol are included.
            
            % TODO: exclude parameters that start with an underscore?
            
            excludeNames = {'identifier', 'version', 'controller', 'epoch', 'epochNum'};
            names = properties(obj);
            pn = {};
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                if ~any(strcmp(name, excludeNames))
                    pn{end + 1} = name; %#ok<AGROW>
                end
            end
            pn = pn';
        end
        
        
        function p = parameters(obj)
            % Return a struct containing the user-defined parameters.
            % By default any parameters defined by a protocol are included.
            
            names = obj.parameterNames();
            for nameIndex = 1:numel(names)
                name = names{nameIndex};
                p.(name) = obj.(name);
            end
        end
        
        
        function prepareEpoch(obj) %#ok<MANU>
            % Override this method to add stimulii, record responses, change parameters, etc.
            
            % TODO: record responses for all inputs by default?
        end
        
        
        function addStimulus(obj, deviceName, stimulusID, stimulusData)
            % Queue data to send to the named device when the epoch is run.
            % TODO: need to specify data units?
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            if isempty(which('NET.createGeneric'))
                stimDataList = GenericList();
            else
                stimDataList = NET.createGeneric('System.Collections.Generic.List', {'Symphony.Core.Measurement'}, length(stimulusData));
            end
            for i=1:length(stimulusData)
                stimDataList.Add(Measurement(stimulusData(i), 'V'));
            end

            outputData = OutputData(stimDataList, obj.controller.DAQController.GetStream('OUT').SampleRate, true);

            stim = RenderedStimulus(stimulusID, structToDictionary(struct()), outputData);

            obj.epoch.Stimuli.Add(device, stim);
        end
        
        
        function setDeviceBackground(obj, deviceName, volts)
            % Set a constant stimulus value to be sent to the device.
            % TODO: totally untested
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            obj.epoch.Background.Add(device, Epoch.EpochBackground(Measurement(volts, 'V'), obj.controller.DAQController.GetStream('OUT').SampleRate));
        end
        
        
        function recordResponse(obj, deviceName)
            % Record the response from the device with the given name when the epoch runs.
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            obj.epoch.Responses.Add(device, Response());
        end
        
        
        function r = response(obj, deviceName)
            % Return the response recorded from the device with the given name.
            
            if nargin == 1
                if isempty(which('NET.createGeneric'))
                    device = obj.epoch.Responses.Keys{1};
                else
                    keys = obj.epoch.Responses.Keys.GetEnumerator();
                    keys.MoveNext();
                    device = keys.Current();
                end
            else
                device = obj.controller.GetDevice(deviceName);
                % TODO: what happens when there is no device with that name?
            end
            
            % Extract the raw data.
            response = obj.epoch.Responses.Item(device);
            data = response.Data.Data;
            r = zeros(1, data.Count);
            for i = 1:data.Count
                r(i) = data.Item(i - 1).Quantity;
            end
        end
        
        
        function r = responseSampleRate(obj, deviceName)
            % Return the sample rate of the response recorded from the device with the given name.
            % TODO: totally untested
            
            if nargin == 1
                if isempty(which('NET.createGeneric'))
                    device = obj.epoch.Responses.Keys{1};
                else
                    keys = obj.epoch.Responses.Keys.GetEnumerator();
                    keys.MoveNext();
                    device = keys.Current();
                end
            else
                device = obj.controller.GetDevice(deviceName);
                % TODO: what happens when there is no device with that name?
            end
            response = obj.epoch.Responses.Item(device);
            r = response.Data.SampleRate.QuantityInBaseUnit;
            % TODO: do we care about the units of the SampleRate measurement?
        end
        
        
        function completeEpoch(obj) %#ok<MANU>
            % Override this method to perform any post-analysis, etc. on the current epoch.
        end
        
        
        function keepGoing = continueEpochGroup(obj) %#ok<MANU>
            % Override this method to return true/false based on the current state.
            % The object's epochNum is typically useful.
            
            keepGoing = false;
        end
        
        
        function completeEpochGroup(obj) %#ok<MANU>
            % Override this method to perform any actions after the last epoch has completed.
        end
        
    end
    
end