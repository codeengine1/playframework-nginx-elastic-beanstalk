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

mkdir -p /opt/elasticbeanstalk/tasks/bundlelogs.d
mkdir -p /opt/elasticbeanstalk/tasks/publishlogs.d
mkdir -p /opt/elasticbeanstalk/tasks/systemtaillogs.d
mkdir -p /opt/elasticbeanstalk/tasks/taillogs.d


cat > /opt/elasticbeanstalk/tasks/taillogs.d/play.conf <<EOLTAILLOG
/var/app/current/logs/*.log
EOLTAILLOG


cat > /opt/elasticbeanstalk/tasks/systemtaillogs.d/play.conf <<EOLSYSTAILLOG
/var/app/current/logs/*.log
EOLSYSTAILLOG

cat > /opt/elasticbeanstalk/tasks/bundlelogs.d/play.conf <<EOLBUNDLELOG
/var/app/current/logs/*.log
EOLBUNDLELOG

cat > /opt/elasticbeanstalk/tasks/publishlogs.d/play.conf <<EOLPUBLOG
/var/app/current/logs/*.gz
EOLPUBLOG

