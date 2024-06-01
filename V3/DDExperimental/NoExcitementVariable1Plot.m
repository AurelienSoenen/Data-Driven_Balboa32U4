

%%
clear; close all; clc;
%% ------------------------------- Theorie ------------------------------- 
% Dimension of A : n x n
A_c = [0 0 1 0; 
       0 0 0 1; 
       0 -69.4 0 0; 
       0  150 0 0];

% Dimension of B : n x m
B_c = [0; 0; 273; -130];

% Parameters
n = size(A_c,2);          
m = size(B_c,2);

Ts = 0.01; % Example: 10ms sampling time -> 100H
% Discretize the system
sys_c = ss(A_c,B_c,[1 0 0 0],0);
sys_d = c2d(sys_c, Ts);
A = sys_d.A;
B = sys_d.B;

% Assigment of the set 
% Define the settling time (in seconds)
t_s = 1;
bessel_4var1 = (1 / t_s) * [-4.016 + 5.072i, -4.016 - 5.072i, -5.528 + 1.655i, -5.528 - 1.655i];
t_s = 0.6;
bessel_4var06 = (1 / t_s) * [-4.016 + 5.072i, -4.016 - 5.072i, -5.528 + 1.655i, -5.528 - 1.655i];
p_4var_bessel1 = exp(bessel_4var1 * Ts);
p_4var_bessel06 = exp(bessel_4var06 * Ts);

% Model-Based Pole-placement methods
% The place.m function requires the Control System Toolbox.
K_bessel1_theory = place(A, B, p_4var_bessel1);
K_bessel06_theory = place(A, B, p_4var_bessel06);
K_MB = K_bessel1_theory - [0 0 0.19 0];

%% ------------------------------- LOAD DATA ------------------------------- 
 
% Arrays to store eigenvalue differences
eig_diff1_values = [];
eig_diff2_values = [];

Tmin = 00;
T_values = (50:10:200);
rng(30);

% Measured data (u,x) is generated by simulating the open loop system
%filePath = sprintf('../data/ITAE/%.1f.txt', t_sITAE);
filePath = sprintf('../data/rdmITAE1.txt');
data = readmatrix(filePath);
% Extract variables
phi = data(:, 2);
theta = data(:, 3);
phi_dot = data(:, 4);
theta_dot = data(:, 5);
u = [data(:, 6)]';  % Normalize input
ref = data(:, 7);  % reference variable
cst = sign(u);
x = [(phi-ref)'; theta'; phi_dot'; theta_dot'];
 
% Arrays to store eigenvalue differences
eig_diff1_values = [];
eig_diff2_values = [];
min_eig_diff1 = inf;
min_eig_diff2 = inf;
best_K_directDD = [];
best_K_indirectDD = [];

% Loop over T values
for T = T_values
    % Feedback gain after perturbation
    U_0 = u(:,Tmin+1:Tmin+T-1); % Dimension of U_0 : m x T-1
    X_0 = x(:,Tmin+1:Tmin+T-1); % Dimension of X_0 : n x T-1
    X_1 = x(:,Tmin+2:Tmin+T); % Dimension of X_1 : n x T-1

    M_rdm = ones(T-1,n);

    rdmPoles = p_4var_bessel1;

    for i = 1:n
        M_rdm(:,i) = fsolve(@(m_i) (X_1 - rdmPoles(i)*X_0)*m_i, M_rdm(:,i));
    end

    K_directDD = - U_0 * M_rdm * pinv(X_0 * M_rdm);
    eig_diff1 = mean(abs(abs(K_directDD - K_MB)./abs(K_MB)));
    eig_diff1_values = [eig_diff1_values, eig_diff1];
    if eig_diff1 < min_eig_diff1
        min_eig_diff1 = eig_diff1;
        best_K_directDD = K_directDD;
    end

    % Linear Regression for A and B
    if T > 5
        BA = X_1 * pinv([X_0; U_0]);
        A_OL = BA(:, 1:4); % This assumes A is in the second column of the combined matrix
        B_OL = BA(:, 5); % This assumes B is in the first column of the combined matrix
        
        K_indirectDD = place(A_OL, B_OL, rdmPoles);
        eig_diff2 = mean(abs(abs(K_indirectDD - K_MB)./-K_MB));
        eig_diff2_values = [eig_diff2_values, eig_diff2];
        if eig_diff2 < min_eig_diff2
            min_eig_diff2 = eig_diff2;
            best_K_indirectDD = K_indirectDD;
        end
    end
end
disp(real(K_MB));
%% Display the values of K_directDD and K_indirectDD for the lowest eigenvalue differences
disp('K_directDD with lowest eig_diff1:');
disp(real(best_K_directDD));
disp(min_eig_diff1);
disp('K_indirectDD with lowest eig_diff2:');
disp(best_K_indirectDD);
disp( min_eig_diff2);

folderName = 'DataForPlot';
if ~exist(folderName, 'dir')
    mkdir(folderName);
end

% Prepare the data to be saved
x = T_values/100;
y1 = eig_diff1_values;
y2 = eig_diff2_values;
data = [x' y1' y2'];

% Write to CSV
file = 'NoExcitementVariable1Plot';
csvwrite(fullfile(folderName, sprintf('%s.csv', file)), data);

% Optionally, include headers using fprintf
fileID = fopen(fullfile(folderName, sprintf('%s.csv', file)), 'w');
fprintf(fileID, 'x,y1,y2\n');
fclose(fileID);
dlmwrite(fullfile(folderName, sprintf('%s.csv', file)), data, '-append');


