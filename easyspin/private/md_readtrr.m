function Traj = md_readtrr(trrfile)

if ~exist(trrfile,'file')
  error('File ''%s'' does not exist.',trrfile);
end

onCleanup(@()delete('xdata.binary'));

trr2matlab(trrfile);
d = readGmx2Matlab('xdata.binary');
Traj.nSteps = d.num_frames;
Traj.dt = d.time_step*1e-12;
Traj.xyz = permute(d.trajectory,[3 2 1]); % -> (nSteps,3,nAtoms)

end


% trr2matlab.m  
% by Evan Arthur, University of Michigan, October 2011
% Matlab outputs trajectories in a relatively consistent format that is
% fundamentally challanging and inefficient for Matlab to read directly. 
% This program translates most trr files from recent versions of Gromacs  
% into binary files that can be read quickly and efficiently into Matlab
% via readGmx2Matlab.m. 
% readGmx2Matlab.m is a sibling program that reads the output of 
% this program. Currently only coordinates, velocities, and forces are 
% output. If I get requests for other outputs (box dimensions, lambda 
% parameters, etc) I'll fit it in. 
% Requirements: 
%    - Gromacs trr trajectory file (GMX trn format)
%         tested on version 4.5 and later
%    - readGmx2Matlab.m  (reads the output from this script)
%    - Free RAM: not much. Less than 500 kb for most simulations.
%    - Free Hard Disk: between 1 to 2 times the .trr you input.
%         By default the entire trajectory is copied and reformatted. It
%         takes the output, converts it into a usable format, and then it
%         rewrites the output with useful information. Temp files are 
%         removed after all calculations are done, so at most the
%         trajectory is just duplicated in a cleaner format.
% Limitations:
%    - Broken trr files. If there is a broken frame, it probably should be
%         removed before inputting the trajectory.
% Inputs:
%     - path to trr file (required, must be first input)
%     - path to output file (optional)
%         if none given, a default name is chosen (such as 'xdata.binary')
%     - 'x' (optional)
%         outputs xyz atomic coordinates
%     - 'v' (optional)
%         outputs xyz of instantaneous velocities
%     - 'f' (optional)
%         outputs xyz of atomic forces
%     - 'single' or 'double' (optional)
%         selects whether to read file as single or double precision
%         This program automatically detects this. Use this option as
%         an override.
%     - [integer] (optional)
%         output frequency on display window of the frame currently being
%         read. 1 = every frame's statistics are output. 1000 = every 1000
%         frames statistics are output
% Outputs:
%     - xyz data 
%         output either by default or if 'x' option is given
%         default name is 'xdata.binary'
%     - velocity data
%         output either by default or if 'v' option is given
%         default name is 'vdata.binary'
%     - force data
%         output either by default or if 'f' option is given
%         default name is 'fdata.binary'
% Example inputs and outputs:
%     trr2matlab ('traj.trr')
%           outputs all atomic coordinates, velocities, and forces as files
%           'xdata.binary', 'vdata.binary', and 'fdata.binary'
%     trr2matlab ('traj.trr', 'x', 'f')
%           outputs all atomic coordinates and forces as files
%           'xdata.binary' and 'fdata.binary' (velocity data is not output)
%     trr2matlab ('traj.trr', 'x')
%           outputs only atomic coordinates as file 'xdata.binary' 
%           (velocity and force data are not output)
%     trr2matlab ('traj.trr', 'f', 'proteinA')
%           outputs only atomic forces as file 'proteinA_xdata.binary' 
%           (velocity and coordinates data are not output)
%     trr2matlab ('traj.trr', 'x', 'single')
%           outputs only atomic forces as file 'xdata.binary' 
%           (velocity and force data are not output)
%           forces single precision mode
%     trr2matlab ('traj.trr', 'x', 10)
%           outputs only atomic forces as file 'xdata.binary' 
%           (velocity and force data are not output)
%           outputs statistics of information in window every 10 frames
% notes on Single/Double Precision:
%     This program detects the precision of the trr file automatically. If
%     the detection fails, write in the input 'single' or 'double'. The
%     program outputs garbage or fails spectacularly when this is not done
%     properly. 
%     
%     Since single precision exceeds the margin of error for most analyses,
%     this program only outputs data as single-precision numbers. If I get
%     requests for the excrutiatingly accurate double-precision output, I
%     will put in an option for it.
%     
function trr2matlab( trajFile, varargin )

