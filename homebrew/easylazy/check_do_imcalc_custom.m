function outname = main(in, outname, operation)
% Calculate Image based on Input Image(s) with customized spmimcal()
% spmimcal should be similar to spm_imcal (not sure how differnt though--jerry)
% USAGE: (in, outname, operation)
%        in  =  str or a cell of str with images (full path), eg. {'a.nii','b.nii'}
%        outname = path for output image, eg. 'diff.nii'
%        operation = string specifying operation to apply
% 
%                    LOGICAL OPERATORS
%                    'i1>i2', 'i1<i2', 'i1>=i2', 'i1<=i2', 'i1==i2', '(i1>100).*i2', '(i1 & i2) & ~i3'
%                          
%                    LOGICAL shortcuts      
%                        'intersect' - intersect/overlap across images i1 & i2 & i3 etc
%                        'union' - united across images i1 | i2 | i3 etc
%
%                    NON-LOGICAL OPERATORS (ACROSS IMAGES)
%                        'sum'   - sum across images
%                        'prod'  - produce across images (ie, i1 .* i2 .* i3)
%                        'mean'  - mean across images
%                        'median' - median across images
%                        'std'   - std across images
%                        'var'   - var across images
%                        'min'   - min across images
%                        'max'   - max across images
%                        'diff'  - contrast across images (2 only) i1 - i2
%                   
%                    NON-LOGICAL OPERATORS (SINGLE IMAGE)
%                        'sqrt'          - square root of image
%                        'negative'      - negative of image
%                        'nan2zero'      - convert NaNs to 0s
%                        'zero2nan'      - convert 0s to NaNs
%                        'zscore'        - convert t-image to z-image
%                        'prctile'       - convert to percentile
%                        'prctilesym'    - convert to percentile for +/- numbers separately
%                        'imfill'        - uses IMFILL to fill holes in (from image processing toolbox)
%                    
%                    SPECIAL OPERATORS
%                        'colorcode' - combine and colorcode multiple images i1 + i2*2 + i3*3 etc
%
% modified slightly: Jerry Zhu Thu, May 05 2016, 12:34:19 PM EDT(-0400)
% CREATED: Bob Spunt, Ph.D. (bobspunt@gmail.com) - 2013.03.20
% CREDIT: Loosely based on functionality of spm_imcalc_ui.m (SPM8)

% -------------------------- Copyright (C) 2014 --------------------------
%	Author: Bob Spunt
%	Affilitation: Caltech
%	Email: spunt@caltech.edu
%
%	$Revision Date: Aug_20_2014
if nargin<3, mfile_showhelp; return; end

% | check variable formats
if ischar(in), in = cellstr(in); end
if iscell(outname), outname = char(outname); end
if iscell(operation), operation = char(operation); end
[p, n, e] = fileparts(outname); 
if isempty(p), p = pwd; end
if isempty(e), e = '.nii'; end
outname = fullfile(p, [n e]); 
    
% | read in data
hdr  = spm_vol(char(in)); 
nvol = length(hdr);

% | apply the operation
tag = 0;
if nvol > 1
    switch lower(operation)
    case {'colorcode'}
        operation  = 'i1'; 
        for i = 2:length(hdr), operation = [operation sprintf('+(i%d*%d)', i, i)]; end
    case {'prod'}
        operation  = 'i1'; 
        for i = 2:nvol, operation = [operation sprintf('.*i%d', i)]; end
    case {'intersect'}
        operation  = 'i1'; 
        for i = 2:nvol, operation = [operation sprintf('&i%d', i)]; end             
    case {'union'}
        operation  = 'i1'; 
        for i = 2:nvol, operation = [operation sprintf('|i%d', i)]; end            
    case {'sum', 'mean', 'median'}
        operation = strcat('nan', operation, '(X)'); 
    case {'min', 'max', 'std', 'var'}
        operation = strcat('nan', operation, '(X)'); 
    case {'diff'}
        if nvol > 2
            disp('ERROR: ''diff'' operation only works with 2 input images'); 
        else
            operation = 'i1-i2'; 
        end
    end
    if regexpi(operation, '\(X\)')
        dmtx = 1; 
    elseif regexp(operation, '\W')
        dmtx = 0; 
    else
        operation = strcat(operation, '(X)'); 
        dmtx = 1;
    end
    outhdr = hdr(1);
    if regexpi(outhdr.descrip, 'SPM{T')
        names   = bspm_con2name(in);
        names(2:end)   = strcat({', '}, names(2:end)); 
        str     = regexp(outhdr.descrip, ' - ', 'split');
        outhdr.descrip = char(strcat(str{1}, {' - '}, upper(operation), {': '}, names{:}));
    else
        outhdr.descrip = [upper(operation) ' IMAGE'];
    end
    outhdr.fname = outname; 
    spmimcalc(hdr, outhdr, operation, {dmtx});
