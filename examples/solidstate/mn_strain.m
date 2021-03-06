% Mn(II) at X band with D strain
%==========================================================================
% Here we simulate the spectrum of a typical Mn(II) species. These often
% exhibit distributions of D values, i.e. different Mn(II) ions in the
% sample have different D values. This D strain is easily simulated with
% one call to pepper. We simulate the zeroth and the first harmonic of the
% absorption spectrum. The first harmonic is generated by field modulation.

clear, clf

Exp.mwFreq = 9.4;
Exp.Range = [270 400];
Exp.nPoints = 2601;
Exp.Harmonic = 0;

Sys = struct('S',5/2,'g',2,'Nucs','55Mn','A',253,'lw',1);

Sys.D = 170;  % D, in MHz
Sys.DStrain = 120; % FWHM of Gaussian distribution of D, in MHz

% Simulation of absorption spectrum
[B,spec0] = pepper(Sys,Exp);

% Generate first-harmonic spectrum with field modulation
ModulationAmplitude = 0.1; % mT
spec1 = fieldmod(B,spec0,ModulationAmplitude);

subplot(2,1,1);
plot(B,spec0); axis tight

subplot(2,1,2);
plot(B,spec1); axis tight
xlabel('magnetic field [mT]');
