% (inputDir, outputDir, parameters);
% smooth
% if output nii files exist with same name, overwrite without any prompt
%
% inputDir ='.../xxx/'; trailing filesep does not matter
% outputDir = '.../xxx/'; % trailing filesep does not matter
% parameters = {FWHM};
%       e.g.,  {[8 8 8]}
% 
% note: 
%   uses SPM functions; SPM must be added to your matlab path: File -> Set Path... -> add with subfolders. 
%   tested under SPM 12-6225 (with mac lion 10.7.5 and matlab 2012b)
%   if you use this job_function for the first time, consider running only one subject and check the results before processing all 
%
% author = jerryzhujian9@gmail.com
% date: December 10 2014, 11:13:30 AM CST
% inspired by http://www.aimfeld.ch/neurotools/neurotools.html
% https://www.youtube.com/playlist?list=PLcNEqVlhR3BtA_tBf8dJHG2eEcqitNJtw

%------------- BEGIN CODE --------------
function [output1,output2] = main(inputDir, outputDir, parameters, email)
% email is optional, if not provided, no email sent
% (re)start spm
spm('fmri')
[FWHM] = parameters{:};

startTime = ez.moment();
runFiles = ez.ls(inputDir,'s\d\d\d\d_r\d\d\.nii$'); % runFiles across all subjects
[dummy runFileNames] = cellfun(@(e) ez.splitpath(e),runFiles,'UniformOutput',false);
runFileNames = cellfun(@(e) regexp(e,'_', 'split'),runFileNames,'UniformOutput',false);
subjects = cellfun(@(e) e{end-1},runFileNames,'UniformOutput',false);  
subjects = ez.unique(subjects); % returns {'s0215';'s0216'}

for n = 1:ez.len(subjects)
    subject = subjects{n};
    ez.print(['Processing ' subject ' ...']);

    load('mod_smooth.mat');
    
    % all volumes across runs for one subject
    runVolumes = cellstr(spm_select('ExtList',inputDir,[subject '_r\d\d\.nii'],[1:1000]));
    runVolumes = cellfun(@(e) ez.joinpath(inputDir,e),runVolumes,'UniformOutput',false);
    matlabbatch{1}.spm.spatial.smooth.data = runVolumes;
    matlabbatch{1}.spm.spatial.smooth.fwhm = FWHM;

    cd(outputDir);
    spm_jobman('run',matlabbatch);

    % check smoothed
    files = cellstr(spm_select('ExtList',inputDir,['^(w|sw).*' subject '_r01\.nii'],[1]));
    files = cellfun(@(e) ez.joinpath(inputDir,e),files,'UniformOutput',false);
    spm_check_registration(char(files));
    fig = spm_figure('FindWin','Graphics');
    ez.export(ez.joinpath(outputDir,[subject '_r01_smoothed.pdf']),fig);

    % move smoothed files
    files = ez.ls(inputDir,['^s.*' subject '_r\d\d\.nii$']);
    cellfun(@(e) ez.mv(e,outputDir),files,'UniformOutput',false);

    save(['job_smooth_' subject '.mat'], 'matlabbatch');
    clear matlabbatch;

    ez.pprint('****************************************'); % pretty colorful print
end
ez.pprint('Done!');
finishTime = ez.moment();
if exist('email','var'), try, batmail(mfilename, startTime, finishTime); end; end;
end % of main function
%------------- END OF CODE --------------