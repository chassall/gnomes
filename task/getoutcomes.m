function outcomes = getoutcomes(trialTypes)
%GETOUTCOMES Summary of this function goes here
%   Detailed explanation goes here

% PDFs
sigma = 0.01; % standard deviation
mus = [1/3; 2/3];

% Gnome 1
mu = mus(1);
pds{1} = makedist('normal','mu',mu,'sigma',sigma);
pds{1}= truncate(pds{1},0,1);

% Gnome 2
mu = mus(2);
pds{2} = makedist('normal','mu',mu,'sigma',sigma);
pds{2}= truncate(pds{2},0,1);

% Gnome 3
p = [0.5, 0.5];
% pds{3} = gmdistribution(mus,cat(3, sigma, sigma), p);
pds{3} = gmdistribution(mus,sigma^2, p);

% Gnome 4
p = [0.8, 0.2];
pds{4} = gmdistribution(mus,sigma^2, p);

% Gnome 5
p = [0.2, 0.8];
pds{5} = gmdistribution(mus,sigma^2, p);

% Gnome 6
pds{6} = makedist('uniform','lower',0.1,'upper',0.9);

outcomes = nan(1,length(trialTypes));
for i = 1:length(trialTypes)
    
    thisPDF = pds{trialTypes(i)};
    
    outcomes(i) = random(thisPDF);
    while outcomes(i) < 0.1 || outcomes(i) > 0.9
        outcomes(i) = random(thisPDF);
    end
    
end

end



