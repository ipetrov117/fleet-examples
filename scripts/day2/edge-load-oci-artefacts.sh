#!/bin/bash
set -e

list="edge-release-helm-oci-artefacts.txt"
source_registry=""
usage () {
    echo "USAGE: $0 [--artefact-list edge-helm-oci-artefacts.txt] --source-registry registry.suse.com --registry my.registry.com:5000"
    echo "  [-al|--artefact-list path] text file with list of images; one image per line."
    echo "  [-r|--registry registry:port] target private registry in the registry:port format."
    echo "  [-s|--source-registry registry:port] source registry in the registry:port format."
    echo "  [-h|--help] Usage message"
}

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
        -al|--artefact-list)
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
    usage
    exit 1
fi

if [[ -z "${list}" ]]; then
    usage
    exit 1
fi

if [[ $help ]]; then
    usage
    exit 0
fi

if [ ! -z "${source_registry}" ]; then
    source_registry="${source_registry}/"
fi

if ! command -v "helm" &> /dev/null; then
    echo "Script requires 'helm' to load images into the target registry."
    echo "For 'helm' installation instructions, see https://helm.sh/docs/intro/install/"
    exit 1
fi


temp_dir=/tmp/edge-release-oci-tgz-$(date +%Y%m%d)
mkdir -p ${temp_dir}
trap "rm -rf ${temp_dir}" EXIT

while IFS= read -r i; do
    [ -z "${i}" ] && continue

    arrI=(${i//:/ })
    if [[ ${#arrI[@]} -ne 2 ]]; then
        echo "Skipping incorrect entry: ${i}"
        continue
    fi
    
    helm pull oci://${source_registry}${arrI[0]} --version ${arrI[1]} --destination ${temp_dir}
done < "${list}"

for FILE in ${temp_dir}/*; do
    helm push ${FILE} oci://${target_registry}
done