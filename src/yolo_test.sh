#!/bin/bash
############################################################################################################
# This script does the following:
# - Downloads the offical Yolo repo from github
# - Fixes an issue that has been identified but not corrected in the repo
# - Creates a Dockerfile and generates an image based on nvidia cuda with Yolo and required python tooling
# - Spins up container from the image and runs a detection against an image shipped with the repo
# NOTE: This script assumes that you have installed and configured the NVIDIA container toolkit.
#       https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
#       However, by changing the final command to use --device cpu, you can ignore that requirement.
############################################################################################################

set -x 

WORK_DIR=$PWD
WORK_DIR="${WORK_DIR%/}/"

MODEL='yolov9-c.pt'
MODELS_DIR='models/'
MODELS_URL='https://github.com/WongKinYiu/yolov9/releases/download/v0.1/'
YOLO_DIR='yolov9/'
YOLO_URL='https://github.com/WongKinYiu/yolov9.git'

IMAGE_NAME='yolo9'

# Download yolov9 if hasn't been already downloaded
if ! [ -d "${WORK_DIR}""${YOLO_DIR}" ]; then
  mkdir "${WORK_DIR}""${YOLO_DIR}"
  git clone "${YOLO_URL}" "${WORK_DIR}""${YOLO_DIR}"
  curl -L "${MODELS_URL}""${MODEL}" -o "${WORK_DIR}""${YOLO_DIR}""${MODELS_DIR}""${MODEL}"

  # fix problem with yolo 
  # https://github.com/WongKinYiu/yolov9/issues/11#issuecomment-1972487764
  CORRECT_ELEMENT='prediction\[0\]\[1\]'
  INCORRECT_ELEMENT='prediction\[0\]'

  if ! grep -R "${CORRECT_ELEMENT}" "${WORK_DIR}""${YOLO_DIR}"/utils/general.py
  then 
    # double quotes required for variable substitution in sed string
    sed -i "s/${INCORRECT_ELEMENT}/${CORRECT_ELEMENT}/" "${WORK_DIR}""${YOLO_DIR}"/utils/general.py
  fi
fi

# Create Dockerfile for yolo container if it doesn't already exist
if ! [ -f "${WORK_DIR}""${YOLO_DIR}"Dockerfile ]; then
  echo 'FROM nvidia/cuda:12.3.2-base-ubuntu22.04
  ENV DEBIAN_FRONTEND=nonintercative
  RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get install -y python3-pip libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6
  RUN ln -fs /usr/bin/python3 /usr/bin/python
  COPY . ./yolo
  WORKDIR /yolo
  RUN pip install --no-cache-dir -r requirements.txt' > "${WORK_DIR}""${YOLO_DIR}"Dockerfile
  
  chmod a+rx "${WORK_DIR}""${YOLO_DIR}"/Dockerfile
fi

cd "${WORK_DIR}""${YOLO_DIR}" || exit

docker build -t "${IMAGE_NAME}" .

# To run using the CPU instead of the GPU, change --device 0 to --device cpu
docker run --gpus all --rm --name yolov9 -v "./runs:/yolo/runs" "${IMAGE_NAME}" \
    python detect.py --weights /yolo/"${MODELS_DIR}""${MODEL}" --source /yolo/data/images/horses.jpg --device 0