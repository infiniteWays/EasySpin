% eulang  Euler angles from rotation matrix
%
%   Angles = eulang(R)
%   [alpha,beta,gamma] = eulang(R)
%
%   Returns the three Euler angles [alpha, beta, gamma]
%   (in radians) of the rotation matrix R, which must be
%   a 3x3 real matrix with determinant very close to +1.
%
%   For a definition of the Euler angles, see erot().
%
%   [alpha,beta,gamma] and [alpha+-pi,-beta,gamma+-pi]
%   give the same rotation matrix. eulang() returns the
%   set with beta>=0.

function varargout = eulang(RotMatrix,SkipFitting)

if (nargin<1), help(mfilename); return; end
if (nargin<2), SkipFitting = 0; end

% Validity checks
%--------------------------------------------------------
if (~isreal(RotMatrix))
  error('eulang: Rotation matrix must be real.');
end

if any(size(RotMatrix)~=3)
  error('eulang: Rotation matrix must be 3x3.');
end

normError = norm(RotMatrix'*RotMatrix-eye(3));
if (normError>1e-6)
  disp('eulang: Rotation matrix is not orthogonal within 1e-6.');
elseif (normError>1e-2)
  error('eulang: Rotation matrix is not orthogonal within 1e-2.');
end

d = det(RotMatrix);
if (d<0)
  error('eulang: Rotation matrix has negative determinant! Change the signs in one column or row.');
end

hardLimit = 1e-1;
softLimit = 5e-3;
detError = abs(d-1);
if (detError>hardLimit)
  error('eulang: Determinant of rotation matrix is %+0.3f, deviates too much from +1!\nRescale argument to R/det(R)^(1/3) if result wanted.',d);
elseif (detError>softLimit)
  fprintf('eulang: Determinant of rotation matrix is %+0.3f.\n',d);
  fprintf('eulang: The output of eulang() is probably inaccurate!\n');
end

% Analytical expressions
%---------------------------------------------------
% Degenerate cases:  R(3,3) = cos(beta) = +-1 -> beta=n*pi. In these
% cases, alpha and gamma are not distinguishable. We collect the entire
% z rotation angle in alpha and set gamma to zero.
DegenerateCaseLimit = 1e-8;
if abs(RotMatrix(3,3)-1)<=DegenerateCaseLimit
  alpha = atan2(RotMatrix(1,2),RotMatrix(2,2));
  beta = 0;
  gamma = 0;
elseif abs(RotMatrix(3,3)+1)<=DegenerateCaseLimit
  alpha = atan2(-RotMatrix(1,2),RotMatrix(2,2));
  beta = pi;
  gamma = 0;
else
  alpha = atan2(RotMatrix(3,2),RotMatrix(3,1));
  beta = atan2(sqrt(RotMatrix(3,1)^2+RotMatrix(3,2)^2),RotMatrix(3,3));
  gamma = atan2(RotMatrix(2,3),-RotMatrix(1,3));
end
Angles = [alpha,beta,gamma];

% Refinement by least-squares fitting
%--------------------------------------------------
if ~SkipFitting
  FitOptions = optimset('TolX',0.0001);
  RotErrorFunction = @(A,R) norm(erot(A)-R);
  Angles = fminsearch(RotErrorFunction,Angles,FitOptions,RotMatrix);
end

% Ranging
%--------------------------------------------------
% Adjust Euler angles so that beta>=0
if Angles(2)<0
  if Angles(1)<0
    Angles = [Angles(1)+pi -Angles(2) Angles(3)+pi];
  else
    Angles = [Angles(1)-pi -Angles(2) Angles(3)-pi];
  end
end

switch nargout
  case 0
    varargout = {Angles};
  case 1
    varargout = {Angles};
  case 3
    varargout = {Angles(1),Angles(2),Angles(3)};
  otherwise
    error('Wrong number of output arguments.')
end
