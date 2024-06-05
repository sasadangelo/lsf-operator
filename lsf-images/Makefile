#--------------------------------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#--------------------------------------------------------

# The version set below will override the Chart.yaml versions
VER=10.1.0.13
OPERVER=1.0.1

ARCH=$(shell uname -m)
NARCH=$(shell if [ `uname -m` = "x86_64" ]; then echo "amd64" ; else echo "`uname -m`" ; fi)
CPWD=$(shell pwd)

# This is the name of my custom OS LSF Compute image
# Change this to whatever name you like
IMAGEMYOS=lsf-comp-myos

# This is the name of the LSF Master image
IMAGENAME=lsf-master

# This is the name of the LSF Compute image
IMAGECOMP=lsf-comp

# This is the name of the GUI image
IMAGEGUI=lsf-gui

# This is the Operator image
IMAGEOPER=lsf-operator

.PHONY: lsf prep-lsf clean other-compute

default: lsf

other-compute: Dockerfile-compute-other-os ${IMAGECOMP}-${NARCH}_${VER}.tar.gz
	@echo "-----------------------------------------------"
	@echo "-  Making Other OS Compute image  "
	@echo "-  "
	@echo "-  VER=${VER}"
	@echo "-  NARCH=${NARCH}"
	@echo "-  PWD=${CPWD}"
	@echo "-----------------------------------------------"
	sed -e s:@VERSION@:${VER}:g < Dockerfile-compute-other-os > Dockerfile
	sed -i -e s:@NARCH@:${NARCH}:g Dockerfile
	sed -i -e s:@ARCH@:${ARCH}:g Dockerfile
	podman build --no-cache --force-rm=true --rm --network host -v${CPWD}/../lsf-repo:/lsf-repo --squash -t ${IMAGEMYOS}-${NARCH}:${VER} .
	podman save -o ${IMAGEMYOS}-${NARCH}_${VER}.tar.gz ${IMAGEMYOS}-${NARCH}:${VER}
	-@rm -rf Dockerfile
	@chmod 644 ${IMAGEMYOS}-${NARCH}_${VER}.tar.gz

Dockerfile-compute-other-os:
	@echo "-----------------------------------------------"
	@echo "-  Create a Dockerfile-compute-other-os file "
	@echo "-  from the Dockerfile-compute-other-os.tmpl "
	@echo "-  Customize the file for your OS and jobs "
	@echo "-  before continuing. "
	@echo "-----------------------------------------------"
	@echo ""
	@exit 1

# Build the LSF Package
lsf: ${IMAGECOMP}-${NARCH}_${VER}.tar.gz ${IMAGENAME}-${NARCH}_${VER}.tar.gz ${IMAGEGUI}-${NARCH}_${VER}.tar.gz
	-@podman rmi ${IMAGENAME}-${NARCH}:${VER}
	-@podman rmi ${IMAGECOMP}-${NARCH}:${VER}
	-@podman rmi ${IMAGEGUI}-${NARCH}:${VER}
	-@podman rmi ${IMAGEOPER}-${NARCH}:${OPERVER}

# Build the Compute image
${IMAGECOMP}-${NARCH}_${VER}.tar.gz: Dockerfile-compute
	@echo "-----------------------------------------------"
	@echo "-  Making Compute image  "
	@echo "-  "
	@echo "-  VER=${VER}"
	@echo "-  NARCH=${NARCH}"
	@echo "-  PWD=${CPWD}"
	@echo "-----------------------------------------------"
	sed -e s:@VERSION@:${VER}:g < Dockerfile-compute > Dockerfile
	sed -i -e s:@NARCH@:${NARCH}:g Dockerfile
	sed -i -e s:@ARCH@:${ARCH}:g Dockerfile
	podman build --no-cache --force-rm=true --rm --network host -v${CPWD}/../lsf-repo:/lsf-repo --squash -t ${IMAGECOMP}-${NARCH}:${VER} .
	podman save -o ${IMAGECOMP}-${NARCH}_${VER}.tar.gz ${IMAGECOMP}-${NARCH}:${VER}
	-@rm -rf Dockerfile rpms-compute
	@chmod 644 ${IMAGECOMP}-${NARCH}_${VER}.tar.gz