% set file inputs and outputs
tic;
% check if input exists
if exist(trajFile, 'file')
    fprintf('Reading trajectory file %s... \n', trajFile);
else
    fprintf('Trajectory file not found, exiting program \n');
    return;
end

% decide if output name was in input, and output frequency
outputX = 'xdata.binary';
outputV = 'vdata.binary';
outputF = 'fdata.binary';
noX = varargin(~strcmp(varargin, 'x'));
noV = noX(~strcmp(noX, 'v'));
noF = noV(~strcmp(noV, 'f'));
outputEveryIntFrames = 100; % default to outputting every 100 frames
for n = 1:numel(noF)
    if isfloat(cell2mat(noF(n))) == true
        outputEveryIntFrames = floor(cell2mat(noF(n)));
    end
    if ischar(cell2mat(noF(n))) == true
        outputName = cell2mat(noF(n));
        outputX = [outputName '_xdata.binary'];
        outputV = [outputName '_vdata.binary'];
        outputF = [outputName '_fdata.binary'];
    end
end
if outputEveryIntFrames < 1
    outputEveryIntFrames = 1;
end
fprintf('outputting data every %g frames\n', outputEveryIntFrames);

% decide which files to output with booleans
writeX = any(strcmp(varargin,'x'));
writeV = any(strcmp(varargin,'v'));
writeF = any(strcmp(varargin,'f'));

% by default, write coordinates only
if writeX + writeV + writeF == 0
    writeX = true;
    writeV = false;
    writeF = false;
end

% determine single/double precision
% user override
if sum(strcmp(varargin, 'single')) > 0
    fileType = 'single';
end
if sum(strcmp(varargin, 'double')) > 0
    fileType = 'double';
end

% detect single/double
if sum(strcmp(varargin, 'single')) + sum(strcmp(varargin, 'double')) == 0
    
    TRRfile = fopen(trajFile, 'r', 'b');
    fseek(TRRfile, 0 ,'bof');
    precisionTest = fread(TRRfile, [1 9], 'int32');
    fclose(TRRfile);
    
    if precisionTest(9) == 36
        fprintf('single precision detected\n');
        fileType = 'single';
    elseif precisionTest(9) == 72
        fprintf('double precision detected\n');
        fileType = 'double';
    else
        fprintf('no precision dectected, defaulting to single precision\n');
        fileType = 'single';
    end
    
end

% parse binary from trr file
% open input trr
TRRfile = fopen(trajFile, 'r', 'b');
fseek(TRRfile, 0 ,'bof');
% remove semi-processed trajectories in same folder
system('rm -f tempx tempv tempf');
%prepare output files
WRITEfile_X = fopen('tempx', 'w', 'b');
    fwrite(WRITEfile_X, 0, 'int32');
    fwrite(WRITEfile_X, 0, 'int32');
    fwrite(WRITEfile_X, 0, 'single');
WRITEfile_V = fopen('tempv', 'w', 'b');
    fwrite(WRITEfile_V, 0, 'int32');
    fwrite(WRITEfile_V, 0, 'int32');
    fwrite(WRITEfile_V, 0, 'single');
WRITEfile_F = fopen('tempf', 'w', 'b');
    fwrite(WRITEfile_F, 0, 'int32');
    fwrite(WRITEfile_F, 0, 'int32');
    fwrite(WRITEfile_F, 0, 'single');

% initialize local variables - throws error for traj > 800,000 frames
maxNumFrames = 800000; % increase this if more than this # frames in sim!
frame_num = 1;
coord_frame = 1;
coord_time = zeros([1, maxNumFrames]);
veloc_frame = 1;
veloc_time = zeros([1, maxNumFrames]);
force_frame = 1;
force_time = zeros([1, maxNumFrames]);

