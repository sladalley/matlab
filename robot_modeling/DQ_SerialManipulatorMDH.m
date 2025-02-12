% Concrete class that extends the DQ_SerialManipulator using the
% modified Denavit-Hartenberg parameters (MDH)
%
% Usage: robot = DQ_SerialManipulatorMDH(A)
% - 'A' is a 5 x n matrix containing the Denavit-Hartenberg parameters
%   (n is the number of links)
%    A = [theta1 ... thetan;
%            d1  ...   dn;
%            a1  ...   an;
%         alpha1 ... alphan;
%         type1  ... typen]
% where type is the actuation type, either DQ_JointType.REVOLUTE
% or DQ_JointType.PRISMATIC
% - The only accepted convention in this subclass is the 'modified' DH
% convention.
%
% If the joint is of type REVOLUTE, then the first row of A will
% have the joint offsets. If the joint is of type PRISMATIC, then the
% second row of A will have the joints offsets.
%
% DQ_SerialManipulatorMDH Methods (Concrete):
%       get_dim_configuration_space - Return the dimension of the configuration space.
%       fkm - Compute the forward kinematics while taking into account base and end-effector's rigid transformations.
%       plot - Plots the serial manipulator.
%       pose_jacobian - Compute the pose Jacobian while taking into account base's and end-effector's rigid transformations.
%       pose_jacobian_derivative - Compute the time derivative of the pose Jacobian.
%       raw_fkm - Compute the FKM without taking into account base's and end-effector's rigid transformations.
%       raw_pose_jacobian - Compute the pose Jacobian without taking into account base's and end-effector's rigid transformations.
%       raw_pose_jacobian_derivative - Compute the pose Jacobian derivative without taking into account base's and end-effector's rigid transformations.
%       set_effector - Set an arbitrary end-effector rigid transformation with respect to the last frame in the kinematic chain.
% See also DQ_SerialManipulator.

