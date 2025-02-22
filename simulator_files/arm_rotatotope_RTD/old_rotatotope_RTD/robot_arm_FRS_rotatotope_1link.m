classdef robot_arm_FRS_rotatotope_1link
    %robot_arm_FRS_rotatotope_fetch Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        rot_axes = [3;2];
        link_joints = {[1;2]};
        link_zonotopes = {zonotope([0.33/2, 0.33/2; 0, 0; 0, 0])};
        link_EE_zonotopes = {zonotope([0.33; 0; 0])};
        n_links = 1;
        n_time_steps = 0;
        dim = 3;
        FRS_path = 'FRS_trig_constantK/';
        FRS_key = [];
        
        q = zeros(2, 1);
        q_dot = zeros(2, 1);
        
        link_rotatotopes = {};
        link_EE_rotatotopes = {};
        link_FRS = {}
        
        FRS_options = {};
        
        A = {}; % polytope (buffered by obs) normal vectors
        
        c_k = [];
        g_k = [];
    end
    
    methods
        function obj = robot_arm_FRS_rotatotope_1link(q, q_dot)
            %robot_arm_FRS_rotatotope_fetch constructs an FRS for the full arm
            % based on rotatotopes. this class is specific to the Fetch,
            % and will create an FRS using default link lengths and
            % rotation axis order.
            % the constructor just requires the current state and velocity
            % of the robot.
            
            obj.q = q;
            obj.q_dot = q_dot;
            
            FRSkeytmp = load([obj.FRS_path, '0key.mat']); % fix this
            obj.FRS_key = FRSkeytmp.c_IC;
            
            obj = obj.create_FRS();
            obj.FRS_options.combs = generate_combinations_upto(200);
            obj.FRS_options.maxcombs = 200;
            
            obj.FRS_options.buffer_dist = 0.0; %% HACK
            
            % all rotatotopes defined for same parameter set:
            obj.c_k = obj.link_rotatotopes{end}{end}.c_k;
            obj.g_k = obj.link_rotatotopes{end}{end}.g_k;
            
            % generate k vertices for each link
            for i = 1:obj.n_links
                cubeV = cubelet_ND(length(obj.link_joints{i}))';
                obj.FRS_options.kV{i} = (cubeV.*obj.g_k(obj.link_joints{i})) + obj.c_k(obj.link_joints{i});
                obj.FRS_options.kV_lambda{i} = cubeV;
            end
        end
        
        function obj = create_FRS(obj)
            % this function loads the appropriate trig FRS's given q_dot,
            % rotates them by q, then constructs and stacks rotatotopes at
            % each time step
            trig_FRS = cell(length(obj.q_dot), 1);
            for i = 1:length(obj.q_dot)
                [~, closest_idx] = min(abs(obj.q_dot(i) - obj.FRS_key));
                filename = sprintf('%strig_FRS_%0.3f.mat', obj.FRS_path, obj.FRS_key(closest_idx));
                trig_FRS_load_tmp = load(filename);
                trig_FRS_load{i} = trig_FRS_load_tmp.Rcont;
                A = [cos(obj.q(i)), -sin(obj.q(i)), 0, 0, 0; sin(obj.q(i)), cos(obj.q(i)), 0, 0, 0;...
                    0, 0, 1, 0, 0; 0, 0, 0, 1, 0; 0, 0, 0, 0, 1];
                for j = 1:length(trig_FRS_load{i})
                    trig_FRS{j}{i} = A*zonotope_slice(trig_FRS_load{i}{j}{1}, 4, obj.q_dot(i));
                end
            end
            obj.n_time_steps = length(trig_FRS);
            
            % construct a bunch of rotatotopes
            for i = 1:obj.n_links
               for j = 1:obj.n_time_steps
                   obj.link_rotatotopes{i}{j} = rotatotope(obj.rot_axes(obj.link_joints{i}), trig_FRS{j}(obj.link_joints{i}), obj.link_zonotopes{i});
               end
            end
            for i = 1:obj.n_links - 1
                for j = 1:obj.n_time_steps
                    obj.link_EE_rotatotopes{i}{j} = rotatotope(obj.rot_axes(obj.link_joints{i}), trig_FRS{j}(obj.link_joints{i}), obj.link_EE_zonotopes{i});
                end
            end
            
            % stack
            obj.link_FRS = obj.link_rotatotopes;
            for i = 2:obj.n_links
                for j = 1:obj.n_time_steps
                    for k = 1:i-1
                        obj.link_FRS{i}{j} = obj.link_FRS{i}{j}.stack(obj.link_EE_rotatotopes{k}{j});
                    end
                end
            end
        end
        
        function [] = plot(obj, rate, colors)
            if ~exist('colors', 'var')
                colors = {'b', 'r', 'm'};
            end
            if ~exist('rate', 'var')
                rate = 1;
            end
            for i = 1:length(obj.link_FRS)
                for j = 1:rate:length(obj.link_FRS{i})
                    obj.link_FRS{i}{j}.plot(colors{i});
                end
            end
            
        end
        
        function [] = plot_slice(obj, k, rate, colors)
            if ~exist('colors', 'var')
                colors = {'b', 'r', 'm'};
            end
            if ~exist('rate', 'var')
                rate = 1;
            end
            for i = 1:length(obj.link_FRS)
                for j = 1:rate:length(obj.link_FRS{i})
                    obj.link_FRS{i}{j}.plot_slice(k(obj.link_joints{i}), colors{i});
                end
            end
            
        end
        
