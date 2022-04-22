# Building the Initial Images

The **lsf-operator** directory contains the source code for building the LSF operator.  I will generate the image for the LSF operator.  The LSF operator contains Ansible playbooks for deploying the LSF cluster on Kubernetes. 
The **lsf-images** directory contains the code for creating the LSF images.  It generates four images:
* lsf-compute		- The LSF image for running jobs on CentOS 7.  This is the base image from which the others are created. 
* lsf-compute-myos	- This is an image you have customized for your applications.  With it you can change the OS, add OS dependencies, add applications (or not), and configure user authentication.
* lsf-master		- This is the image for the LSF scheduler main processes.  Jobs should not be run here.  It is based on the lsf-compute CentOS 7 image.
* lsf-gui		- This is the image for the LSF GUI processes.  It is based on the lsf-compute CentOS 7 image.

The images are build from a CentOS 7 base, however instructions are provided for creating alternate OS images.  The images need to be customized to:
1. Enable LDAP/AD/NIS users to login to the LSF GUI.  This will require installing any OS packages needed to authenticate users, and starting the needed authentication processes.
2. Install an alternate OS needed by the jobs.  The LSF cluster supports running multiple types of Compute images at the same time.
2. Installing any OS dependencies that the workload may require.  Applications can be mounted from NFS directories, however those applications may require OS packages.  


## Prerequisutes
The LSF Suite installation bin file is needed to generate the images.  This bin file is used to create an LSF Suite installer node.  This installer node hosts a yum repository containing the LSF rpms that are needed to generate the images.  The RPMs needed will be extracted from this machine.

The following will be needed to create the images:
* podman
* git
* jq and oniguruma packages


## Image Creation
This section describes how to build the LSF images.  CentOS 7 is used to build the initial images.  Other OS images can be created from these initial images.  The code in this directory can generate the LSF images for x86 and POWER.
The x86_64 images are:
* lsf-master-amd64_10.xxx.tar.gz
* lsf-comp-amd64_10.xxx.tar.gz
* lsf-gui-amd64_10.xxx.tar.gz

A POWER and x86 machine is needed to generate the images. 

Use the steps below to create the initial images:

1. Clone the repository 
```
git clone https://github.com/IBMSpectrumComputing/lsf-operator.git
cd lsf-operator
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

5. Create the initial LSF images.  The LSF compute image is the base image for the LSF Scheduler and LSF GUI images.  Customizing the LSF compute image will be copied to the other images.  Expect to iterate on this until the images are correct.
```
cd lsf-images
```
Edit the `Dockerfile-compute`file and add any additional rpms you might need in the CentOS 7 image.  If you plan on running jobs in the CentOS 7 image also add any OS packages needed by the workload.  The GUI and master images are based on this image, so also add any OS packages needed to support user authentication.

6. Build the images.  Run:
```
make
```
If there errors edit the Dockerfiles and rebuild.

[Return to previous page](README.md)
