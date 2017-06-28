#!/bin/bash -e

echo "Step 1 - Checking for Proxy"

if [[ ! -z "$NO_PROXY" ]]; then
  echo "$OM_IP $OPS_MGR_HOST" >> /etc/hosts
fi

echo "Step 2 - Checking for Stemcell Version"

STEMCELL_VERSION=`cat ./pivnet-product/metadata.json | jq --raw-output '.Dependencies[] | select(.Release.Product.Name | contains("Stemcells")) | .Release.Version'`

echo "Step 2 Output. Stemcell Version = "
echo "$STEMCELL_VERSION"

if [ -n "$STEMCELL_VERSION" ]; then
  diagnostic_report=$(
    om-linux \
      --target https://$OPS_MGR_HOST \
      --username $OPS_MGR_USR \
      --password $OPS_MGR_PWD \
      --skip-ssl-validation
  )

  echo "Step 3"

  stemcell=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
    '.stemcells[] | select(contains($version) and contains($glob))'
  )

  echo "Step 4"

  if [[ -z "$stemcell" ]]; then
    echo "Downloading stemcell $STEMCELL_VERSION"
    pivnet-cli login --api-token="$PIVNET_API_TOKEN"
    pivnet-cli download-product-files -p stemcells -r $STEMCELL_VERSION -g "*${IAAS}*" --accept-eula

    SC_FILE_PATH=`find ./ -name *.tgz`

    echo "Step 5. SC File Path = "
    echo "$SC_FILE_PATH"

    if [ ! -f "$SC_FILE_PATH" ]; then
      echo "Stemcell file not found!"
      exit 1
    fi

    om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-stemcell -s $SC_FILE_PATH

    echo "Step 6. Completed "

    echo "Removing downloaded stemcell $STEMCELL_VERSION"
    rm $SC_FILE_PATH
  fi
fi

echo "Step 7. Upload Product. "

FILE_PATH=`find ./pivnet-product -name *.pivotal`

echo "Step 8. Product File Path =  "
echo "$FILE_PATH"

om-linux -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k upload-product -p $FILE_PATH
