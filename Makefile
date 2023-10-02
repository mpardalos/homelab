ISO:=fedora-coreos-38.20230902.3.0-live.x86_64.iso
CUSTOM_ISO:=freya.iso
IGNITION_FILE:=freya.ign
UPLOAD_SHARE:=//freyr.home.mpardalos.com/data
UPLOAD_DIR:=proxmox/template/iso

custom-iso: $(CUSTOM_ISO)
base-iso: $(ISO)

.PHONY: reimage
reimage: upload
	scripts/freya-reimage.sh

upload: $(CUSTOM_ISO)
	smbclient $(UPLOAD_SHARE) --directory $(UPLOAD_DIR) --no-pass --command "put $(CUSTOM_ISO)"
	touch upload

$(CUSTOM_ISO): $(ISO) $(IGNITION_FILE)
	rm -f $(CUSTOM_ISO)
	coreos-installer iso customize --dest-device /dev/vda --dest-ignition $(IGNITION_FILE) --output $(CUSTOM_ISO) $(ISO)

$(ISO):
	curl -LO https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/38.20230902.3.0/x86_64/fedora-coreos-38.20230902.3.0-live.x86_64.iso

%.ign: %.bu
	butane --strict --files-dir files --output $@ $<