# Build the GUI image
${IMAGEGUI}-${NARCH}_${VER}.tar.gz: ${IMAGECOMP}-${NARCH}_${VER}.tar.gz 
	@echo "-----------------------------------------------"
	@echo "-  Making GUI image  "
	@echo "-  "
	@echo "-  VER=${VER}"
	@echo "-  NARCH=${NARCH}"
	@echo "-  PWD=${CPWD}"
	@echo "-----------------------------------------------"
	@echo "Building GUI Image.   PWD=${CPWD}"
	sed -e s:@VERSION@:${VER}:g < Dockerfile-gui > Dockerfile
	sed -i -e s:@NARCH@:${NARCH}:g Dockerfile
	sed -i -e s:@ARCH@:${ARCH}:g Dockerfile
	podman build --no-cache --force-rm=true --rm --network host -v${CPWD}/../lsf-repo:/lsf-repo --squash -t ${IMAGEGUI}-${NARCH}:${VER} .
	podman save -o ${IMAGEGUI}-${NARCH}_${VER}.tar.gz ${IMAGEGUI}-${NARCH}:${VER}
	-@rm -rf Dockerfile
	@chmod 644 ${IMAGEGUI}-${NARCH}_${VER}.tar.gz


# Build the LSF Master Image
${IMAGENAME}-${NARCH}_${VER}.tar.gz: Dockerfile-master ${IMAGECOMP}-${NARCH}_${VER}.tar.gz
	@echo "-----------------------------------------------"
	@echo "-  Making Master image  "
	@echo "-  "
	@echo "-  VER=${VER}"
	@echo "-  NARCH=${NARCH}"
	@echo "-  PWD=${CPWD}"
	@echo "-----------------------------------------------"
	sed -e s:@VERSION@:${VER}:g < Dockerfile-master > Dockerfile
	sed -i -e s:@NARCH@:${NARCH}:g Dockerfile
	sed -i -e s:@ARCH@:${ARCH}:g Dockerfile
	podman build --no-cache --force-rm=true --rm --network host -v${CPWD}/../lsf-repo:/lsf-repo --squash -t ${IMAGENAME}-${NARCH}:${VER} .
	podman save -o ${IMAGENAME}-${NARCH}_${VER}.tar.gz ${IMAGENAME}-${NARCH}:${VER}
	-@rm -rf Dockerfile rpms-master
	@chmod 644 ${IMAGENAME}-${NARCH}_${VER}.tar.gz

# Build the Operator image
${IMAGEOPER}-${NARCH}_${OPERVER}.tar.gz:
	@echo "-----------------------------------------------"
	@echo "-  Making Operator image  "
	@echo "-  "
	@echo "-  OPERVER=${OPERVER}"
	@echo "-  NARCH=${NARCH}"
	@echo "-  PWD=${CPWD}"
	@echo "-----------------------------------------------"
	(cd ../ibm-lsf-operator ;make )
	cp ../${IMAGEOPER}-${NARCH}* .


clean:
	-@rm -rf lsf-comp.img lsf-master.img centos4lsf.img lsf-tar-contents podfiles/patch-x86_64.tgz podfiles/patch-ppc64le.tgz
	-@rm -rf ${IMAGECOMP}-${NARCH}_${VER}.tar.gz ${IMAGENAME}-${NARCH}_${VER}.tar.gz
	-@rm -rf ${IMAGEGUI}-${NARCH}_${VER}.tar.gz lsf-repo-${NARCH}_${VER}.tar.gz
	-@rm -rf ${IMAGEOPER}-${NARCH}_${OPERVER}.tar.gz
	-@podman rmi ${IMAGECOMP}-${NARCH}:${VER}
	-@podman rmi ${IMAGEGUI}-${NARCH}:${VER}
	-@podman rmi ${IMAGENAME}-${NARCH}:${VER}
	-@rm -rf ${IMAGECOMP}-tp-${NARCH}_${VER}.tar.gz ${IMAGENAME}-tp-${NARCH}_${VER}.tar.gz  
	-@echo "----  Remaining LSF Images -----"
	-@podman images |grep lsf |awk '{print $$1 ":" $$2 }'