data_present_words = {'coordinate  ', 'velocity  ', 'force  '};
% fix offset for end of file
[~] = fread(TRRfile, [1], '*char');
while ~feof(TRRfile)
    
    intro_words = fread(TRRfile, [1 51], '*char');
    data_present = fread(TRRfile, [1 3], 'int32');
    num_atoms = fread(TRRfile, 1, 'int32');
    frame_step = fread(TRRfile, [1 2], 'int32');
    frame_time = fread(TRRfile, 1, fileType);
    box_params = fread(TRRfile, [1 10], fileType);
    
    % display statistics in periodic intervals
    if ~mod(frame_num, outputEveryIntFrames) && 0
      fprintf(['\nopening file "%s",\n        ...%s\n' ...
        '    frame number %g contains %g atoms,\n'...
        '    and is located at time step %u\n' ...
        '    frame is set at %g ps from beginning of simulation\n' ...
        '    box dimensions are %g by %g by %g nm\n' ...
        '  %sdata present in this frame\n' ], ...
        trajFile, intro_words(12:25), frame_num, num_atoms, frame_step(1), ...
        frame_time, box_params(2), box_params(6), box_params(10), ...
        cell2mat(data_present_words(data_present ~= 0)));
    end
     
    % coordinate data
    if data_present(1)        
        coord_frame = coord_frame + 1;
        coord_time(frame_num) = frame_time;
        coord_XYZ = fread(TRRfile, [1 (num_atoms * 3)], fileType);
        if writeX
            fwrite(WRITEfile_X, coord_XYZ, 'single');
        end
    end
    
    % velocity data
    if data_present(2)
        veloc_frame = veloc_frame + 1;
        veloc_time(frame_num) = frame_time;
        velocity_XYZ = fread(TRRfile, [1 (num_atoms * 3)], fileType);
        if writeV
            fwrite(WRITEfile_V, velocity_XYZ, 'single');
        end
    end
    
    % force data
    if data_present(3) 
        force_frame = force_frame + 1;
        force_time(frame_num) = frame_time;
        force_XYZ = fread(TRRfile, [1 (num_atoms * 3)], fileType);
        if writeF == true
            fwrite(WRITEfile_F, force_XYZ, 'single');
        end
    end
    
    frame_num = frame_num + 1;
    % fix offset for end of file
    [~] = fread(TRRfile, [1], '*char');
    
end
fclose(TRRfile);

% finish processing binary output, delete temporary files
%-------------------------------------------------------------------------------
% xyz coord output
if writeX
    fprintf('\ncorrecting intro binaries of xyz data %s\n', outputX);
    
    coord_frame = coord_frame - 1;
    coord_increment = coord_time(2) - coord_time(1);
    frewind(WRITEfile_X);
    fwrite(WRITEfile_X, num_atoms, 'int32');
    fwrite(WRITEfile_X, coord_frame, 'int32');
    fwrite(WRITEfile_X, coord_increment, 'single');
    fclose(WRITEfile_X);
    movefile('tempx', outputX);
else
    fclose(WRITEfile_X);
    delete('tempx');
end

% velocity output
if writeV
    fprintf('\ncorrecting intro binaries of velocity data %s\n', outputV);
    
    veloc_frame = veloc_frame - 1;
    veloc_incriment = veloc_time(2) - veloc_time(1);
    
    frewind(WRITEfile_V);
    fwrite(WRITEfile_V, num_atoms, 'int32');
    fwrite(WRITEfile_V, veloc_frame, 'int32');
    fwrite(WRITEfile_V, veloc_incriment, 'single');
    
    fclose(WRITEfile_V);
    movefile('tempv', outputV);
else
    fclose(WRITEfile_V);
    delete('tempv');
end

% force output
if writeF
    fprintf('\ncorrecting intro binaries of force data %s\n', outputF);
    
    force_frame = force_frame - 1;
    force_incriment = force_time(2) - force_time(1);
    
    frewind(WRITEfile_F);
    fwrite(WRITEfile_F, num_atoms, 'int32');
    fwrite(WRITEfile_F, force_frame, 'int32');
    fwrite(WRITEfile_F, force_incriment, 'single');
    
    fclose(WRITEfile_F);
    movefile('tempf', outputF);
else
    fclose(WRITEfile_F);
    delete('tempf');
end

timeSpent = toc;
fprintf('\n%g seconds spent processing trajectory %s\n\n', timeSpent, trajFile);

end




