function [files_in,files_out,opt] = niak_brick_fir_tseries(files_in,files_out,opt);
% ROI-based non-parametric estimation of the finite impulse response in fMRI.
%
% SYNTAX:
% [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_FIR_TSERIES(FILES_IN,FILES_OUT,OPT)
%
% _________________________________________________________________________
% INPUTS:
%
% FILES_IN
%   (structure) with the following fields:
%
%   FMRI
%       (cell of strings) a list of fMRI datasets, all in the same space.
%
%   MASK
%       (string or cell of strings) The name of a 3D volume containing ROIs 
%       defined through integer labels, i.e. ROI number I is filled with Is. 
%       0 is the code for background and is ignored.
%
%   TIMING
%       (cell of strings) a list of .mat files coding for the time of 
%       events. Each file can be either in '.mat' or '.csv' format. 
%           
%       case '.mat': TIMING{I} contains one variable TIME_EVENTS
%           (vector) a list of event time that will be used to derive 
%           the FIR estimation for fMRI{I}.
%
%       case '.csv': a csv file where the first column code for the 
%           timing of event. Other columns are ignored. There can 
%           also be a first column with (string) condition labels and
%           a first line with column labels. The latter is ignored, 
%           and the former is used to code multiple conditions in 
%           one CSV file. In this case, OPT.NAME_CONDITION can be used
%           to specify the name of the condition of interest (by default 
%           the first one is used). 
%
% FILES_OUT
%   (string or cell of strings) The name of a .mat file with the following 
%   variables (the nth entry FILES_OUT{n} is generated based on FILES_IN.MASK{n}:
%           
%   FIR_MEAN
%       (cell of 2D array, or 2D array) FIR_MEAN{n}(:,I) is the mean FIR response 
%       estimated at the spatial location I for FILES_IN.MASK{n}. If FILES_IN.MASK
%       is a string, then FIR_MEAN is simply a 2D array.
%
%   FIR_ALL
%       (cell of 3D array, or 3D array) FIR_ALL{n}(:,I,J) is the FIR response at the 
%       spatial location I for the Jth event, for FILES_IN.MASK{n}. If FILES_IN.MASK
%       is a string, then FIR_ALL is simply a 2D array.
%
%   TIME_SAMPLES
%       (vector) TIME_SAMPLES(T) is the time associated with the Tth row of 
%       FIR_MEAN{n} and FIR_ALL{n}. Note that time 0 would correspond to the event 
%       time.
%
% OPT
%   (structure) with the following fields : 
%
%   TIME_WINDOW
%       (scalar, default 10) the length of the time window for the hrf 
%       estimation (the units need to be consistent with those used in 
%       TIME_EVENTS and TIME_FRAMES, generally seconds).
%
%   TIME_SAMPLING
%       (scalar, default 0.5) the time between two time points in the hrf 
%       estimation (again the units need to be consistent with 
%       TIME_WINDOW).
%
%   INTERPOLATION
%       (string, default 'linear') the temporal interpolation scheme.
%       See the METHOD argument of the matlab function INTERP1 for
%       possible options.
%
%   MAX_INTERPOLATION
%       (scalar, default one TR) the maximal time interval where temporal 
%       interpolations can be performed. Usually interpolations are done
%       between two TRs, but if scrubbing of time frames with excessive 
%       motion is used, then the native temporal sampling grid may be 
%       irregular. This parameter can then be used to exclude events where
%       too many time frames are missing. Any response that involve an 
%       interpolation between points that are too far apart will be excluded.
% 
%   TYPE_NORM
%       (string, default 'fir_shape') the type of temporal normalization
%       applied on each response sample. Available option 'fir' or
%       'fir_shape'. See NIAK_BUILD_FIR for details.
%
%   TIME_NORM
%       (scalar, default 1) the number of seconds of signal at the
%       begining of each response which are used to set the baseline to 
%       zero.
%
%   NAME_CONDITION
%       (string, default '') in case the timing of events is coded with a csv file
%       including multiple conditions, NAME_CONDITION is the name of the condition 
%       to use. By default (empty string), the first condition is used. 
%
%   FLAG_VERBOSE
%       (boolean, default 1) if FLAG_VERBOSE == 1, print some information 
%       on the advance of computation
%
%   FLAG_TEST
%       (boolean, default 0) if FLAG_TEST equals 1, the brick does not do 
%       anything but update the default values in FILES_IN, FILES_OUT 
%       and OPT.
%
% _________________________________________________________________________
% OUTPUTS:
%
% The structures FILES_IN, FILES_OUT and OPT are updated with default
% valued. If OPT.FLAG_TEST == 0, the specified outputs are written.
%
% _________________________________________________________________________
% SEE ALSO:
% NIAK_BUILD_FIR, NIAK_PIPELINE_BASC_FIR, NIAK_BRICK_FIR
%
% _________________________________________________________________________
% COMMENTS:
%
% Copyright (c) Pierre Bellec, Montreal Neurological Institute, 2008-2010.
%               Centre de recherche de l'institut de Gériatrie de Montréal
%               Département d'informatique et de recherche opérationnelle
%               Université de Montréal, 2010.
% Maintainer : pbellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : HRF, FIR, fMRI

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Seting up default arguments %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Check syntax
if ~exist('files_in','var')||~exist('files_out','var')
    error('fnak:brick','syntax: [FILES_IN,FILES_OUT,OPT] = NIAK_BRICK_FIR_TSERIES(FILES_IN,FILES_OUT,OPT)\n Type ''help niak_brick_fir_tseries'' for more info.')
end

%% Inputs
gb_name_structure = 'files_in';
gb_list_fields    = {'fmri' , 'mask' , 'timing' };
gb_list_defaults  = {NaN    , NaN    , NaN      };
niak_set_defaults

%% Default options
gb_name_structure = 'opt';
gb_list_fields    = {'name_condition' , 'max_interpolation' , 'type_norm' , 'time_norm' , 'time_window' , 'time_sampling' , 'interpolation' , 'flag_verbose' , 'flag_test' };
gb_list_defaults  = {''               , []                  , 'fir_shape' , 1           , 10            , 0.5             , 'linear'        , true           , false       };
niak_set_defaults

%% If the test flag is true, stop here !
if flag_test
    return
end

%% Adjust inputs to cell of strings if necessary
if ischar(files_in.mask)
    files_in.mask = {files_in.mask};
    flag_string = true;
else
    flag_string = false;
end

if ischar(files_out)
    files_out = {files_out};
end

if length(files_in.mask) ~= length(files_out)
    error('FILES_IN.MASK and FILES_OUT should have the same number of entries')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The core of the brick starts here %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if flag_verbose
    msg = sprintf('FIR estimation');
    stars = repmat('*',[length(msg) 1]);
    fprintf('\n%s\n%s\n%s\n',stars,msg,stars);
end

%% Read the mask
if flag_verbose
    fprintf('Read the brain mask in file %s \n',files_in.mask);
end

for num_m = 1:length(files_in.mask)
    if num_m == 1
        hdr = niak_read_vol(files_in.mask{1});
        mask = zeros([hdr.info.dimensions(:)' length(files_in.mask)]);
    end
    [hdr,mask(:,:,:,num_m)] = niak_read_vol(files_in.mask);
end
mask = round(mask);

%% Extract time series and perform HRF estimation
opt_fir.time_window       = opt.time_window;
opt_fir.flag_verbose      = false;
opt_fir.time_sampling     = opt.time_sampling;
opt_fir.interpolation     = opt.interpolation;
opt_norm.type          = type_norm;
opt_norm.time_norm     = time_norm;
opt_norm.time_sampling = opt.time_sampling;

opt_tseries.correction.type = 'none';
fir_all_tot = cell([length(files_in.fmri) length(files_in.mask)]);
fir_mean_tot = cell([length(files_in.mask) 1]);
nb_events = zeros([length(files_in.fmri) length(files_in.mask)]);
nb_fir_tot = zeros([length(files_in.mask) 1]);

for num_r = 1:length(files_in.fmri)
    if flag_verbose
        fprintf('Estimation for fMRI dataset %s ...\n',files_in.fmri{num_r});
    end
    [hdr,vol] = niak_read_vol(files_in.fmri{num_r});
    if isempty(opt.max_interpolation)
        opt_fir.max_interpolation = hdr.info.tr;
    else
        opt_fir.max_interpolation = opt.max_interpolation;
    end
    [path_time,name_time,ext_time] = niak_fileparts(files_in.timing{num_r});
    switch ext_time
        case '.mat'
            timing = load(files_in.timing{num_r});
            time_events = timing.time_events;
        case '.csv'
            [time_events,labels_conditions] = niak_read_csv(files_in.timing{num_r});
            if isempty(opt.name_condition)
                mask_cond = ismember(labels_conditions,labels_conditions{1});
            else
                mask_cond = ismember(labels_conditions,opt.name_condition);
            end
            time_events = sort(time_events(mask_cond,:));
        otherwise
            error('%s is not supported (available extensions .mat or .csv',files_in.timing{num_r})
    end
    opt_fir.time_events = time_events;
    if isfield(hdr,'extra')
        opt_fir.time_frames = hdr.extra.time_frames;
    else
        opt_fir.time_frames = (0:(size(vol,4)-1))*hdr.info.tr;
    end
    for num_m = 1:length(files_in.mask)
        tseries = niak_build_tseries(vol,mask(:,:,:,num_m),opt_tseries);
        if num_r == 1
            [fir_mean,nb_fir,fir_all,time_samples] = niak_build_fir(tseries,opt_fir);
        else
            [fir_mean,nb_fir,fir_all] = niak_build_fir(tseries,opt_fir);
        end
        nb_events(num_r,num_m) = nb_fir;
        nb_fir_tot(num_m) = nb_events(num_r,num_m) + nb_fir_tot(num_m);    
        if (num_r == 1)
            fir_mean_tot{num_m} = nb_events(num_r)*fir_mean;
        else
            fir_mean_tot{num_m} = (nb_events(num_r)*fir_mean)+fir_mean_tot{num_m};
        end
        fir_all_tot{num_r,num_m} = fir_all;
    end
end

%% Normalize FIR_MEAN
fir_mean = cell([length(files_in.mask) 1]);
for num_m = 1:length(files_in.mask)
    if nb_fir_tot>0
        fir_mean{num_m} = fir_mean_tot{num_m}/nb_fir_tot(num_m);
        fir_mean{num_m} = niak_normalize_fir(fir_mean{num_m},opt_norm);    
    end
end

%% Reshape the FIR_ALL array    
fir_all = cell([length(files_in.mask) 1]);

for num_m = 1:length(files_in.mask)
    if max(nb_fir_tot(num_m)) > 0
    pos = 1;
    fir_all{num_m} = zeros([size(fir_all_tot{1,num_m},1) size(fir_all_tot{1,num_m},2) nb_fir_tot(num_m)]);
    for num_r = 1:length(files_in.fmri)
            fir_all{num_m}(:,:,pos:(pos+nb_events(num_r,num_m)-1),:) = fir_all_tot{num_r,num_m};
            pos = pos + nb_events(num_r,num_m);
        end
    end
end

%% write the results
if flag_verbose
    fprintf('Writting the FIR estimates %s ...\n',files_out);
end

for num_m = 1:length(files_in.mask)
    save(files_out{num_m},'fir_mean','fir_all','nb_fir_tot','time_samples');
end