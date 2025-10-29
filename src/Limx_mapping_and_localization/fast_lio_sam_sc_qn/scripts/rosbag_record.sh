#!/bin/bash
set -euo pipefail

DATA_ROOT="/mnt/ssd512/prod_maps"
# TODO : 10hz / 20hz 구분 해야함
RAW_DATA_ROOT="/mnt/ssd512/raw_datasets/10hz"

if ! rosparam get /  >/dev/null 2>&1; then
  echo "[ERROR] ROS master is not running)"
  exit 1
fi

# RUN_ID(Asia/Seoul), RUN_DIR 생성 및 rosparam에 기록
RBT_ID="rbt-002"
RUN_ID="${RBT_ID}_$(TZ=Asia/Seoul date +%Y%m%d_%H%M%S)"
# RUN_ID="$(TZ=Asia/Seoul date +%Y%m%d_%H%M%S)"
RUN_DIR="${DATA_ROOT}/${RUN_ID}"
RAW_DIR="${RAW_DATA_ROOT}/${RUN_ID}"

mkdir -p "${RUN_DIR}"
mkdir -p "${RAW_DIR}"

rosparam set /data_collector/run_id "'${RUN_ID}'" || true
rosparam set /data_collector/run_dir "${RUN_DIR}" || true

echo "[INFO] RUN_ID=${RUN_ID}"
echo "[INFO] RUN_DIR=${RUN_DIR}"

META_PATH="${RUN_DIR}/params.yaml"

# 종료 시 결과 이동. EXIT에만 훅을 걸어 rosbag 인덱싱 완료 이후 실행되도록 함.
cleanup() {
  # rosparam에서 다시 가져와(혹시 스크립트 변수 유실 대비)
  RD="$(rosparam get /data_collector/run_dir 2>/dev/null || echo "${RUN_DIR}")"
  [[ -d "${RD}" ]] || RD="${RUN_DIR}"

  # 종료 시점 전체 파라미터 저장
  echo "params:" > "${META_PATH}"
  rosparam get / | sed 's/^/  /' >> "${META_PATH}"
  echo "[INFO] wrote all params -> ${META_PATH}"

  echo "[INFO] done. dataset folder: ${RD}"
}
# 스크립트가 종료될 때(EXIT 신호) cleanup 함수 실행
trap cleanup EXIT

# rosbag 기록 시작
BAG_FILE="${RAW_DIR}/raw.bag"
echo "[INFO] start rosbag -> ${BAG_FILE}"
rosbag record -O "${BAG_FILE}" /livox/lidar /livox/imu
# rosbag이 포그라운드로 실행됩니다.
# Ctrl+C를 누르면 rosbag이 안전 종료(인덱싱)되고,
# 그 직후 trap(EXIT)이 실행되어 결과가 이동됩니다.
