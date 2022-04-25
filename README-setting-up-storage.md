# Setting up Storage
The LSF cluster needs storage configured for:
1. Storing the LSF configuration
2. Running jobs

In both cases the LSF cluster will mount pre-created Persistent Volume Claims (PVC)s to access the storage.
Dynamic storage is not recommended for LSF configuration.  Deleting the LSF cluster will also remove the LSF job data.  Dynamic storage should only be used for initial testing were job data loss is okay.

More commonly users home directories, data and application binaries will be hosted on NFS servers.  In this case a Persistent Volume (PV) and PVC can be created to access NFS filesystems. 

## Using Dynamic Storage for LSF Configuration
If you choose to use dynamic storage for LSF configuration and work data, use the following to create the PVC:
1. Create a file called `lsfpvc.yaml` with the following contents:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mylsfpvc
  namespace: lsf
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20G
  storageClassName: {Provide the StorageClassName of the dynamic storage}
  volumeMode: Filesystem
```
2. Create the PVC with:
```bash
kubectl create -f lsfpvc.yaml
```
3. Verify that the PVC has been created with:
```bash
kubectl get pvc -n lsf
```
You should see the `mylsfpvc` pvc.


## Creating a NFS Hosted PV and PVC for LSF
Kubernetes pods can access NFS servers provied the worker nodes can mount the NFS filesystem.  Use the following proceedure to create a PV and PVC for LSF configuration and work directories:
1. Create the PV spec file `mylsfpv.yaml` with the following contents:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mylsfpv
spec:
  accessModes:
  - ReadWriteMany             # Has to be this for failover
  capacity:
    storage: 10Gi             # Specify the amount of storage to provide
  nfs:
    path: /some/export        # Use you exported filesystem from the NFS server
    server: 11.22.33.44       # Use the IP address of your NFS server
  persistentVolumeReclaimPolicy: Retain
  volumeMode: Filesystem
  claimRef:
    name: mylsfpvc            # We are pre-binding the PVC to ensure that the correct PVC uses this PV
    namespace: lsf
```
2. Create the PV:
```bash
kubectl create -f mylsfpv.yaml
```
3. Create the PVC spec file `mylsfpvc.yaml` with the following contents:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mylsfpvc
  namespace: lsf
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10G
  volumeMode: Filesystem
  storageClassName: ""
```
4. Create the PV:
```bash
kubectl create -f mylsfpvc.yaml
```
5. Check that the PVC has been created and is bound to the PV
```bash
kubectl get pvc -n lsf mylsfpvc
```
You should see something like:
```
NAME         STATUS   VOLUME              CAPACITY   ACCESS MODES   STORAGECLASS          AGE
mylsfpvc     Bound    mylsfpv             10Gi       RWX                                  4s
```
The PVC is ready for use.  Remember to set the `lsfpvcname` in the LSF cluster yaml file.

## Creating a NFS Hosted PV and PVC for Home, Data and Applications
The process to create PV's and PVC's for other volumes is the same as for the LSF configuration and work directory.
1. Create copies of the `mylsfpv.yaml` and `mylsfpvc.yaml` files for each filesystem you want to access in the LSF pods.
```bash
cp mylsfpv.yaml myhomepv.yaml
cp mylsfpvc.yaml myhomepvc.yaml
```
2. Edit the files and change the names of the PV and PVCs.  
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: myhomepv           <---- Change the name
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myhomepvc           <---- Change the name
```
3. In the PV file set the NFS server and exported path to want to mount in the PV file.  
```yaml
kind: PersistentVolume
metadata:
  name: myhomepv
spec:
  nfs:
    path: /some/export        # Use you exported filesystem from the NFS server
    server: 11.22.33.44       # Use the IP address of your NFS server
```
4. Change the PV access mode if needed:
```yaml
spec:
  accessModes:
  - ReadWriteMany             # You may use ReadOnlyMany to prevent write access
```
5. Update the PV claimReference in the PV to bind it to the PVC.
```yaml
spec:
  claimRef:
    name: mylsfpvc            # We are pre-binding the PVC to ensure that the correct PVC uses this PV
    namespace: lsf
```
6. Repeat these steps to prepare additional PV's and PVC's needed by the LSF jobs.

**Remember to update the LSF cluster yaml file with the names of the PVCs just created.**

[Return to previous page](README.md)
