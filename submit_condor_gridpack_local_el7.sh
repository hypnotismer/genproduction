#!/bin/bash

<<1
./submit_condor_gridpack_local_el7.sh \
  WH_012j_NLO_HToBBGamma_WToLNu \
  cards/WH_012j_NLO_HToBBGamma_WToLNu \
  /afs/cern.ch/user/z/zkou/hbbgamma/gridpack_logs/WH_012j_NLO_HToBBGamma_WToLNu \
  16 \
  16000 \
  40000000 \
  slc7_amd64_gcc700 \
  CMSSW_10_6_19

./submit_condor_gridpack_local_el7.sh \
  WZR_012j_NLO_WToLNu \
  cards/WZR_012j_NLO_WToLNu \
  /afs/cern.ch/user/z/zkou/hbbgamma/gridpack_logs/WZR_012j_NLO_WToLNu \
  16 \
  16000 \
  40000000 \
  slc7_amd64_gcc700 \
  CMSSW_10_6_19 \
  "50 75 100 125 150 175 200 225 250"
1


set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 NAME CARD_DIR [LOG_DIR] [REQUEST_CPUS] [REQUEST_MEMORY_MB] [REQUEST_DISK_KB] [SCRAM_ARCH] [CMSSW_VERSION] [MASS_LIST]"
  echo
  echo "Single gridpack:"
  echo "  $0 NAME CARD_DIR [LOG_DIR] [REQUEST_CPUS] [REQUEST_MEMORY_MB] [REQUEST_DISK_KB] [SCRAM_ARCH] [CMSSW_VERSION]"
  echo
  echo "Multiple mass points:"
  echo "  $0 BASE_NAME BASE_CARD_DIR [LOG_DIR] [REQUEST_CPUS] [REQUEST_MEMORY_MB] [REQUEST_DISK_KB] [SCRAM_ARCH] [CMSSW_VERSION] \"50 75 100\""
  echo
  echo "Gridpack tarballs are uploaded with xrdcp to:"
  echo "  \${EOS_GRIDPACK_DIR:-/eos/user/z/zkou/gridpacks}"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUNNER="${SCRIPT_DIR}/condor_run_gridpack_local_el7.sh"
SOURCE_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
MG_ROOT="${SOURCE_ROOT}/bin/MadGraph5_aMCatNLO"

NAME=$1
CARD_DIR=$2
OUTPUT_DIR=${3:-${SCRIPT_DIR}/condor_logs/${NAME}}
REQUEST_CPUS=${4:-16}
REQUEST_MEMORY_MB=${5:-16000}
REQUEST_DISK_KB=${6:-40000000}
SCRAM_ARCH=${7:-slc7_amd64_gcc700}
CMSSW_VERSION=${8:-CMSSW_10_6_19}
MASS_LIST=${9:-}

if [ ! -x "${RUNNER}" ]; then
  echo "ERROR: runner script is missing or not executable: ${RUNNER}"
  exit 1
fi

if [ ! -d "${MG_ROOT}" ]; then
  echo "ERROR: MadGraph root does not exist: ${MG_ROOT}"
  exit 1
fi

submit_one_job() {
  local job_name=$1
  local job_card_dir=$2
  local job_output_dir=$3
  local card_path="${MG_ROOT}/${job_card_dir}"

  if [ ! -d "${card_path}" ]; then
    echo "ERROR: card directory does not exist: ${card_path}"
    exit 1
  fi

  mkdir -p "${job_output_dir}"

  echo "Submitting ${job_name}"
  echo "  cards : ${job_card_dir}"
  echo "  logs  : ${job_output_dir}"

  condor_submit <<EOF
universe = vanilla
executable = ${RUNNER}
arguments = ${SOURCE_ROOT} ${job_name} ${job_card_dir} ${job_output_dir} ${SCRAM_ARCH} ${CMSSW_VERSION}
getenv = True
should_transfer_files = NO
request_cpus = ${REQUEST_CPUS}
request_memory = ${REQUEST_MEMORY_MB}
request_disk = ${REQUEST_DISK_KB}
+JobFlavour = "nextweek"
output = ${job_output_dir}/condor.\$(ClusterId).\$(ProcId).out
error = ${job_output_dir}/condor.\$(ClusterId).\$(ProcId).err
log = ${job_output_dir}/condor.\$(ClusterId).log
queue 1
EOF
}

if [ -z "${MASS_LIST}" ]; then
  submit_one_job "${NAME}" "${CARD_DIR}" "${OUTPUT_DIR}"
  exit 0
fi

IFS=', ' read -r -a MASSES <<< "${MASS_LIST}"

if [ "${#MASSES[@]}" -eq 0 ]; then
  echo "ERROR: MASS_LIST was provided but no mass points were parsed."
  exit 1
fi

for mass in "${MASSES[@]}"; do
  if [ -z "${mass}" ]; then
    continue
  fi

  job_name="${NAME}_M${mass}"
  job_card_dir="${CARD_DIR}/${job_name}"
  job_output_dir="${OUTPUT_DIR}/${job_name}"

  submit_one_job "${job_name}" "${job_card_dir}" "${job_output_dir}"
done
