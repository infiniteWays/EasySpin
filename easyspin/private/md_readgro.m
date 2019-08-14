% md_readgro  Read protein structure file in Gromos87 format.
%
%   data = md_readgro(FileName);
%
% Input:
%   grofile    filename, including .gro extension

function data = md_readgro(GroFile,ResName,LabelName,AtomNames)

if ~strcmpi(GroFile(end-3:end),'.GRO')
  error('File extension must be .gro.');
end

fh = fopen(GroFile);

if fh<0
  error('Could not open file ''%s''',GroFile);
end

allLines = textscan(fh,'%s','whitespace','','delimiter','\n');
allLines = allLines{1};
fclose(fh);

data.title = allLines{1};
data.nAtoms = sscanf(allLines{2},'%d');

if numel(allLines)~=data.nAtoms+3
  error('Number of lines in file ''%s'' appears incorrect.',GroFile);
end

resnum = zeros(1,data.nAtoms);
resnames = cell(1,data.nAtoms);
atomnames = cell(1,data.nAtoms);
atomnumber = zeros(1,data.nAtoms);
pos = zeros(data.nAtoms,3);
vel = zeros(data.nAtoms,3);
for k = 1:data.nAtoms
  L = allLines{k+2};
  resnum(k) = sscanf(L(1:5),'%d');
  resnames{k} = L(6:10);
  atomnames{k} = L(11:15);
  atomnumber(k) = sscanf(L(16:20),'%d');
  pos(k,:) = sscanf(L(21:44),'%f %f %f');
  vel(k,:) = sscanf(L(45:68),'%f %f %f');
end
box = sscanf(allLines{data.nAtoms+3},'%f');
resnames = strtrim(resnames);
atomnames = strtrim(atomnames);

data.idx_ProteinCA = strcmpi(atomnames,'CA');
idx_SpinLabel = strcmpi(resnames,ResName);
data.idx_SpinLabel = idx_SpinLabel;

% locate spin label atoms
findatomindex = @(name) strcmpi(atomnames(idx_SpinLabel),name);
switch LabelName
  case 'R1'
    data.idx_ON = findatomindex(AtomNames.ONname);
    data.idx_NN = findatomindex(AtomNames.NNname);
    data.idx_C1 = findatomindex(AtomNames.C1name);
    data.idx_C2 = findatomindex(AtomNames.C2name);
    data.idx_C1R = findatomindex(AtomNames.C1Rname);
    data.idx_C2R = findatomindex(AtomNames.C2Rname);
    data.idx_C1L = findatomindex(AtomNames.C1Lname);
    data.idx_S1L = findatomindex(AtomNames.S1Lname);
    data.idx_SG = findatomindex(AtomNames.SGname);
    data.idx_CB = findatomindex(AtomNames.CBname);
    data.idx_CA = findatomindex(AtomNames.CAname);
    data.idx_N = findatomindex(AtomNames.Nname);
  case 'TOAC'
    data.idx_ON = findatomindex(AtomNames.ONname);
    data.idx_NN = findatomindex(AtomNames.NNname);
    data.idx_CGS = findatomindex(AtomNames.CGSname);
    data.idx_CGR = findatomindex(AtomNames.CGRname);
    data.idx_CBS = findatomindex(AtomNames.CBSname);
    data.idx_CBR = findatomindex(AtomNames.CBRname);
    data.idx_CA = findatomindex(AtomNames.CAname);
    data.idx_N = findatomindex(AtomNames.Nname);
end

data.resnum = resnum;
data.resname = resnames;
data.atomname = atomnames;
data.atomnumber = atomnumber;
data.pos = pos;
data.vel = vel;
data.box = box;

return
