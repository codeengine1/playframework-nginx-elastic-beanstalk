#!/bin/bash
#==============================================================================
# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================

set -xe

monit restart play
monit restart nginx
monit stop awslogs

sleep 2
cp -f /opt/elasticbeanstalk/containerfiles/awslogs.conf /etc/awslogs/awslogs.conf
ELASTIC_BEANSTALK_ENVIRONMENT="$( ebname.py )"
sed -i "s/{environment_name}/$ELASTIC_BEANSTALK_ENVIRONMENT/g" /etc/awslogs/awslogs.conf
sleep 2

monit start awslogs