% (C) Copyright 2020-2023 DQ Robotics Developers
%
% This file is part of DQ Robotics.
%
%     DQ Robotics is free software: you can redistribute it and/or modify
%     it under the terms of the GNU Lesser General Public License as published
%     by the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
%     DQ Robotics is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU Lesser General Public License for more details.
%
%     You should have received a copy of the GNU Lesser General Public License
%     along with DQ Robotics.  If not, see <http://www.gnu.org/licenses/>.
%
% DQ Robotics website: dqrobotics.github.io
%
% Contributors to this file:
%     1. Bruno Vihena Adorno (adorno@ieee.org)
%        Responsible for the original implementation in file SerialManipulator.m 
%        [bvadorno committed on Apr 10, 2019] (bc7a95f)
%        (https://github.com/dqrobotics/matlab/blob/bc7a95f064b15046f43421d418946f60b1b33058/robot_modeling/DQ_SerialManipulator.m).
%
%     2. Murilo M. Marinho (murilo@nml.t.u-tokyo.ac.jp)
%        - Reorganized the code by moving the implementation of SerialManipulator.m 
%         to the file DQ_SerialManipulatorDH at #56
%        (https://github.com/dqrobotics/matlab/pull/56),
%         which is the starting point for this file.
%
%     3. Juan Jose Quiroz Omana (juanjqo@g.ecc.u-tokyo.ac.jp)
%        - Created this file. Implemented the case for prismatic joints
%          in method get_w().





classdef DQ_SerialManipulatorMDH < DQ_SerialManipulator
    properties
        theta,d,a,alpha;
    end
    
    properties (Constant)
        % Joints that can be actuated
        % Rotational joint
        JOINT_ROTATIONAL = 1; % Deprecated
        % Prismatic joint
        JOINT_PRISMATIC = 2;  % Deprecated
    end
    methods (Access = protected)
        function dq = get_link2dq(obj,q,ith)
            %   GET_LINK2DQ(q, ith) calculates  the corresponding dual quaternion for
            %   a given link's modified DH parameters
            %
            %   Usage: dq = get_link2dq(q,ith), where
            %          q: joint value
            %          ith: link number
            %
            %   Eq. (2.34) of Adorno, B. V. (2011). Two-arm Manipulation: From Manipulators
            %   to Enhanced Human-Robot Collaboration [Contribution à la manipulation à deux bras : 
            %   des manipulateurs à la collaboration homme-robot]. 
            %   https://tel.archives-ouvertes.fr/tel-00641678/
            
            if nargin ~= 3
                error('Wrong number of arguments. The parameters are joint value and the correspondent link')
            end
            
            % Store half angles and displacements
            half_theta = obj.theta(ith)/2.0;
            d = obj.d(ith);
            a = obj.a(ith);
            half_alpha = obj.alpha(ith)/2.0;
            
            % Add the effect of the joint value
            if obj.get_joint_type(ith) == DQ_JointType.REVOLUTE
                % If joint is revolute
                half_theta = half_theta + (q/2.0);
            else
                % If joint is prismatic
                d = d + q;
            end
            
            % Pre-calculate cosines and sines
            sine_of_half_theta = sin(half_theta);
            cosine_of_half_theta = cos(half_theta);
            sine_of_half_alpha = sin(half_alpha);
            cosine_of_half_alpha = cos(half_alpha);
            
            d2 = d/2;
            a2 = a/2;
            h(1) = cosine_of_half_alpha*cosine_of_half_theta;
            h(2) = sine_of_half_alpha*cosine_of_half_theta;
            h(3) = -sine_of_half_alpha*sine_of_half_theta;
            h(4) = cosine_of_half_alpha*sine_of_half_theta;
            h(5) = -a2*h(2) - d2*h(4);
            h(6) =  a2*h(1) - d2*-h(3);
            h(7) = -a2*h(4) - d2*h(2);
            h(8) = d2*h(1)  - a2*-h(3);
            dq = DQ(h);
        end 

        function w = get_w(obj,ith) 
        % This method returns the term 'w' related with the time derivative of 
        % the unit dual quaternion pose using the Modified DH convention.
        % See. eq (2.32) of 'Two-arm Manipulation: From Manipulators to Enhanced 
        % Human-Robot Collaboration' by Bruno Adorno.
        % Usage: w = get_w(ith), where
        %          ith: link number

            if obj.get_joint_type(ith) == DQ_JointType.REVOLUTE            
                w = -DQ.j*sin(obj.alpha(ith))+ DQ.k*cos(obj.alpha(ith))...
                    -DQ.E*obj.a(ith)*(DQ.j*cos(obj.alpha(ith)) + DQ.k*sin(obj.alpha(ith)));
            else % if joint is PRISMATIC          
                w = DQ.E*(cos(obj.alpha(ith))*DQ.k - sin(obj.alpha(ith))*DQ.j);
            end
        end 
    end

    methods (Static, Access = protected) 
         % This method returns the supported joint types.
         function ret = get_supported_joint_types()
        % This method returns the supported joint types.
            ret = [DQ_JointType.REVOLUTE, DQ_JointType.PRISMATIC];
         end
    end

    methods
        function obj = DQ_SerialManipulatorMDH(A)
            % These are initialized in the constructor of
            % DQ_SerialManipulator 
            % obj.dim_configuration_space = dim_configuration_space;

            str = ['DQ_SerialManipulatorMDH(A), where ' ...
                   'A = [theta1 ... thetan; ' ...
                   ' d1  ...   dn; ' ...
                   ' a1  ...   an; ' ...
                   ' alpha1 ... alphan; ' ...
                   ' type1  ... typen]'];
            
            
            if nargin == 0
                error(['Input: matrix whose columns contain the modified DH parameters' ...
                       ' and type of joints. Example: ' str])
            end
            
            if(size(A,1) ~= 5)
                error('Input: Invalid modified DH matrix. It must have 5 rows.')
            end

            obj.dim_configuration_space = size(A,2);

            % Add theta, d, a, alpha and type
            obj.theta = A(1,:);
            obj.d     = A(2,:);
            obj.a     = A(3,:);
            obj.alpha = A(4,:);
            obj.set_joint_types(A(5,:));
        end
        
    end
    
end