% readGmx2Matlab.m  
% by Evan Arthur, University of Michigan, October 2011
% Matlab outputs trajectories in a relatively consistent format that is
% fundamentally challanging and inefficient for Matlab to read directly. 
% This program turns the output from trr2matlab.m into matricies for other
% programs to read. These are by default in a ".binary format". The matrix
% has introductory code, and the trajectory. There are options to read only
% a small portion of the trajectory with a starting frame and ending frame
% option. Skipping frames during the reading process (say, to read in every 
% other frame), is not implimented. If I get requests, I will add it.
% Requirements: 
%    - binary file from trr2matlab.m program
%    - Free RAM: a little more than the size of the binaries being read. 
%         10,000 atoms * 3 axes * 1000 frames * 4 bytes = 160 mb (single precision)
%    - Free Hard Disk: none
% Inputs:
%     - path to binary file (required, must be first input)
%     - start frame (optional)
%         integer, starts reading at this point
%     - end frame (optional)
%         integer, stops reading at this point
%
%     please note! if only one numeric input is given, this program
%     interprets that as the "end frame" and begins reading from the first
%     frame of the simulation
% Outputs:
%     - trajectory matrix
%         this is output as "coodData.trajectory" in the file
%         this is a 3D matrix is made of the trajectory with the format
%           (atom number ; xyz value ; frame number)
%     - information of trajectory 
%         coodData.num_atoms has number of atoms
%         coodData.num_frames has number of frames
%         coodData.time_step has the time increment between frames
% Example inputs and outputs:
%     [coodData] = readGmx2Matlab('xdata.binary')
%         - makes a 3D matrix (coodData.trajectory) of entire coordinate trajectory
%     [coodData] = readGmx2Matlab('vdata.binary', 1000)
%         - makes a 3D matrix (coodData.trajectory) of velocity trajectory from frames 1 to 1000
%     [coodData] = readGmx2Matlab('fdata.binary', 1000, 2000)
%         - makes a 3D matrix (coodData.trajectory) of force trajectory from frames 1000 to 2000
%
%     [coodData] = readGmx2Matlab('xdata.binary');
%     trajectory = coodData.trajectory(:,:,1:2:end);
%     for n = 1:size(trajectory,3)
%       plot3(trajectory(:,1,n), trajectory(:,2,n), trajectory(:,3,n),'.');
%       drawnow;
%       pause(0.2);
%     end
%        - plot out every other frame of trajectory as a 3D figure
function [coodData] = readGmx2Matlab(coordFile, start_frame, end_frame)

% catch if file can't be found
if exist(coordFile, 'file')
    fprintf('Reading binary file %s... \n', coordFile);
else
    fprintf('\n    Trajectory file %s not found, exiting program\n', coordFile);
    
    % return null data if trajectory not found, then exit program
    coodData.trajectory = 0;
    coodData.num_atoms = 0;
    coodData.num_frames = 0;
    coodData.time_step = 0;
    
    return;
end

% read in introductory data (first 3 numbers in file)
% open file: read-only, big-endian
file_ID = fopen(coordFile, 'r', 'b');
% extract statistics about simulation
coodData.num_atoms = fread(file_ID, 1, 'int32');
coodData.num_frames = fread(file_ID, 1, 'int32');
coodData.time_step = fread(file_ID, 1, 'single');

% interpret input options
if nargin == 3
    if (end_frame > coodData.num_frames)
        end_frame = coodData.num_frames;
    end
    
    if (start_frame > end_frame)
        fprintf(['    starting frame %g is not in trajectory\n' ...
                 ' ...exiting\n'], start_frame);
        return;
    end
    
    fprintf('    beginning from %g frame \n', start_frame);
    fprintf('    processing simulation until frame %g \n', end_frame);
elseif nargin == 2
    end_frame = start_frame;
    start_frame = 1;
    if (end_frame > coodData.num_frames)
        end_frame = coodData.num_frames;
    end
    fprintf('    processing simulation until frame %g \n', end_frame);
else 
    fprintf('    processing all frames from simulation \n');
    start_frame = 1;
    end_frame = coodData.num_frames;
end

% read in data
% find first frame to read (3 axes * 4 bytes per floating point decimal)
fseek(file_ID, (start_frame - 1)*12*coodData.num_atoms, 'cof');
% stream in data, only stream in number of frames needed
rawdata = fread(file_ID, [3 coodData.num_atoms*(end_frame - start_frame + 1)], 'single');
fclose(file_ID);
% structure data as XYZ * atoms * frames 3D matrix
coodData.trajectory = permute(reshape(rawdata,3,coodData.num_atoms,[]),[2 1 3]);
fprintf('Done reading file \n');

end


