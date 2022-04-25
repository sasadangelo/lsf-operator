# Building the Initial Images

The **lsf-operator** directory contains the source code for building the LSF operator.  The LSF operator contains Ansible playbooks for deploying the LSF cluster on Kubernetes. 
The **lsf-images** directory contains the code for creating the LSF images.  It generates four images:
* **lsf-compute**	- This is the base image for generating all of the other images.  The image is built from CentOS 7, and can be customized for running jobs on CentOS 7.  At a minimum this image should be customized to support user authentication.  
* **lsf-compute-myos**	- This is an image you have customized for your applications.  With it you can change the OS, add OS dependencies, add applications (or not), and configure user authentication.
* **lsf-master**		- This is the image for the LSF scheduler main processes.  Jobs should not be run here.  It is based on the lsf-compute CentOS 7 image.
* **lsf-gui**		- This is the image for the LSF GUI processes.  It is based on the lsf-compute CentOS 7 image.  Users will login to this pod and submit jobs.

The images are build from a CentOS 7 base, however instructions are provided for creating alternate OS images.  The images should to be customized to:
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
This section describes how to build the LSF images.  CentOS 7 is used to build the initial images.  It is possible to use another OS for the base image.  An understanding of Dockerfiles and LSF installation is needed for that, and is beyond the scope of this repository.  Other OS based compute images can be created from the initial images, and will be covered later.  The code in this directory can generate the LSF images for x86 and POWER.
The x86_64 images are:
* lsf-master-amd64_10.xxx.tar.gz
* lsf-comp-amd64_10.xxx.tar.gz
* lsf-gui-amd64_10.xxx.tar.gz

A POWER or x86 machine is needed to generate there respective images. 

Use the steps below to create the initial images:

1. Clone the repository 
```
git clone https://github.com/IBMSpectrumComputing/lsf-operator.git
cd lsf-operator
```

2. Copy the LSF Suite RPMs into the lsf-repo directory.  On the machine where the LSF Suite bin file was run locate the /var/www/html/lsf_suite_pkgs/{Architecture} directory.  In there will be the LSF Suite RPMs.  Copy the following list of rpms to the lsf-repo directory created in the step above:
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

5. Create the initial LSF images.  The LSF compute image is the base image for the LSF Scheduler and LSF GUI images.  Customizing the LSF compute image will be carried over to the Scheduler and GUI images.  Expect to iterate on this until the images are correct.
```
cd lsf-images
```
Edit the `Dockerfile-compute` file and add any additional rpms you might need in the CentOS 7 image.  If you plan on running jobs in the CentOS 7 image also add any OS packages needed by the workload.  The GUI and master images are based on this image, so also add any OS packages needed to support user authentication.

6. Build the images.  Run:
```
make
```
If there errors edit the Dockerfiles and rebuild.

## Pushing the Images to a Registry
**Do not push your images to a Public registry on the internet!  They contain LSF binaries and entitlements that are not for public access.**

The Kubernetes cluster will need to be able to pull images from a registry.  This must be a private registry, and not accessable on the internet.  The Kubernetes cluster will pull the images from this registry to the worker nodes when a pod is deployed.  Once pulled the worker node will cache that image, so it it important to **change the image tag** when you build new images, otherwise you may inadvertantly run older image versions.

Once the images are build, they need to be pushed to a registry.  To push the machines to the registry use the following proceedure.

1. Load the image **tar.gz** files onto a machine that can access the registry.  For example on x86_64 run:
```bash
podman load -i lsf-operator/lsf-operator-amd64_1.0.1.tar.gz
podman load -i lsf-images/lsf-comp-amd64_10.1.0.13.tar.gz
podman load -i lsf-images/lsf-master-amd64_10.1.0.13.tar.gz
podman load -i lsf-images/lsf-gui-amd64_10.1.0.13.tar.gz
```
If you have created a custon OS image you will also need to load it.

2. Get the names of the LSF image in the local host.  You should see all the images you previously loaded.
```bash
podman images |grep lsf
```

3. Set the build and registry variables.  The build number must be changed each time you rebuild the images.  Set the MYREGISTRY variable to your registry.  Optionally also include a directory e.g.
```bash
export BUILD=v1      # Change this value each time you rebuild the images
export MYREGISTRY=some.machine.company.com/some-directory
```

4. Tag the LSF images on the local host with the registry and a new version tag e.g
```bash
podman tag localhost/lsf-operator-amd64:1.0.1 ${MYREGISTRY}/lsf-operator-amd64:1.0.1-${BUILD}
podman tag localhost/lsf-comp-amd64:10.1.0.12 ${MYREGISTRY}/lsf-comp-amd64:10.1.0.12-${BUILD}
podman tag localhost/lsf-master-amd64:10.1.0.12 ${MYREGISTRY}/lsf-master-amd64:10.1.0.12-${BUILD}
podman tag localhost/lsf-gui-amd64:10.1.0.12 ${MYREGISTRY}/lsf-gui-amd64:10.1.0.12-${BUILD}
```

5. Push the images to the registry:
```bash
podman push ${MYREGISTRY}/lsf-operator-amd64:1.0.1-${BUILD}
podman push ${MYREGISTRY}/lsf-comp-amd64:10.1.0.12-${BUILD}
podman push ${MYREGISTRY}/lsf-master-amd64:10.1.0.12-${BUILD}
podman push ${MYREGISTRY}/lsf-gui-amd64:10.1.0.12-${BUILD}
```

If you have built a custom OS image, repeat the process for that image.

Expect to repeat this proceedure as you customize the images and create other OS images.

Note the names of the images.  These will be used later when you deploy the LSF operator and LSF cluster.


[Return to previous page](README.md)
