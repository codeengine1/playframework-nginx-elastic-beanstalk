#!/bin/bash
if [[ "$EB_IS_COMMAND_LEADER" == "true" ]]; then 
  exit 0 
else  
  exit 1 
fi 
