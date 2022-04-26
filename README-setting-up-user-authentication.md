# Setting up User Authentication
Setting up user authentication is needed so that users can share the LSF cluster.  The pods are configured to only run the LSF and authentication daemons.  They are not using Systemd to start processes in the pods.  The processes are started by the containers entrypoint script.  This document covers how to:
* Provide the configuration needed for user authentication daemons.
* Start the user authentication daemons.

Experience with configuring an OS to authenticate users is needed to complete this step.  Each datacenter will have different steps to configure authentication, so this document will cover how to get the parts needed for authentication into the pods.  Expect to rebuild the images and re-deploy the LSF cluster multiple times.
 
## Installing OS Packages Needed for Authentication
Any OS package needed for authentication have to be pre-installed in the OS images.  The lsf-gui and lsf-master images are based on the lsf-compute image, which is based on CentOS 7.  The `Dockerfile-compute` is the Dockerfile for building the lsf-compute image.  

As an example, say that our images needed `sssd`.  To add the package we would:
1. Edit the `Dockerfile-compute` and find the yum command e.g.
```bash
    && yum -y --skip-broken install nss-pam-ldapd authconfig ypbind --setopt=tsflags=nodocs \
```
2. Add the `sssd` package:
```bash
    && yum -y --skip-broken install nss-pam-ldapd authconfig ypbind sssd --setopt=tsflags=nodocs \
```
3. Add any other packages you need in the image.
4. Rebuild the images
```bash
make clean
make
```
5. Tag and push the images to the registry.  Remember to change the tag
6. Deploy the LSF cluster and check the results.

If you are building images with a custom OS add the packages to the Dockerfile for the custom OS using the appropriate commands.

## Adding Configuration Files to the Image
Configuration files for the user authentication daemons may be needed inside the running pod.  There are two ways to add them:
1. Add the configuration files to the image building process. 
2. Add the files as part of the LSF cluster deployment.  The LSF cluster spec file provides a way to map pre-created configuration files into the running pod.  Note these files will be copied to each pod irrespective of the OS type.

### Adding Configuration Files During the Build Process
During the image build process the `lsf-repo` directory contents are mounted as `/lsf-repo` inside the building image.  Any files placed in the `lsf-repo` directory can then be copied into the image.  For example:
1. Copy some `my-example-file` file into `lsf-repo` directory
```bash
cp my-example-file lsf-repo/
```
2. Edit the `Dockerfile-compute` and add something like below to the **RUN** section:
```
    && mkdir -p /the/directory/for/the/file \
    && cp /lsf-repo/my-example-file /the/directory/for/the/file/ \
    && chmod 664 /the/directory/for/the/file/my-example-file \
```
**NOTE: The last line in the RUN section should not have a trailing \.**
3. Repeat the process for any other configuration file to add to the image.
4. Rebuild the images, tag and push them, then deploy a LSF cluster using the new images.  Look for the new files.
5. Repeat this process for any custom OS images.

### Adding Configuration Files During the LSF Cluster Deployment
The LSF Cluster spec file can include secrets to add to each pod.  These secrets can be configuration files.  This provides a more secure way to add sensitive files to a pod.

The secrets must be precreated before deploying the LSF cluster.  To create a secret containing a configuration file run:
```bash
kubectl create secret generic test-secret --from-file=(path to file)
```
The secret is called **test-secret**.

The secret(s) are then added to the LSF cluster spec file.
```yaml
    userauth:
        # Configs are a list of secrets that will be passed to the
        # running pod as configuration files.  This is how to pass
        # certificates to the authentication daemons.  The secret has
        # a name and value and is created using:
        #    kubectl create secret generic test-secret --from-file=(path to file)
        # The actual filename in the pod is the filename from the configs
        # list below plus the filename from the command above.
        # Note: The permission is the decimal value e.g 0600 octal is 384 decimal
        #       The configs will only be appied when there is a authconfigargs entry
      configs:
      - name: "test-secret"
        filename: "/etc/test/myconfig.file"
        permission: 384
      - name: "another-secret"
        filename: "/etc/test/another.file"
        permission: 384
```
**NOTE: The permission value is a decimal.  Convert the octal value into a decimal to set the permissions needed.**
More than one file can be mapped this way.  Simply list them.

## Starting Daemons in the Pods
The entrypoint script will start a list of daemons provided to it in the **userauth.starts** list.  It will simply run the listed process and send STDERR to STDOUT. 
**NOTE: Any script that is run should not block.  A script that does not return immediately will stop the LSF daemons from starting.**
List the daemons you wish to run in the userauth section of the LSF cluster spec file.  For example:
```yaml
    userauth:

        # List the daemons to start, e.g.  nslcd, and sssd
      starts:
      - /usr/sbin/nslcd
```

This is not limited to OS daemons.  This same process can be used to run **any** process in a pod.  That process will be started as root.  It can be used to run sripts inside the pod at startup.  Those scripts can perform further customization of the running containers.

## Running Authconfig
The LSF entrypoint script can run `authconfig` on startup.  This can help in configuring user authentication, but does not have to be used.  The proceedures above provide other ways to setup user authentication.  For OS's that support it, it can setup many of the configuration files needed to authenticate users.  The relevent section of the LSf cluster spec file is:
```yaml
    userauth:

        # These are the arguments to invoke the "authconfig" command
        # with.  This will generate the needed configuration files.
        # NOTE:  The "--nostart" argument will be added.
      authconfigargs: "--enableldap --enableldapauth --ldapserver=ldap://172.16.2.2/,ldap://172.16.2.3/ --ldapbase
dn=dc=platformlab,dc=ibm,dc=com --update"
```
If defined, all pods in the LSF cluster will attempt to run `authconfig`.  This may not be appropriate for all Linux versions.

## Testing
When setup properly users should be able to login to the web GUI, however to test use the following proceedure:
1. As an administrative user locate and connect to a LSF pod:
```bash
kubectl get pods -n lsf
```
2. Connect to the LSF master pod:
```bash
kubectl exec -ti -n lsf {Name of pod from above} /bin/bash
```
3. Inside the pod test to see if the user and groups can be retrieved e.g.
```
getent passwd
getent group
```
If all is working you should see a copy of the password and group files.  
If you are using LDAP you may need to map the home directory to the correct location in the pod.  This is outside of the scope of this document.


[Return to previous page](README.md)
