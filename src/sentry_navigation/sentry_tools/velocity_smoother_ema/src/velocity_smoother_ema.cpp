// Copyright information
//
// © [2024] LimX Dynamics Technology Co., Ltd. All rights reserved.

#include <velocity_smoother_ema/velocity_smoother_ema.hpp>
#include <iostream>


VelocitySmootherEma::VelocitySmootherEma(ros::NodeHandle* nh):nh_(*nh)
{
    nh_.param<double>("/alpha_v", alpha_v, 0.4);
    nh_.param<double>("/alpha_w", alpha_w, 0.4);
    nh_.param<std::string>("/raw_cmd_topic", raw_cmd_topic, "raw_cmd_vel");
    nh_.param<std::string>("/cmd_topic", cmd_topic, "cmd_vel");
    nh_.param<double>("/cmd_rate", cmd_rate, 30.0);

    velocity_sub_ = nh_.subscribe(raw_cmd_topic, 10, &VelocitySmootherEma::twist_callback, this);
    velocity_pub_ = nh_.advertise<geometry_msgs::Twist>(cmd_topic, 10, true);
    timer = nh_.createTimer(ros::Duration(1.0 / cmd_rate), &VelocitySmootherEma::update, this);

    previous_x_vel = 0.0;
    previous_y_vel = 0.0;
    previous_w_vel = 0.0;
    x_vel = 0.0;
    y_vel = 0.0;
    w_vel = 0.0;
    smoothed_x_vel = 0.0;
    smoothed_y_vel = 0.0;
    smoothed_w_vel = 0.0;
}

VelocitySmootherEma::~VelocitySmootherEma()
{
    ros::shutdown();
}

void VelocitySmootherEma::twist_callback(const geometry_msgs::Twist::ConstPtr msg)
{
    // ROS_INFO("I RECEIVED A NEW MESSAGE");
    cmd_vel_msg_ = *msg;
    // send_request("request_twist", {{"x", cmd_vel_msg_.linear.x}, {"y",0}, {"z", cmd_vel_msg_.angular.z}});
    // std::cout<<"request_twist : x = "<<cmd_vel_msg_.linear.x<<" ; y = "<<   cmd_vel_msg_.linear.y<<" ; z = "<<cmd_vel_msg_.angular.z<<std::endl;  
}

void VelocitySmootherEma::update(const ros::TimerEvent&)
{
    x_vel = cmd_vel_msg_.linear.x;
    y_vel = cmd_vel_msg_.linear.y;
    w_vel = cmd_vel_msg_.angular.z;

    smoothed_x_vel = alpha_v * x_vel + (1 - alpha_v) * previous_x_vel;
    smoothed_y_vel = alpha_v * y_vel + (1 - alpha_v) * previous_y_vel;
    smoothed_w_vel = alpha_w * w_vel + (1 - alpha_w) * previous_w_vel;

    cmd_vel_msg_.linear.x = smoothed_x_vel;
    cmd_vel_msg_.linear.y = smoothed_y_vel;
    cmd_vel_msg_.angular.z = smoothed_w_vel;

    previous_x_vel = smoothed_x_vel;
    previous_y_vel = smoothed_y_vel;
    previous_w_vel = smoothed_w_vel;    

    velocity_pub_.publish(cmd_vel_msg_);
    // ROS_INFO("PUBLISHING TWIST MESSAGE!");
}

int main(int argc, char** argv)
{
    ros::init(argc, argv, "velocity_smoother_ema");

    ros::NodeHandle nh;

    VelocitySmootherEma vse(&nh);
    
    // 옵션 1
    // 启动异步的 ROS Spinner（4个线程）
    ros::AsyncSpinner spinner(4); // 线程数可根据需要调整
    spinner.start(); // 非阻塞

    std::cout << "ROS velocity_smoother_ema 노드 실행 중... Ctrl+C로 종료하세요." << std::endl;

    // ROS 종료될 때까지 대기 (Ctrl+C 입력 등)
    ros::waitForShutdown();

    spinner.stop();

    // 옵션 2
    // 웹소켓/수동 루프 제거 → ROS 기본 스핀 사용
    // std::cout << "ROS velocity_smoother_ema 노드 실행 중... Ctrl+C로 종료하세요." << std::endl;
    // ros::spin();

    return 0;
}
