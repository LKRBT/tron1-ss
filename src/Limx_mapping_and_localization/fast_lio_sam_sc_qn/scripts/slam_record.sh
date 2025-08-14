#!/bin/bash
set -euo pipefail

DATA_ROOT="/mnt/ssd512/slam_datasets"
RESULT_SRC_DIR="/workspaces/lk_tron/catkin_ws/src/tron1-ss/src/Limx_mapping_and_localization/fast_lio_sam_sc_qn"
WAIT_MAX_SEC="${WAIT_MAX_SEC:-30}"   # 결과 파일이 생성될 때까지 최대 N초 대기. 기본 30초

if ! rosparam get /  >/dev/null 2>&1; then
  echo "[ERROR] ROS master is not running)"
  exit 1
fi

# RUN_ID(Asia/Seoul), RUN_DIR 생성 및 rosparam에 기록
RUN_ID="$(TZ=Asia/Seoul date +%Y%m%d_%H%M%S)"
RUN_DIR="${DATA_ROOT}/${RUN_ID}"

mkdir -p "${RUN_DIR}"

rosparam set /data_collector/run_id "'${RUN_ID}'" || true
rosparam set /data_collector/run_dir "${RUN_DIR}" || true

echo "[INFO] RUN_ID=${RUN_ID}"
echo "[INFO] RUN_DIR=${RUN_DIR}"

# SLAM 결과 파일이 늦게 생성/flush될 수 있으므로, 최대 WAIT_MAX_SEC 동안 폴링 대기
wait_for_file() {
  # 주어진 경로의 파일이 나타날 때까지 1초 간격으로 최대 WAIT_MAX_SEC초 대기
  local path="$1"
  local waited=0
  while [ ! -f "$path" ] && [ "$waited" -lt "$WAIT_MAX_SEC" ]; do
    sleep 1
    waited=$((waited+1))
  done
  [ -f "$path" ]
}

# 결과 파일 이동 로직 중복 제거용 함수
move_result_file() {
  local filename="$1"
  local src="${RESULT_SRC_DIR}/${filename}"
  local dst_dir="$2"

  if [[ -f "${src}" ]]; then
    mv -f "${src}" "${dst_dir}/${filename}"
    echo "[INFO] moved ${filename} -> ${dst_dir}/${filename}"
  else
    if wait_for_file "${src}"; then
      mv -f "${src}" "${dst_dir}/${filename}"
      echo "[INFO] moved ${filename} -> ${dst_dir}/${filename}"
    else
      echo "[WARN] ${filename} not found within ${WAIT_MAX_SEC}s at ${RESULT_SRC_DIR}"
    fi
  fi
}

META_PATH="${RUN_DIR}/meta.yaml"

# 종료 시 결과 이동. EXIT에만 훅을 걸어 rosbag 인덱싱 완료 이후 실행되도록 함.
cleanup() {
  # rosparam에서 다시 가져와(혹시 스크립트 변수 유실 대비)
  RD="$(rosparam get /data_collector/run_dir 2>/dev/null || echo "${RUN_DIR}")"
  [[ -d "${RD}" ]] || RD="${RUN_DIR}"

  # 종료 시점 전체 파라미터 저장
  echo "params:" > "${META_PATH}"
  rosparam get / | sed 's/^/  /' >> "${META_PATH}"
  echo "[INFO] wrote all params -> ${META_PATH}"

  # 결과 이동(존재할 때만) - 중복 로직을 함수로 대체
  move_result_file "result.pcd" "${RD}"
  move_result_file "result.bag" "${RD}"

  echo "[INFO] done. dataset folder: ${RD}"
}
trap cleanup EXIT

# rosbag 기록 시작
BAG_FILE="${RUN_DIR}/raw.bag"
echo "[INFO] start rosbag -> ${BAG_FILE}"
rosbag record -O "${BAG_FILE}" /livox/lidar /livox/imu
# rosbag이 포그라운드로 실행됩니다.
# Ctrl+C를 누르면 rosbag이 안전 종료(인덱싱)되고,
# 그 직후 trap(EXIT)이 실행되어 결과가 이동됩니다.
