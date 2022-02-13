#!/bin/bash
#Order: ec2, describe, nginx, target, loadbalancer
ip1=""
ip2=""
id1=""
id2=""

#2db EC2 instance indítása
start_instances() {
desc=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=erdelyi*" "Name=instance-state-name,Values=running" \
       --output text --query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Tags[?Key==`Name`].Value]')
if [ -z "$desc" ]
then
aws ec2 run-instances --image-id ami-042ad9eec03638628 \
--count 1 --instance-type t2.micro --key-name erdelyi-tamas \
--security-group-ids sg-08fb876c08317c18c \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=erdelyi-tamas-nginx1}]'

aws ec2 run-instances --image-id ami-042ad9eec03638628 \
--count 1 --instance-type t2.micro --key-name erdelyi-tamas \
--security-group-ids sg-08fb876c08317c18c \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=erdelyi-tamas-nginx2}]'
starter
else
#Ha futnak már futnak a gépek, itt ki lehet őket lőni.
echo "Instances are already running."
read -p "Terminate the instances?" term
if [ "$term" == "yes" ]
then
while IFS=" " read -r ips
do
ezaz+="$ips "
done <<< "$desc"
id1=$(echo $ezaz | cut -d " " -f 2)
id2=$(echo $ezaz | cut -d " " -f 5)
aws ec2 terminate-instances --instance-ids $id1 $id2
starter
else
starter
fi
fi
}

describe_my_instances() {
#InstanceID and public IP
desc=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=erdelyi*" "Name=instance-state-name,Values=running" \
       --output text --query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Tags[?Key==`Name`].Value]')
if [ -z "$desc" ]
then
echo "Instance not available!"
starter
else
while IFS=" " read -r ips
do
ezaz+="$ips "
done <<< "$desc"
ip1=$(echo $ezaz | cut -d " " -f 1)
ip2=$(echo $ezaz | cut -d " " -f 4)
id1=$(echo $ezaz | cut -d " " -f 2)
id2=$(echo $ezaz | cut -d " " -f 5)
echo "First instance IP:" $ip1 "ID:" $id1
echo "Second instance IP:" $ip2 "ID:" $id2
starter
fi
}

#The name speaks for itself
install_nginx() {
curling=$(curl $ip1:3000 | grep "If you see this page")
if [ "$curling" == "<p>If you see this page, the nginx web server is successfully installed and" ]
then
echo "Nginx is already installed!"
starter
else
read -p "How many instance:" num
if [ "$num" == 1 ]
then
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip1 < nginx.sh
    starter
elif [ "$num" == 2 ]
then
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip1 < nginx.sh
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip2 < nginx2.sh
    starter
fi
fi
}

create_target() {
#Target Group OK
target_test=$(aws elbv2 describe-target-groups --names team8-targetGroup --query "TargetGroups[*].[TargetGroupName]" --output text)
if [ "$target_test" == "team8-targetGroup" ]
then
echo "Target group are already created!"
read -p "Delete target group?" del_target
if [ "$del_target" == "yes" ]
then
grouparn=$(aws elbv2 describe-target-groups --names team8-targetGroup | grep -i "TargetGroupArn" | cut -d '"' -f 4)
aws elbv2 delete-target-group --target-group-arn $grouparn
starter
else
starter
fi
else
aws elbv2 create-target-group --name team8-targetGroup --protocol HTTP \
--target-type instance \
--port 3000 --vpc-id vpc-0a169bcf3056ea695 --health-check-port 3000 \
--health-check-enabled --health-check-path / --health-check-interval-seconds 5 \
--health-check-timeout-seconds 2 --healthy-threshold-count 2 \
--matcher HttpCode="200"
grouparn=$(aws elbv2 describe-target-groups --names team8-targetGroup | grep -i "TargetGroupArn" | cut -d '"' -f 4)
aws elbv2 register-targets --target-group-arn $grouparn \
--targets Id=$id1 Id=$id2
starter
fi
}

loadbalancer() {
grouparn=$(aws elbv2 describe-target-groups --names team8-targetGroup | grep -i "TargetGroupArn" | cut -d '"' -f 4)
securitytest=$(aws ec2 describe-security-groups --group-names team8-loadbalance --query "SecurityGroups[*].[GroupName]" --output text)
if [ "$securitytest" == "team8-loadbalance" ]
then
echo "Security group already created!"
read -p "Delete security group?" del_group
    if [ "$del_group" == "yes" ]
    then
    aws ec2 delete-security-group --group-name team8-loadbalance
    fi
else
    aws ec2 create-security-group --group-name team8-loadbalance \
    --description "Load balancer for team 8" \
    --vpc-id vpc-0a169bcf3056ea695
#Inbound rule - only available on port 80
aws ec2 authorize-security-group-ingress --group-name team8-loadbalance \
--protocol tcp \
--port 80 \
--cidr 0.0.0.0/0
fi
secure=$(aws ec2 describe-security-groups --group-names team8-loadbalance --query "SecurityGroups[*].[GroupId]" --output text)
loadbalancertest=$(aws elbv2 describe-load-balancers --names team8-loadbalancer --query "LoadBalancers[*].[LoadBalancerName]" --output text)
if [ "$loadbalancertest" == "team8-loadbalancer" ]
then
echo "Load balancer already created!"
read -r "Delete load balancer?" del_balancer
    if [ "$del_balancer" == "yes" ]
    then
    loadbalancearn=$(aws elbv2 describe-load-balancers --names team8-loadbalancer --query "LoadBalancers[*].[LoadBalancerArn]" --output text)
    aws elbv2 delete-load-balancer --load-balancer-arn $loadbalancearn
    fi
else
aws elbv2 create-load-balancer --name team8-loadbalancer \
--subnets subnet-08dfcde0987331ae7 subnet-0b961cdffe0cf2af8 subnet-02d203f989dfb4dd8 \
--security-groups $secure

loadbalancearn=$(aws elbv2 describe-load-balancers --names team8-loadbalancer --query "LoadBalancers[*].[LoadBalancerArn]" --output text)

aws elbv2 create-listener --load-balancer-arn $loadbalancearn \
--protocol HTTP --port 80 \
--default-actions Type=forward,TargetGroupArn=$grouparn
fi
starter
}

help() {
    printf "            ec2 = Starting 2 EC2 instances \n
            nginx = Start nginx on the instances \n
            describe = Describe my instances \n
            target = Creating target group \n
            loadbalancer = Creating application load balancer \n
            exit = Exit the program \n"
    starter
}

starter() {
    read -p "Choose function:" func
    if [ "$func" == "help" ]
    then
    help
    elif [ "$func" == "ec2" ]
    then
    start_instances
    elif [ "$func" == "nginx" ]
    then
    install_nginx
    elif [ "$func" == "describe" ]
    then
    describe_my_instances
    elif [ "$func" == "target" ]
    then
    create_target
    elif [ "$func" == "loadbalancer" ]
    then
    loadbalancer
    elif [ "$func" == "exit" ]
    then
    echo "Bye!"
    exit
    else
    echo "Wrong command!"
    starter
    fi
}
echo "Load Balancer project"
starter