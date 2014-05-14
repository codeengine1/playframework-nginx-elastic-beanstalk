#!/usr/bin/env python
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


from __future__ import with_statement
from optparse import OptionParser
from os import environ
import os.path
import glob

try: 
    import simplejson as json
except ImportError:
    import json

_DATA_FILE='/opt/elasticbeanstalk/deploy/configuration/containerconfiguration'
_TOMCAT_TMP_DIR='/tmp/deployment/application/ROOT'
_LEADER_VAR='EB_IS_COMMAND_LEADER'

def get_classpath(deploy_dir):
    classpath = environ['classpath'] if 'classpath' in environ else ""
    classpath += os.path.join(deploy_dir, 'WEB-INF', 'classes')
    lib_dir = os.path.join(deploy_dir, 'WEB-INF', 'lib')
    if os.path.exists(lib_dir):
        jars = glob.glob(os.path.join(lib_dir, '*.jar'))
        classpath += ":"
        classpath += ':'.join(jars)

    return classpath
    

def main():
    parser = OptionParser()
    parser.add_option('-d', '--data-file', dest='data_file', default=_DATA_FILE)
    parser.add_option('-t', '--deploy-dir', dest='deploy_dir', default=_TOMCAT_TMP_DIR)
    (options, args) = parser.parse_args()

    data = {}
    with open(options.data_file) as f:
        data = json.loads(f.read())

    tomcat_data = data['tomcat']

    environment = {}
    if 'plugins' in data: 
        plugin_data = data['plugins']
        for resource_key, resource_value in plugin_data.iteritems():
            if 'env' in resource_value:
                resource_env_params = resource_value['env']
                environment.update(resource_env_params)
          
    if 'env' in tomcat_data:
        for keyvalue in tomcat_data['env']:
            (key, s, value) = keyvalue.partition('=')
            environment[key] = value

    classpath = get_classpath(options.deploy_dir)
    if 'CLASSPATH' in os.environ:
        environment['CLASSPATH'] = '%s:%s' % (os.environ['CLASSPATH'], classpath)
    else:
        environment['CLASSPATH'] = classpath

    if _LEADER_VAR in os.environ:
        environment[_LEADER_VAR] = os.environ[_LEADER_VAR]

    response = {"env": environment, "cwd": options.deploy_dir}
    print json.dumps(response)

if __name__=='__main__':
    main()

