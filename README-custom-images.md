# LSF On Kubernetes/OpenShift

This directory contains the code needed to generate the docker images for LSF.  It generates four images:
* lsf-operator	- The tool that will install a LSF cluster on Kubernetes
* lsf-compute	- The LSF image for running jobs.  This is the image that should be customized to support the workloads you wish to run.
* lsf-master	- This is the image for the LSF scheduler main processes.  Jobs should not be run here.
* lsf-gui	- This is the image for the LSF GUI processes.

The images are build from a CentOS 7 base, however instructions are provided for creating alternate OS images.  The images need to be customized to:
1. Enable LDAP/AD/NIS users to login to the LSF GUI.  This will require installing any OS packages needed to authenticate users, and starting the needed authentication processes.
2. Installing any OS dependencies that the workload may require.  Applications can be mounted from NFS directories, however those applications may require OS packages.  


## Prerequisutes
The LSF Suite installation bin file is needed to generate the images.  This bin file is used to create an LSF Suite installer node.  This installer node hosts a yum repository containing the LSF rpms that are needed to generate the images.  The RPMs needed will be extracted from this machine.

The following will be needed to create the images:
* podman
* git
* jq and oniguruma OS packages


## Image Creation
This section describes how to build the LSF images.  CentOS 7 is used to build the initial images.  Other OS images can be created from these initial images.  Use the steps below to create the images: 

1. Clone the repository 
```
git clone { FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME }
cd { FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME FIX ME }
```

2. Copy the LSF Suite RPMs into the lsf-repo directory.  On the machine where the LSF Suite bin file was run locate the /var/www/html/lsf_suite_pkgs/{Architecture} directory.  In there will be the LSF Suite RPMs.  Copy the following list of rpms to the lsf-repo directory created in the step above 
* ibm-jre
* lsf-appcenter
* lsf-client
* lsf-conf
* lsf-ego-master
* lsf-ego-server
* lsf-gui
* lsf-integrations
* lsf-man-pages
* lsf-master
* lsf-perf
* lsf-server
If you want other LSF features in the images copy the other needed rpms.

3. Copy the entitlement files from the machine where the LSF Suite bin file was run.  Locate the entitlement files in /opt/ibm/lsf_installer/entitlement.  Copy them to the **lsf-repo** directory created in the first step.

4. Build the LSF operator image.  This image is used to deploy the LSF cluster on Kubernetes/Openshift clusters.
```
cd lsf-operator
sudo make
```
This image should not require any customization.

5. Customize the LSF images.  The LSF compute image is the base image for the LSF Scheduler and LSF GUI images.  Customizing the LSF compute image will be copied to the other images.   
```
cd lsf-images

```



## Images produced

The code in this directory can generate the LSF images for x86 and POWER.
The images are: 
* lsf-master-amd64_10.xxx.tar.gz
* lsf-comp-amd64_10.xxx.tar.gz
* lsf-gui-amd64_10.xxx.tar.gz
* lsf-master-ppc64le_10.xxx.tar.gz
* lsf-comp-ppc64le_10.xxx.tar.gz
* lsf-gui-ppc64le_10.xxx.tar.gz

A POWER and x86 machine is needed to generate the images.  Build the image by running:
```bash
$ make
```
Then repeat the process on the other architecture.