%         function [obj] = generate_constraints(obj, obstacles)
%             for i = 1:length(obstacles)
%                 for j = 1:length(obj.link_FRS)
%                     for k = 1:length(obj.link_FRS{j})
%                         [obj.A_con{i}{j}{k}, obj.b_con{i}{j}{k}, obj.k_con{i}{j}{k}] = obj.link_FRS{j}{k}.generate_constraints(obstacles{i}.zono.Z, obj.FRS_options, j);
%                     end
%                 end
%             end
%         end

        function [obj] = generate_polytope_normals(obj, obstacles)
            for i = 1:length(obstacles)
                obs_Z = [obstacles{i}.zono.Z, obj.FRS_options.buffer_dist/2*eye(3)];
                for j = 1:length(obj.link_FRS)
                    for k = 1:length(obj.link_FRS{j})
                        [obj.A{i}{j}{k}] = obj.link_FRS{j}{k}.generate_polytope_normals(obs_Z, obj.FRS_options);
                    end
                end
            end
        end
        
        function [h, grad_h] = evaluate_sliced_constraints(obj, k_opt, obstacles)
            h = [];
            grad_h = [];
            k_opt_length = length(k_opt);
            for i = 1:length(obstacles)
                obs_Z = [obstacles{i}.zono.Z, obj.FRS_options.buffer_dist/2*eye(3)];
                for j = 1:length(obj.link_FRS)
                    idx = find(~cellfun('isempty', obj.A{i}{j}));
                    for k = 1:length(idx)
                        [h_tmp, grad_h_tmp] = obj.link_FRS{j}{idx(k)}.evaluate_sliced_constraints(k_opt, obs_Z, obj.A{i}{j}{idx(k)});
                        h = [h; h_tmp];
                        grad_h = [grad_h, grad_h_tmp];
                    end
                end
            end
        end
%         function [h, grad_h] = evaluate_sliced_constraints(obj, k_opt, obstacles)
%             h = [];
%             epsilon = 1e-6;
%             for i = 1:length(obstacles)
%                 obs_Z = obstacles{i}.zono.Z;
%                 for j = 1:length(obj.link_FRS)
%                     for k = 1:length(obj.link_FRS{j})
%                         
%                         if isempty(obj.A{i}{j}{k})
%                             h = [h; -inf];
%                             grad_h = [grad_h, []];
%                             continue;
%                         end
%                         
%                         Z = obj.link_FRS{j}{k}.slice(k_opt);
%                         c = Z(:, 1) - obs_Z(:, 1); % shift so that obstacle is zero centered!
%                         G = [Z(:, 2:end), obs_Z(:, 2:end)];
%                         
%                         deltaD = sum(abs((obj.A{i}{j}{k}*G)'))';
%                     
%                         d = obj.A{i}{j}{k}*c;
%                         
%                         Pb = [d+deltaD; -d+deltaD];
%                         
%                         h_obs = -Pb; % equivalent to A*[0;0;0] - b
%                         h_obs_max = max(h_obs);
%                         h_tmp = -(h_obs_max - epsilon);
%                         
%                         h = [h; h_tmp];
%                         grad_h = [grad_h, []];
%                     end
%                 end
%             end
%         end

        
    end
end

