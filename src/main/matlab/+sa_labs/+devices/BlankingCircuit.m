classdef BlankingCircuit < symphonyui.core.Device
    
    properties (Access = private)
        serialPortObject
    end

    methods
        
        function obj = BlankingCircuit(comPort)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('blankingCircuit', 'Schwartz Lab', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            if comPort > 0
                devs = instrfind('port',comPort);
                if isempty(devs)
                    obj.serialPortObject = serial(comPort, 'baudrate', 9600);
                else
                    obj.serialPortObject = devs(1);
                end
                if strcmp(obj.serialPortObject.status, 'closed')
                    fopen(obj.serialPortObject);
                end
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
        end
        
        function status = isBlanking(obj, LEDs)
            % status = false(numel(LEDs),1);
            % for i = 1:numel(LEDs)
            %     if LEDs(i) < 0
            %         status(i) = -1;
            %     else
            %         status(i) = obj.write(LEDs(i));%,'uint8', 'uint8');
            %     end
            % end
            self.writeline('1\n');
            status = ones(size(LEDs)) * self.readline('%d\n');
        end

        function blank(obj, LEDs, levels)
            % for i = 1:numel(LEDs) 
            %     if LEDs(i) < 0
            %         continue;
            %     else
            %         obj.write([LEDs(i) + 3, levels(i)],'uint8'); %something like this...
            %     end
            % end
            if all(levels == 1) || all(levels == 0)
                obj.writeline('2,%d\n',levels(1));
            else
                error('All leds msut be blanked at the same time in current implementation.')
            end
        end

        % function unblank(obj, LED)
        %     obj.serialPortObject.flush();
        %     obj.serialPortObject.write([LEDs(i) + 3, 0],'uint8'); %something like this...
        % end

        % function status = getLevel(obj, LEDs)
        %     status = zeros(numel(LEDs),1);
        %     for i = 1:numel(LEDs)
        %         if LEDs(i) < 0
        %             status(i) = -1;
        %         else
        %             status(i) = obj.write(LEDs(i)+6,'uint8', 'uint16');
        %         end     
        %     end
        % end
            
        % function setLevel(obj, LEDs, levels)
        %     for i = 1:numel(LEDs)
        %         if LEDs(i) < 0
        %             continue
        %         else
        %             obj.write([LEDs(i) + 9, levels(i)],'uint8'); %something like this...
        %         end
        %     end
        % end

        function writeline(self, varargin)
            fprintf(self.serialPortObject, varargin{:});
        end

        function data = readline(self, varargin)
            tstart = tic;
            data = [];
            while toc(tstart)<0.1 && ~get(self.serialPortObject, 'BytesAvailable')
            end
            if get(self.serialPortObject, 'BytesAvailable')
                data = fscanf(self.serialPortObject, varargin{:});
            end
        end

        function close(obj)
            fclose(obj.serialPortObject);
        end


        function delete(obj)           
            delete(obj.serialPortObject);
        end
    end

    
end