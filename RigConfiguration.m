classdef RigConfiguration < handle
    
    properties (Constant, Abstract)
        displayName
    end
    
    
    properties
        controller
    end
    
    
    properties (Dependent)
        sampleRate
    end
    
    
    properties (GetAccess = private)
        hekaDigitalOutDevice = []
        hekaDigitalOutNames = {}
        hekaDigitalOutChannels = []
    end
    
    
    properties (Hidden)
        proxySampleRate                 % numeric, in Hz
    end
    
    
    methods
        
        function obj = RigConfiguration()
            import Symphony.Core.*;
            
            obj.controller = Controller();
            obj.controller.DAQController = obj.createDAQ();
            obj.controller.Clock = obj.controller.DAQController;
            
            obj.sampleRate = 10000;
            
            try
                obj.createDevices();
                
                % Have all devices start emitting their background values.
                obj.controller.DAQController.SetStreamsBackground();
            catch ME
                obj.close();
                disp(getReport(ME));
                throw(ME);
            end
        end
        
        
        function daq = createDAQ(obj)
            % Create a Heka DAQ controller if on Windows or a simulation controller on Mac.
            import Symphony.Core.*;
            
            import Heka.*;
                
            if ~isempty(which('HekaDAQInputStream'))
                import Heka.*;
                
                % Register the unit converters
                HekaDAQInputStream.RegisterConverters();
                HekaDAQOutputStream.RegisterConverters();
                
                % Get the bus ID of the Heka ITC.
                % (Stored as a local pref so that each rig can have its own value.)
                hekaID = getpref('Symphony', 'HekaBusID', '');
                if isempty(hekaID)
                    answer = questdlg('How is the Heka connected?', 'Symphony', 'USB', 'PCI', 'Cancel', 'Cancel');
                    if strcmp(answer, 'Cancel')
                        error('Symphony:Heka:NoBusID', 'Cannot create a Heka controller without a bus ID');
                    elseif strcmp(answer, 'PCI')
                        hekaID = 1;
                    else    % USB
                        hekaID = 5;
                    end
                    setpref('Symphony', 'HekaBusID', hekaID);
                end
                
                daq = HekaDAQController(hekaID, 0);
                daq.InitHardware();
            else
                import Symphony.SimulationDAQController.*;
                
                disp('Could not load the Heka driver, using the simulation controller instead.');
                
                Converters.Register('V', 'V', @(m) m);
                daq = SimulationDAQController();
                daq.BeginSetup();
                
                daq.SimulationRunner = Simulation(@(output,step) loopbackSimulation(obj, output, step, outStream, inStream));
            end
            
            daq.Clock = daq;
        end
        
        
        function input = loopbackSimulation(obj, output, ~, outStream, inStream)
            import Symphony.Core.*;
            
            input = NET.createGeneric('System.Collections.Generic.Dictionary', {'Symphony.Core.IDAQInputStream','Symphony.Core.IInputData'});
            outData = output.Item(outStream);
            inData = InputData(outData.Data, outData.SampleRate, obj.controller.Clock.Now);
            input.Add(inStream, inData);
        end
        
        
        function set.sampleRate(obj, rate)
            import Symphony.Core.*;             % import this so this method knows what a 'Measurement' - see below - is...

            if ~isnumeric(rate)
                error('Symphony:InvalidSampleRate', 'The sample rate for a rig configuration must be a number.');
            end
            
            % Update the rate of the DAQ controller.
            srProp = findprop(obj.controller.DAQController, 'SampleRate');
            if isempty(srProp)
                obj.proxySampleRate = rate;
            else
                obj.controller.DAQController.SampleRate = Measurement(rate, 'Hz');
            end
            
            % Update the rate of all device streams.
            % TODO: is this needed?
