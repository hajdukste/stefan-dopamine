function result = preproc_fip_clean(fip, lp_cutoff)
% preproc_fip_clean  Lowpass filter + exponential bleaching correction for fiber photometry
%   result = preproc_fip_clean(fip, lp_cutoff)
%
%   fip       - table with columns: time, signal, reference
%   lp_cutoff - lowpass cutoff frequency in Hz (default: 10)
%
%   result struct fields:
%     .time       - time vector
%     .raw        - original signal
%     .lowpassed  - after lowpass filter
%     .exp_fit    - the exponential fit curve
%     .corrected  - after subtracting exponential fit
%     .exp_coeffs - [a b c d] coefficients of exp2 fit

if nargin < 2; lp_cutoff = 10; end

time = fip.time;
if ismember('signal_artcorr', fip.Properties.VariableNames)
    sig = fip.signal_artcorr;
else
    sig = fip.signal;
end
fs = 1 / median(diff(time));

% step 1: lowpass butterworth filter
wn = lp_cutoff / (fs / 2);
[b, a] = butter(3, wn, 'low');
sig_lp = filtfilt(b, a, sig);

% step 2: exponential fit (double exponential) and subtract
f = fit(time, sig_lp, 'exp2');
exp_curve = f(time);
coeffs = coeffvalues(f);
sig_cor = sig_lp - exp_curve;

result.time = time;
result.raw = sig;
result.lowpassed = sig_lp;
result.exp_fit = exp_curve;
result.corrected = sig_cor;
result.exp_coeffs = coeffs;

end
