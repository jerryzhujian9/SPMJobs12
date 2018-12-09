function result = main(roiNiiPath,verbose,folder)
% Description:
%       Uses marsbar functions to generate .mat ROI
%       If marsbar path not in searchpath, auto add them internally first.    
% Input:
%       roiNiiPath: path to roi image(s), str or cell of str
%                   recommendated ROIName format is: ROI_label_x_y_z.nii
%       verbose = 0/1, if true, print out roi info and display roi, default true
%       folder, path to folder where ROI files will be saved, default pwd
% Output:
%       ROIName_x_y_z_roi.mat (ROIName is the same as roi's filename, xyz is added automatically)
%                              recommendated ROIName format is: ROI_label_x_y_z.nii
%       the full path to the generated ROI mat file(s), if more than one file, a cell; otherwise a str

if (isempty(which('marsbar'))||isempty(which('spm_get')))
    ez.print('addpath marsbar...')
    extsPath = ez.joinpath(ez.parentdir(ez.parentdir(ez.csd())), 'extensions');
    thePath = ez.lsd(extsPath,'^marsbar');
    thePath = ez.joinpath(extsPath,thePath{1});
    addpath(thePath,'-end');
    % additional path that would be added by marsbar
    addpath(ez.joinpath(thePath,'spm5'),'-end');
end

if ischar(roiNiiPath), roiNiiPath = cellstr(roiNiiPath); end
if nargin<2, verbose = 1; end
if nargin<3, folder = pwd; else ez.mkdir(folder); end

% flags is cluster
flags = 'c';
result = cell(length(roiNiiPath),1);

for i = 1:length(roiNiiPath)
    roi = roiNiiPath{i};
    [~, prefix] = ez.splitpath(roi);
    mars_img2rois(roi, folder, prefix, flags);


    if verbose
    % output some useful info of the input roi image
    
    fprintf('\nInput ROI image info:\n');
    hdr_out = spm_vol(roi);
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
    end % end if

    % mars_img2rois does not return anything
    % work around to get the full path of generated roi file
    roimat = ez.ls(folder,[prefix '_-?\d{1,2}_-?\d{1,2}_-?\d{1,2}_roi\.mat$']);
    result{i,1} = roimat{1};
ez.pprint('========================================================================\n');
end % end for

if verbose,
    spmpath = fileparts(which('spm'));
    mars_display_roi('display',char(result),fullfile(spmpath,'canonical','avg152T1.nii'));
end % end if

% output a text list of generated rois
ROIs = cellstr(spm_select('List',folder,['_-?\d{1,2}_-?\d{1,2}_-?\d{1,2}_roi\.mat$']));
ROIs = strrep(ROIs,'ROI_','');
ROIs = regexprep(ROIs,'_-?\d{1,2}_-?\d{1,2}_-?\d{1,2}_roi\.mat$','');
ROIs = regexprep(ROIs,'_-?\d{1,2}_-?\d{1,2}_-?\d{1,2}','');
ez.cell2csv(fullfile(folder,'ALLROINAMES.txt'),ROIs);

if length(result)==1, result=result{1}; end
end % end function