else
    im = spm_read_vols(hdr);
    switch lower(operation)
        case {'negative'}
            outim = -1*im;
        case {'sqrt'}
            outim = sqrt(im);
        case {'nan2zero'}
            outim = im; outim(isnan(outim)) = 0; tag = 1;
        case {'zero2nan'}
            outim = im; outim(outim==0) = NaN; tag = 1;
        case {'zscore'}
            i1 = strfind(hdr.descrip,'[');
            i2 = strfind(hdr.descrip,']');
            df = str2num(hdr.descrip(i1+1:i2-1));
            outim = im; 
            outim(abs(outim) > 0) = bspm_t2z(outim(abs(outim) > 0),df);
            outim(outim==Inf) = max(outim(outim~=Inf))*1.01;
        case {'prctile'}
            outim = im; 
            outim(abs(outim) > 0) = 100*(tiedrank(outim(abs(outim) > 0)) ./ sum(abs(outim(:)) > 0));
        case {'prctilesym'}
            outim = im;
            posidx = find(outim > 0); 
            negidx = find(outim < 0); 
            pos = 100*(tiedrank(outim(posidx)) ./ length(posidx));
            neg = -100*(tiedrank(abs(outim(negidx))) ./ length(negidx));
            outim(posidx) = pos;
            outim(negidx) = neg;
        case {'imfill'}
            outim = imfill(im,6,'holes');
        otherwise
            outim = eval(['im' operation]);
    end
    % construct outname and write image
    if ~tag
        tmp = hdr.descrip;
        idx = regexp(tmp,'SPM{T','ONCE');
        if ~isempty(idx)
            tmp(regexp(tmp,'-')+2:end) = [];
            hdr.descrip = [tmp upper(operation) ' IMAGE'];
        else
            hdr.descrip = [upper(operation) ' IMAGE'];
        end
    end
    hdr.fname = outname; 
    spm_write_vol(hdr, outim);
end % end if

% output some useful info of the generated image
hdr_out = spm_vol(outname);
type_out = spm_type(hdr_out.dt(1));
values_out = spm_read_vols(hdr_out);
n_out = length(find(values_out ~= 0)); % how many non-zero voxels, ie the masked voxels of the ROI
unique_values_out = unique(spm_read_vols(hdr_out));
dim_out = hdr_out.dim;
Z = spm_imatrix(hdr_out.mat);
voxsize = Z(7:9);
description_out = hdr_out.descrip;

fprintf('note: UINT allows only positive values and 0;\n');
fprintf('if negative included, select INT;\n');
fprintf('single=float32, double=float64 also allow negative values\n\n');

fprintf('Data type: %s\n',type_out);
if length(unique_values_out) < 10
    fprintf('Unique values: %s\n',mat2str(unique_values_out));
else
    fprintf('Unique values: %d in total, showing first 10... %s\n', length(unique_values_out), mat2str(unique_values_out(1:10)))
end

fprintf('Min value: %s\n',num2str(min(unique_values_out)));
fprintf('Max value: %s\n',num2str(max(unique_values_out)));

fprintf('Non-zero voxels #: %d\n', n_out);
fprintf('Dimension: %s\n',mat2str(dim_out));
fprintf('Voxel size: %s\n',mat2str(abs(voxsize)));
fprintf('Description: %s\n',description_out);

end % end func