# Add the package to the Docker Hub registry
# You have to login first before running this
dockerhub-push:
	@echo "-----------------------------------------------"
	@echo "-"
	@echo "- Pushing images to docker hub"
	@echo "- NOTE:  Login to docker hub first e.g"
	@echo "-  docker login --username=mblack"
	@echo "- ONLY Shen and Mark have access to push images to ibmcom"
	@echo "-"
	@echo "-----------------------------------------------"
	@echo "-    LOADING IMAGES                           -"
	@echo "-----------------------------------------------"
	docker load -i ${_release}/${IMAGECOMP}-amd64_${VER}.tar.gz
	docker load -i ${_release}/${IMAGENAME}-amd64_${VER}.tar.gz
	docker load -i ${_release}/${IMAGEGUI}-amd64_${VER}.tar.gz
	docker load -i ${_release}/${IMAGEREPO}-amd64_${VER}.tar.gz
	docker load -i ${_release}/${IMAGEOPER}-amd64_${OPERVER}.tar.gz
	docker load -i ${_release}/${IMAGECOMP}-ppc64le_${VER}.tar.gz
	docker load -i ${_release}/${IMAGENAME}-ppc64le_${VER}.tar.gz
	docker load -i ${_release}/${IMAGEGUI}-ppc64le_${VER}.tar.gz
	docker load -i ${_release}/${IMAGEREPO}-ppc64le_${VER}.tar.gz
	-docker load -i ${_release}/${IMAGEOPER}-ppc64le_${OPERVER}.tar.gz
	@echo "-----------------------------------------------"
	@echo "-    Tagging IMAGES                           -"
	@echo "-----------------------------------------------"
	@docker tag ${IMAGECOMP}-amd64:${VER} ${CEICOMP}:${DHVER}-amd64
	@docker tag ${IMAGENAME}-amd64:${VER} ${CEINAME}:${DHVER}-amd64
	@docker tag ${IMAGEGUI}-amd64:${VER}  ${CEIGUI}:${DHVER}-amd64
	@docker tag ${IMAGEREPO}-amd64:${VER} ${CEIREPO}:${DHVER}-amd64
	@docker tag ibm-lsf-operator-amd64:${OPERVER} ${CEIOPER}:${DHOPERVER}-amd64
	@docker tag ${IMAGECOMP}-ppc64le:${VER} ${CEICOMP}:${DHVER}-ppc64le
	@docker tag ${IMAGENAME}-ppc64le:${VER} ${CEINAME}:${DHVER}-ppc64le
	@docker tag ${IMAGEGUI}-ppc64le:${VER} ${CEIGUI}:${DHVER}-ppc64le
	@docker tag ${IMAGEREPO}-ppc64le:${VER} ${CEIREPO}:${DHVER}-ppc64le
	-@docker tag ibm-lsf-operator-ppc64le:${OPERVER} ${CEIOPER}:${DHOPERVER}-ppc64le
	@echo "-----------------------------------------------"
	@echo "-    Pushing IMAGES                           -"
	@echo "-----------------------------------------------"
	docker push ${CEICOMP}:${DHVER}-amd64
	docker push ${CEINAME}:${DHVER}-amd64
	docker push ${CEIGUI}:${DHVER}-amd64
	docker push ${CEIREPO}:${DHVER}-amd64
	docker push ${CEIOPER}:${DHOPERVER}-amd64
	docker push ${CEICOMP}:${DHVER}-ppc64le
	docker push ${CEINAME}:${DHVER}-ppc64le
	docker push ${CEIGUI}:${DHVER}-ppc64le
	docker push ${CEIREPO}:${DHVER}-ppc64le
	-@docker push ${CEIOPER}:${DHOPERVER}-ppc64le
	@echo "-----------------------------------------------"
	@echo "-    Making Manifest IMAGES                   -"
	@echo "-----------------------------------------------"
	@echo "----  ${CEICOMP}  -----"
	/nfs/docker-linux-amd64 manifest create --amend ${CEICOMP}:${DHVER} ${CEICOMP}:${DHVER}-amd64 ${CEICOMP}:${DHVER}-ppc64le
	/nfs/docker-linux-amd64 manifest annotate ${CEICOMP}:${DHVER} ${CEICOMP}:${DHVER}-amd64 --os linux --arch amd64
	/nfs/docker-linux-amd64 manifest annotate ${CEICOMP}:${DHVER} ${CEICOMP}:${DHVER}-ppc64le --os linux --arch ppc64le
	/nfs/docker-linux-amd64 manifest inspect ${CEICOMP}:${DHVER}
	/nfs/docker-linux-amd64 manifest push ${CEICOMP}:${DHVER}
	@echo "----  ${CEINAME}  -----"
	/nfs/docker-linux-amd64 manifest create --amend ${CEINAME}:${DHVER} ${CEINAME}:${DHVER}-amd64 ${CEINAME}:${DHVER}-ppc64le
	/nfs/docker-linux-amd64 manifest annotate ${CEINAME}:${DHVER} ${CEINAME}:${DHVER}-amd64 --os linux --arch amd64
	/nfs/docker-linux-amd64 manifest annotate ${CEINAME}:${DHVER} ${CEINAME}:${DHVER}-ppc64le --os linux --arch ppc64le
	/nfs/docker-linux-amd64 manifest inspect ${CEINAME}:${DHVER}
	/nfs/docker-linux-amd64 manifest push ${CEINAME}:${DHVER}
	@echo "----  ${CEIGUI}  -----"
	/nfs/docker-linux-amd64 manifest create --amend ${CEIGUI}:${DHVER} ${CEIGUI}:${DHVER}-amd64 ${CEIGUI}:${DHVER}-ppc64le
	/nfs/docker-linux-amd64 manifest annotate ${CEIGUI}:${DHVER} ${CEIGUI}:${DHVER}-amd64 --os linux --arch amd64
	/nfs/docker-linux-amd64 manifest annotate ${CEIGUI}:${DHVER} ${CEIGUI}:${DHVER}-ppc64le --os linux --arch ppc64le
	/nfs/docker-linux-amd64 manifest inspect ${CEIGUI}:${DHVER}
	/nfs/docker-linux-amd64 manifest push ${CEIGUI}:${DHVER}
	@echo "----  ${CEIREPO}  -----"
	/nfs/docker-linux-amd64 manifest create --amend ${CEIREPO}:${VER} ${CEIREPO}:${VER}-amd64 ${CEIREPO}:${VER}-ppc64le
	/nfs/docker-linux-amd64 manifest annotate ${CEIREPO}:${VER} ${CEIREPO}:${VER}-amd64 --os linux --arch amd64
	/nfs/docker-linux-amd64 manifest annotate ${CEIREPO}:${VER} ${CEIREPO}:${VER}-ppc64le --os linux --arch ppc64le
	/nfs/docker-linux-amd64 manifest inspect ${CEIREPO}:${VER}
	/nfs/docker-linux-amd64 manifest push ${CEIREPO}:${VER}
	@echo "----  ${CEIOPER}  -----"
	/nfs/docker-linux-amd64 manifest create --amend ${CEIOPER}:${DHOPERVER} ${CEIOPER}:${DHOPERVER}-amd64 ${CEIOPER}:${DHOPERVER}-ppc64le
	/nfs/docker-linux-amd64 manifest annotate ${CEIOPER}:${DHOPERVER} ${CEIOPER}:${DHOPERVER}-amd64 --os linux --arch amd64
	/nfs/docker-linux-amd64 manifest annotate ${CEIOPER}:${DHOPERVER} ${CEIOPER}:${DHOPERVER}-ppc64le --os linux --arch ppc64le
	/nfs/docker-linux-amd64 manifest inspect ${CEIOPER}:${DHOPERVER}
	/nfs/docker-linux-amd64 manifest push ${CEIOPER}:${DHOPERVER}
	@echo "-----------------------------------------------"
	@echo "-    DELETING IMAGES                           -"
	@echo "-----------------------------------------------"
	docker rmi ${CEICOMP}:${DHVER}-amd64
	docker rmi ${CEINAME}:${DHVER}-amd64
	docker rmi ${CEIGUI}:${DHVER}-amd64
	docker rmi ${CEIREPO}:${DHVER}-amd64
	docker rmi ${CEIOPER}:${DHOPERVER}-amd64
	docker rmi ${IMAGECOMP}-amd64:${VER} 
	docker rmi ${IMAGENAME}-amd64:${VER}
	docker rmi ${IMAGEGUI}-amd64:${VER}
	docker rmi ${IMAGEREPO}-amd64:${VER}
	docker rmi ibm-lsf-operator-amd64:${OPERVER}
	@echo "-----------------------------------------------"
	docker rmi ${CEICOMP}:${DHVER}-ppc64le
	docker rmi ${CEINAME}:${DHVER}-ppc64le
	docker rmi ${CEIGUI}:${DHVER}-ppc64le
	docker rmi ${CEIREPO}:${DHVER}-ppc64le
	-@docker rmi ${CEIOPER}:${DHOPERVER}-ppc64le
	docker rmi ${IMAGECOMP}-ppc64le:${VER} 
	docker rmi ${IMAGENAME}-ppc64le:${VER}
	docker rmi ${IMAGEGUI}-ppc64le:${VER}
	docker rmi ${IMAGEREPO}-ppc64le:${VER}
	-@docker rmi ibm-lsf-operator-ppc64le:${OPERVER}
	@echo "-----------------------------------------------"
	@echo "-  Done............                           -"
	@echo "-----------------------------------------------"
