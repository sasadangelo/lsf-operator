# Deploying the LSF Cluster

The LSF cluster is defined by a yaml file which the LSF operator uses to deploy the LSF cluster.
A sample LSF cluster definition is in: `lsf-operator/config/samples/example-lsfcluster.yaml`

This file should be modified to suit the LSF configuration you need.  The LSF operator can deploy and delete the cluster in a few minutes, so it is easy to try different configurations.

**NOTE: The images are cached locally on the kubernetes nodes......................