function Vo = spmimcalc(Vi,Vo,f,flags)
% Perform algebraic functions on images
% FORMAT Vo = spm_imcalc(Vi, Vo, f [,flags [,extra_vars...]])
% Vi            - struct array (from spm_vol) of images to work on
%                 or a char array of input image filenames
% Vo (input)    - struct array (from spm_vol) containing information on
%                 output image
%                 ( pinfo field is computed for the resultant image data, )
%                 ( and can be omitted from Vo on input.  See spm_vol     )
%                 or output image filename
% f             - MATLAB expression to be evaluated
% flags         - cell array of flags: {dmtx,mask,interp,dtype}
%                 or structure with these fieldnames
%      dmtx     - Read images into data matrix?
%                 [defaults (missing or empty) to 0 - no]
%      mask     - implicit zero mask?
%                 [defaults (missing or empty) to 0]
%                  ( negative value implies NaNs should be zeroed )
%      interp   - interpolation hold (see spm_slice_vol)
%                 [defaults (missing or empty) to 0 - nearest neighbour]
%      dtype    - data type for output image (see spm_type)
%                 [defaults (missing or empty) to 4 - 16 bit signed shorts]
% extra_vars... - additional variables which can be used in expression
%
% Vo (output)   - spm_vol structure of output image volume after
%                 modifications for writing
%__________________________________________________________________________
%
% spm_imcalc performs user-specified algebraic manipulations on a set of
% images, with the result being written out as an image. 
% The images specified in Vi, are referred to as i1, i2, i3,...  in the
% expression to be evaluated, unless the dmtx flag is setm in which
% case the images are read into a data matrix X, with images in rows.
%
% Computation is plane by plane, so in data-matrix mode, X is a NxK
% matrix, where N is the number of input images [prod(size(Vi))], and K
% is the number of voxels per plane [prod(Vi(1).dim(1:2))].
%
% For data types without a representation of NaN, implicit zero masking
% assumes that all zero voxels are to be treated as missing, and treats
% them as NaN. NaN's are written as zero, for data types without a
% representation of NaN.
%
% With images of different sizes and orientations, the size and orientation
% of the reference image is used. Reference is the first image, if
% Vo (input) is a filename, otherwise reference is Vo (input). A
% warning is given in this situation. Images are sampled into this
% orientation using the interpolation specified by the interp parameter.
%__________________________________________________________________________
%
% Example expressions (f):
%
%    i)  Mean of six images (select six images)
%        f = '(i1+i2+i3+i4+i5+i6)/6'
%   ii)  Make a binary mask image at threshold of 100
%        f = 'i1>100'
%   iii) Make a mask from one image and apply to another
%        f = '(i1>100).*i2'
%        (here the first image is used to make the mask, which is applied
%         to the second image - note the '.*' operator)
%   iv)  Sum of n images
%        f = 'i1 + i2 + i3 + i4 + i5 + ...'
%   v)   Sum of n images (when reading data into data-matrix)
%        f = 'sum(X)'
%   vi)  Mean of n images (when reading data into data-matrix)
%        f = 'mean(X)'
%__________________________________________________________________________
%
% Furthermore, additional variables for use in the computation can be
% passed at the end of the argument list. These should be referred to by
% the names of the arguments passed in the expression to be evaluated. 
% E.g. if c is a 1xn vector of weights, then for n images, using the (dmtx)
% data-matrix version, the weighted sum can be computed using:
%       Vi = spm_vol(spm_select(inf,'image'));
%       Vo = 'output.img'
%       Q  = spm_imcalc(Vi,Vo,'c*X',{1},c)
% Here we've pre-specified the expression and passed the vector c as an
% additional variable (you'll be prompted to select the n images).
%__________________________________________________________________________
% Copyright (C) 1998-2011 Wellcome Trust Centre for Neuroimaging

% John Ashburner & Andrew Holmes
% $Id: spm_imcalc.m 6124 2014-07-29 11:51:11Z guillaume $

if isstruct(Vo)
    Vchk   = spm_cat_struct(Vo,Vi);
    refstr = 'output';
else
    Vchk   = Vi(:);
    refstr = '1st';
end
% [sts, str] = spm_check_orientations(Vchk, false);
% if ~sts
%     for i=1:size(str,1)
%         fprintf('Warning: %s - using %s image.\n',strtrim(str(i,:)),refstr);
%     end
% end

%-Flags
%--------------------------------------------------------------------------
if nargin < 4, flags = {}; end
if iscell(flags)
    if length(flags) < 4, dtype  = []; else dtype  = flags{4}; end
    if length(flags) < 3, interp = []; else interp = flags{3}; end
    if length(flags) < 2, mask   = []; else mask   = flags{2}; end
    if length(flags) < 1, dmtx   = []; else dmtx   = flags{1}; end
else
    if isfield(flags,'dmtx'),   dmtx   = flags.dmtx;   else dmtx   = []; end
    if isfield(flags,'mask'),   mask   = flags.mask;   else mask   = []; end
    if isfield(flags,'interp'), interp = flags.interp; else interp = []; end
    if isfield(flags,'dtype'),  dtype  = flags.dtype;  else dtype  = []; end
end
if isempty(interp), interp = 0; end
if isempty(mask),   mask   = 0; end
if isempty(dmtx),   dmtx   = 0; end
if isempty(dtype),  dtype  = spm_type('int16'); end

%-Output image
%--------------------------------------------------------------------------
if ischar(Vo)
    [p, n, e] = spm_fileparts(Vo);
    Vo = struct('fname',   fullfile(p, [n, e]),...
                'dim',     Vi(1).dim(1:3),...
                'dt',      [dtype spm_platform('bigend')],...
                'pinfo',   [Inf Inf Inf]',...
                'mat',     Vi(1).mat,...
                'n',       1);
    if numel(Vi) > 1
        tmp = vertcat(Vi.descrip);
        tmp(:, sum(diff(tmp))~=0) = [];
        tmp = tmp(1,:);
    else
        tmp = Vi.descrip; 
    end
    Vo.descrip = [tmp ' - ' upper(f) ':SPM_IMCALC']; 
end


%-Computation
%==========================================================================
n = numel(Vi);
Y = zeros(Vo.dim(1:3));

%-Loop over planes computing result Y
%--------------------------------------------------------------------------
for p = 1:Vo.dim(3)
    B = spm_matrix([0 0 -p 0 0 0 1 1 1]);
    if dmtx, X = zeros(n,prod(Vo.dim(1:2))); end
    for i = 1:n
        M = inv(B * inv(Vo.mat) * Vi(i).mat);
        d = spm_slice_vol(Vi(i), M, Vo.dim(1:2), [interp,NaN]);
        if (mask < 0), d(isnan(d)) = 0; end
        if (mask > 0) && ~spm_type(Vi(i).dt(1),'nanrep'), d(d==0)=NaN; end
        if dmtx, X(i,:) = d(:)'; else eval(['i',num2str(i),'=d;']); end
    end
    try
        eval(['Yp = ' f ';']);
    catch
        l = lasterror;
        error('%s\nCan''t evaluate "%s".',l.message,f);
    end
    if prod(Vo.dim(1:2)) ~= numel(Yp)
        error(['"',f,'" produced incompatible image.']); end
    if (mask < 0), Yp(isnan(Yp)) = 0; end
    Y(:,:,p) = reshape(Yp,Vo.dim(1:2));
end

%-Write output image
%--------------------------------------------------------------------------
Vo = spm_write_vol(Vo,Y);
end  

function mfile_showhelp(varargin)
% MFILE_SHOWHELP
ST = dbstack('-completenames');
if isempty(ST), fprintf('\nYou must call this within a function\n\n'); return; end
eval(sprintf('help ''%s''', ST(2).file));  
end
 
function z = bspm_t2z(t, df)
% BOB_T2P Get p-value from t-value + df
%
%   USAGE: p = bspm_t2z(t, df)
%
%   OUTPUT
%       z = z-value
%
%   ARGUMENTS
%       t = t-value
%       df = degrees of freedom
%
% =========================================
if nargin<1, error('USAGE: bspm_t2z(t, df)'), end
z = -sqrt(2) * erfcinv((tcdf(t, df))*2);
end

function name = bspm_con2name(con, numberit)
% BSPM_CON2NAME
% USAGE: name = bspm_con2name(con)
%
if nargin<2, numberit = 0; end
if nargin==0, mfile_showhelp; return; end
if iscell(con), con = char(con); end
h       = spm_vol(con);
name    = {h.descrip}';
name    = regexprep(name, '.*\d+:\s', '');
name    = regexprep(name, '\s\W\sAll\sSessions', '');
name    = regexprep(name, '\s', '_');
if numberit
    ncon = length(name);
    fmt = ['%0' num2str(length(num2str(ncon))) 'd'];
    for i = 1:length(name)
        name{i} = sprintf(['C' fmt '_%s'], i, name{i});
    end
end
end
 
