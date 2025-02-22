function [E,J] = joint2_IK(in1,in2,in3)
%JOINT2_IK
%    [E,J] = JOINT2_IK(IN1,IN2,IN3)

%    This function was generated by the Symbolic Math Toolbox version 8.2.
%    16-Aug-2019 16:45:03

q1 = in2(1,:);
q2 = in2(2,:);
q3 = in3(1,:);
q4 = in3(2,:);
x2 = in1(1,:);
y2 = in1(2,:);
z2 = in1(3,:);
t2 = cos(q1);
t3 = cos(q2);
t4 = sin(q1);
t5 = sin(q4);
t6 = sin(q3);
t7 = cos(q3);
t8 = sin(q2);
t9 = cos(q4);
t10 = t3.*t4.*(3.3e1./1.0e2);
t11 = t2.*t3.*(3.3e1./1.0e2);
E = [t11-x2-t5.*(t4.*t6+t2.*t7.*t8).*(3.3e1./1.0e2)+t2.*t3.*t9.*(3.3e1./1.0e2);t10-y2+t5.*(t2.*t6-t4.*t7.*t8).*(3.3e1./1.0e2)+t3.*t4.*t9.*(3.3e1./1.0e2);t8.*(-3.3e1./1.0e2)-z2-t8.*t9.*(3.3e1./1.0e2)-t3.*t5.*t7.*(3.3e1./1.0e2)];
if nargout > 1
    J = reshape([-t10,t11,0.0,t2.*t8.*(-3.3e1./1.0e2),t4.*t8.*(-3.3e1./1.0e2),t3.*(-3.3e1./1.0e2)],[3,2]);
end
