.PHONY: check tun-on tun-off fix-1080 fix-vscode disk-rescue

check:
	./scripts/00_check.sh

tun-on:
	./scripts/20_tun_on.sh

tun-off:
	./scripts/21_tun_off.sh

fix-1080:
	./scripts/10_fix_proxy_1080.sh

fix-vscode:
	./scripts/11_fix_vscode_settings_proxy.py zhangfanlong

disk-rescue:
	./scripts/30_disk_rescue.sh
