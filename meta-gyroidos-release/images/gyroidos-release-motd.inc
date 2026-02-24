overwrite_motd () {
	echo "THIS IS AN EVALUATION RELEASE!" > ${IMAGE_ROOTFS}/etc/motd
	echo "" >> ${IMAGE_ROOTFS}/etc/motd

}

ROOTFS_POSTPROCESS_COMMAND:append = " overwrite_motd; "
