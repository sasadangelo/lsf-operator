#!/bin/bash
#--------------------------------------------------------
# Copyright IBM Corp. 1992, 2019. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#--------------------------------------------------------

# This script will trigger the LSF machines to reconfigure

if [ ! -e lsf.cluster.myCluster ]; then
    echo "Error:  This script has to be run in the LSF conf directory"
    exit 1
fi

if [ ! -e .reconfighosts ]; then
    echo "Error:  This does not appear to be a LSF cluster running in ICP"
    exit 1
fi

echo "Are you sure you want to reconfigure [y|n]?"
read IN
if [ "$IN" = "y" -o "$IN" = "Y" ]; then
    touch .reconfighosts/lsfmaster
    echo "Checking the cluster status after reconfiguring is recommended"
else
    echo "Aborting."
fi
