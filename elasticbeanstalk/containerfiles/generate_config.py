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

try: 
  import simplejson as json
except ImportError:
  import json

__data_file='/opt/elasticbeanstalk/deploy/configuration/containerconfiguration'
__output_file='/tmp/deployment/config/tomcat7'
if __name__=='__main__':
  parser = OptionParser()
  parser.add_option('-d', '--data-file', dest='data_file', default=__data_file)
  parser.add_option('-o', '--output-file', dest='output_file', default=__output_file)
  (options, args) = parser.parse_args()

  try:
    data = []
    with open(options.data_file) as f:
      data = json.loads(f.read())
          
    tomcat_data = data['tomcat']
    print 'using tomcat_data'

    output_line = ''
    if 'plugins' in data: 
      plugin_data = data['plugins']
      for resource_key, resource_value in plugin_data.iteritems():
      	if 'env' in resource_value:
      		resource_env_params = resource_value['env']
      		for resource_env_param_key, resource_env_param_value in resource_env_params.iteritems():
          		output_line += ' -D%s=\\"%s\\"' % (resource_env_param_key, resource_env_param_value)

    if 'env' in tomcat_data:
      for keyvalue in tomcat_data['env']:
        # Partition on first =
        (key, s, value) = keyvalue.partition('=')
        output_line += ' -D%s=\\"%s\\"' % (key, value)
          
    if 'jvmoptions' in tomcat_data:
      for keyvalue in tomcat_data['jvmoptions']:
        (key, s, value) = keyvalue.partition('=')
        if key.startswith('XX'):
          if value:
            output_line += ' -%s=%s' % (key, value)
          else:
            output_line += ' -%s' % key
        
        elif key.startswith('X'):
          if value:
            output_line += ' -%s%s' % (key, value)
          else:
            output_line += ' -%s' % key
      
        elif key == 'JVM Options' and value:
          output_line += ' %s' % value

        else:
          pass
     
    with open(options.output_file, 'w') as f:
      print 'Writing JAVA_OPTS'
      f.write('JAVA_OPTS="%s"' % output_line)

  except Exception, e:
    raise e
