classdef CsvReader < handle
    properties
        Filename
        NRows
        NColumns
        Headers
        HeadersAsVarNames
    end

    properties (Access = private)
        SafeFilename
        RowFormat
        Data
    end

    methods (Access = public)
        function self = CsvReader(filename)
            self.Filename = filename;
            self.SafeFilename = strrep(filename, ' ', '\ ');
            self.ValidateFileExists();
            self.ProbeNColumns();
            self.ProbeNRows();
            self.ProbeHeaders();
            self.ProbeRowFormat();
        end

        function Read(self)
            fid = fopen(self.Filename, 'r');
            assert(fid ~= 0);
            self.Data = textscan(fid, self.RowFormat, ...
                                 'HeaderLines', 1, 'DELIMITER', ',');
            fclose(fid);
            if (length(self.Data{1}) ~= self.NRows - 1)
                error(['Could not parse entire file - number of parsed ' ...
                    'rows (%d) differs from actuall number of rows (%d)'], ...
                    length(self.Data{2}), self.NRows - 1);
            end
        end

        function data = GetColumnByIndex(self, index)
            validateattributes(index, {'numeric'}, {'nonempty'});
            data = self.Data{index};
        end

        function data = GetColumnByExcelIndex(self, excelIndex)
            validateattributes(excelIndex, {'char'}, {'nonempty'});
            index = CsvReader.ExcelIndexToIndex(excelIndex);
            data = self.GetColumnByIndex(index);
        end

        function CreateVarFromColumnByIndex(self, index)
            validateattributes(index, {'numeric'}, {'nonempty'});
            name = self.HeadersAsVarNames{index};
            data = self.Data{index};
            assignin('base', name, data);
        end

        function CreateVarFromColumnByExcelIndex(self, excelIndex)
            validateattributes(excelIndex, {'char'}, {'nonempty'});
            index = CsvReader.ExcelIndexToIndex(excelIndex);
            self.CreateVarFromColumnByIndex(index)
        end

        function header = GetHeaderByIndex(self, index)
            validateattributes(index, {'numeric'}, {'nonempty'});
            header = self.Headers{index};
        end

        function header = GetHeaderByExcelIndex(self, excelIndex)
            validateattributes(excelIndex, {'char'}, {'nonempty'});
            index = CsvReader.ExcelIndexToIndex(excelIndex);
            header = self.GetHeaderByIndex(index);
        end

        function data = GetData(self)
            data = self.Data;
        end
    end % methods (Access = public)

    methods (Access = private)
        function ValidateFileExists(self)
            if ~exist(self.Filename, 'file');
                error('File %s does not exist', self.Filename);
            end
        end
        function ProbeNColumns(self)
            file = self.SafeFilename;
            cmd = ['head -n 1 ' file ' | tr '','' ''\n'' | ', ...
                   'wc -l | awk ''{print $1}'''];
            [status, output] = system(cmd);
            assert(status == 0);
            self.NColumns = str2double(output);
        end

        function ProbeNRows(self)
            file = self.SafeFilename;
            cmd = ['wc -l ' file ' | awk ''{print $1}'''];
            [status, output] = system(cmd);
            assert(status == 0);
            self.NRows = str2double(output);
        end

        function ProbeHeaders(self)
            cmd = ['head -n 1 ' self.SafeFilename];
            [status, output] = system(cmd);
            assert(status == 0);
            self.Headers = strsplit(output, ',');
            self.HeadersAsVarNames = genvarname(self.Headers);
        end

        function ProbeRowFormat(self)
            cmd = ['head -n 2 ' self.SafeFilename ' | tail -n 1'];
            [status, output] = system(cmd);
            assert(status == 0);
            row_values = strsplit(output, ',');
            formats = cell(1, self.NColumns);
            for i = 1:length(row_values)
                formats{i} = CsvReader.DetectValueFormat(row_values{i});
            end
            self.RowFormat = strjoin(formats, '');
        end
    end % methods (Access = private)

    methods (Static, Access = private)
        function format = DetectValueFormat(val)
            val = strtrim(val);
            if isempty(val)
                format = '%s';
            elseif ~isempty(regexp(val, '^-?[0-9]+.[0-9]+$', 'once')) % floats
                format = '%f';
            elseif ~isempty(regexp(val, '^-?[0-9]+$', 'once')) % integers
                    format = '%d';
            else
                    format = '%s';
            end
        end

        function index = ExcelIndexToIndex(excelIndex)
            validateattributes(excelIndex, {'char'}, {'nonempty'});
            if ~isempty(regexp(excelIndex, '[^A-Z]', 'once'))
                error('excelIndex must be all caps');
            end
            A = uint8('A');
            Z = uint8('Z');

            index = 0;
            for i = 1:length(excelIndex)
                index = index * (Z - A + 1);
                c = excelIndex(i);
                index = index + uint8(c) - A + 1;
            end
        end
    end % methods (Static, Acces = private)
end % classdef
