#!/bin/bash

source scripts/utils.sh

ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem


CHANNEL_NAME=${1:-"channel"}
CHANNEL_ID=${2:-"1"}
CC_NAME=${3}
CC_SRC_PATH=${4}
CC_SRC_LANGUAGE=${5}
CC_VERSION=${6:-"1.0"}
CC_SEQUENCE=${7:-"1"}
CC_INIT_FCN=${8:-"NA"}
CC_END_POLICY=${9:-"NA"}
CC_COLL_CONFIG=${10:-"NA"}
VERBOSE=${11:-"false"}
MODE=${12:-"package"}

println "executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CHANNEL_ID: ${C_GREEN}${CHANNEL_ID}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"


## 开始

packageChaincode() {
  set -x

  local _P=${PWD}

  cd ${CC_SRC_PATH}
  go env -w GO111MODULE=on
  go env -w GOPROXY=https://goproxy.cn,direct
  go mod vendor

  cd ${_P}
  peer lifecycle chaincode package ${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz --path ${CC_SRC_PATH} --label ${CC_NAME}_${CC_VERSION} >&log.txt

  mv ${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz ${PWD}/../chaincode/releases/
  
  docker cp ${PWD}/../chaincode/releases/${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz cli10:/opt/gopath/src/github.com/hyperledger/fabric/peer/
  docker cp ${PWD}/../chaincode/releases/${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz cli20:/opt/gopath/src/github.com/hyperledger/fabric/peer/
  docker cp ${PWD}/../chaincode/releases/${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz cli30:/opt/gopath/src/github.com/hyperledger/fabric/peer/


  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

# installChaincode PEER ORG
installChaincode() {
  set -x
  mv ${CC_NAME}_${CHANNEL_NAME}${CHANNEL_ID}.tar.gz ${CC_NAME}.tar.gz
  peer lifecycle chaincode install ${CC_NAME}.tar.gz 
  >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  peer lifecycle chaincode queryinstalled | tee /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/cc/package_id.txt
}

readPackageID() {
  PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" /opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/cc/package_id.txt)
}

approveForMyOrg() {
  readPackageID
  
  set -x
  peer lifecycle chaincode approveformyorg --tls true --cafile ${ORDERER_CA} --channelID ${CHANNEL_NAME}${CHANNEL_ID} --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

commitChaincodeDefinition() {
  set -x
  peer lifecycle chaincode commit  -o orderer.example.com:7050 --tls true --cafile $ORDERER_CA --channelID ${CHANNEL_NAME}${CHANNEL_ID} --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --peerAddresses peer0.org3.example.com:11051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
  >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

chaincodeInvokeInit() {
  set -x
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o orderer.example.com:7050 --tls true --cafile $ORDERER_CA -C ${CHANNEL_NAME}${CHANNEL_ID} -n ${CC_NAME}  --isInit -c ${fcn_call} --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --peerAddresses peer0.org3.example.com:11051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
  >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}


chaincodeInvokeTest() {
  infoln ""
  ## !!! 输入参数在 shell 中不要有空格
  # ### Org1MSP
  # infoln "测试 Produce"
  # chaincodeInvoke '{"function":"register","Args":["p1","t1","{\"name\":\"bj-P1\",\"producer\":\"bj\",\"address\":\"beijing\",\"date\":\"2021-05-01-12:00:00\",\"life\":\"-1\"}"]}' produce
  # sleep 5
  # chaincodeInvoke '{"function":"query","Args":["p1"]}' produce
  # ### Org2MSP
  # infoln "测试 Process"
  # chaincodeInvoke '{"function":"register","Args":["pp1","t1","{\"name\":\"cq-PP1\",\"type\":\"machine\",\"processor\":\"cq\",\"address\":\"chongqing\",\"date\":\"2021-05-10-23:00:00\",\"life\":\"-1\"}"]}' process
  # sleep 5
  # chaincodeInvoke '{"function":"query","Args":["pp1"]}' process
  # ### Org3MSP
  # infoln "测试 Transport"
  # chaincodeInvoke '{"function":"register","Args":["tt1","t1","{\"transporter\":\"Shunfeng\",\"originAddress\":\"chongqing\",\"targetAddress\":\"neimenggu\",\"startDate\":\"2021-05-11-7:00:00\",\"endDate\":\"2021-05-15-15:30:00\"}"]}' transport
  # sleep 5
  # chaincodeInvoke '{"function":"query","Args":["tt1"]}' transport
  # chaincodeInvoke '{"function":"query","Args":["t1"]}' trace

  # chaincodeInvoke '{"function":"queryHistory","Args":["t1"]}' trace
}

chaincodeInvoke() {
  set -x
  local fcn_call=$1
  local cc_name=$2
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o orderer.example.com:7050 --tls true --cafile $ORDERER_CA --channelID ${CHANNEL_NAME}${CHANNEL_ID} --name ${cc_name} --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --peerAddresses peer0.org3.example.com:11051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/orgs/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt -c ${fcn_call}
  >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
}

if [ "${MODE}" == "package" ]; then
  packageChaincode
elif [ "${MODE}" == "install" ]; then
  installChaincode
elif [ "${MODE}" == "approve" ]; then
  approveForMyOrg
elif [ "${MODE}" == "commit" ]; then
  commitChaincodeDefinition
elif [ "${MODE}" == "init" ]; then
  chaincodeInvokeInit
elif [ "${MODE}" == "test" ]; then
  chaincodeInvokeTest
else
  printHelp
  exit 1
fi