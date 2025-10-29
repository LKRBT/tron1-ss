#!/bin/bash
set -euo pipefail

DATA_ROOT="/mnt/ssd512/slam_datasets"
RESULT_SRC_DIR="/workspaces/lk_tron/catkin_ws/src/tron1-ss/src/Limx_mapping_and_localization/fast_lio_sam_sc_qn"

if ! rosparam get /  >/dev/null 2>&1; then
  echo "[ERROR] ROS master is not running)"
  exit 1
fi

# RUN_ID="20250924_100919"
RUN_ID="20251024_151523"
# TODO : 사용 전, RUN_ID를 변경한다.
RUN_DIR="${DATA_ROOT}/${RUN_ID}"

# 수정(추가)된 항목
# RUN_DIR가 이미 존재하면 _1, _2, _3 ... 식으로 가장 작은 가용 번호를 찾아서 폴더명을 결정
# 설명: 기존 폴더는 덮어쓰거나 삭제하지 않으며, 비어있는 번호를 찾아 RUN_DIR를 갱신
if [[ -d "${RUN_DIR}" ]]; then
  i=1
  while [[ -d "${RUN_DIR}_${i}" ]]; do
    i=$((i+1))
  done
  # 수정(추가)된 항목
  # 실제 저장 위치를 가용 번호가 붙은 폴더로 변경
  RUN_DIR="${RUN_DIR}_${i}"
  echo "[INFO] base folder exists; using '${RUN_DIR}'"
fi

# 최종 결정된 RUN_DIR를 생성
mkdir -p "${RUN_DIR}"

# 결과 파일 존재 시 이동
move_result_file() {
  local filename="$1"
  local src="${RESULT_SRC_DIR}/${filename}"
  local dst_dir="$2"

  if [[ -f "${src}" ]]; then
    mv -f "${src}" "${dst_dir}/${filename}"
    echo "[INFO] moved ${filename} -> ${dst_dir}/${filename}"
  else
    echo "[WARN] ${filename} not found at ${RESULT_SRC_DIR}"
  fi
}

META_PATH="${RUN_DIR}/params.yaml"

# 스크립트 실행 즉시 파라미터 저장 및 결과 이동 수행.
echo "params:" > "${META_PATH}"
rosparam get / | sed 's/^/  /' >> "${META_PATH}"
echo "[INFO] wrote all params -> ${META_PATH}"

move_result_file "result.pcd" "${RUN_DIR}"
move_result_file "result.bag" "${RUN_DIR}"

echo "[INFO] done. dataset folder: ${RUN_DIR}"
