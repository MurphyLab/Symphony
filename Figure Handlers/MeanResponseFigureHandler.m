classdef MeanResponseFigureHandler < FigureHandler
    
    properties (Constant)
        figureName = 'Mean Response'
    end
    
    properties
        meanPlots   % array of structures to store the properties of each class of epoch.
    end
    
    methods
        
        function obj = MeanResponseFigureHandler(protocolPlugin)
            obj = obj@FigureHandler(protocolPlugin);
            
            xlabel(obj.axesHandle, 'sec');
            
            obj.resetPlots();
        end
        
        
        function handleCurrentEpoch(obj)
            [responseData, sampleRate, units] = obj.protocolPlugin.response();
            
            % Check if we have existing data for this "class" of epoch.
            % The class of the epoch is defined by the set of its unique parameters.
            epochParams = obj.protocolPlugin.epochSpecificParameters();
            meanPlot = struct([]);
            for i = 1:numel(obj.meanPlots)
                if isequal(obj.meanPlots(i).params, epochParams)
                    meanPlot = obj.meanPlots(i);
                    break;
                end
            end
            
            if isempty(meanPlot)
                % This is the first epoch of this class to be plotted.
                meanPlot = {};
                meanPlot.params = epochParams;
                meanPlot.data = responseData;
                meanPlot.sampleRate = sampleRate;
                meanPlot.units = units;
                meanPlot.count = 1;
                hold(obj.axesHandle, 'on');
                meanPlot.plotHandle = plot(obj.axesHandle, 1:numel(meanPlot.data), meanPlot.data);
                obj.meanPlots(end + 1) = meanPlot;
            else
                % This class of epoch has been seen before, add the current response to the mean.
                % TODO: Adjust response data to the same sample rate and unit as previous epochs if needed.
                % TODO: if the length of data is varying then the mean will not be correct beyond the min length.
                meanPlot.data = (meanPlot.data * meanPlot.count + responseData) / (meanPlot.count + 1);
                meanPlot.count = meanPlot.count + 1;
                set(meanPlot.plotHandle, 'XData', 1:numel(meanPlot.data), ...
                                         'YData', meanPlot.data);
                obj.meanPlots(i) = meanPlot;
            end
            
            % Draw ticks every 0.1 seconds.
            maxSamples = max(arrayfun(@(x) numel(x.data), obj.meanPlots));
            duration = maxSamples / sampleRate;
            samplesPerTenth = sampleRate / 10;
            set(obj.axesHandle, 'XTick', 1:samplesPerTenth:maxSamples, ...
                                'XTickLabel', 0:.1:duration);
            
            % Update the y axis with the units of the response.
            ylabel(obj.axesHandle, units);
        end
        
        
        function clearFigure(obj)
            obj.resetPlots();
            
            clearFigure@FigureHandler(obj);
        end
        
        
        function resetPlots(obj)
            obj.meanPlots = struct('params', {}, ...        % The params that define this class of epochs.
                                   'data', {}, ...          % The mean of all responses of this class.
                                   'sampleRate', {}, ...    % The sampling rate of the mean response.
                                   'units', {}, ...         % The units of the mean response.
                                   'count', {}, ...         % The number of responses used to calculate the mean reponse.
                                   'plotHandle', {});       % The handle of the plot for the mean response of this class.
        end
        
    end
    
end