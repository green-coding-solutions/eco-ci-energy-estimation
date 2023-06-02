#!/bin/bash

model_name=$(cat /proc/cpuinfo  | grep "model name")

if [[ "$model_name" == *"8272CL"* ]]; then
    echo "Found 8272CL model"
    echo "ECO_CI_MODEL_NAME=8272CL" >> $GITHUB_ENV

    echo "ECO_CI_TDP=195" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_THREADS=52" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CORES=26" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_MAKE=intel" >> $GITHUB_ENV;
    echo "ECO_CI_RELEASE_YEAR=2019" >> $GITHUB_ENV;
    echo "ECO_CI_RAM=7" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_FREQ=2600" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CHIPS=1" >> $GITHUB_ENV;
    echo "ECO_CI_VHOST_RATIO=$(echo "2/52" | bc -l)" >> $GITHUB_ENV;

elif [[ "$model_name" == *"8370C"* ]]; then
    echo "Found 8370C model"
    echo "ECO_CI_MODEL_NAME=8370C" >> $GITHUB_ENV

    echo "ECO_CI_TDP=270" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_THREADS=64" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CORES=32" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_MAKE=intel" >> $GITHUB_ENV;
    echo "ECO_CI_RELEASE_YEAR=2021" >> $GITHUB_ENV;
    echo "ECO_CI_RAM=7" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_FREQ=2800" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CHIPS=1" >> $GITHUB_ENV;
    echo "ECO_CI_VHOST_RATIO=$(echo "2/64" | bc -l)" >> $GITHUB_ENV;

elif [[ "$model_name" == *"E5-2673 v4"* ]]; then
    echo "Found E5-2673 v4 model"
    echo "ECO_CI_MODEL_NAME=E5-2673v4" >> $GITHUB_ENV

    echo "ECO_CI_TDP=165" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_THREADS=52" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CORES=26" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_MAKE=intel" >> $GITHUB_ENV;
    echo "ECO_CI_RELEASE_YEAR=2018" >> $GITHUB_ENV;
    echo "ECO_CI_RAM=7" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_FREQ=2300" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CHIPS=1" >> $GITHUB_ENV;
    echo "ECO_CI_VHOST_RATIO=$(echo "2/52" | bc -l)" >> $GITHUB_ENV

elif [[ "$model_name" == *"E5-2673 v3"* ]]; then
    echo "Found E5-2673 v3 model"
    echo "ECO_CI_MODEL_NAME=E5-2673v3" >> $GITHUB_ENV

    echo "ECO_CI_TDP=110" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_THREADS=24" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CORES=12" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_MAKE=intel" >> $GITHUB_ENV;
    echo "ECO_CI_RELEASE_YEAR=2015" >> $GITHUB_ENV;
    echo "ECO_CI_RAM=7" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_FREQ=2400" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CHIPS=1" >> $GITHUB_ENV;
    echo "ECO_CI_VHOST_RATIO=$(echo "2/24" | bc -l)" >> $GITHUB_ENV

# model is underclocked
elif [[ "$model_name" == *"8171M"* ]]; then
    echo "Found 8171M model"
    echo "ECO_CI_MODEL_NAME=8171M" >> $GITHUB_ENV

    echo "ECO_CI_TDP=165" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_THREADS=52" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CORES=26" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_MAKE=intel" >> $GITHUB_ENV;
    echo "ECO_CI_RELEASE_YEAR=2018" >> $GITHUB_ENV;
    echo "ECO_CI_RAM=7" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_FREQ=2600" >> $GITHUB_ENV;
    echo "ECO_CI_CPU_CHIPS=1" >> $GITHUB_ENV;
    echo "ECO_CI_VHOST_RATIO=$(echo "2/52" | bc -l)" >> $GITHUB_ENV

else
    echo "⚠️ Unknown model $model_name for estimation, running default ..."  >> $GITHUB_STEP_SUMMARY
    echo "ECO_CI_MODEL_NAME=unknown" >> $GITHUB_ENV

fi