CUSTOM_ISO:=freya.iso
IGNITION_FILE:=freya.ign
UPLOAD_SHARE:=//freyr.home.mpardalos.com/data
UPLOAD_DIR:=proxmox/template/iso

.PHONY: update-config
update-config: upload
	scripts/freya-reboot.sh

upload: $(CUSTOM_ISO)
	smbclient $(UPLOAD_SHARE) --directory $(UPLOAD_DIR) --no-pass --command "put $(CUSTOM_ISO)"
	touch upload

$(CUSTOM_ISO): base-iso $(IGNITION_FILE)
	rm -f $(CUSTOM_ISO)
	coreos-installer iso customize \
		--live-ignition $(IGNITION_FILE) \
		--output $(CUSTOM_ISO) \
		$(shell cat isos/base-iso)

# Contains the filename of the latest downloaded iso
isos/base-iso:
	mkdir -p isos
	coreos-installer download --stream stable --format iso --directory isos > isos/base-iso

.PHONY: update-iso
update-iso:
	rm isos/base-iso
	make isos/base-iso

%.ign: %.bu $(wildcard files/*)
	butane --strict --files-dir files --output $@ $<
