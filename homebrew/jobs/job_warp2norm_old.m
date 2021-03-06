% (inputDir, outputDir, inputDir2, inputDir3);
% warp anatomical and functional images into normalized/standard space
% step 1) coregister anat to functional mean ref, write the transformation matrix to anat file header, involves only linear transformation
% step 2) segment updated anat file to grey(c1), white(c2), csf(c3)
%         get the deformation info, involves linear transformation and nonlinear warp
% step 3) combine parameters from step 1 & 2, apply to functional and anat images
% output a lot of files: 
%       mxxx.nii -bias corrected
%       anat_seg_inv_sn.mat;    anat_seg_sn.mat
%       c1-c3 segmented
%       wxxx.nii  warped files (during normalization step also down/up-resample functional and anat to 2*2*2 mm)
%
%       sxxxx_coreg.pdf   <-- function coreg anat
%       sxxxx_segs.pdf    <-- c1-c6 of anat
%       sxxxx_warped.pdf  <-- warped anat plus the first volume of each run
% if output nii files exist with same name, overwrite without any prompt
%
% inputDir ='.../xxx/'; trailing filesep does not matter
% outputDir = '.../xxx/'; % trailing filesep does not matter
% inputDir2 = folder for functional_mean_ref images
% inputDir3 = folder for anat_source images
% optional input: together = 0/1 (default 1) if 0 only generates job_.mat files, 1 run the jobs and clean up afterwards
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
function [output1,output2] = main(inputDir, outputDir, inputDir2, inputDir3, together, email)
% email is optional, if not provided, no email sent
% (re)start spm
spm('fmri');
if ~exist('together','var'), together = 1; end

startTime = ez.moment();
% 1) copy anat files to the inputDir
anatFiles = ez.ls(inputDir3,'s\d\d\d\d_anat\.nii$');
cellfun(@(e) ez.cp(e,outputDir),anatFiles,'UniformOutput',false);

% 2) process each subject one by one
% runFiles = ez.ls(inputDir,'^(?!mean).*s\d\d\d\d_r\d\d.nii$');  % not starting with 'mean'  % runFiles across all subjects
runFiles = ez.ls(inputDir,'s\d\d\d\d_r\d\d.nii$');  % runFiles across all subjects
[dummy runFileNames] = cellfun(@(e) ez.splitpath(e),runFiles,'UniformOutput',false);
runFileNames = cellfun(@(e) regexp(e,'_', 'split'),runFileNames,'UniformOutput',false);
subjects = cellfun(@(e) e{end-1},runFileNames,'UniformOutput',false);  
subjects = ez.unique(subjects); % returns {'s0215';'s0216'}

for n = 1:ez.len(subjects)
    subject = subjects{n};
    ez.print(['Processing ' subject ' ...']);

    load('mod_warp2norm_old.mat');

    % fill out coreg
    refImage = cellstr(spm_select('ExtList',inputDir2,['^mean.*' subject '.*\.nii'],[1]));
    refImage = cellfun(@(e) ez.joinpath(inputDir2,e),refImage,'UniformOutput',false);
    matlabbatch{1}.spm.spatial.coreg.estimate.ref = refImage;

    sourceImage = cellstr(spm_select('ExtList',outputDir,[subject '_anat\.nii'],[1]));
    sourceImage = cellfun(@(e) ez.joinpath(outputDir,e),sourceImage,'UniformOutput',false);
    matlabbatch{1}.spm.spatial.coreg.estimate.source = sourceImage;

    % fill out segment
    spmFolder = ez.splitpath(which('spm'));
    tpmFile = ez.joinpath(spmFolder,'toolbox','OldSeg');
    matlabbatch{2}.spm.tools.oldseg.opts.tpm = {ez.joinpath(tpmFile,'grey.nii,1');
                                                ez.joinpath(tpmFile,'white.nii,1');
                                                ez.joinpath(tpmFile,'csf.nii,1');};

    % fill out normalise
    resampleImages = {};
    % all volumes across runs for one subject
    runVolumes = cellstr(spm_select('ExtList',inputDir,['^(?!mean).*' subject '.*\.nii'],[1:1000]));
    runVolumes = cellfun(@(e) ez.joinpath(inputDir,e),runVolumes,'UniformOutput',false);
    % also warp anat to normalised space
    resampleImages = [sourceImage;runVolumes];
    matlabbatch{3}.spm.tools.oldnorm.write.subj.resample = resampleImages;

    cd(outputDir);
    save(['job_warp2norm_' subject '.mat'], 'matlabbatch');

    if together
        spm_jobman('run',matlabbatch);

        % move stuff to hallway
        hallway = ez.joinpath(outputDir,'hallway'); ez.mkdir(hallway);
        % inverse/forward matrices
        ez.mv(ez.joinpath(outputDir,'*seg*.mat'),hallway);
        % segments
        segs = ez.ls(outputDir,'^c\d.*nii$');
        check_reg(segs);
        fig = spm_figure('FindWin','Graphics');
        ez.export(ez.joinpath(outputDir,[subject '_segs.pdf']),fig);
        cellfun(@(e) ez.mv(e,hallway),segs,'UniformOutput',false);
        % bias corrected file
        files = ez.ls(outputDir,'^m.*anat\.nii$');
        cellfun(@(e) ez.mv(e,hallway),files,'UniformOutput',false);
        % process graph
        psFile = ez.ls(outputDir,'\.ps$'){1};
        ez.ps2pdf(psFile,ez.joinpath(outputDir,[subject '_coreg.pdf']));  
        ez.rm(psFile);
        % move warped files
        files = ez.ls(inputDir,['^w.*' subject '_r\d\d\.nii$']);
        cellfun(@(e) ez.mv(e,outputDir),files,'UniformOutput',false);
        % check warped
        files = cellstr(spm_select('ExtList',outputDir,['^w.*' subject '.*\.nii'],[1]));
        files = cellfun(@(e) ez.joinpath(outputDir,e),files,'UniformOutput',false);
        check_reg(files, [0 0 0]);
        fig = spm_figure('FindWin','Graphics');
        ez.export(ez.joinpath(outputDir,[subject '_warped.pdf']),fig);
        % finally anat with header changed
        files = ez.ls(outputDir,['^_' subject '_anat\.nii$']);
        cellfun(@(e) ez.mv(e,hallway),files,'UniformOutput',false);
    end

    clear matlabbatch;

    ez.pprint('****************************************'); % pretty colorful print
end
ez.pprint('Done!');
finishTime = ez.moment();
if exist('email','var') && together, try, jobmail(mfilename, startTime, finishTime); end; end;
end % of main function
%------------- END OF CODE --------------