classdef SymphonyProtocol < handle & matlab.mixin.Copyable
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
    % * setDeviceBackground
    % * recordResponse
    
    properties (Constant, Abstract)
        identifier
        version
        displayName
    end
    
    
    properties
        controller                  % A Symphony.Core.Controller instance.
        epoch = []                  % A Symphony.Core.Epoch instance.
        epochNum = 0                % The number of epochs that have been run.
        parametersEdited = false    % A flag indicating whether the user has edited the parameters.
        responses                   % A structure for caching converted responses.
    end
    
    
    methods
        
        function obj = SymphonyProtocol(controller)
            obj = obj@handle();
            
            obj.controller = controller;
            obj.responses = containers.Map();
        end 
        
        
        function prepareEpochGroup(obj) %#ok<MANU>
            % Override this method to perform any actions before the start of the first epoch, e.g. open a figure window, etc.
        end
        
        
        function pn = parameterNames(obj)
            % Return a cell array of strings containing the names of the user-defined parameters.
            % By default any parameters defined by a protocol are included.
            
            % TODO: exclude parameters that start with an underscore?
            
            excludeNames = {'identifier', 'version', 'displayName', 'controller', 'epoch', 'epochNum', 'parametersEdited', 'responses'};
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
        
        
        function addParameter(obj, name, value)
            obj.epoch.ProtocolParameters.Add(name, value);
        end
        
        
        function p = epochSpecificParameters(obj)
            % Determine the parameters unique to the current epoch.
            % TODO: diff against the previous epoch's parameters instead?
            protocolParams = obj.parameters();
            p = structDiff(dictionaryToStruct(obj.epoch.ProtocolParameters), protocolParams);
        end
        
        
        function r = deviceSampleRate(obj, device, inOrOut) %#ok<MANU>
            % Return the output sample rate for the given device based on any bound stream.
            
            import Symphony.Core.*;
            
            r = Measurement(10000, 'Hz');   % default if no output stream is found
            [~, streams] = dictionaryKeysAndValues(device.Streams);
            for index = 1:numel(streams)
                stream = streams{index};
                if (strcmp(inOrOut, 'IN') && isa(stream, 'DAQInputStream')) || (strcmp(inOrOut, 'OUT') && isa(stream, 'DAQOutputStream'))
                    r = stream.SampleRate;
                    break;
                end
            end
        end
        
        
        function addStimulus(obj, deviceName, stimulusID, stimulusData)
            % Queue data to send to the named device when the epoch is run.
            % TODO: need to specify data units?
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            stimDataList = Measurement.FromArray(stimulusData, 'V');

            outputData = OutputData(stimDataList, obj.deviceSampleRate(device, 'OUT'), true);

            stim = RenderedStimulus(stimulusID, structToDictionary(struct()), outputData);

            obj.epoch.Stimuli.Add(device, stim);
            
            % Clear out the cache of responses now that we're starting a new epoch.
            % TODO: this would be cleaner to do in prepareEpoch() but that would require all protocols to call the super method...
            obj.responses = containers.Map();
        end
        
        
        function setDeviceBackground(obj, deviceName, volts)
            % Set a constant stimulus value to be sent to the device.
            % TODO: totally untested
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            obj.epoch.SetBackground(device, Measurement(volts, 'V'), obj.deviceSampleRate(device, 'OUT'));
        end
        
        
        function recordResponse(obj, deviceName)
            % Record the response from the device with the given name when the epoch runs.
            
            import Symphony.Core.*;
            
            device = obj.controller.GetDevice(deviceName);
            % TODO: what happens when there is no device with that name?
            
            obj.epoch.Responses.Add(device, Response());
        end
        
        
        function [r, s, u] = response(obj, deviceName)
            % Return the response, sample rate and units recorded from the device with the given name.
            
            import Symphony.Core.*;
            
            if nargin == 1
                % If no device specified then pick the first one.
                devices = dictionaryKeysAndValues(obj.epoch.Responses);
                if isempty(devices)
                    error('Symphony:NoDevicesRecorded', 'No devices have had their responses recorded.');
                end
                device = devices{1};
            else
                device = obj.controller.GetDevice(deviceName);
                % TODO: what happens when there is no device with that name?
            end
            
            deviceName = char(device.Name);
            
            if isKey(obj.responses, deviceName)
                % Use the cached response data.
                response = obj.responses(deviceName);
                r = response.data;
                s = response.sampleRate;
                u = response.units;
            else
                % Extract the raw data.
                response = obj.epoch.Responses.Item(device);
                data = response.Data.Data;
                r = double(Measurement.ToQuantityArray(data));
                u = char(Measurement.HomogenousUnits(data));
                
                s = response.Data.SampleRate.QuantityInBaseUnit;
                % TODO: do we care about the units of the SampleRate measurement?
                
                % Cache the results.
                obj.responses(deviceName) = struct('data', r, 'sampleRate', s, 'units', u);
            end
        end
        
        
        function stats = responseStatistics(obj) %#ok<MANU>
            stats = {};
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