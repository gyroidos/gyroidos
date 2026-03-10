GYROIDOS_DATAPART_EXTRA_SPACE := "2048"
GYROIDOS_DATAPART_EXTRA_SPACE:genericx86-64 := "8192"

prepare_device_conf:append () {
    bbnote "Enabling locally signed images"
    echo "locally_signed_images: true" >> ${WORKDIR}/device.conf

    if [ -z "$(grep 'signed_configs' ${WORKDIR}/device.conf)" ]; then
       bbnote "Disabling signature enforcement for container configuration in evaluation build"
       echo "signed_configs: false" >> ${WORKDIR}/device.conf
    fi
}