%             devices = obj.devices();
%             for i = 1:length(devices)
%                 devices(i).SampleRate = Measurement(rate, 'Hz');
%             end
        end
        
        
        function rate = get.sampleRate(obj)
            srProp = findprop(obj.controller.DAQController, 'SampleRate');
            if isempty(srProp)
                rate = obj.proxySampleRate;
            else
                m = obj.controller.DAQController.SampleRate;
                if ~strcmp(m.Unit, 'Hz')
                    error('Symphony:SampleRateNotInHz', 'The sample rate is not in Hz.');
                end
                rate = m.QuantityInBaseUnit;
            end
        end
        
        
        function stream = streamWithName(obj, streamName, isOutput)
            import Symphony.Core.*;
            
            if isa(obj.controller.DAQController, 'Heka.HekaDAQController')     % TODO: or has method 'GetStream'?
                stream = obj.controller.DAQController.GetStream(streamName);
            else
                if isOutput
                    stream = DAQOutputStream(streamName);
                else
                    stream = DAQInputStream(streamName);
                end
                stream.SampleRate = Measurement(obj.sampleRate, 'Hz');
                stream.MeasurementConversionTarget = 'V';
                stream.Clock = obj.controller.DAQController;
                obj.controller.DAQController.AddStream(stream);
            end
        end
        
        
        function addStreams(obj, device, outStreamName, inStreamName)
            % Create and bind any output stream.
            if ~isempty(outStreamName)
                stream = obj.streamWithName(outStreamName, true);
                device.BindStream(stream);
            end
            
            % Create and bind any input stream.
            if ~isempty(inStreamName)
                stream = obj.streamWithName(inStreamName, false);
                device.BindStream(stream);
            end
        end
        
        
        function addDevice(obj, deviceName, outStreamName, inStreamName)
            import Symphony.Core.*;
            import Symphony.ExternalDevices.*;
            
            if isa(obj.controller.DAQController, 'Heka.HekaDAQController') && strncmp(outStreamName, 'DIGITAL_OUT', 11)
                % The digital out channels for the Heka ITC share a single device.
                if isempty(obj.hekaDigitalOutDevice)
                    obj.hekaDigitalOutDevice = UnitConvertingExternalDevice('Heka Digital Out', 'HEKA Instruments', obj.controller, Measurement(0, 'V'));
                    obj.hekaDigitalOutDevice.MeasurementConversionTarget = 'V';
                    obj.hekaDigitalOutDevice.Clock = obj.controller.DAQController;
                    
                    stream = obj.streamWithName('DIGITAL_OUT.1', true);
                    obj.hekaDigitalOutDevice.BindStream(stream);
                end
                
                % Keep track of which virtual device names map to which channel of the real device.
                obj.hekaDigitalOutNames{end + 1} = deviceName;
                obj.hekaDigitalOutChannels(end + 1) = str2double(outStreamName(end));
            else
                dev = UnitConvertingExternalDevice(deviceName, 'unknown', obj.controller, Measurement(0, 'V'));
                dev.MeasurementConversionTarget = 'V';
                dev.Clock = obj.controller.DAQController;
                
                obj.addStreams(dev, outStreamName, inStreamName);
            end
        end
        
        
        function mode = multiClampMode(obj, deviceName)
            if nargin == 2 && ~isempty(deviceName)
                device = obj.deviceWithName(deviceName);
            else
                % Find a MultiClamp device to query.
                device = [];
                devices = listValues(obj.controller.Devices);
                for i = 1:length(devices)
                    if isa(devices{i}, 'Symphony.ExternalDevices.MultiClampDevice')
                        device = devices{i};
                        break;
                    end
                end
            end

            if isempty(device)
                error('Symphony:MultiClamp:NoDevice', 'Cannot determine the MultiClamp mode because no MultiClamp device has been created.');
            end

            % Make sure the user toggles the MultiClamp mode so the data gets telegraphed.
            mode = '';
            while isempty(mode) || (~strcmp(mode, 'VClamp') && ~strcmp(mode, 'I0') && ~strcmp(mode, 'IClamp'))
                gotMode = false;
                try
                    mode = char(device.DeviceParametersForInput(System.DateTimeOffset.Now).Data.OperatingMode);
                    if strcmp(mode, 'VClamp') || strcmp(mode, 'I0') || strcmp(mode, 'IClamp')
                        gotMode = true;
                    end
                catch ME %#ok<NASGU>
                end

                if ~gotMode
                    answer = questdlg('Please toggle the MultiClamp commander mode.', 'Symphony', 'OK', 'Cancel', 'OK');
                    if strcmp(answer, 'Cancel')
                        error('Symphony:MultiClamp:UnknownMode', 'The MultiClamp mode could not be determined.');
                    end
                end
            end
        end
        
        
        function addMultiClampDevice(obj, deviceName, channel, outStreamName, inStreamName)
            import Symphony.Core.*;
            import Symphony.ExternalDevices.*;
            
            if channel ~= 1 && channel ~= 2
                error('Symphony:MultiClamp:InvalidChannel', 'The MultiClamp channel must be either 1 or 2.');
            end
            
            % TODO: validate that the same channel is not added a second time?
            
            % Get the local serial number of the MultiClamp.
            % (Stored as a local pref so that each rig can have its own value.)
            multiClampSN = getpref('MultiClamp', 'SerialNumber', '');
            if isempty(multiClampSN)
                answer = inputdlg({'Enter the serial number of the MultiClamp:'}, 'Symphony', 1, {'831400'});
                if isempty(answer)
                    error('Symphony:MultiClamp:NoSerialNumber', 'Cannot create a MultiClamp device without a serial number');
                else
                    multiClampSN = uint32(str2double(answer{1}));
                    setpref('MultiClamp', 'SerialNumber', multiClampSN);
                end
            end
            
            % Create the device so we can query for the current mode.
            modes = NET.createArray('System.String', 3);
            modes(1) = 'VClamp';
            modes(2) = 'I0';
            modes(3) = 'IClamp';
            
            backgroundMeasurements = NET.createArray('Symphony.Core.IMeasurement', 3);
            backgroundMeasurements(1) = Measurement(0, 'V');
            backgroundMeasurements(2) = Measurement(0, 'A');
            backgroundMeasurements(3) = Measurement(0, 'A');
            
            dev = MultiClampDevice(multiClampSN, channel, obj.controller.DAQController, obj.controller,...
                modes,...
                backgroundMeasurements...
                );
            dev.Name = deviceName;
            dev.Clock = obj.controller.DAQController;
            
            % Bind the streams.
            obj.addStreams(dev, outStreamName, inStreamName);
            
            % Make sure the current mode of the MultiClamp is known.
            try
                obj.multiClampMode(deviceName);
            catch ME
                dev.Controller = [];
                obj.controller.Devices.Remove(dev);
                throw(ME);
            end
        end
        
        
        function d = devices(obj)
            d = listValues(obj.controller.Devices);
        end
        
        
        function [device, digitalChannel] = deviceWithName(obj, name)
            ind = find(strcmp(obj.hekaDigitalOutNames, name));
            
            if isempty(ind)
                device = obj.controller.GetDevice(name);
                digitalChannel = [];
            else
                device = obj.hekaDigitalOutDevice;
                digitalChannel = obj.hekaDigitalOutChannels(ind);
            end
        end
        
        
        function desc = describeDevices(obj)
            desc = '';
            devices = obj.devices();
            for i = 1:length(devices)
                [~, streams] = dictionaryKeysAndValues(devices{i}.Streams);
                for j = 1:length(streams)
                    if isa(streams{j}, 'Symphony.Core.IDAQInputStream')
                        desc = [desc sprintf('%s  <--  %s\n', char(devices{i}.Name), char(streams{j}.Name))]; %#ok<AGROW>
                    else
                        desc = [desc sprintf('%s  -->  %s\n', char(devices{i}.Name), char(streams{j}.Name))]; %#ok<AGROW>
                    end
                end
            end
        end
        
        
        function setDeviceBackground(obj, deviceName, background)
            device = obj.deviceWithName(deviceName);
            device.Background = background;
        end
        
        
        function close(obj)
            % Release any hold we have on hardware.
            if isa(obj.controller.DAQController, 'Heka.HekaDAQController')
                obj.controller.DAQController.CloseHardware();
            end
        end
        
    end
    
    
    methods (Abstract)
        
        createDevices(obj);
        
    end
    
end


%% To support units coversion:
%
% fromUnits = 'foo'
% toUnits = 'V'
% Converters.Register(fromUnits, toUnits, @conversionProc);
% 
% 
% function measurementOut = conversionProc(measurementIn)
%   ...
% end
