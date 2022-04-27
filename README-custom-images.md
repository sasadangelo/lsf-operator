# Creating Custom LSF Compute Images
The jobs that LSF will run may need different combination of Operating Systems (OS) and libraries.  The LSF cluster can have multiple types of compute pods with different OS's and packages installed on them.  The diagram below illustrates some of the types of LSF compute images that could be generated.

![Image types](LSFonK8s-images.png)

The application binaries that the jobs run can be part of the image, or can be mounted from an external source.  See the [storage configuration](README-setting-up-storage.md) for more details on how to setup storage.

The images will need to have the following at a minimum:
* A OS base image.
* Any OS packages needed by the applications.
* The LSF binaries.
* The LSF startup script.
* (Recommended) OS packages and files needed for user authentication.

## How to Build Other OS Images
Other OS LSF compute images are built by using a base image for the OS and adding in the LSF binaries and startup script.  A template Dockerfile `Dockerfile-compute-other-os.tmpl` is provided to help create a working Dockerfile.
1. Copy the `Dockerfile-compute-other-os.tmpl` file to `Dockerfile-compute-other-os`
```bash
cd lsf-images
cp Dockerfile-compute-other-os.tmpl Dockerfile-compute-other-os
```

2. Edit the `Dockerfile-compute-other-os` file and set the base image for the OS you wish to use:
```bash
# Provide the OS base image you want to add LSF to.  Create your own
# base image, or use one from a trusted registry.
FROM ubuntu:latest      <----- Set this to the OS image you wish to base the LSF compute image on
```

3. LSF needs some OS packages to work.  On CentOS 7 and RHEL the packages are:
  * hostname
  * wget
  * gettext
  * net-tools
  * which
  * iproute
  * iputils

You will need to locate the OS packages that provide these and install them with the OS appropriate command e.g.
```bash
RUN yum -y install hostname wget gettext net-tools which iproute iputils openldap openldap-clients systemd-sysv make
 --setopt=tsflags=nodocs
```

4. The LSF startup script needs the `jq` command.  Install it in the image:
```bash
# The start_lsf script needs the jq command.  Perform the steps needed to install
# that package for your OS.
RUN yum -y install jq
```

5. User authentication will require site specific OS packages add the needed packages using an OS appropriate command e.g.
```bash
# To use LDAP or other user authentication services you will need to install the
# OS packages need for that.  What to install will depend on the OS and authentication
# service used.  Use the appropriate OS commands to install the needed services.
# below is an example for CentOS and LDAP.  If you need to setup any configuration
# files for authentication it is best to do it here as well.
RUN yum -y install openldap openldap-clients nss-pam-ldapd authconfig ypbind --setopt=tsflags=nodocs
```

6. The applications that are to run on the cluster may have dependencies on OS packages.  Install the packages using OS appropriate command e.g.
```bash
# The jobs you run in LSF may get there data and binaries from NFS, however those
# jobs my require OS packages.  Install those OS packages here.
yum install -y Some_package
```

7. Build the OS specific image using:
```bash
make other-compute
```

8. Fix any errors in the `Dockerfile-compute-other-os` file.

When the build is successful it will generate a tar.gz file.  Use the proceedure outlined in the [building images](README-Building-the-images.md) documentation to load, tag and push the image to your registry.  Use the steps below to include an additional compute type in the LSf cluster spec file, and deploy your cluster.

Change the contents of the `Dockerfile-compute-other-os` file until it is able to run your jobs.


## How to Run Other OS Images in the LSF Cluster
The LSF cluster can run multiple compute pods with different OS's.  The LSF Cluster spec file contains a list of all the OS images it should deploy as part of the LSF cluster.  Below is the **computes** section of an LSF Cluster spec file with one OS type.  The list of compute pod types starts with the **name:**.  A short name should be used as the pods will contain this string.

To add other compute pod types copy the entire section from the **name:** down and replace the **image:** and other attributes.

```yaml
  computes:
    # This is the start of a specific compute pod type.  The name
    # given should be short and without spaces
    - name: "RHEL7"

      # A meaningful description should be given to the pod.  It should
      # describe what applications this pod is capable of running
      description: "Compute pods for running app1 and app2"

      # The compute pods will provide the resources for running
      # various workloads.  Resources listed here will be assigned
      # to the pods in LSF
      provider:
        - rhel7
        - app1
        - app2

      # Define where to get the image from
      image: "ibmcom/lsfce-comp:10.1.0.9r02"
      imagePullPolicy: "Always"

      # Define the number of this type of pod you want to have running
      replicas: 1

      # The placement variables control how the pods will be placed
      placement:
        # includeLabel  - Optional label to apply to hosts that
        #                 should be allowed to run the compute pod
        includeLabel: ""

        # excludeLabel  - Is a label to apply to hosts to prevent
        #                 them from being used to host the compute pod
        excludeLabel: "excludelsf"

        # Taints can be used to control which nodes are available
        # to the LSF and Kubernetes scheduler.  If used these
        # parameters are used to allow the LSF pods to run on
        # tainted nodes.  When not defined the K8s master nodes
        # will be used to host the master pod.
        #
        #  tolerateName  - Optional name of the taint that has been
        #                  applied to a node
        #  tolerateValue - The value given to the taint
        #  tolerateEffect - The effect of the taint
        #
        tolerateName: ""
        tolerateValue: ""
        tolerateEffect: NoExecute

      resources:
        requests:
          cpu: "2"
          memory: "1G"
        limits:
          cpu: "2"
          memory: "1G"
        # gpu - defines if the compute pod should be created with
        #       support for the GPU.  Valid values are "yes|no".
        # If set to "yes", the NVIDIA___ environment variables will be
        # set and the nodeSelectorTerms will include the
        # openshift.com/gpu-accelerator key with operator Exists.
        # The seLinuxOptions will set the type to 'nvidia_container_t'
        # and the SYS_ADMIN capability will be added for GPU mode switching
        gpu: "no"

      # The application running in the pods will typically need to get
      # access to the user data and even application binaries.  The
      # mountList provides a way to access directories from the OS
      # running on the Kubernetes worker nodes.  This will be translated
      # into hostPath volumeMounts for the pod to access. For example
      # listing '/home' will cause /home from the worker OS to be
      # mounted in the running container, allowing users to access there
      # home directory (assuming automounter is setup).
      #mountList:
      #  - /home
      #  - /apps
``` 

The **replicas:** controls the number of compute pods of this type to deploy in the Kubernetes cluster.  The **resources:** controls how much CPU and memory to allot to each pod.  The **replicas:** and **resources:** will control how many jobe the cluster can run at a time.


[Return to previous page](README.md)
