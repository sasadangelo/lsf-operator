# Deploying the LSF Cluster

The LSF cluster is defined by a yaml file which the LSF operator uses to deploy the LSF cluster.
A sample LSF cluster definition is in: `lsf-operator/config/samples/example-lsfcluster.yaml` or [here](https://raw.githubusercontent.com/IBMSpectrumComputing/lsf-operator/main/lsf-operator/config/samples/example-lsfcluster.yaml)
This file should be modified to suit the LSF configuration you need.  The LSF operator can deploy and delete the cluster in a few minutes, so it is easy to try different configurations.

**NOTE: The images referenced in the LSF cluster yaml file are cached locally on the kubernetes nodes.  Each time you build the images change the tag to something different, and update the LSF cluster yaml file with the new tags.**

This file is structured into functional parts:
1. **Cluster** - This contains configuration for the entire cluster.  The setting here are applied to all pods.  It defines the type of LSF cluster it will deploy. It defines the storage volume for the cluster to use.  For **LSF on Kubernetes** clusters it includes configuration for setting up user authentication, so that ordinary users can login to the LSF GUI and submit work, and settings for accessing additional volumes for users home directories and applications.
2. **Master** - This provides the parameters for deploying the LSF master pod.  It has the typical controls for the image and resources along with controls to control the placement of the pod.
3. **GUI** - This provides the parameters for deploying the LSF GUI pod.  It only is used with the **LSF on Kubernetes** cluster.  It has the typical controls for the image and resources along with controls for placement of the pod.
4. **Computes** - This is a list of LSF compute pod types.  The cluster can have more than one OS software stack.  This way the compute images can be tailored for the workload it needs to run.  Each compute type can specify the image to use, along with the number of replicas, and the type of resources that this pod supports.  For example, you might have some pods with a Ubuntu software stack, and another with RHEL 8.  A small CentOS 7 compute image is provided.  Instructions on building your own images are [here.](README-custom-images.md)


## Configuration
The LSF operator uses a configuration file to deploy the LSF cluster.  Start with the sample file provided above and edit them for your specific needs.  The instructions below provide more details on how to prepare the file.

Use the instructions below to modify the cluster for your needs.  Edit the file.
1. Set the name of the LSF cluster object in Kubernetes.  Here it is `example-lsfcluster`.
```yaml
metadata:
  name: example-lsfcluster
```

2. Read the licenses and indicate acceptance by setting the `licenseAccepted` flag to `true`.  The licenses are available from [http://www-03.ibm.com/software/sla/sladb.nsf](http://www-03.ibm.com/software/sla/sladb.nsf)
```yaml
spec:
  # Indicate acceptance of the Licenses
  # The licenses are available from this site:
  #      http://www-03.ibm.com/software/sla/sladb.nsf
  # Use the search option to find IBM Spectrum LSF CE
  licenseAccepted: false
```

5. Set the name of the cluster.  This will be used as a prefix to many of the objects the operator will create
```yaml
spec:
  cluster:
    clustername: mylsf
```

7. For **LSF on Kubernetes** clusters one or more users need to be designated as LSF administrators.  These users will be able to perform LSF administrative functions using the GUI.  After user authentication is enabled, provide a list of the UNIX usernames to use as administrators for example
```yaml
spec:
  cluster:
    administrators:
    - someuser
    - someotheruser
```

6. Provide the storage parameters for the LSF cluster.  Using an existing PersistentVolume (PV) is recommended.  Label the PV with your own label and label value, and use the label as the `selectorLabel` below, and the the label value as the `selectorValue` below.  If dynamic storage is to be used set `dynamicStorage` to true and specify the `storageClass`.
```yaml
spec:
  cluster:
    # PersistentVolumeClaim (Storage volume) parameters
    pvc:
      dynamicStorage: false
      storageClass: ""
      selectorLabel: "lsfvol"
      selectorValue: "lsfvol"
      size: "10G"
```

8. For **LSF on Kubernetes** clusters the pods in the cluster will need to access user data and applications.  The **volumes** section provides a way to connect existing PVs to the LSF cluster pods.  More complete instructions are provided [here.](README-setting-up-storage.md)  It is recommended to leave this commented out for the initial deployment.  Define PVs for the data and application binaries and add as many as needed for your site e.g.  
```yaml 
    volumes:
    - name: "Home"
      mount: "/home"
      selectorLabel: "realhome"
      selectorValue: "realhome"
      accessModes: "ReadWriteMany"
      size: ""
    - name: "Applications"
      mount: "/apps"
      selectorLabel: "apps"
      selectorValue: "apps"
      accessModes: "ReadOnlyMany"
      size: ""
```
**NOTE: When creating the PVs to use as volumes in the cluster do NOT set the `Reclaim Policy` to `Recycle`.  This would cause Kubernetes to delete everything in the PV when the LSF cluster is deleted.**

9. **LSF on Kubernetes** clusters users need to login to the LSF GUI to submit work.   You will need to define the configuration for the pod authentication.  Inside the pods the entrypoint script will run **authconfig** to generate the needed configuration files.  The **userauth** section allows you to:
   - Define the arguments to the authconfig command
   - Provide any configuration files needed by the authentication daemons
   - List any daemons that should be started for authentication.
Edit the **userauth** section and define your configuration.  It may be necessary to test the configuration.  This can be done by logging into the master pod and running the following commands to verify that user authentication is functioning:
```bash
# getent passwd
# getent group
```

More detailed instructions are available [here.](README-setting-up-user-authentication.md)

10. Placement options are provided for all the pods.  They can be used to control where the pods will be placed.  The `includeLabel` is used to place the pods on worker nodes that have that label.  The `excludeLabel` has the opposite effect.  Worker nodes that have the `excludeLabel` will not be used for running the LSF pods.  Taints can also be used to taint worker nodes so that the kube-scheduler will not normally use those worker nodes for running pods.  This can be used to grant the LSF cluster exclusive use of a worker node.  To have a worker node exclusively for the LSF cluster taint the node and use the taint name, value and effect in the placement.tolerate... section e.g.
```yaml
spec:
  master:    # The GUI and Computes have the same controls
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
```

11. The `image` and `imagePullPolicy` control where and how the images are pulled.  The free images are hosted on docker hub.  If you are building your own images, or pulling from an internal registry change the `image` value to your internal registry
```yaml
spec:
  master:      # The GUI and Computes will have similar configuration
    image: "MyRegistry/MyProject/lsfce-master:10.1.0.9"
    imagePullPolicy: "Always"
```

12. The `resources` section defines how much memory and CPU to assign to each pod.  LSF will only use the resources provided to its pods, so the pods should be sized to allow the largest LSF job to run.  Conversely **Enhanced Pod Scheduler** pods are sized for the minimum resource consumption.  The defaults are good for **Enhanced Pod Scheduler**, however for **LSF on Kubernetes** clusters the `computes` `memory` and `cpu` should be increased as large as possible.  
```yaml
  computes:
    - name: "Name of this collection of compute pods"
      resources:
        # Change the cpu and memory values to as large as possible 
        requests:
          cpu: "2"
          memory: "1G"
        limits:
          cpu: "2"
          memory: "1G"
      # Define the number of this type of pod you want to have running
      replicas: 1
```

13. For **LSF on Kubernetes** clusters an alternate way pods can access data and applications is using the **mountList**.  This mounts the list of provided paths from the host into the pod.  The path must exist on the worker node.  This is not available on OpenShift.
```yaml
    mountList:
      - /usr/local
```

14. For **LSF on Kubernetes** clusters the LSF GUI uses a database.  The GUI container communicates with the database container with the aid of a password.  The password is provided via a secret.  The name of the secret is provided in the LSF cluster spec file as:
```yaml
spec:
  gui:
    db:
      passwordSecret: "db-pass"
```
The secret needs to be created prior to deploying the cluster.  Replace the **MyPasswordString** with your password in the command below to generate the secret:
```bash
kubectl create secret generic db-pass --from-literal=MYSQL_ROOT_PASSWORD=MyPasswordString
```
If using the OpenShift GUI create a Key/Value secret by setting the secret name, and using the key `MYSQL_ROOT_PASSWORD`.  The value must be provided from a file that has the value in it.

15. For **LSF on Kubernetes** clusters the cluster can have more than one OS software stack.  This is defined in the `computes` list.  This way the compute images can be tailored for the workload it needs to run.  Each compute type can specify the image to use, along with the number of replicas, and the type of resources that this pod supports.  For example, you might have some pods with a RHEL 7 software stack, and another with CentOS 6.  A small compute image is provided.  Instructions on building your own images are [here.](https://github.com/IBMSpectrumComputing/lsf-kubernetes/tree/master/doc/LSF_Operator)  The images should be pushed to an internal registry, and the `image` files updated for that compute type.  Each compute type provides a different software stack for the applications.  The `provides` is used to construct LSF resource groups, so that a user can submit a job and request the correct software stack for the application e.g.
```yaml
spec:
  computes:
    - name: "MyRHEL7"
      # A meaningful description should be given to the pod.  It should
      # describe what applications this pod is capable of running
      description: "Compute pods for Openfoam"

      # Content removed for clarity

      # The compute pods will provide the resources for running
      # various workloads.  Resources listed here will be assigned
      # to the pods in LSF
      provider:
        - rhel7
        - openfoam  

    - name: "TheNextComputeType"
      # The other compute type goes here
```

### Deploying the Cluster
The cluster is deployed by creating an instance of a **lsfcluster**.  Use the file from above to deploy the cluster e.g.  OpenShift users can deploy the cluster from the GUI by providing the yaml file created in the above steps.  Kubernetes users can use the following:
```bash
kubectl create -n {Your namespace} -f example-lsf.yaml
```
To check the progress of the deployment run:
```bash
kubectl get lsfclusters -n {Your namespace}
kubectl get pods -n {Your namespace}
```
There should be a minimum of 4 pod types, but you may have more.
```bash
NAME                                 READY     STATUS    RESTARTS   AGE
dept-a-lsf-gui-58f6ccfdb-49x8f       2/2       Running   0          4d
dept-a-lsf-master-85dbdbf6c8-sv7jr   1/1       Running   0          4d
dept-a-lsf-rhel7-55f8c44cfb-vmjz8    3/3       Running   0          4d
dept-a-lsf-centos6-5ac8c43cfa-fdfh2  4/4       Running   0          4d
ibm-lsf-operator-5b84545b69-mdd7r    2/2       Running   0          4d
```
Only one **Enhanced Pod Scheduler** cluster can be deployed at a time.  Deploying more than one will have unpredictable effects.

## Debugging your Yaml File
As you are testing the LSF cluster you may find that the pods are not created.  This is usually from an issue in the yaml file.  To debug you can use the following commands to see what went wrong:
```
kubectl get pods |grep ibm-lsf-operator
```
This is the operator pod.  You will need the name for the following steps.

To see the Ansible logs run:
```
kubectl logs -c ansible {Pod name from above}
```
A successful run looks something like:
```
<removed>

PLAY RECAP *********************************************************************
localhost                  : ok=28   changed=0    unreachable=0    failed=0    skipped=18   rescued=0    ignored=0
```
The failed count should be 0.  If not look for the failed task.  This will provide a clue as to which parameter may be in error.

If the log only shows:
```
Setting up watches.  Beware: since -r was given, this may take a while!
Watches established.
```
Either:
- The cluster has not been created.  Run:  **oc get lsfclusters** to check.
- The operator is polling for changes and has not woke up yet.  Give it 30 seconds.
- The operator has failed to initialize.  Run: **oc logs -c operator {Operator Pod}**

Another common issue is forgetting to create the database secret.  When this happens the GUI pod in the LSF on Kubernetes cluster will be stuck in a pending state.  To resolve it create the secret and re-create the cluster.

## Deleting an LSF Cluster
The LSF cluster can be deleted by running:
```bash
kubectl get lsfclusters -n {Your namespace}
```
This gets the name of the LSF cluster that has been deployed in this namespace.  Use the name to delete the cluster e.g.
```bash
kubectl delete lsfcluster -n {Your namespace} {Your LSF Cluster name from above}
```
**NOTE:  The storage may be still bound.  If needed release the storage before redeploying the cluster.**


## Accessing the Cluster
How to access the cluster depends on which cluster is deployed.  When the **LSF on Kubernetes** cluster is deployed it will create a route on OpenShift, or an ingress on Kubernetes.  On OpenShift navigate to `Networking` then `Routes` and locate the `lsf-route`.  The `Location` is the URL of the LSF Application Center GUI.  If authentication is setup properly you should be able to login using your UNIX account.


[Return to previous page](README.md)
