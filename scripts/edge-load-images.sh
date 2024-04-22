#!/bin/bash
list="edge-release-images.txt"
source_registry=""

usage () {
    echo "USAGE: $0 [--image-list edge-release-images.txt]"
    echo "  [-s|--source-registry] source registry to pull images from in registry:port format e.g. docker.io."
    echo "  [-l|--image-list path] text file with list of images; one image per line."
    echo "  [-r|--registry registry:port] target private registry in the registry:port format."
    echo "  [-h|--help] Usage message"
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--registry)
        target_registry="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--source-registry)
        source_registry="$2"
        shift # past argument
        shift # past value
        ;;
        -l|--image-list)
        list="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        help="true"
        shift
        ;;
        *)
        usage
        exit 1
        ;;
    esac
done

if [[ -z "${target_registry}" ]]; then
    echo "Missing -r|--registry"
    usage
    exit 1
fi

if [[ -z "${list}" ]]; then
    echo "Missing -l|--image-list"
    usage
    exit 1
fi

if [ -z "${source_registry}" ]; then
    echo "-s|--source-registry"
    usage
    exit 1
fi

if [[ $help ]]; then
    usage
    exit 0
fi

temp_dir=/tmp/edge-release-images-tgz-$(date +%Y%m%d)
mkdir -p ${temp_dir}
trap "rm -rf ${temp_dir}" EXIT

images=${temp_dir}/edge-release-images.tar.gz

pulled=""
while IFS= read -r i; do
    [ -z "${i}" ] && continue
    i="${source_registry}/${i}"
    if docker pull "${i}" > /dev/null 2>&1; then
        echo "Image pull success: ${i}"
        pulled="${pulled} ${i}"
    else
        if docker inspect "${i}" > /dev/null 2>&1; then
            pulled="${pulled} ${i}"
        else
            echo "Image pull failed: ${i}"
        fi
    fi
done < "${list}"

echo "Creating ${images} with $(echo ${pulled} | wc -w | tr -d '[:space:]') images"
docker save $(echo ${pulled}) | gzip --stdout > ${images}

echo "Loading ${images}"
docker load --input ${images}

echo "Pushing image to ${target_registry}"
linux_images=()
while IFS= read -r i; do
    [ -z "${i}" ] && continue
    linux_images+=("${i}");
done < "${list}"

for i in "${linux_images[@]}"; do
    [ -z "${i}" ] && continue

    docker tag "${source_registry}/${i}" "${target_registry}/${i}"
    docker push "${image_name}"
done