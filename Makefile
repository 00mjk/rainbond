GO_LDFLAGS=-ldflags " -w"
VERSION=3.4.1
WORK_DIR=/go/src/github.com/goodrain/rainbond
BASE_NAME=rainbond
BASE_DOCKER=./hack/contrib/docker
BIN_PATH=./_output/${VERSION}

default: help
all: build pkgs images ## build linux binaries, build linux packages, build images for docker

clean: 
	@rm -rf ${BIN_PATH}/*

build: build-mq build-worker build-chaos build-mqcli build-node build-entrance build-eventlog build-webcli build-grctl build-api ## build all binaries
build-mq:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-mq ./cmd/mq
build-worker:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-worker ./cmd/worker
build-chaos:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-chaos ./cmd/builder
build-mqcli:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-mqcli ./cmd/mqcli
build-node:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-node ./cmd/node
build-entrance:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-entrance ./cmd/entrance	
build-eventlog:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-eventlog ./cmd/eventlog
build-grctl:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-grctl ./cmd/grctl
build-api:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-api ./cmd/api
build-webcli:
	go build ${GO_LDFLAGS} -o ${BIN_PATH}/${BASE_NAME}-webcli ./cmd/webcli
	
deb: ## build the deb packages
	@bash ./release.sh deb
rpm: ## build the rpm packages
	@bash ./release.sh rpm
pkgs:
	@bash ./release.sh pkg
	
images: build-image-worker  build-image-mq build-image-chaos build-image-entrance build-image-eventlog build-image-api build-image-webcli ## build all images
build-image-worker:
	@echo "🐳 $@"
	@bash ./release.sh worker
build-image-mq:
	@echo "🐳 $@"
	@bash ./release.sh mq
build-image-chaos:
	@echo "🐳 $@"
	@bash ./release.sh chaos
build-image-node:
	@echo "🐳 $@"
	@bash ./release.sh node
#	@docker run -v `pwd`:${WORK_DIR} -w ${WORK_DIR} -it golang:1.8.3 go build  ${GO_LDFLAGS}  -o ${BASE_DOCKER}/node/${BASE_NAME}-node ./cmd/node
build-image-entrance:
	@echo "🐳 $@"
	@cp -r ${BASE_DOCKER}/dist ${BASE_DOCKER}/entrance/dist
	@bash ./release.sh entrance
	@rm -rf ${BASE_DOCKER}/entrance/dist
	
build-image-eventlog:
	@echo "🐳 $@"
	@bash ./release.sh eventlog
build-image-api:
	@echo "🐳 $@"
	@bash ./release.sh api
build-image-webcli:
	@echo "🐳 $@"
	@bash ./release.sh webcli
push-gr-image: 
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-eventlog:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-entrance:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-chaos:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-mq:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-worker:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-webcli:${VERSION}
	@docker push hub.goodrain.com/${BASE_NAME}/rbd-api:${VERSION}

push-hub-image:
	@docker push ${BASE_NAME}/rbd-eventlog:${VERSION}
	@docker push ${BASE_NAME}/rbd-entrance:${VERSION}
	@docker push ${BASE_NAME}/rbd-chaos:${VERSION}
	@docker push ${BASE_NAME}/rbd-mq:${VERSION}
	@docker push ${BASE_NAME}/rbd-worker:${VERSION}
	@docker push ${BASE_NAME}/rbd-webcli:${VERSION}
	@docker push ${BASE_NAME}/rbd-api:${VERSION}

run-api:build-api
	${BIN_PATH}/${BASE_NAME}-api --log-level=debug --mysql="admin:admin@tcp(127.0.0.1:3306)/region" --kube-config="`PWD`/admin.kubeconfig"
run-mq:build-mq
	${BIN_PATH}/${BASE_NAME}-mq --log-level=debug
run-worker:build-worker
	CUR_NET=midonet EX_DOMAIN=test-ali.goodrain.net:10080 ${BIN_PATH}/${BASE_NAME}-worker \
	--log-level=debug  \
	--db-type=cockroachdb \
	--mysql="postgresql://root@localhost:26257/region" \
	--kube-config=./admin.kubeconfig
run-chaos:build-chaos
	${BIN_PATH}/${BASE_NAME}-chaos
run-eventlog:build-eventlog
	${BIN_PATH}/${BASE_NAME}-eventlog \
	 --log.level=debug --discover.etcd.addr=http://127.0.0.1:2379 \
	 --db.url="root:admin@tcp(127.0.0.1:3306)/event" \
	 --dockerlog.mode=stream \
	 --message.dockerlog.handle.core.number=2 \
	 --message.garbage.file="/tmp/garbage.log" \
	 --docker.log.homepath="/Users/qingguo/tmp"
run-node:build-node
	${BIN_PATH}/${BASE_NAME}-node \
	 --run-mode=master --kube-conf=`pwd`/test/admin.kubeconfig \
	 --nodeid-file=`pwd`/test/host_id.conf \
	 --static-task-path=`pwd`/test/tasks \
	 --statsd.mapping-config=`pwd`/test/mapper.yml \
	 --log-level=debug

doc: ## build the docs 
	@cd cmd/api && swagger generate spec -o ../../hack/contrib/docker/api/html/swagger.json

help: ## this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\033[32m ❗❗❗ eventlog,entrance,chaos,mq,worker,webcli,api not support deb/rpm \033[0m"
	@echo "\033[32m ❗❗❗ node,grctl not support image \033[0m"
	@echo "\033[32m  plugin: node,grctl,eventlog,entrance,chaos,mq,worker,webcli,api  \033[0m"
	@echo "\033[32m   \033[0m"
	@echo "\033[36m 🤔 single plugin,how to work?   \033[0m"
	@echo "\033[01;34mmake build-<plugin>\033[0m Just like: make build-mq"
	@echo "\033[01;34mmake build-image-<plugin>\033[0m Just like: make build-image-mq"
	@echo "\033[01;34mmake run-<plugin>\033[0m Just like: make run-mq"
