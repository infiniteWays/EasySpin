function [err,data] = test(opt,olddata)

% System ------------------------
Sys.S = [3/2];
Sys.D = 200;
Sys.g = gfree;

% Experiment -------------------
Pulse.Type = 'quartersin/linear';
Pulse.trise = 0.015; % us

Exp.t = [0.1 0.5];
Exp.Pulses = {Pulse 0};
Exp.Field = 1195; 
Exp.TimeStep = 0.0001; % us
Exp.Frequency = [-0.100 0.100];
Exp.Flip = [pi pi];
Exp.mwFreq = 33.5;
Exp.DetEvents = [1 1]; 

% Options ---------------------------
Opt.DetOperator = {'z1'};
Opt.FrameShift = 32;

[t1, signal1] = spidyan(Sys,Exp,Opt);

data.t1 = t1;
data.signal1 = signal1;

if ~isempty(olddata)
  err = ~areequal(signal1,olddata.signal1,1e-4);
else
  err = [];
end

